import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../ui.dart';

class ProjectDocumentsPanel extends StatefulWidget {
  final int applicationId;
  final bool canManage;
  final bool canUploadVersions;
  final Future<void> Function()? onChanged;

  const ProjectDocumentsPanel({
    super.key,
    required this.applicationId,
    required this.canManage,
    required this.canUploadVersions,
    this.onChanged,
  });

  @override
  State<ProjectDocumentsPanel> createState() => _ProjectDocumentsPanelState();
}

class _ProjectDocumentsPanelState extends State<ProjectDocumentsPanel> {
  static const _categories = {
    'todo': 'To do',
    'in_progress': 'In progress',
    'review': 'For review',
  };
  List<dynamic> _documents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final documents = await Api.documents(widget.applicationId);
      if (!mounted) return;
      setState(() {
        _documents = documents;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _download(Map<String, dynamic> document) async {
    try {
      final bytes = await Api.downloadDocument(document['document_id'] as int);
      final path = await Api.saveDownloadedFile(
          '${document['filename'] ?? 'project-file'}', bytes);
      if (mounted && path != null) snack(context, 'File saved.');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> document) async {
    final id = document['document_id'] as int;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete project file?'),
        content:
            Text('${document['filename'] ?? 'This file'} will be removed.'),
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
    if (confirmed != true) return;
    try {
      await Api.deleteDocument(id);
      await _load();
      await widget.onChanged?.call();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shared project files',
                style: context.textLg.copyWith(
                    color: context.textColor, fontWeight: FontWeight.w700)),
            if (_loading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              ListTile(
                title: Text(_error!,
                    style: TextStyle(color: context.errorColor())),
                trailing: IconButton(
                  onPressed: _load,
                  tooltip: 'Retry',
                  icon: const Icon(Icons.refresh),
                ),
              )
            else if (_documents.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('No shared files yet.',
                    style: TextStyle(color: context.textMuted)),
              )
            else
              for (final raw in _documents)
                _documentTile(Map<String, dynamic>.from(raw as Map)),
          ],
        ),
      );

  Widget _documentTile(Map<String, dynamic> document) {
    final id = document['document_id'] as int;
    final uploadedBy = document['uploaded_by'];
    final canDelete = widget.canManage &&
        Api.user?['role'] == 'student' &&
        uploadedBy == Api.user?['user_id'];
    final category = _categories['${document['category']}'] ??
        '${document['category'] ?? 'Project file'}';
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.insert_drive_file_outlined),
        title: Text('${document['filename'] ?? 'Project file'}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle:
            Text('$category · ${document['uploaded_by_name'] ?? 'Uploaded'}'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _download(document),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download'),
                ),
              ),
              if (canDelete)
                IconButton(
                  onPressed: () => _delete(document),
                  tooltip: 'Delete project file',
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          _DocumentVersionsPanel(
            key: ValueKey('versions-$id'),
            documentId: id,
            canUpload: widget.canUploadVersions,
            onChanged: () async {
              await _load();
              await widget.onChanged?.call();
            },
          ),
        ],
      ),
    );
  }
}

class _DocumentVersionsPanel extends StatefulWidget {
  final int documentId;
  final bool canUpload;
  final Future<void> Function()? onChanged;

  const _DocumentVersionsPanel({
    super.key,
    required this.documentId,
    required this.canUpload,
    this.onChanged,
  });

  @override
  State<_DocumentVersionsPanel> createState() => _DocumentVersionsPanelState();
}

class _DocumentVersionsPanelState extends State<_DocumentVersionsPanel> {
  List<dynamic> _versions = [];
  bool _expanded = false;
  bool _loading = false;
  bool _uploading = false;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final versions = await Api.documentVersions(widget.documentId);
      if (!mounted) return;
      setState(() {
        _versions = versions;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _upload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final extension = (file.extension ?? '').toLowerCase();
      if (!{'pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'}.contains(extension)) {
        throw ApiException('Only PDF, Word, and image files are allowed.');
      }
      if (file.size > 10 * 1024 * 1024) {
        throw ApiException('Files must be 10 MB or smaller.');
      }
      if (file.bytes == null) {
        throw ApiException('The selected file could not be read.');
      }
      final comment = TextEditingController();
      final saveComment = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Upload new version'),
          content: TextField(
            controller: comment,
            maxLength: 500,
            decoration:
                const InputDecoration(labelText: 'What changed? (optional)'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Upload')),
          ],
        ),
      );
      final commentText = comment.text.trim();
      comment.dispose();
      if (saveComment != true) return;
      setState(() => _uploading = true);
      await Api.uploadDocumentVersion(
        widget.documentId,
        file.name,
        file.bytes!,
        comment: commentText,
      );
      await _load();
      await widget.onChanged?.call();
      if (mounted) snack(context, 'New file version uploaded.');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _download(Map<String, dynamic> version) async {
    try {
      final bytes =
          await Api.downloadDocumentVersion(version['version_id'] as int);
      final path = await Api.saveDownloadedFile(
          '${version['filename'] ?? 'document'}', bytes);
      if (mounted && path != null) snack(context, 'Version saved.');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  String _formatSize(dynamic value) {
    final bytes = value as int? ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Versions'),
        onExpansionChanged: (expanded) {
          setState(() => _expanded = expanded);
          if (expanded && _versions.isEmpty && !_loading) _load();
        },
        children: [
          if (_expanded && widget.canUpload)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file),
                label: Text(_uploading ? 'Uploading…' : 'Upload version'),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ListTile(
              title:
                  Text(_error!, style: TextStyle(color: context.errorColor())),
              trailing: IconButton(
                onPressed: _load,
                tooltip: 'Retry',
                icon: const Icon(Icons.refresh),
              ),
            )
          else if (_expanded && _versions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('No versions yet.',
                  style: TextStyle(color: context.textMuted)),
            )
          else
            for (final raw in _versions)
              _versionTile(Map<String, dynamic>.from(raw as Map)),
        ],
      );

  Widget _versionTile(Map<String, dynamic> version) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
            radius: 16, child: Text('v${version['version_number'] ?? '?'}')),
        title: Text('${version['filename'] ?? 'Version'}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${_formatSize(version['size_bytes'])} · ${version['uploaded_by_name'] ?? 'Uploaded'}${version['comment'] == null ? '' : '\n${version['comment']}'}'),
        trailing: IconButton(
          onPressed: () => _download(version),
          tooltip: 'Download version',
          icon: const Icon(Icons.download_outlined),
        ),
        isThreeLine: version['comment'] != null,
      );
}
