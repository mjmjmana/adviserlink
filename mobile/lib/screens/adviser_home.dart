import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../audio.dart';
import '../api.dart';
import '../components/analytics_data_view.dart';
import '../components/adviser_schedule_tools.dart';
import '../components/calendar_marker_grid.dart';
import '../theme.dart';
import '../ui.dart';
import '../util.dart';
import 'messaging.dart';
import 'notifications.dart';
import 'project.dart';
import 'settings.dart';

class AdviserHomeShell extends StatefulWidget {
  const AdviserHomeShell({super.key});

  @override
  State<AdviserHomeShell> createState() => _AdviserHomeShellState();
}

class _AdviserHomeShellState extends State<AdviserHomeShell> {
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
        .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))
        .then((_) => _loadNotifications());
  }

  void _openProfile() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Adviser profile')),
        body: BentoBackground(
          child: BentoContainer(
            child: const SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AdviserProfileScreen(),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const AdviserScheduleScreen(),
      const AdviserApplicationsScreen(),
      const AdviserAnalyticsScreen(),
      const NotificationsScreen(),
      const SettingsScreen(),
    ];
    const destinations = [
      NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined), label: 'Schedule'),
      NavigationDestination(
          icon: Icon(Icons.people_outline), label: 'Advisees'),
      NavigationDestination(
          icon: Icon(Icons.insights_outlined), label: 'Reports'),
      NavigationDestination(
          icon: Icon(Icons.notifications_none), label: 'Alerts'),
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
                          'Adviser workspace',
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
                      IconButton(
                        onPressed: _openProfile,
                        tooltip: 'Edit adviser profile',
                        icon: const Icon(Icons.badge_outlined),
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
                      key: ValueKey(_index),
                      child: pages[_index],
                    ),
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

class AdviserScheduleScreen extends StatefulWidget {
  const AdviserScheduleScreen({super.key});

  @override
  State<AdviserScheduleScreen> createState() => _AdviserScheduleScreenState();
}

