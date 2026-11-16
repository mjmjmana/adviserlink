import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../components/project_documents.dart';
import '../theme.dart';
import '../ui.dart';

class ProjectScreen extends StatefulWidget {
  final int applicationId;
  final bool milestones;

  const ProjectScreen({
    super.key,
    required this.applicationId,
    this.milestones = false,
  });

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  late Future<dynamic> _data;

  bool get _isAdviser => Api.user?['role'] == 'adviser';
  bool get _isStudent => Api.user?['role'] == 'student';

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<dynamic> _load() => widget.milestones
      ? Api.milestones(widget.applicationId)
      : Api.board(widget.applicationId);

  Future<void> _reload() async {
    final request = _load();
    setState(() => _data = request);
    await request;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _LoadError(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return widget.milestones
              ? _milestoneList(snapshot.data as List<dynamic>)
              : _board(Map<String, dynamic>.from(snapshot.data as Map));
        },
      );

  Widget _board(Map<String, dynamic> board) {
    final tasks = board['tasks'] as List<dynamic>? ?? const [];
    final progress = board['progress'] as Map? ?? const {};
    final total = progress['total'] as int? ?? 0;
    final done = progress['done'] as int? ?? 0;
    final columns = <String, List<Map<String, dynamic>>>{
      'To Do': [],
      'In progress': [],
      'For review': [],
      'Done': [],
    };
    for (final raw in tasks) {
      final task = Map<String, dynamic>.from(raw as Map);
      final column = switch ('${task['status'] ?? 'todo'}') {
        'in_progress' => 'In progress',
        'review' => 'For review',
        'done' => 'Done',
        _ => 'To Do',
      };
      columns[column]!.add(task);
    }
    final canComment = board['can_comment'] == true;
    final canManage = board['can_manage'] == true || board['can_manage'] == 1;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Progress board',
                  style: context.text3xl.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.textColor,
                  ),
                ),
              ),
              if (_isAdviser)
                IconButton.filled(
                  onPressed: _addTask,
                  tooltip: 'Add task',
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
          Text(
            '${board['application']?['topic_brief'] ?? 'Your shared research project'}',
            style: context.textBase.copyWith(color: context.textMuted),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.track_changes),
              title: Text(
                total == 0 ? 'No tasks yet' : '$done of $total tasks complete',
              ),
              subtitle: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 6,
              ),
            ),
          ),
          if (tasks.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No tasks on the board yet.'),
                subtitle:
                    Text('Your adviser can add a task when work is ready.'),
              ),
            ),
          for (final entry in columns.entries) ...[
            if (entry.value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                child: Text(
                  entry.key,
                  style: context.textLg.copyWith(
                    color: context.textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            for (final task in entry.value)
              _taskCard(
                task,
                canComment: canComment,
                canManage: canManage,
              ),
          ],
          const SizedBox(height: 12),
          ProjectDocumentsPanel(
            applicationId: widget.applicationId,
            canManage: canManage,
            canUploadVersions: _isStudent && canManage,
            onChanged: _reload,
          ),
        ],
      ),
    );
  }

  Widget _taskCard(
    Map<String, dynamic> task, {
    required bool canComment,
    required bool canManage,
  }) {
    final id = task['task_id'] as int;
    final status = '${task['status'] ?? 'todo'}';
    final comments = task['comments'] as List<dynamic>? ?? const [];
    final documents = task['documents'] as List<dynamic>? ?? const [];
    final isLeader = _isStudent && canManage;
    return Card(
      child: ExpansionTile(
        leading: Icon(status == 'done'
            ? Icons.check_circle_outline
            : Icons.radio_button_unchecked),
        title: Text('${task['title'] ?? 'Task'}'),
        subtitle: Text(
          [
            if ((task['description'] as String? ?? '').isNotEmpty)
              task['description'],
            if (task['due_date'] != null) 'Due ${task['due_date']}',
            'Stage: ${_taskStatus(status)}',
          ].join('\n'),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (documents.isNotEmpty) ...[
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Task files',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final raw in documents)
              _documentTile(Map<String, dynamic>.from(raw as Map),
                  canDelete: isLeader),
          ],
          if (comments.isNotEmpty) ...[
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Comments',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final raw in comments)
              _commentTile(Map<String, dynamic>.from(raw as Map)),
          ],
          if (canComment)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _addComment(task),
                icon: const Icon(Icons.comment_outlined),
                label: const Text('Comment / attach file'),
              ),
            ),
          if (isLeader && status == 'in_progress')
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _attachWork(task),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload work'),
                ),
                FilledButton(
                  onPressed: () => _setTaskStatus(id, 'review'),
                  child: const Text('Submit for review'),
                ),
              ],
            ),
          if (isLeader && status == 'todo')
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _setTaskStatus(id, 'in_progress'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start task'),
              ),
            ),
          if (_isAdviser && status == 'review')
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _setTaskStatus(id, 'in_progress'),
                  child: const Text('Return for revision'),
                ),
                FilledButton(
                  onPressed: () => _setTaskStatus(id, 'done'),
                  child: const Text('Mark done'),
                ),
              ],
            ),
          if (_isAdviser)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  TextButton.icon(
                    onPressed: () => _editTask(task),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteTask(task),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _commentTile(Map<String, dynamic> comment) {
    final attachment = comment['attachment'] as Map?;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${comment['author_name'] ?? 'User'}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${comment['body'] ?? ''}'),
          if (attachment != null)
            TextButton.icon(
              onPressed: () => _downloadFile(
                attachment['document_id'] as int,
                '${attachment['filename'] ?? 'attachment'}',
              ),
              icon: const Icon(Icons.attach_file),
              label: Text('${attachment['filename'] ?? 'Attachment'}'),
            ),
        ],
      ),
    );
  }

  Widget _documentTile(Map<String, dynamic> document,
      {required bool canDelete}) {
    final id = document['document_id'] as int;
    final uploadedBy = document['uploaded_by'];
    final isMine = uploadedBy == Api.user?['user_id'];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.insert_drive_file_outlined),
      title: Text('${document['filename'] ?? 'File'}'),
      subtitle: Text('${document['uploaded_by_name'] ?? 'Uploaded'}'),
      onTap: () => _downloadFile(id, '${document['filename'] ?? 'file'}'),
      trailing: canDelete && isMine
          ? IconButton(
              tooltip: 'Delete file',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteDocument(id),
            )
          : const Icon(Icons.download_outlined),
    );
  }

  Future<void> _downloadFile(int id, String filename) async {
    try {
      final bytes = await Api.downloadDocument(id);
      final path = await Api.saveDownloadedFile(filename, bytes);
      if (mounted && path != null) snack(context, 'File saved.');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<PlatformFile?> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  Future<void> _attachWork(Map<String, dynamic> task) async {
    try {
      final file = await _pickFile();
      if (file == null) return;
      final Uint8List? bytes = file.bytes;
      if (bytes == null) {
        throw ApiException('The selected file could not be read.');
      }
      await Api.uploadDocumentBytes(
        widget.applicationId,
        file.name,
        bytes,
        category: 'in_progress',
        taskId: task['task_id'] as int,
      );
      if (mounted) snack(context, 'Work attached to this task.');
      await _reload();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _addComment(Map<String, dynamic> task) async {
    final controller = TextEditingController();
    PlatformFile? file;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Task comment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 5,
                maxLength: 2000,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Comment',
                  alignLabelWithHint: true,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    try {
                      final picked = await _pickFile();
                      if (picked != null) setDialogState(() => file = picked);
                    } catch (e) {
                      if (mounted) snack(context, e.toString(), error: true);
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                      file == null ? 'Attach a file (optional)' : file!.name),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: controller.text.trim().isNotEmpty
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Send comment'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) {
      controller.dispose();
      return;
    }
    try {
      if (file != null && file!.bytes == null) {
        throw ApiException('The selected attachment could not be read.');
      }
      await Api.addTaskComment(
        task['task_id'] as int,
        controller.text.trim(),
        fileName: file?.name,
        bytes: file?.bytes,
      );
      if (mounted) snack(context, 'Comment sent.');
      await _reload();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteDocument(int documentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this file?'),
        content: const Text('This removes the file from the task.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deleteDocument(documentId);
      await _reload();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _setTaskStatus(int taskId, String status) async {
    try {
      await Api.updateTask(taskId, {'status': status});
      await _reload();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _addTask() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final dueDate = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add project task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  maxLength: 150,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(labelText: 'Task title'),
                ),
                TextField(
                    controller: description,
                    maxLength: 2000,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Instructions (optional)')),
                TextField(
                    controller: dueDate,
                    decoration: const InputDecoration(
                        labelText: 'Due date (YYYY-MM-DD, optional)')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: title.text.trim().isNotEmpty
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Add task'),
            ),
          ],
        ),
      ),
    );
    if (submitted == true) {
      try {
        await Api.addTask(
          widget.applicationId,
          title.text.trim(),
          description.text.trim(),
          dueDate.text.trim().isEmpty ? null : dueDate.text.trim(),
        );
        await _reload();
      } catch (e) {
        if (mounted) snack(context, e.toString(), error: true);
      }
    }
    title.dispose();
    description.dispose();
    dueDate.dispose();
  }

  Future<void> _editTask(Map<String, dynamic> task) async {
    final title = TextEditingController(text: '${task['title'] ?? ''}');
    final description =
        TextEditingController(text: '${task['description'] ?? ''}');
    final dueDate = TextEditingController(text: '${task['due_date'] ?? ''}');
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  maxLength: 150,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(labelText: 'Task title'),
                ),
                TextField(
                    controller: description,
                    maxLength: 2000,
                    minLines: 2,
                    maxLines: 4,
                    decoration:
                        const InputDecoration(labelText: 'Instructions')),
                TextField(
                    controller: dueDate,
                    decoration: const InputDecoration(
                        labelText: 'Due date (YYYY-MM-DD, optional)')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: title.text.trim().isNotEmpty
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (submitted == true) {
      try {
        await Api.updateTask(task['task_id'] as int, {
          'title': title.text.trim(),
          'description': description.text.trim(),
          'due_date': dueDate.text.trim().isEmpty ? null : dueDate.text.trim(),
        });
        await _reload();
      } catch (e) {
        if (mounted) snack(context, e.toString(), error: true);
      }
    }
    title.dispose();
    description.dispose();
    dueDate.dispose();
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this task?'),
        content: const Text('Its comments will also be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deleteTask(task['task_id'] as int);
      await _reload();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  String _taskStatus(String status) => switch (status) {
        'in_progress' => 'In progress',
        'review' => 'For review',
        'done' => 'Done',
        _ => 'To Do',
      };

  Widget _milestoneList(List<dynamic> milestones) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Milestones',
                  style: context.text3xl.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.textColor,
                  ),
                ),
              ),
              if (_isAdviser)
                IconButton.filled(
                  onPressed: _addMilestone,
                  tooltip: 'Add milestone',
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
          if (milestones.isEmpty)
            Card(
              child: ListTile(
                title: Text(_isAdviser
                    ? 'No milestones added yet.'
                    : 'Your adviser has not added any milestones yet.'),
              ),
            ),
          for (final raw in milestones)
            _milestoneCard(Map<String, dynamic>.from(raw as Map)),
        ],
      ),
    );
  }

  Widget _milestoneCard(Map<String, dynamic> milestone) {
    final status = '${milestone['status'] ?? 'pending'}';
    final id = milestone['milestone_id'] as int;
    return Card(
      child: ListTile(
        leading: Icon(
          status == 'completed' ? Icons.check_circle : Icons.flag_outlined,
          color: status == 'completed'
              ? context.successColor()
              : context.brandPrimary,
        ),
        title: Text('${milestone['title'] ?? 'Milestone'}'),
        subtitle: Text(
          [
            if ((milestone['description'] as String? ?? '').isNotEmpty)
              milestone['description'],
            if (milestone['due_date'] != null) 'Due ${milestone['due_date']}',
            'Status: ${_label(status)}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: _isAdviser
            ? PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') _editMilestone(milestone);
                  if (action == 'delete') _deleteMilestone(id);
                  if (action.startsWith('status:')) {
                    _setMilestoneStatus(id, action.substring(7));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  for (final value in ['pending', 'in_progress', 'completed'])
                    PopupMenuItem(
                        value: 'status:$value',
                        child: Text('Mark ${_label(value)}')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              )
            : null,
      ),
    );
  }

  Future<void> _setMilestoneStatus(int id, String status) async {
    try {
      await Api.updateMilestone(id, {'status': status});
      await _reload();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<Map<String, String>?> _milestoneForm(
      {Map<String, dynamic>? existing}) async {
    final title = TextEditingController(text: '${existing?['title'] ?? ''}');
    final description =
        TextEditingController(text: '${existing?['description'] ?? ''}');
    final dueDate =
        TextEditingController(text: '${existing?['due_date'] ?? ''}');
    const stages = [
      'title_defense',
      'chapters_1_3',
      'proposal_defense',
      'final_defense',
      'custom',
    ];
    var stage = stages.contains(existing?['stage'])
        ? '${existing?['stage']}'
        : 'custom';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add milestone' : 'Edit milestone'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: title,
                    maxLength: 150,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(labelText: 'Title')),
                TextField(
                    controller: description,
                    maxLength: 2000,
                    minLines: 2,
                    maxLines: 4,
                    decoration:
                        const InputDecoration(labelText: 'Description')),
                DropdownButtonFormField<String>(
                  initialValue: stage,
                  decoration: const InputDecoration(labelText: 'Stage'),
                  items: [
                    for (final value in stages)
                      DropdownMenuItem(
                          value: value, child: Text(_label(value))),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => stage = value);
                  },
                ),
                TextField(
                    controller: dueDate,
                    decoration: const InputDecoration(
                        labelText: 'Due date (YYYY-MM-DD, optional)')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: title.text.trim().isNotEmpty
                  ? () => Navigator.pop(dialogContext, {
                        'title': title.text.trim(),
                        'description': description.text.trim(),
                        'stage': stage,
                        'due_date': dueDate.text.trim(),
                      })
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    description.dispose();
    dueDate.dispose();
    return result;
  }

  Future<void> _addMilestone() async {
    final values = await _milestoneForm();
    if (values == null) return;
    try {
      await Api.addMilestone(
        widget.applicationId,
        values['title']!,
        values['description']!,
        values['stage']!,
        values['due_date']!.isEmpty ? null : values['due_date'],
      );
      await _reload();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _editMilestone(Map<String, dynamic> milestone) async {
    final values = await _milestoneForm(existing: milestone);
    if (values == null) return;
    try {
      await Api.updateMilestone(milestone['milestone_id'] as int, {
        'title': values['title'],
        'description': values['description'],
        'stage': values['stage'],
        'due_date': values['due_date']!.isEmpty ? null : values['due_date'],
      });
      await _reload();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _deleteMilestone(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete milestone?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deleteMilestone(id);
      await _reload();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  String _label(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}
