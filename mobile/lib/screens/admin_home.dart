import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../audio.dart';
import '../api.dart';
import '../components/analytics_data_view.dart';
import '../theme.dart';
import '../ui.dart';
import 'notifications.dart';
import 'settings.dart';

class AdminHomeShell extends StatefulWidget {
  const AdminHomeShell({super.key});

  @override
  State<AdminHomeShell> createState() => _AdminHomeShellState();
}

class _AdminHomeShellState extends State<AdminHomeShell> {
  int _index = 0;
  int _unread = 0;
  int? _lastNotificationId;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      _loadNotifications();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final result = await Api.notifications();
      final items = result['items'] as List<dynamic>? ?? const [];
      final newest =
          items.isNotEmpty ? items.first['notification_id'] as int : 0;
      if (_lastNotificationId != null && newest > _lastNotificationId!) {
        final hasUnreadNewNotification = items.any((item) =>
            item['notification_id'] > _lastNotificationId! &&
            item['is_read'] == 0);
        if (hasUnreadNewNotification) {
          AppAudio.playNotificationSafely();
        }
      }
      _lastNotificationId = newest;
      if (mounted) setState(() => _unread = result['unread'] as int? ?? 0);
    } catch (_) {
      // The notification badge is optional while offline.
    }
  }

  void _openNotifications() {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => NotificationsScreen(
                  onOpenAdminConversation: _openNotificationConversation,
                )))
        .then((_) => _loadNotifications());
  }

  Future<void> _openNotificationConversation(
      Map<String, dynamic> notification) async {
    final applicationId = notification['related_application_id'];
    if (applicationId is! num) return;
    try {
      final threads = await Api.adminMessageThreads();
      if (!mounted) return;
      Map<String, dynamic>? targetThread;
      for (final raw in threads) {
        final thread = Map<String, dynamic>.from(raw as Map);
        if (thread['application_id'] == applicationId) {
          targetThread = thread;
          break;
        }
      }
      if (targetThread == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('That conversation is no longer available.')),
        );
        return;
      }
      final thread = targetThread;
      final messageId = notification['related_message_id'];
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AdminThreadScreen(
          applicationId: applicationId.toInt(),
          studentName: '${thread['student_name'] ?? 'Student'}',
          adviserName: '${thread['adviser_name'] ?? 'Adviser'}',
          targetMessageId: messageId is num ? messageId.toInt() : null,
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open conversation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const AdminOverviewScreen(),
      const AdminUsersScreen(),
      const AdminMessagesScreen(),
      const AdminAuditScreen(),
      const SettingsScreen(),
    ];
    const destinations = [
      NavigationDestination(
          icon: Icon(Icons.dashboard_outlined), label: 'Overview'),
      NavigationDestination(
          icon: Icon(Icons.manage_accounts_outlined), label: 'Accounts'),
      NavigationDestination(
          icon: Icon(Icons.forum_outlined), label: 'Messages'),
      NavigationDestination(icon: Icon(Icons.history), label: 'Audit'),
      NavigationDestination(
          icon: Icon(Icons.settings_outlined), label: 'Settings'),
    ];
    return Scaffold(
      body: BentoBackground(
        child: BentoContainer(
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset('assets/adviserlink-logo.png',
                            width: 30, height: 30),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Admin workspace',
                          style: context.textLg.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _openNotifications,
                        tooltip: 'Notifications',
                        icon: Badge(
                          isLabelVisible: _unread > 0,
                          label: Text('$_unread'),
                          child: const Icon(Icons.notifications_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: KeyedSubtree(
                        key: ValueKey(_index), child: pages[_index]),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                  child: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: (index) =>
                        setState(() => _index = index),
                    destinations: destinations,
                    height: 64,
                    backgroundColor: context.surfaceElevated,
                    indicatorColor: context.brandPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  late Future<Map<String, dynamic>> _report;

  @override
  void initState() {
    super.initState();
    _report = Api.analytics();
  }

  Future<void> _reload() async {
    final report = Api.analytics();
    setState(() => _report = report);
    await report;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _report,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(snapshot.error.toString(), textAlign: TextAlign.center),
                TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry')),
              ]),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              children: [
                Text('System overview',
                    style: context.text3xl.copyWith(
                        color: context.textColor, fontWeight: FontWeight.w800)),
                Text('Platform activity and reports.',
                    style: TextStyle(color: context.textMuted)),
                const SizedBox(height: 12),
                for (final section in snapshot.data!.entries)
                  AnalyticsDataCard(
                      title: _label(section.key), data: section.value),
              ],
            ),
          );
        },
      );

  String _label(String key) => key
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  String _role = '';
  String _status = 'pending';
  List<dynamic> _users = [];
  int _total = 0;
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Api.adminUsers(
        query: _search.text.trim(),
        role: _role,
        status: _status,
      );
      if (!mounted) return;
      setState(() {
        _users = result['items'] as List<dynamic>? ?? [];
        _total = result['total'] as int? ?? _users.length;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _setStatus(Map<String, dynamic> account, String status) async {
    final id = account['user_id'] as int;
    setState(() => _busy.add(id));
    try {
      await Api.setUserStatus(id, status);
      if (mounted) snack(context, '${account['name']} account updated.');
      await _load();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Accounts',
                    style: context.text3xl.copyWith(
                        color: context.textColor, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(),
                  decoration: InputDecoration(
                    hintText: 'Search name or email',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                        onPressed: _load, icon: const Icon(Icons.refresh)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('All roles')),
                          DropdownMenuItem(
                              value: 'student', child: Text('Students')),
                          DropdownMenuItem(
                              value: 'adviser', child: Text('Advisers')),
                        ],
                        onChanged: (value) {
                          setState(() => _role = value ?? '');
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(
                              value: '', child: Text('All statuses')),
                          DropdownMenuItem(
                              value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(
                              value: 'active', child: Text('Active')),
                          DropdownMenuItem(
                              value: 'disabled', child: Text('Disabled')),
                        ],
                        onChanged: (value) {
                          setState(() => _status = value ?? '');
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child:
                  Text(_error!, style: TextStyle(color: context.errorColor())),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('$_total account(s)',
                        style: TextStyle(color: context.textMuted)),
                  ),
                  if (!_loading && _users.isEmpty)
                    const Card(
                        child: ListTile(
                            title: Text('No accounts match these filters.'))),
                  for (final raw in _users)
                    _userCard(Map<String, dynamic>.from(raw as Map)),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _userCard(Map<String, dynamic> account) {
    final role = '${account['role'] ?? 'student'}';
    final status = '${account['account_status'] ?? 'active'}';
    final id = account['user_id'] as int;
    final busy = _busy.contains(id);
    final isAdmin = role == 'admin';
    final nextStatus = status == 'active' ? 'disabled' : 'active';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${account['name'] ?? 'Account'}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${account['email'] ?? ''}'),
            const SizedBox(height: 4),
            Text(
              '${_label(role)} · ${_label(status)}'
              '${account['advisees'] == null ? '' : ' · ${account['advisees']} advisees'}',
              style: TextStyle(color: context.textMuted),
            ),
            if (!isAdmin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                      busy ? null : () => _setStatus(account, nextStatus),
                  icon: Icon(status == 'active'
                      ? Icons.block_outlined
                      : Icons.check_circle_outline),
                  label: Text(
                    busy
                        ? 'Saving…'
                        : status == 'active'
                            ? 'Deactivate'
                            : status == 'pending'
                                ? 'Approve'
                                : 'Activate',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _label(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  List<dynamic> _threads = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final threads = await Api.adminMessageThreads();
      if (mounted) {
        setState(() {
          _threads = threads;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _open(Map<String, dynamic> thread) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AdminThreadScreen(
        applicationId: thread['application_id'] as int,
        studentName: '${thread['student_name'] ?? 'Student'}',
        adviserName: '${thread['adviser_name'] ?? 'Adviser'}',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        children: [
          Text('Conversations',
              style: context.text3xl.copyWith(
                  color: context.textColor, fontWeight: FontWeight.w800)),
          Text('Review flagged messages and send admin replies.',
              style: TextStyle(color: context.textMuted)),
          const SizedBox(height: 12),
          if (_threads.isEmpty)
            const Card(
                child: ListTile(
                    title: Text('No conversations yet'),
                    subtitle:
                        Text('Approved student–adviser chats appear here.'))),
          for (final raw in _threads)
            _threadCard(Map<String, dynamic>.from(raw as Map)),
        ],
      ),
    );
  }

  Widget _threadCard(Map<String, dynamic> thread) {
    final unread = thread['unread_count'] as int? ?? 0;
    final moderated = thread['latest_message_kind'] == 'moderation_warning';
    return Card(
      child: ListTile(
        onTap: () => _open(thread),
        title: Text(
          '${thread['student_name'] ?? 'Student'} (Student) ↔ ${thread['adviser_name'] ?? 'Adviser'} (Adviser)',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${thread['topic_brief'] ?? ''}\n'
          '${moderated ? 'AdviserLink Moderation (Automated)' : thread['latest_sender_name'] ?? ''}: '
          '${thread['latest_message'] ?? ''}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: unread > 0
            ? CircleAvatar(
                radius: 13,
                backgroundColor: context.brandPrimary,
                child: Text('$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class AdminThreadScreen extends StatefulWidget {
  final int applicationId;
  final String studentName;
  final String adviserName;
  final int? targetMessageId;

  const AdminThreadScreen({
    super.key,
    required this.applicationId,
    required this.studentName,
    required this.adviserName,
    this.targetMessageId,
  });

  @override
  State<AdminThreadScreen> createState() => _AdminThreadScreenState();
}

class _AdminThreadScreenState extends State<AdminThreadScreen> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  final Map<int, GlobalKey> _messageKeys = {};
  List<dynamic> _messages = [];
  Timer? _timer;
  bool _loading = true;
  bool _sending = false;
  bool _focusedTarget = false;
  bool _forceScrollToLatest = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await Api.adminMessages(
        widget.applicationId,
        targetMessageId: widget.targetMessageId,
      );
      if (!mounted) return;
      final nextMessages = result['messages'] as List<dynamic>? ?? [];
      final previousLatestId = _messages.fold<int>(
        0,
        (latest, raw) {
          final message = Map<String, dynamic>.from(raw as Map);
          return (message['message_id'] as int) > latest
              ? message['message_id'] as int
              : latest;
        },
      );
      final nextLatestId = nextMessages.fold<int>(
        0,
        (latest, raw) {
          final message = Map<String, dynamic>.from(raw as Map);
          return (message['message_id'] as int) > latest
              ? message['message_id'] as int
              : latest;
        },
      );
      final wasAtBottom = _loading ||
          !_scroll.hasClients ||
          _scroll.position.maxScrollExtent - _scroll.position.pixels < 60;
      final shouldScrollToLatest = _forceScrollToLatest ||
          _messages.isEmpty ||
          (wasAtBottom && nextLatestId > previousLatestId);
      _forceScrollToLatest = false;
      setState(() {
        _messages = nextMessages;
        _loading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = widget.targetMessageId == null
            ? null
            : _messageKeys[widget.targetMessageId]?.currentContext;
        if (widget.targetMessageId != null && !_focusedTarget) {
          _focusedTarget = true;
          if (targetContext != null) {
            Scrollable.ensureVisible(
              targetContext,
              alignment: 0.5,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            );
            return;
          }
        }
        if (shouldScrollToLatest && _scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final body = _draft.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await Api.sendAdminMessage(widget.applicationId, body);
      _draft.clear();
      _forceScrollToLatest = true;
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('${widget.studentName} (Student)'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('with ${widget.adviserName} (Adviser)',
                  style: TextStyle(color: context.textMuted)),
            ),
          ),
        ),
        body: BentoBackground(
          child: BentoContainer(
            child: SafeArea(
              child: Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(_error!,
                          style: TextStyle(color: context.errorColor())),
                    ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              controller: _scroll,
                              padding: const EdgeInsets.all(12),
                              children: [
                                if (_messages.isEmpty)
                                  const Center(child: Text('No messages yet.')),
                                for (final raw in _messages)
                                  _message(
                                      Map<String, dynamic>.from(raw as Map)),
                              ],
                            ),
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _draft,
                              maxLength: 5000,
                              minLines: 1,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: 'Reply to this conversation…',
                                counterText: '',
                              ),
                            ),
                          ),
                          IconButton.filled(
                            onPressed: _sending ? null : _send,
                            icon: _sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _message(Map<String, dynamic> message) {
    final mine = message['sender_id'] == Api.user?['user_id'];
    final automated = message['message_kind'] == 'moderation_warning';
    final categories = message['moderation_categories'];
    final messageId = message['message_id'] as int;
    final isTarget = messageId == widget.targetMessageId;
    return Align(
      key: _messageKeys.putIfAbsent(messageId, () => GlobalKey()),
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? context.brandPrimary : context.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: isTarget
              ? Border.all(color: context.brandPrimary, width: 2)
              : mine
                  ? null
                  : Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              automated
                  ? 'AdviserLink Moderation (Automated)'
                  : mine
                      ? 'You (Admin)'
                      : '${message['sender_name'] ?? ''} (${_roleName(message['sender_role'])})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: mine ? Colors.white70 : context.textMuted,
              ),
            ),
            if (categories != null && '$categories'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('Flagged: $categories',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: mine ? Colors.white : context.errorColor())),
              ),
            const SizedBox(height: 3),
            Text('${message['body'] ?? ''}',
                style:
                    TextStyle(color: mine ? Colors.white : context.textColor)),
            if (message['created_at'] != null)
              Align(
                alignment: Alignment.centerRight,
                child: Text('${message['created_at']}',
                    style: TextStyle(
                        fontSize: 10,
                        color: mine ? Colors.white70 : context.textMuted)),
              ),
          ],
        ),
      ),
    );
  }

  String _roleName(dynamic role) {
    final value = role?.toString() ?? 'user';
    return value.isEmpty
        ? value
        : '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class AdminAuditScreen extends StatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  State<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends State<AdminAuditScreen> {
  late Future<List<dynamic>> _logs;

  @override
  void initState() {
    super.initState();
    _logs = Api.adminAuditLogs();
  }

  Future<void> _reload() async {
    final logs = Api.adminAuditLogs();
    setState(() => _logs = logs);
    await logs;
  }

  String _json(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      try {
        return const JsonEncoder.withIndent('  ').convert(jsonDecode(value));
      } catch (_) {
        return value;
      }
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return '$value';
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
        future: _logs,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(snapshot.error.toString(), textAlign: TextAlign.center),
                TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry')),
              ]),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              children: [
                Text('Audit history',
                    style: context.text3xl.copyWith(
                        color: context.textColor, fontWeight: FontWeight.w800)),
                Text('Latest administrative actions.',
                    style: TextStyle(color: context.textMuted)),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  const Card(
                      child:
                          ListTile(title: Text('No audit records available.'))),
                for (final raw in rows)
                  _auditCard(Map<String, dynamic>.from(raw as Map)),
              ],
            ),
          );
        },
      );

  Widget _auditCard(Map<String, dynamic> log) => Card(
        child: ExpansionTile(
          title: Text('${log['action'] ?? 'Action'}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${log['user_name'] ?? 'System'} · ${log['target_type'] ?? ''} ${log['target_id'] ?? ''}\n${log['created_at'] ?? ''}'),
          children: [
            if (log['old_values'] != null)
              ListTile(
                title: const Text('Before'),
                subtitle: SelectableText(_json(log['old_values'])),
              ),
            if (log['new_values'] != null)
              ListTile(
                title: const Text('After'),
                subtitle: SelectableText(_json(log['new_values'])),
              ),
          ],
        ),
      );
}