class _AdviserScheduleScreenState extends State<AdviserScheduleScreen> {
  static const _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  List<dynamic> _availability = [];
  List<dynamic> _bookings = [];
  List<dynamic> _calendarBookings = [];
  List<dynamic> _calendarSlots = [];
  DateTime _calendarSelected = DateTime.now();
  String _calendarView = 'month';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final start = _ymd(now);
      final end = _ymd(now.add(const Duration(days: 62)));
      final calendar = monthGrid(_calendarSelected);
      final adviserId = Api.user?['user_id'] as int?;
      if (adviserId == null) {
        throw ApiException('Could not determine the adviser account.');
      }
      final results = await Future.wait<dynamic>([
        Api.availability(),
        Api.bookings(start, end),
        Api.bookings(_ymd(calendar.first), _ymd(calendar.last)),
        Api.slotsRange(adviserId, _ymd(calendar.first), _ymd(calendar.last)),
      ]);
      if (!mounted) return;
      setState(() {
        _availability = results[0];
        _bookings = results[1];
        _calendarBookings = results[2];
        _calendarSlots = results[3];
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

  String _ymd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool _isTrue(dynamic value) => value == true || value == 1;

  Set<String> get _activityDates => _calendarBookings
      .where((booking) => _isTrue(booking['has_new_activity']))
      .map((booking) => '${booking['slot_date']}')
      .toSet();

  Set<String> get _bookedDates => _calendarBookings
      .where((booking) =>
          booking['status'] == 'confirmed' &&
          !_activityDates.contains('${booking['slot_date']}'))
      .map((booking) => '${booking['slot_date']}')
      .toSet();

  Set<String> get _openDates => _calendarSlots
      .where((slot) => _isTrue(slot['available']))
      .map((slot) => '${slot['date']}')
      .toSet();

  Future<void> _selectCalendarDate(DateTime date) async {
    final monthChanged = date.year != _calendarSelected.year ||
        date.month != _calendarSelected.month;
    setState(() => _calendarSelected = date);
    if (!monthChanged) return;
    final adviserId = Api.user?['user_id'] as int?;
    if (adviserId == null) return;
    final calendar = monthGrid(date);
    try {
      final results = await Future.wait<dynamic>([
        Api.bookings(_ymd(calendar.first), _ymd(calendar.last)),
        Api.slotsRange(adviserId, _ymd(calendar.first), _ymd(calendar.last)),
      ]);
      if (!mounted) return;
      setState(() {
        _calendarBookings = results[0] as List<dynamic>;
        _calendarSlots = results[1] as List<dynamic>;
      });
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  void _stepCalendar(int direction) {
    final date = _calendarView == 'month'
        ? DateTime(
            _calendarSelected.year, _calendarSelected.month + direction, 1)
        : DateTime(_calendarSelected.year, _calendarSelected.month,
            _calendarSelected.day + direction * 7);
    _selectCalendarDate(date);
  }

  String _timeLabel(String? value) {
    if (value == null || value.length < 5) return value ?? '';
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _addAvailability({Map<String, dynamic>? existing}) async {
    var weekday = existing?['day_of_week'] as String? ?? _weekdays[0];
    var mode = existing?['specific_date'] != null ? 'date' : 'weekly';
    var selectedDate =
        DateTime.tryParse('${existing?['specific_date'] ?? ''}') ??
            DateTime.now();
    var start =
        (existing?['start_time'] as String?)?.substring(0, 5) ?? '09:00';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final parts = start.split(':').map(int.parse).toList();
          final canSave = parts[0] * 60 + parts[1] + 30 < 24 * 60;
          return AlertDialog(
            title: Text(
                existing == null ? 'Open a 30-minute time' : 'Edit open time'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: 'Schedule'),
                  items: const [
                    DropdownMenuItem(
                        value: 'weekly', child: Text('Every week')),
                    DropdownMenuItem(
                        value: 'date', child: Text('Specific date')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => mode = value);
                  },
                ),
                if (mode == 'date')
                  TextButton.icon(
                    onPressed: () async {
                      final value = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (value != null) {
                        setDialogState(() => selectedDate = value);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_ymd(selectedDate)),
                  ),
                if (mode == 'weekly')
                  DropdownButtonFormField<String>(
                    initialValue: weekday,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: _weekdays
                        .map((day) =>
                            DropdownMenuItem(value: day, child: Text(day)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => weekday = value);
                    },
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('30-minute time slot',
                      style: Theme.of(dialogContext).textTheme.labelLarge),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: dialogContext,
                      initialTime: TimeOfDay(
                        hour: parts[0],
                        minute: parts[1],
                      ),
                      initialEntryMode: TimePickerEntryMode.input,
                    );
                    if (picked != null) {
                      setDialogState(() {
                        start =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  icon: const Icon(Icons.access_time),
                  label: Text(
                      '${_timeLabel(start)} – ${_timeLabel(_addMinutes(start, 30))}'),
                ),
                Text(
                  canSave
                      ? 'Choose any start minute; the slot always lasts 30 minutes.'
                      : 'Latest start time is 11:29 PM.',
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                        color: canSave
                            ? null
                            : Theme.of(dialogContext).colorScheme.error,
                      ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    canSave ? () => Navigator.pop(dialogContext, true) : null,
                child: Text(existing == null ? 'Save time' : 'Save changes'),
              ),
            ],
          );
        },
      ),
    );
    if (result != true) return;
    try {
      final dayOfWeek = mode == 'weekly' ? weekday : null;
      final specificDate = mode == 'date' ? _ymd(selectedDate) : null;
      final endTime = _addMinutes(start, 30);
      if (existing == null) {
        await Api.addAvailability(
          dayOfWeek: dayOfWeek,
          specificDate: specificDate,
          startTime: start,
          endTime: endTime,
        );
      } else {
        await Api.updateAvailability(
          existing['availability_id'] as int,
          dayOfWeek: dayOfWeek,
          specificDate: specificDate,
          startTime: start,
          endTime: endTime,
        );
      }
      await _load();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  String _addMinutes(String value, int minutes) {
    final parts = value.split(':');
    final total = (int.parse(parts[0]) * 60) + int.parse(parts[1]) + minutes;
    final hour = (total ~/ 60) % 24;
    final minute = total % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _removeAvailability(int id) async {
    try {
      await Api.deleteAvailability(id);
      await _load();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _setMeeting(Map<String, dynamic> booking) async {
    var type = booking['meeting_type'] == 'online' ? 'online' : 'in-person';
    final location =
        TextEditingController(text: booking['location'] as String? ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Consultation details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Meeting type'),
                items: const [
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                  DropdownMenuItem(
                      value: 'in-person', child: Text('In person')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => type = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: location,
                maxLength: 255,
                decoration: InputDecoration(
                  labelText:
                      type == 'online' ? 'Meeting link' : 'Meeting location',
                  hintText: type == 'online'
                      ? 'https://meet.google.com/...'
                      : 'Room / building',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      location.dispose();
      return;
    }
    try {
      await Api.setMeeting(
        booking['booking_id'] as int,
        type,
        location.text.trim(),
      );
      await _load();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      location.dispose();
    }
  }

  String _calendarUtc(String date, String time) {
    final value = DateTime.parse('${date}T$time').toUtc();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}'
        'T${twoDigits(value.hour)}${twoDigits(value.minute)}'
        '${twoDigits(value.second)}Z';
  }

  Future<void> _addToGoogleCalendar(Map<String, dynamic> booking) async {
    try {
      final date = '${booking['slot_date']}';
      final uri = Uri.https('calendar.google.com', '/calendar/render', {
        'action': 'TEMPLATE',
        'text': 'Consultation with ${booking['student_name'] ?? 'Student'}',
        'dates':
            '${_calendarUtc(date, '${booking['start_time']}')}/${_calendarUtc(date, '${booking['end_time']}')}',
        if (booking['location'] != null) 'location': '${booking['location']}',
        if (booking['notes'] != null) 'details': '${booking['notes']}',
      });
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        snack(context, 'Could not open Google Calendar.', error: true);
      }
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _joinMeeting(String link) async {
    try {
      if (!await launchMeetingLink(link) && mounted) {
        snack(context, 'This meeting link is invalid or could not be opened.',
            error: true);
      }
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _downloadCalendarFile(int bookingId) async {
    try {
      final bytes = await Api.downloadIcs(bookingId);
      final path =
          await Api.saveDownloadedFile('consultation-$bookingId.ics', bytes);
      if (mounted && path != null) snack(context, 'Calendar file saved.');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          Text('Schedule',
              style: context.text3xl.copyWith(
                  color: context.textColor, fontWeight: FontWeight.w800)),
          Text('Manage open times and upcoming consultations.',
              style: TextStyle(color: context.textMuted)),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Consultation calendar',
                    style: context.textLg.copyWith(
                        color: context.textColor, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'month', label: Text('Month')),
                    ButtonSegment(value: 'week', label: Text('Week')),
                  ],
                  selected: {_calendarView},
                  onSelectionChanged: (selection) =>
                      setState(() => _calendarView = selection.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 8),
                CalendarMarkerGrid(
                  selected: _calendarSelected,
                  monthView: _calendarView == 'month',
                  bookedDates: _bookedDates,
                  openDates: _openDates,
                  activityDates: _activityDates,
                  onSelect: _selectCalendarDate,
                  onPrevious: () => _stepCalendar(-1),
                  onNext: () => _stepCalendar(1),
                ),
                const SizedBox(height: 8),
                const CalendarMarkerLegend(),
                const Divider(height: 24),
                Text(fmtDateLong(_calendarSelected),
                    style: context.textBase.copyWith(
                        color: context.textColor, fontWeight: FontWeight.w700)),
                for (final raw in _calendarBookings.where((booking) =>
                    booking['slot_date'] == _ymd(_calendarSelected)))
                  _bookingCard(Map<String, dynamic>.from(raw as Map)),
                if (!_calendarBookings.any((booking) =>
                    booking['slot_date'] == _ymd(_calendarSelected)))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('No consultations on this day.',
                        style: TextStyle(color: context.textMuted)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('Weekly availability',
                    style: context.textLg.copyWith(
                        color: context.textColor, fontWeight: FontWeight.w700)),
              ),
              IconButton.filled(
                onPressed: _addAvailability,
                tooltip: 'Add open time',
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (_availability.isEmpty)
            const Card(
                child: ListTile(
                    title: Text('No open times yet'),
                    subtitle: Text('Add a weekly time for students to book.'))),
          for (final raw in _availability)
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_available_outlined),
                title: Text(
                  raw['specific_date'] != null
                      ? '${raw['specific_date']}'
                      : '${raw['day_of_week']}',
                ),
                subtitle: Text(
                    '${_timeLabel(raw['start_time'] as String?)} – ${_timeLabel(raw['end_time'] as String?)}'),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      onPressed: () => _addAvailability(
                          existing: Map<String, dynamic>.from(raw as Map)),
                      tooltip: 'Edit open time',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () =>
                          _removeAvailability(raw['availability_id'] as int),
                      tooltip: 'Remove open time',
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          AvailabilityExceptionsPanel(onChanged: _load),
          const SizedBox(height: 12),
          const AdviserWaitlistPanel(),
          const SizedBox(height: 16),
          Text('Upcoming consultations',
              style: context.textLg.copyWith(
                  color: context.textColor, fontWeight: FontWeight.w700)),
          if (_bookings.isEmpty)
            const Card(
                child: ListTile(
                    title: Text('No upcoming consultations'),
                    subtitle: Text('New bookings will appear here.'))),
          for (final raw in _bookings)
            _bookingCard(Map<String, dynamic>.from(raw as Map)),
        ],
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final status = '${booking['status'] ?? 'confirmed'}';
    final location = booking['location'] as String? ?? '';
    final type = booking['meeting_type'] as String?;
    final canSetDetails = status == 'confirmed';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${booking['student_name'] ?? 'Student'}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
                '${booking['slot_date']} · ${_timeLabel(booking['start_time'] as String?)}–${_timeLabel(booking['end_time'] as String?)}'),
            if ((booking['topic_brief'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${booking['topic_brief']}'),
              ),
            const SizedBox(height: 6),
            Text(
              status == 'completed'
                  ? 'Completed'
                  : status == 'cancelled'
                      ? 'Cancelled'
                      : type == null
                          ? 'Meeting details not set'
                          : ' ${type == 'online' ? 'Online' : 'In person'}${location.isEmpty ? '' : ' · $location'}${booking['leader_accepted'] == 1 ? ' · Leader accepted' : ' · Waiting for leader'}',
              style: TextStyle(color: context.textMuted),
            ),
            if (canSetDetails)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _setMeeting(booking),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: Text(type == null ? 'Set details' : 'Edit details'),
                ),
              ),
            if (status == 'confirmed' &&
                type == 'online' &&
                location.trim().isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _joinMeeting(location),
                  icon: const Icon(Icons.video_call_outlined),
                  label: const Text('Join online meeting'),
                ),
              ),
            if (status == 'confirmed')
              Wrap(
                children: [
                  TextButton.icon(
                    onPressed: () => _addToGoogleCalendar(booking),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Add to Google Calendar'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _downloadCalendarFile(booking['booking_id'] as int),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download .ics'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class AdviserApplicationsScreen extends StatefulWidget {
  const AdviserApplicationsScreen({super.key});

  @override
  State<AdviserApplicationsScreen> createState() =>
      _AdviserApplicationsScreenState();
}

class _AdviserApplicationsScreenState extends State<AdviserApplicationsScreen> {
  List<dynamic> _applications = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Api.applications();
      if (mounted) {
        setState(() {
          _applications = rows;
          _loading = false;
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

  Future<void> _decide(Map<String, dynamic> application, String status) async {
    final id = application['application_id'] as int;
    setState(() => _busy.add(id));
    try {
      await Api.decideApplication(id, status);
      await _load();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _open(String title, Widget child) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: BentoBackground(
          child: BentoContainer(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: child,
              ),
            ),
          ),
        ),
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
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          Text('Requests & advisees',
              style: context.text3xl.copyWith(
                  color: context.textColor, fontWeight: FontWeight.w800)),
          Text('Review requests and open a project workspace.',
              style: TextStyle(color: context.textMuted)),
          const SizedBox(height: 12),
          if (_applications.isEmpty)
            const Card(
                child: ListTile(
                    title: Text('No applications yet'),
                    subtitle: Text('Student requests will show up here.'))),
          for (final raw in _applications)
            _applicationCard(Map<String, dynamic>.from(raw as Map)),
        ],
      ),
    );
  }

  Widget _applicationCard(Map<String, dynamic> application) {
    final id = application['application_id'] as int;
    final status = '${application['status'] ?? 'pending'}';
    final busy = _busy.contains(id);
    final name = '${application['student_name'] ?? 'Student'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${application['topic_brief'] ?? ''}'),
            const SizedBox(height: 6),
            Text('Status: ${status[0].toUpperCase()}${status.substring(1)}',
                style: TextStyle(color: context.textMuted)),
            if (status == 'pending')
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        busy ? null : () => _decide(application, 'declined'),
                    child: const Text('Decline'),
                  ),
                  FilledButton(
                    onPressed:
                        busy ? null : () => _decide(application, 'approved'),
                    child: Text(busy ? 'Saving…' : 'Approve'),
                  ),
                ],
              ),
            if (status == 'approved')
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () => _open(
                        'Project board', ProjectScreen(applicationId: id)),
                    icon: const Icon(Icons.view_kanban_outlined),
                    label: const Text('Board'),
                  ),
                  TextButton.icon(
                    onPressed: () => _open('Milestones',
                        ProjectScreen(applicationId: id, milestones: true)),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Milestones'),
                  ),
                  TextButton.icon(
                    onPressed: () => _open(
                      'Messages',
                      MessagingScreen(
                        applicationId: id,
                        contactName: '$name (Student)',
                        contactProfilePhoto:
                            application['student_profile_photo'] as String?,
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                  ),
                ],
              ),
            if (status == 'approved')
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Group members'),
                children: [
                  AdviserGroupMembers(applicationId: id),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class AdviserGroupMembers extends StatefulWidget {
  final int applicationId;

  const AdviserGroupMembers({super.key, required this.applicationId});

  @override
  State<AdviserGroupMembers> createState() => _AdviserGroupMembersState();
}

class _AdviserGroupMembersState extends State<AdviserGroupMembers> {
  late Future<List<dynamic>> _members;

  @override
  void initState() {
    super.initState();
    _members = Api.groupMembers(widget.applicationId);
  }

  void _reload() => setState(() {
        _members = Api.groupMembers(widget.applicationId);
      });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
        future: _members,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListTile(
              title: Text(snapshot.error.toString(),
                  style: TextStyle(color: context.errorColor())),
              trailing: IconButton(
                onPressed: _reload,
                tooltip: 'Retry',
                icon: const Icon(Icons.refresh),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data!.isEmpty) {
            return const ListTile(title: Text('No group members yet.'));
          }
          return Column(
            children: [
              for (final raw in snapshot.data!)
                _memberTile(Map<String, dynamic>.from(raw as Map)),
            ],
          );
        },
      );

  Widget _memberTile(Map<String, dynamic> member) {
    final name = '${member['name'] ?? 'Student'}';
    final photo = member['profile_photo'] as String?;
    final photoUrl = photo == null || photo.isEmpty
        ? null
        : photo.startsWith('http')
            ? photo
            : '${Api.baseUrl}${photo.startsWith('/') ? '' : '/'}$photo';
    final isLeader = member['is_leader'] == true ||
        member['is_leader'] == 1 ||
        member['student_group_role'] == 'leader';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
        child: photoUrl == null
            ? Text(name.isEmpty ? '?' : name[0].toUpperCase())
            : null,
      ),
      title: Text(name),
      subtitle: Text('${member['email'] ?? ''}'),
      trailing: isLeader ? const Chip(label: Text('Leader')) : null,
    );
  }
}

class AdviserProfileScreen extends StatefulWidget {
  const AdviserProfileScreen({super.key});

  @override
  State<AdviserProfileScreen> createState() => _AdviserProfileScreenState();
}

class _AdviserProfileScreenState extends State<AdviserProfileScreen> {
  static const _departments = [
    'Information Technology',
    'Computer Science',
    'Information Systems',
    'Data Science and Analytics',
    'Library and Information Science',
  ];
  final _specializations = TextEditingController();
  final _certifications = TextEditingController();
  final _capacity = TextEditingController();
  late Future<Map<String, dynamic>> _profile;
  String _department = _departments.first;
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = Api.adviserProfile();
  }

  @override
  void dispose() {
    _specializations.dispose();
    _certifications.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final request = Api.adviserProfile();
    setState(() {
      _initialized = false;
      _profile = request;
    });
    await request;
  }

  Future<void> _save() async {
    final capacity = int.tryParse(_capacity.text.trim());
    if (capacity == null || capacity < 1 || capacity > 50) {
      snack(context, 'Capacity must be between 1 and 50.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await Api.saveAdviserProfile(
        department: _department,
        specializationTags: _specializations.text.trim(),
        certifications: _certifications.text.trim(),
        maxCapacity: capacity,
      );
      if (mounted) snack(context, 'Adviser profile saved.');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _profile,
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
          final profile = snapshot.data!;
          if (!_initialized) {
            _department = _departments.contains(profile['department'])
                ? '${profile['department']}'
                : _departments.first;
            _specializations.text =
                '${profile['specialization_tags_text'] ?? ''}';
            _certifications.text = '${profile['certifications'] ?? ''}';
            _capacity.text = '${profile['max_capacity'] ?? 5}';
            _initialized = true;
          }
          return ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 20),
            children: [
              Text('${profile['name'] ?? 'Adviser'}',
                  style: context.text2xl.copyWith(
                      color: context.textColor, fontWeight: FontWeight.w800)),
              Text(
                  '${profile['current_advisee_count'] ?? 0} / ${profile['max_capacity'] ?? 0} advisees',
                  style: TextStyle(color: context.textMuted)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _department,
                decoration: const InputDecoration(labelText: 'Department'),
                items: _departments
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _department = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _specializations,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Specializations',
                  hintText: 'Separate topics with commas',
                ),
              ),
              TextField(
                controller: _certifications,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Certifications'),
              ),
              TextField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum advisees',
                  helperText: 'Must be at least your current advisee count.',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save profile'),
              ),
            ],
          );
        },
      );
}

class AdviserAnalyticsScreen extends StatefulWidget {
  const AdviserAnalyticsScreen({super.key});

  @override
  State<AdviserAnalyticsScreen> createState() => _AdviserAnalyticsScreenState();
}

class _AdviserAnalyticsScreenState extends State<AdviserAnalyticsScreen> {
  late Future<Map<String, dynamic>> _report;

  @override
  void initState() {
    super.initState();
    _report = Api.analytics();
  }

  Future<void> _reload() async {
    final future = Api.analytics();
    setState(() => _report = future);
    await future;
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
                Text('Reports',
                    style: context.text3xl.copyWith(
                        color: context.textColor, fontWeight: FontWeight.w800)),
                Text('Analytics for your advisees and consultations.',
                    style: TextStyle(color: context.textMuted)),
                const SizedBox(height: 12),
                Text('Open detailed records',
                    style: context.textLg.copyWith(
                        color: context.textColor, fontWeight: FontWeight.w700)),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final item in const [
                      ('Advisees', 'advisees'),
                      ('Consultations', 'consultations'),
                      ('Pending requests', 'pending'),
                      ('Applications', 'applications'),
                      ('Bookings', 'bookings'),
                      ('Cancellations', 'cancellations'),
                      ('Ratings', 'ratings'),
                      ('Board tasks', 'tasks'),
                      ('Capacity', 'workload'),
                      ('By weekday', 'weekday'),
                      ('By start time', 'hour'),
                      ('Who cancels?', 'cancelled_by'),
                    ])
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdviserAnalyticsRecordsScreen(
                              title: item.$1,
                              category: item.$2,
                            ),
                          ),
                        ),
                        child: Text(item.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final entry in snapshot.data!.entries)
                  AnalyticsDataCard(
                      title: _label(entry.key), data: entry.value),
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

class AdviserAnalyticsRecordsScreen extends StatefulWidget {
  final String title;
  final String category;

  const AdviserAnalyticsRecordsScreen({
    super.key,
    required this.title,
    required this.category,
  });

  @override
  State<AdviserAnalyticsRecordsScreen> createState() =>
      _AdviserAnalyticsRecordsScreenState();
}

class _AdviserAnalyticsRecordsScreenState
    extends State<AdviserAnalyticsRecordsScreen> {
  late Future<List<dynamic>> _records;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _records = Api.analyticsDetails(widget.category);
  }

  void _reload() => setState(() {
        _records = Api.analyticsDetails(widget.category);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: BentoBackground(
          child: BentoContainer(
            child: SafeArea(
              child: FutureBuilder<List<dynamic>>(
                future: _records,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(snapshot.error.toString(),
                                textAlign: TextAlign.center),
                            TextButton.icon(
                              onPressed: _reload,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final records = snapshot.data!
                      .whereType<Map>()
                      .map((row) => Map<String, dynamic>.from(row))
                      .where((row) => row.values.any((value) => '$value'
                          .toLowerCase()
                          .contains(_query.toLowerCase())))
                      .toList();
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Search records',
                                style: context.textLg.copyWith(
                                    color: context.textColor,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            TextField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'Search records',
                              ),
                              onChanged: (value) =>
                                  setState(() => _query = value.trim()),
                            ),
                            const SizedBox(height: 4),
                            Text('${records.length} record(s)',
                                style: TextStyle(color: context.textMuted)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: records.isEmpty
                            ? const Center(
                                child: Text('No records found.'),
                              )
                            : ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                children: [
                                  for (final record in records)
                                    Card(
                                      child: ExpansionTile(
                                        title: Text(_recordTitle(record)),
                                        children: [
                                          for (final entry in record.entries)
                                            ListTile(
                                              title: Text(_label(entry.key)),
                                              subtitle:
                                                  Text(_display(entry.value)),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

  String _recordTitle(Map<String, dynamic> record) {
    for (final key in [
      'student',
      'name',
      'title',
      'week',
      'booking_id',
      'application_id',
      'task_id',
    ]) {
      final value = record[key];
      if (value != null && '$value'.isNotEmpty) return '$value';
    }
    return 'Record';
  }

  String _label(String key) => key
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  String _display(dynamic value) => AnalyticsDataView.formatValue(value);
}
