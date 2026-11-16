import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../ui.dart';
import '../util.dart';

class AvailabilityExceptionsPanel extends StatefulWidget {
  final Future<void> Function()? onChanged;

  const AvailabilityExceptionsPanel({super.key, this.onChanged});

  @override
  State<AvailabilityExceptionsPanel> createState() =>
      _AvailabilityExceptionsPanelState();
}

class _AvailabilityExceptionsPanelState
    extends State<AvailabilityExceptionsPanel> {
  List<dynamic> _exceptions = [];
  bool _loading = true;
  String? _error;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await Api.availabilityExceptions();
      if (!mounted) return;
      setState(() {
        _exceptions = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _add() async {
    DateTime? date;
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 17, minute: 0);
    var allDay = false;
    final reason = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Block date or time'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showDatePicker(
                      context: dialogContext,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (value != null) {
                      setDialogState(() => date = value);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(date == null ? 'Choose date *' : ymd(date!)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Block all day'),
                  value: allDay,
                  onChanged: (value) => setDialogState(() => allDay = value),
                ),
                if (!allDay) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final value = await showTimePicker(
                              context: dialogContext,
                              initialTime: start,
                            );
                            if (value != null) {
                              setDialogState(() => start = value);
                            }
                          },
                          child: Text('Start: ${start.format(dialogContext)}'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final value = await showTimePicker(
                              context: dialogContext,
                              initialTime: end,
                            );
                            if (value != null) {
                              setDialogState(() => end = value);
                            }
                          },
                          child: Text('End: ${end.format(dialogContext)}'),
                        ),
                      ),
                    ],
                  ),
                ],
                TextField(
                  controller: reason,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText: 'e.g. Faculty meeting',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: date == null ||
                      (!allDay &&
                          start.hour * 60 + start.minute >=
                              end.hour * 60 + end.minute)
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Block time'),
            ),
          ],
        ),
      ),
    );
    if (result != true || date == null) {
      reason.dispose();
      return;
    }
    try {
      await Api.addAvailabilityException(
        specificDate: ymd(date!),
        startTime:
            '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
        endTime:
            '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
        reason: reason.text.trim(),
        allDay: allDay,
      );
      await _load();
      await widget.onChanged?.call();
      if (mounted) snack(context, 'Availability exception added.');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      reason.dispose();
    }
  }

  Future<void> _delete(Map<String, dynamic> exception) async {
    final id = exception['exception_id'] as int;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove blocked time?'),
        content: const Text('Your regular availability will apply again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyId = id);
    try {
      await Api.deleteAvailabilityException(id);
      await _load();
      await widget.onChanged?.call();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _timeLabel(String? value) {
    if (value == null || value.length < 5) return '';
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Availability exceptions',
                      style: context.textLg.copyWith(
                          color: context.textColor,
                          fontWeight: FontWeight.w700)),
                ),
                IconButton.filled(
                  onPressed: _add,
                  tooltip: 'Block date or time',
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
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
            else if (_exceptions.isEmpty)
              Text('No blocked dates or times.',
                  style: TextStyle(color: context.textMuted))
            else
              for (final raw in _exceptions)
                _exceptionTile(Map<String, dynamic>.from(raw as Map)),
          ],
        ),
      );

  Widget _exceptionTile(Map<String, dynamic> exception) {
    final id = exception['exception_id'] as int;
    final allDay = exception['is_all_day'] == true ||
        exception['is_all_day'] == 1;
    final time = allDay
        ? 'All day'
        : '${_timeLabel(exception['start_time'] as String?)} – ${_timeLabel(exception['end_time'] as String?)}';
    final reason = exception['reason'] as String? ?? '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_busy_outlined),
      title: Text('${exception['specific_date']} · $time'),
      subtitle: reason.isEmpty ? null : Text(reason),
      trailing: IconButton(
        onPressed: _busyId == id ? null : () => _delete(exception),
        tooltip: 'Remove exception',
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}

class AdviserWaitlistPanel extends StatefulWidget {
  const AdviserWaitlistPanel({super.key});

  @override
  State<AdviserWaitlistPanel> createState() => _AdviserWaitlistPanelState();
}

class _AdviserWaitlistPanelState extends State<AdviserWaitlistPanel> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await Api.adviserWaitlist();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _perform(
      int id, Future<void> Function() action, String message) async {
    setState(() => _busy.add(id));
    try {
      await action();
      await _load();
      if (mounted) snack(context, message);
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Waitlist for your slots',
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
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('No students on your waitlist.',
                    style: TextStyle(color: context.textMuted)),
              )
            else
              for (final raw in _items)
                _waitlistTile(Map<String, dynamic>.from(raw as Map)),
          ],
        ),
      );

  Widget _waitlistTile(Map<String, dynamic> item) {
    final id = item['waitlist_id'] as int;
    final waiting = item['status'] == 'waiting';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text('${item['position'] ?? '-'}')),
      title: Text('${item['student_name'] ?? 'Student'}'),
      subtitle: Text('${item['topic_brief'] ?? ''}'),
      trailing: waiting
          ? Wrap(
              children: [
                IconButton(
                  onPressed: _busy.contains(id)
                      ? null
                      : () => _perform(
                            id,
                            () => Api.notifyWaitlist(id),
                            'Student notified. They have 48 hours to apply.',
                          ),
                  tooltip: 'Notify student',
                  icon: const Icon(Icons.notifications_active_outlined),
                ),
                IconButton(
                  onPressed: _busy.contains(id)
                      ? null
                      : () => _perform(
                            id,
                            () => Api.cancelWaitlist(id),
                            'Waitlist entry cancelled.',
                          ),
                  tooltip: 'Remove from waitlist',
                  icon: const Icon(Icons.close),
                ),
              ],
            )
          : Chip(label: Text('${item['status']}')),
    );
  }
}
