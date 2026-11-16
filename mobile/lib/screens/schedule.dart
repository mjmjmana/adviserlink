import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../components/calendar_marker_grid.dart';
import '../theme.dart';
import '../util.dart';
import '../ui.dart';

/// Pang-student: calendar (week/month), mga consultation sa napiling araw, at pag-book.
class ScheduleScreen extends StatefulWidget {
  final int adviserId;
  final String adviserName;
  const ScheduleScreen(
      {super.key, required this.adviserId, required this.adviserName});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selected = DateTime.now();
  String _view = 'week';
  List<dynamic> _bookings = [];
  List<dynamic> _availabilitySlots = [];
  List<dynamic> _attention = [];
  List<dynamic> _quick = [];
  String _error = '';
  bool get _canBook => Api.user?['student_group_role'] != 'member';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // "Needs your attention" at "Quick book": mga mabilisang gawin
  Future<void> _loadSmart() async {
    try {
      final a = await Api.attention();
      final q = await Api.nextSlots(widget.adviserId);
      if (mounted)
        setState(() {
          _attention = a;
          _quick = q;
        });
    } catch (_) {/* hindi mahalaga kung pumalya */}
  }

  Future<void> _load() async {
    _loadSmart();
    try {
      final grid = monthGrid(_selected);
      final results = await Future.wait<dynamic>([
        Api.bookings(ymd(grid.first), ymd(grid.last)),
        Api.slotsRange(widget.adviserId, ymd(grid.first), ymd(grid.last)),
      ]);
      if (!mounted) return;
      setState(() {
        _bookings = results[0] as List<dynamic>;
        _availabilitySlots = results[1] as List<dynamic>;
        _error = '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _select(DateTime d) {
    final monthChanged = d.year != _selected.year || d.month != _selected.month;
    setState(() => _selected = d);
    if (monthChanged) _load();
  }

  void _step(int dir) {
    if (_view == 'month') {
      _select(DateTime(_selected.year, _selected.month + dir, 1));
    } else {
      _select(
          DateTime(_selected.year, _selected.month, _selected.day + 7 * dir));
    }
  }

  bool _isTrue(dynamic value) => value == true || value == 1;

  Set<String> get _activityDates => _bookings
      .where((booking) => _isTrue(booking['has_new_activity']))
      .map((booking) => '${booking['slot_date']}')
      .toSet();

  Set<String> get _bookedDates => _bookings
      .where((booking) =>
          booking['status'] == 'confirmed' &&
          !_activityDates.contains('${booking['slot_date']}'))
      .map((booking) => '${booking['slot_date']}')
      .toSet();

  Set<String> get _openDates => _availabilitySlots
      .where((slot) => _isTrue(slot['available']))
      .map((slot) => '${slot['date']}')
      .toSet();

  Widget _calendar() => CalendarMarkerGrid(
        selected: _selected,
        monthView: _view == 'month',
        bookedDates: _bookedDates,
        openDates: _openDates,
        activityDates: _activityDates,
        onSelect: _select,
        onPrevious: () => _step(-1),
        onNext: () => _step(1),
      );

  Future<void> _cancel(Map<String, dynamic> b) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceElevated,
        title: Text('Cancel this consultation?',
            style: TextStyle(color: context.textColor)),
        content: TextField(
            controller: c,
            maxLines: 3,
            decoration: InputDecoration(
                labelText: 'Reason (optional)',
                labelStyle: TextStyle(color: context.textMuted))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text('Keep it', style: TextStyle(color: context.textMuted))),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: context.errorColor()),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.cancelBooking(b['booking_id'] as int, c.text.trim());
      if (mounted) snack(context, 'Consultation cancelled.');
      _load();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _book() async {
    if (!_canBook) {
      snack(context, 'Only the group leader can book consultations.',
          error: true);
      return;
    }
    final date = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookSheet(
          adviserId: widget.adviserId, adviserName: widget.adviserName),
    );
    if (date != null) {
      setState(() => _selected = parseYmd(date));
      if (mounted)
        snack(context, 'Consultation booked. Your adviser was notified.');
      _load();
    }
  }

  Widget _attentionCard() {
    if (_attention.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Needs your attention',
              style: context.textLg.copyWith(
                  fontWeight: FontWeight.w800, color: context.textColor)),
          const SizedBox(height: 8),
          for (final raw in _attention)
            _attentionRow(Map<String, dynamic>.from(raw as Map)),
        ]),
      ),
    );
  }

  Widget _attentionRow(Map<String, dynamic> it) {
    final action = it['action'] as Map?;
    final type = action == null ? null : action['type'];
    final level = it['level'] as String? ?? 'info';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: level == 'warn'
            ? DesignTokens.warningBg(context)
            : DesignTokens.infoBg(context),
        borderRadius: BorderRadius.circular(DesignTokens.radius2xl),
      ),
      child: Row(children: [
        Icon(
          level == 'warn' ? Icons.warning_amber_rounded : Icons.info_outline,
          color: level == 'warn'
              ? DesignTokens.warningColor(context)
              : DesignTokens.infoColor(context),
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text('${it['text']}',
                style: context.textSm.copyWith(color: context.textColor))),
        if (type == 'book' && _canBook)
          TextButton(
              onPressed: _book,
              child: Text('Book',
                  style: TextStyle(
                      color: context.brandPrimary,
                      fontWeight: FontWeight.w600))),
        if (type == 'rate')
          TextButton(
              onPressed: () => _rate(action!['booking_id'] as int),
              child: Text('Rate',
                  style: TextStyle(
                      color: context.brandPrimary,
                      fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _quickCard() {
    if (_quick.isEmpty || !_canBook) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Quick book',
              style: context.textLg.copyWith(
                  fontWeight: FontWeight.w800, color: context.textColor)),
          Text('Next available with ${widget.adviserName}',
              style: context.textSm.copyWith(color: context.textMuted)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final raw in _quick)
              ActionChip(
                label: Text(
                    '${fmtDateLong(parseYmd('${raw['date']}'))} · ${fmtTime('${raw['start']}')}'),
                onPressed: () =>
                    _quickBook(Map<String, dynamic>.from(raw as Map)),
                backgroundColor: context.surfaceHover,
                side: BorderSide(color: context.borderColor),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusFull)),
              ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _quickBook(Map<String, dynamic> q) async {
    final controller = TextEditingController();
    var error = '';
    final notes = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceElevated,
          title: Text(
              'Book ${fmtDateLong(parseYmd('${q['date']}'))} at ${fmtTime('${q['start']}')}?',
              style: TextStyle(color: context.textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your adviser will set if it is online or in person.',
                style: TextStyle(color: context.textMuted),
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: controller,
                label: 'What will you discuss?',
                required: true,
                maxLines: 3,
                maxLength: 1000,
                prefixIcon: Icons.note_alt,
              ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error,
                    style: TextStyle(color: context.errorColor()),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: context.textMuted)),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setDialogState(
                      () => error = 'Please tell us what you will discuss.');
                  return;
                }
                Navigator.pop(ctx, value);
              },
              child: const Text('Yes, book it'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (notes == null) return;
    try {
      await Api.book(widget.adviserId, '${q['date']}', '${q['start']}', notes);
      setState(() => _selected = parseYmd('${q['date']}'));
      if (mounted)
        snack(context, 'Consultation booked. Your adviser was notified.');
      _load();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
      _load();
    }
  }

  Future<void> _rate(int bookingId) async {
    var stars = 0;
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: context.surfaceElevated,
          title: Text('How was your consultation?',
              style: TextStyle(color: context.textColor)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var n = 1; n <= 5; n++)
                IconButton(
                  onPressed: () => setS(() => stars = n),
                  icon: Icon(n <= stars ? Icons.star : Icons.star_border,
                      color: context.brandPrimary, size: 34),
                ),
            ]),
            TextField(
                controller: c,
                maxLines: 3,
                decoration: InputDecoration(
                    labelText: 'Comment (optional)',
                    labelStyle: TextStyle(color: context.textMuted))),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child:
                    Text('Cancel', style: TextStyle(color: context.textMuted))),
            FilledButton(
                onPressed: stars == 0 ? null : () => Navigator.pop(ctx, true),
                child: const Text('Send')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await Api.rate(bookingId, stars, c.text.trim());
      if (mounted) snack(context, 'Thanks for your feedback!');
      _load();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = Api.user?['name'] as String? ?? '';
    final day =
        _bookings.where((b) => b['slot_date'] == ymd(_selected)).toList();
    return RefreshIndicator(
      color: context.brandPrimary,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Hello, ${firstName(name)}!',
            style: context.text3xl.copyWith(
                fontWeight: FontWeight.w800, color: context.textColor)),
        Text('Your consultations with ${widget.adviserName}',
            style: context.textBase.copyWith(color: context.textMuted)),
        const SizedBox(height: 12),
        if (_error.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Text(_error, style: TextStyle(color: context.errorColor()))),
        _attentionCard(),
        _quickCard(),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'week', label: Text('Week')),
                  ButtonSegment(value: 'month', label: Text('Month'))
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
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
            ),
            const SizedBox(height: 8),
            _calendar(),
            const SizedBox(height: 8),
            const CalendarMarkerLegend(),
          ]),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(fmtDateLong(_selected),
                  style: context.textXl.copyWith(
                      fontWeight: FontWeight.w800, color: context.textColor)),
              if (_canBook)
                PrimaryButton(
                    onPressed: _book, label: 'Book', fullWidth: false),
            ]),
            if (day.isEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('No consultations on this day.',
                      style:
                          context.textBase.copyWith(color: context.textMuted))),
            for (final raw in day)
              _eventCard(Map<String, dynamic>.from(raw as Map)),
          ]),
        ),
      ]),
    );
  }

  Widget _eventCard(Map<String, dynamic> b) {
    final cancelled = b['status'] == 'cancelled';
    return Opacity(
      opacity: cancelled ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: context.surfaceHover,
            borderRadius: BorderRadius.circular(DesignTokens.radius3xl)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
                color: context.brandPrimary,
                borderRadius: BorderRadius.circular(DesignTokens.radius2xl)),
            child: Column(children: [
              Text(fmtTime('${b['start_time']}'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              Text(fmtTime('${b['end_time']}'),
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${b['adviser_name']}',
                  style: context.textBase.copyWith(
                      fontWeight: FontWeight.w800, color: context.textColor)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                StatusPill(
                    label: '${b['status']}',
                    tone: _statusTone('${b['status']}')),
                if (b['status'] == 'confirmed' && b['meeting_type'] != null)
                  AppBadge(
                      label: b['meeting_type'] == 'online'
                          ? 'Online'
                          : 'In person',
                      variant: BadgeVariant.info),
                if (b['status'] == 'confirmed' && b['meeting_type'] == null)
                  AppBadge(
                      label: 'Awaiting meeting details',
                      variant: BadgeVariant.warning),
              ]),
              if (b['location'] != null && b['meeting_type'] != 'online')
                InfoRow(
                    icon: Icons.location_on,
                    label: 'Location',
                    value: '${b['location']}',
                    iconColor: context.textMuted),
              if (b['status'] == 'confirmed' &&
                  b['meeting_type'] == 'online' &&
                  (b['location'] as String? ?? '').trim().isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _joinMeeting('${b['location']}'),
                    icon: const Icon(Icons.video_call_outlined),
                    label: const Text('Join online meeting'),
                  ),
                ),
              if (b['notes'] != null)
                InfoRow(
                    icon: Icons.note_alt,
                    label: 'Notes',
                    value: '${b['notes']}',
                    iconColor: context.textMuted),
              if (cancelled && b['cancel_reason'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Reason: ${b['cancel_reason']}',
                      style: context.textSm.copyWith(color: context.textMuted)),
                ),
              if (b['status'] == 'confirmed')
                if (b['meeting_type'] != null &&
                    b['leader_accepted'] != 1 &&
                    b['leader_accepted'] != true &&
                    (b['can_manage'] == 1 || b['can_manage'] == true))
                  TextButton(
                    onPressed: () => _acceptMeeting(b['booking_id'] as int),
                    child: Text('Accept meeting details',
                        style: TextStyle(
                            color: context.brandPrimary,
                            fontWeight: FontWeight.w700)),
                  ),
              if (b['status'] == 'confirmed' &&
                  (b['leader_accepted'] == 1 || b['leader_accepted'] == true))
                Text('Meeting accepted',
                    style: context.textSm.copyWith(
                        color: context.successColor(),
                        fontWeight: FontWeight.w700)),
              if (b['status'] == 'confirmed') ...[
                if (_canBook)
                  TextButton(
                      onPressed: () => _cancel(b),
                      child: Text('Cancel',
                          style: TextStyle(
                              color: context.errorColor(),
                              fontWeight: FontWeight.w700))),
                Wrap(
                  children: [
                    TextButton.icon(
                      onPressed: () => _addToGoogleCalendar(b),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Add to Google Calendar'),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _downloadCalendarFile(b['booking_id'] as int),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download .ics'),
                    ),
                  ],
                ),
              ],
              if (b['status'] == 'completed' && b['rating'] == null && _canBook)
                TextButton(
                    onPressed: () => _rate(b['booking_id'] as int),
                    child: Text('Rate this consultation',
                        style: TextStyle(
                            color: context.brandPrimary,
                            fontWeight: FontWeight.w700))),
              if (b['status'] == 'completed' && b['rating'] != null)
                Text('★ ${b['rating']}',
                    style: context.textBase.copyWith(
                        fontWeight: FontWeight.w800, color: context.textColor)),
            ]),
          ),
        ]),
      ),
    );
  }

  String _calendarUtc(String date, String time) {
    final value = DateTime.parse('${date}T$time').toUtc();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}'
        'T${twoDigits(value.hour)}${twoDigits(value.minute)}'
        '${twoDigits(value.second)}Z';
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

  Future<void> _addToGoogleCalendar(Map<String, dynamic> booking) async {
    try {
      final date = '${booking['slot_date']}';
      final uri = Uri.https('calendar.google.com', '/calendar/render', {
        'action': 'TEMPLATE',
        'text': 'Consultation with ${booking['adviser_name'] ?? 'Adviser'}',
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

  Future<void> _acceptMeeting(int bookingId) async {
    try {
      await Api.acceptMeeting(bookingId);
      if (mounted) snack(context, 'Meeting details accepted.');
      await _load();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  String _statusTone(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'confirmed':
        return 'info';
      case 'completed':
        return 'success';
      case 'declined':
      case 'cancelled':
        return 'error';
      default:
        return 'primary';
    }
  }
}

/// Bottom sheet para pumili ng petsa, oras, at uri ng meeting.
class BookSheet extends StatefulWidget {
  final int adviserId;
  final String adviserName;
  const BookSheet(
      {super.key, required this.adviserId, required this.adviserName});
  @override
  State<BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<BookSheet> {
  DateTime _date = DateTime.now();
  List<dynamic> _slots = [];
  String? _start;
  bool _loading = false;
  bool _busy = false;
  String _error = '';
  final _notes = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loading = true;
      _start = null;
    });
    try {
      final s = await Api.slots(widget.adviserId, ymd(_date));
      if (mounted)
        setState(() {
          _slots = s;
          _error = '';
        });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      builder: (ctx, child) => Theme(data: buildLight(), child: child!),
    );
    if (d != null) {
      setState(() => _date = d);
      _loadSlots();
    }
  }

  Future<void> _confirm() async {
    if (_start == null) {
      setState(() => _error = 'Pick a time first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await Api.book(widget.adviserId, ymd(_date), _start!, _notes.text.trim());
      if (mounted) Navigator.pop(context, ymd(_date));
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
      _loadSlots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
        child: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Book ${widget.adviserName}',
                style: context.textXl.copyWith(
                    fontWeight: FontWeight.w800, color: context.textColor)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: Icon(Icons.calendar_today,
                  size: 18, color: context.textColor),
              label: Text(fmtDateLong(_date),
                  style: TextStyle(color: context.textColor)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.space4,
                    vertical: DesignTokens.space3),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radius2xl)),
                side: BorderSide(color: context.borderColor),
              ),
            ),
            const SizedBox(height: 10),
            Text('Open times',
                style: context.textLg.copyWith(
                    fontWeight: FontWeight.w700, color: context.textColor)),
            if (_loading)
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: LinearProgressIndicator(color: context.brandPrimary)),
            if (!_loading && _slots.isEmpty)
              Text('No open times on this day. Try another date.',
                  style: context.textBase.copyWith(color: context.textMuted)),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final s in _slots)
                ChoiceChip(
                  label: Text(fmtTime('${s['start']}')),
                  selected: _start == s['start'],
                  selectedColor: context.brandPrimary,
                  labelStyle: TextStyle(
                      color: _start == s['start']
                          ? Colors.white
                          : context.textColor),
                  onSelected: s['available'] == true
                      ? (_) => setState(() => _start = '${s['start']}')
                      : null,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusFull)),
                  backgroundColor: context.surfaceHover,
                  side: BorderSide(color: context.borderColor),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  'Your adviser will tell you if it will be online or in person.',
                  style: context.textSm.copyWith(color: context.textMuted)),
            ),
            const SizedBox(height: 10),
            Form(
              key: _formKey,
              child: AppInput(
                controller: _notes,
                label: 'What will you discuss?',
                required: true,
                maxLines: 2,
                maxLength: 1000,
                prefixIcon: Icons.note_alt,
                validator: (value) => value?.trim().isNotEmpty == true
                    ? null
                    : 'Please tell us what you will discuss.',
              ),
            ),
            if (_error.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error,
                      style: TextStyle(color: context.errorColor()))),
            const SizedBox(height: 14),
            SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                    onPressed: _busy ? null : _confirm,
                    label: _busy ? 'Booking…' : 'Confirm booking')),
          ]),
        ),
      ),
    );
  }
}
