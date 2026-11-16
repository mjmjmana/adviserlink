import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../ui.dart';

class MessagingScreen extends StatefulWidget {
  final int applicationId;
  final String contactName;
  final String? contactProfilePhoto;
  final int? targetMessageId;

  const MessagingScreen({
    super.key,
    required this.applicationId,
    required this.contactName,
    this.contactProfilePhoto,
    this.targetMessageId,
  });

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> {
  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (mounted) setState(() => _visible = !_visible);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Typing',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
          AnimatedOpacity(
            opacity: _visible ? 1 : 0.25,
            duration: const Duration(milliseconds: 300),
            child: Text(' …', style: TextStyle(color: context.textMuted)),
          ),
        ]),
      );
}

class _MessagingScreenState extends State<MessagingScreen> {
  final _message = TextEditingController();
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _messageKeys = {};
  List<dynamic> _messages = [];
  Timer? _pollTimer;
  Timer? _typingTimer;
  bool _loading = true;
  bool _sending = false;
  bool _loadingMessages = false;
  bool _sendingActivity = false;
  bool _typing = false;
  bool _focusedTarget = false;
  Map<String, dynamic> _contactActivity = const {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _refreshActivity();
    _publishActivity(false);
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadMessages(silent: true);
      _refreshActivity();
      _publishActivity(_typing);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _typingTimer?.cancel();
    _message.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_loadingMessages) return;
    _loadingMessages = true;
    try {
      final messages = await Api.messages(
        widget.applicationId,
        limit: widget.targetMessageId == null ? 50 : 200,
        targetMessageId: widget.targetMessageId,
      );
      if (!mounted) return;
      final shouldScroll = messages.length != _messages.length;
      setState(() {
        _messages = messages;
        _loading = false;
        _error = null;
      });
      if (widget.targetMessageId != null) {
        if (!_focusedTarget) {
          _focusedTarget = true;
          _scrollToTarget();
        }
      } else if (shouldScroll) {
        _scrollToLatest();
      }
      final incoming = messages.where((message) =>
          message['sender_id'] != Api.user?['user_id'] &&
          message['is_read'] != 1 &&
          message['is_read'] != true);
      if (incoming.isNotEmpty) {
        final latestId = messages.fold<int>(
          0,
          (latest, message) => (message['message_id'] as int) > latest
              ? message['message_id'] as int
              : latest,
        );
        if (latestId > 0) {
          await Api.markMessagesRead(widget.applicationId, latestId);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _messages.isEmpty) _error = e.toString();
      });
    } finally {
      _loadingMessages = false;
    }
  }

  Future<void> _refreshActivity() async {
    try {
      final activity = await Api.chatActivity(widget.applicationId);
      if (mounted) setState(() => _contactActivity = activity);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _publishActivity(bool typing) async {
    if (_sendingActivity) return;
    _sendingActivity = true;
    try {
      await Api.updateChatActivity(widget.applicationId, typing: typing);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _sendingActivity = false;
    }
  }

  void _onTextChanged(String value) {
    _typingTimer?.cancel();
    if (value.trim().isEmpty) {
      _typing = false;
      _publishActivity(false);
      return;
    }
    _typingTimer = Timer(const Duration(milliseconds: 250), () {
      _typing = true;
      _publishActivity(true);
    });
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    _typingTimer?.cancel();
    _typing = false;
    await _publishActivity(false);
    try {
      await Api.sendMessage(widget.applicationId, body);
      _message.clear();
      await _loadMessages();
      _scrollToLatest();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _scrollToTarget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = widget.targetMessageId == null
          ? null
          : _messageKeys[widget.targetMessageId]?.currentContext;
      if (targetContext == null) {
        _scrollToLatest();
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Api.user?['user_id'];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    backgroundColor:
                        context.brandPrimary.withValues(alpha: 0.12),
                    backgroundImage: widget.contactProfilePhoto == null
                        ? null
                        : NetworkImage(widget.contactProfilePhoto!),
                    child: widget.contactProfilePhoto == null
                        ? Icon(Icons.person_outline,
                            color: context.brandPrimary)
                        : null,
                  ),
                  if (_contactActivity['is_online'] == true)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messages',
                      style: context.textXl.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.textColor,
                      ),
                    ),
                    Text(
                      'Chat with ${widget.contactName}',
                      style: context.textSm.copyWith(color: context.textMuted),
                    ),
                    Text(
                      _contactActivity['is_typing'] == true
                          ? 'Typing…'
                          : _contactActivity['is_online'] == true
                              ? 'Online'
                              : 'Offline',
                      style: context.textSm.copyWith(
                        color: _contactActivity['is_online'] == true
                            ? Colors.green
                            : context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh messages',
                onPressed: _loadingMessages ? null : _loadMessages,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.errorColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: context.errorColor()),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadMessages,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    children: [
                      if (_messages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 80),
                          child: Column(
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 44, color: context.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                'No messages yet',
                                style: context.textLg.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: context.textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Start a conversation with ${widget.contactName}.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: context.textMuted),
                              ),
                            ],
                          ),
                        ),
                      for (final raw in _messages)
                        _messageBubble(
                          Map<String, dynamic>.from(raw as Map),
                          isMine: raw['sender_id'] == currentUserId,
                          isTarget: raw['message_id'] == widget.targetMessageId,
                          key: _messageKeys.putIfAbsent(
                            raw['message_id'] as int,
                            GlobalKey.new,
                          ),
                        ),
                      if (_contactActivity['is_typing'] == true)
                        const _TypingIndicator(),
                    ],
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 5000,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Write a message…',
                      counterText: '',
                      filled: true,
                      fillColor: context.inputColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: context.borderColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _messageBubble(
    Map<String, dynamic> message, {
    required bool isMine,
    required bool isTarget,
    required Key key,
  }) {
    final color = isMine ? context.brandPrimary : context.surfaceElevated;
    final foreground = isMine ? Colors.white : context.textColor;
    final automated = message['message_kind'] == 'moderation_warning';
    final currentRole = Api.user?['role']?.toString() ?? 'student';
    final otherRole = currentRole == 'adviser' ? 'student' : 'adviser';
    final senderRole = message['sender_role']?.toString() ??
        (isMine ? currentRole : otherRole);
    final senderName = automated
        ? 'AdviserLink Moderation (Automated)'
        : isMine
            ? 'You'
            : (message['sender_name'] ?? widget.contactName);
    final roleLabel = senderRole.isEmpty
        ? ''
        : ' (${senderRole[0].toUpperCase()}${senderRole.substring(1)})';
    return Align(
      key: key,
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            border: isTarget
                ? Border.all(color: context.brandPrimary, width: 2)
                : isMine
                    ? null
                    : Border.all(color: context.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '$senderName${automated ? '' : roleLabel}',
                  style: TextStyle(
                    color: isMine ? Colors.white70 : context.brandPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (message['moderation_categories'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'Flagged: ${message['moderation_categories']}',
                    style: TextStyle(
                      color: isMine ? Colors.white : context.errorColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Text(
                '${message['body'] ?? ''}',
                style: TextStyle(color: foreground),
              ),
              if (message['created_at'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${message['created_at']}',
                        style: TextStyle(
                          color: foreground.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                      if (isMine && !automated) ...[
                        const SizedBox(width: 6),
                        Text(
                          message['read_at'] != null ||
                                  message['is_read'] == 1 ||
                                  message['is_read'] == true
                              ? 'Seen'
                              : message['delivered_at'] != null
                                  ? 'Delivered'
                                  : 'Sent',
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
