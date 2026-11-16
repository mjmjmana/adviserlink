import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../ui.dart';
import 'messaging.dart';

/// Buong listahan ng notifications. I-tap ang isa para mabasa nang buo (at ma-mark na read).
class NotificationsScreen extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>)? onOpenAdminConversation;

  const NotificationsScreen({
    super.key,
    this.onOpenAdminConversation,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _items = [];
  bool _unreadOnly = false;
  bool _loaded = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.notifications(limit: 200);
      if (mounted)
        setState(() {
          _items = d['items'] as List<dynamic>;
          _loaded = true;
          _error = '';
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loaded = true;
        });
    }
  }

  Future<void> _markAll() async {
    await Api.readAll().catchError((_) {});
    _load();
  }

  Map<String, int>? _conversationTarget(Map<String, dynamic> n) {
    final message = '${n['message'] ?? ''}'.toLowerCase();
    final isMessage = message.startsWith('new message from ');
    final isAdminModeration = Api.user?['role'] == 'admin' &&
        message.contains('chat moderation alert for application ');
    final applicationId = n['related_application_id'];
    if ((!isMessage && !isAdminModeration) ||
        applicationId is! num ||
        applicationId <= 0 ||
        (Api.user?['role'] == 'admin' &&
            widget.onOpenAdminConversation == null)) {
      return null;
    }

    final target = <String, int>{'applicationId': applicationId.toInt()};
    final messageId = n['related_message_id'];
    if (messageId is num && messageId > 0) {
      target['messageId'] = messageId.toInt();
    }
    return target;
  }

  String _contactName(Map<String, dynamic> n) {
    final message = '${n['message'] ?? ''}';
    final match = RegExp(
      r'^New message from (?:admin )?(.+?):',
      caseSensitive: false,
    ).firstMatch(message);
    return match?.group(1)?.trim() ?? 'your conversation';
  }

  Future<void> _openConversation(
    Map<String, dynamic> n,
    Map<String, int> target,
    BuildContext sheetContext,
  ) async {
    Navigator.of(sheetContext).pop();
    await _navigateToConversation(n, target);
  }

  Future<void> _openConversationFromCard(
    Map<String, dynamic> n,
    Map<String, int> target,
  ) async {
    _markRead(n);
    await _navigateToConversation(n, target);
  }

  Future<void> _navigateToConversation(
    Map<String, dynamic> n,
    Map<String, int> target,
  ) async {
    if (Api.user?['role'] == 'admin') {
      await widget.onOpenAdminConversation?.call(n);
      return;
    }

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Conversation')),
        body: BentoBackground(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MessagingScreen(
              applicationId: target['applicationId']!,
              contactName: _contactName(n),
              targetMessageId: target['messageId'],
            ),
          ),
        ),
      ),
    ));
  }

  void _markRead(Map<String, dynamic> n) {
    if (n['is_read'] == 0) {
      setState(() => n['is_read'] = 1);
      Api.readOne(n['notification_id'] as int).catchError((_) {});
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    _markRead(n);
    final conversationTarget = _conversationTarget(n);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: EdgeInsets.fromLTRB(
              16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.surfaceElevated,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(DesignTokens.radius4xl)),
            border: Border.all(
                color: context.borderColor.withValues(alpha: 0.5), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  backgroundColor: context.brandPrimary,
                  child:
                      Icon(Icons.notifications, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text('${n['date_sent']}',
                    style: context.textSm.copyWith(color: context.textMuted)),
              ]),
              const SizedBox(height: 14),
              Text('${n['message']}',
                  style: context.textXl.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: context.textColor)),
              const SizedBox(height: 16),
              if (conversationTarget != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        _openConversation(n, conversationTarget, sheetContext),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(Api.user?['role'] == 'admin'
                        ? 'Open flagged conversation'
                        : 'Open conversation'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown =
        _unreadOnly ? _items.where((n) => n['is_read'] == 0).toList() : _items;
    final unread = _items.where((n) => n['is_read'] == 0).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.surface,
        title: Text('Notifications',
            style: context.textXl.copyWith(
                fontWeight: FontWeight.w800, color: context.textColor)),
        actions: [
          TextButton(
            onPressed: unread == 0 ? null : _markAll,
            child: Text('Mark all read',
                style: TextStyle(
                    color: context.brandPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: BentoBackground(
        child: RefreshIndicator(
          color: context.brandPrimary,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: const Text('All')),
                  ButtonSegment(value: true, label: Text('Unread ($unread)')),
                ],
                selected: {_unreadOnly},
                onSelectionChanged: (s) =>
                    setState(() => _unreadOnly = s.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected))
                      return context.brandPrimary;
                    return context.surfaceHover;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected))
                      return Colors.white;
                    return context.textColor;
                  }),
                  side: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected))
                      return BorderSide.none;
                    return BorderSide(color: context.borderColor);
                  }),
                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radius2xl))),
                ),
              ),
              const SizedBox(height: 12),
              if (_error.isNotEmpty)
                Text(_error, style: TextStyle(color: context.errorColor())),
              if (_loaded && shown.isEmpty)
                EmptyState(
                  icon: Icons.notifications_none,
                  title:
                      _unreadOnly ? 'No unread notifications' : 'Nothing yet',
                  description: _unreadOnly
                      ? 'All caught up!'
                      : 'You\'ll see notifications here when they arrive.',
                ),
              for (final raw in shown)
                Builder(builder: (context) {
                  final n = raw as Map<String, dynamic>;
                  final isUnread = n['is_read'] == 0;
                  final conversationTarget = _conversationTarget(n);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 6, right: 10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isUnread
                                  ? context.brandPrimary
                                  : Colors.transparent,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () => _open(n),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${n['message']}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.textBase.copyWith(
                                            fontWeight: isUnread
                                                ? FontWeight.w800
                                                : FontWeight.w500,
                                            color: context.textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('${n['date_sent']}',
                                            style: context.textXs.copyWith(
                                                color: context.textMuted)),
                                      ],
                                    ),
                                  ),
                                ),
                                if (conversationTarget != null)
                                  TextButton.icon(
                                    onPressed: () => _openConversationFromCard(
                                        n, conversationTarget),
                                    icon: const Icon(Icons.chat_bubble_outline,
                                        size: 18),
                                    label: Text(Api.user?['role'] == 'admin'
                                        ? 'Open flagged conversation'
                                        : 'Open conversation'),
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 0),
                                      foregroundColor: context.brandPrimary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (conversationTarget == null)
                            Icon(Icons.chevron_right, color: context.textMuted),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
