import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../audio.dart';
import '../api.dart';
import '../design_tokens.dart';
import '../theme.dart';
import '../ui.dart';
import '../util.dart';
import 'advisers.dart';
import 'schedule.dart';
import 'notifications.dart';
import 'settings.dart';
import 'project.dart';
import 'messaging.dart';
import 'adviser_home.dart';
import 'admin_home.dart';
import 'student_profile_setup.dart';
import 'student_tools.dart';

bool hasApprovedAdviser(Map<String, dynamic>? status) {
  final application = status?['application'];
  return application is Map &&
      (status?['has_adviser'] == true || application['status'] == 'approved');
}

Widget homeForRole(String? role) {
  switch (role) {
    case 'adviser':
      return const AdviserHomeShell();
    case 'admin':
      return const AdminHomeShell();
    default:
      return const _StudentHomeShell();
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    if (needsStudentTitleSetup(Api.user)) {
      return StudentProfileSetupScreen(
        onComplete: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeShell()),
            (_) => false,
          );
        },
      );
    }
    return homeForRole(Api.user?['role']);
  }
}

class _StudentHomeShell extends StatefulWidget {
  const _StudentHomeShell();
  @override
  State<_StudentHomeShell> createState() => _StudentHomeShellState();
}

class _StudentHomeShellState extends State<_StudentHomeShell> {
  int _index = 0;
  int _unread = 0;
  int? _lastId;
  Map<String, dynamic>? _status;
  Timer? _timer;
  Timer? _consultationTimer;
  Timer? _bookingAlarmTimer;
  Timer? _bookingStartTimer;
  int? _alarmBookingId;
  bool _checkingConsultation = false;
  String? _statusError;

  bool get _hasAdviser => hasApprovedAdviser(_status);

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
    _pollConsultationAlert();
    _consultationTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _pollConsultationAlert());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _consultationTimer?.cancel();
    _cancelBookingAlarm();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final before = _hasAdviser;
      final s = await Api.status();
      if (!mounted) return;
      setState(() {
        _status = s;
        _statusError = null;
        if (before != _hasAdviser) _index = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusError = e.toString());
    }
  }

  Future<void> _poll() async {
    await _loadStatus();
    try {
      final d = await Api.notifications();
      final items = d['items'] as List<dynamic>;
      final newest =
          items.isNotEmpty ? items.first['notification_id'] as int : 0;
      if (_lastId != null && newest > _lastId!) {
        final fresh = items
            .where((n) =>
                (n['notification_id'] as int) > _lastId! && n['is_read'] == 0)
            .toList();
        if (fresh.isNotEmpty && mounted) {
          AppAudio.playNotificationSafely();
          HapticFeedback.vibrate();
          snack(
              context,
              fresh.length > 1
                  ? '🔔 ${fresh.length} new notifications'
                  : '🔔 ${fresh.first['message']}');
        }
      }
      _lastId = newest;
      if (mounted)
        setState(() {
          _unread = d['unread'] as int;
        });
    } catch (_) {/* offline: okay lang */}
  }

  Future<void> _pollConsultationAlert() async {
    if (_checkingConsultation || Api.user?['role'] != 'student') return;
    _checkingConsultation = true;
    try {
      final now = DateTime.now();
      final bookings = await Api.bookings(
        ymd(now),
        ymd(now.add(const Duration(days: 1))),
      );
      if (!mounted) return;

      final isLeader = Api.user?['student_group_role'] != 'member';
      final userId = Api.user?['user_id'];
      Map<String, dynamic>? nextBooking;
      DateTime? nextStart;
      for (final raw in bookings) {
        final booking = Map<String, dynamic>.from(raw as Map);
        final accepted = booking['leader_accepted'] == true ||
            booking['leader_accepted'] == 1;
        if (booking['status'] != 'confirmed' || accepted) continue;
        if (isLeader && booking['student_id'] != userId) continue;

        final startsAt = DateTime.parse(
          '${booking['slot_date']}T${booking['start_time']}',
        );
        final untilStart = startsAt.difference(now);
        if (untilStart.isNegative || untilStart > const Duration(minutes: 10)) {
          continue;
        }
        if (nextStart == null || startsAt.isBefore(nextStart)) {
          nextBooking = booking;
          nextStart = startsAt;
        }
      }

      if (nextBooking == null || nextStart == null) {
        _cancelBookingAlarm();
        return;
      }

      final bookingId = nextBooking['booking_id'] as int;
      if (_alarmBookingId == bookingId) return;
      _cancelBookingAlarm();
      _alarmBookingId = bookingId;
      AppAudio.playBookingAlarmSafely();
      _bookingAlarmTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => AppAudio.playBookingAlarmSafely(),
      );
      _bookingStartTimer = Timer(
        nextStart.difference(DateTime.now()),
        () {
          if (_alarmBookingId == bookingId) {
            AppAudio.playBookingAlarmSafely();
          }
        },
      );
    } on Exception catch (error, stackTrace) {
      debugPrint('Could not check for upcoming consultations: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _checkingConsultation = false;
    }
  }

  void _cancelBookingAlarm() {
    _bookingAlarmTimer?.cancel();
    _bookingStartTimer?.cancel();
    _bookingAlarmTimer = null;
    _bookingStartTimer = null;
    _alarmBookingId = null;
  }

  Future<void> _openBell() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    _poll();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == null) {
      return Scaffold(
        body: BentoBackground(
          child: BentoContainer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _statusError == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off,
                              size: 48, color: context.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            'Can’t connect to AdviserLink',
                            textAlign: TextAlign.center,
                            style: context.textXl.copyWith(
                              color: context.textColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_statusError\n\nCould not connect to ${Api.baseUrl}. Check that the API is running. For a real phone, use your computer LAN IP and the same Wi-Fi network.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.textMuted),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() => _statusError = null);
                              _loadStatus();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    }

    final app = _status!['application'] as Map<String, dynamic>?;
    final isGroupMember = Api.user?['student_group_role'] == 'member';
    final pages = _hasAdviser
        ? <Widget>[
            ScheduleScreen(
                adviserId: app!['adviser_id'] as int,
                adviserName: '${app['adviser_name']}'),
            ProjectScreen(applicationId: app['application_id'] as int),
            ProjectScreen(
                applicationId: app['application_id'] as int, milestones: true),
            StudentToolsScreen(
                applicationId: app['application_id'] as int),
            const NotificationsScreen(),
            const SettingsScreen(),
          ]
        : isGroupMember
        ? <Widget>[
            const StudentToolsScreen(),
            const NotificationsScreen(),
            const SettingsScreen(),
          ]
        : <Widget>[
            AdvisersScreen(status: _status!, onChanged: _loadStatus),
            const StudentToolsScreen(),
            const NotificationsScreen(),
            const SettingsScreen(),
          ];
    final destinations = _hasAdviser
        ? const [
            NavigationDestination(
                icon: Icon(Icons.calendar_month), label: 'Schedule'),
            NavigationDestination(
                icon: Icon(Icons.view_kanban_outlined), label: 'Board'),
            NavigationDestination(
                icon: Icon(Icons.flag_outlined), label: 'Milestones'),
            NavigationDestination(
                icon: Icon(Icons.more_horiz), label: 'More'),
            NavigationDestination(
                icon: Icon(Icons.notifications_none), label: 'Alerts'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined), label: 'Settings'),
          ]
        : isGroupMember
        ? const [
            NavigationDestination(
                icon: Icon(Icons.groups_outlined), label: 'Find a group'),
            NavigationDestination(
                icon: Icon(Icons.notifications_none), label: 'Alerts'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined), label: 'Settings'),
          ]
        : const [
            NavigationDestination(
                icon: Icon(Icons.search), label: 'Find adviser'),
            NavigationDestination(
                icon: Icon(Icons.more_horiz), label: 'More'),
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
              // Custom app bar inside bento container
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset('assets/adviserlink-logo.png',
                              width: 30, height: 30)),
                      const SizedBox(width: 8),
                      Text('adviserlink',
                          style: context.textXl.copyWith(
                              fontWeight: FontWeight.w800,
                              color: context.textColor)),
                      const Spacer(),
                      if (_hasAdviser)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: const Text('Messages'),
                                    backgroundColor: context.surface,
                                    foregroundColor: context.textColor,
                                  ),
                                  body: BentoBackground(
                                    child: BentoContainer(
                                      child: SafeArea(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16),
                                          child: MessagingScreen(
                                            applicationId:
                                                app!['application_id'] as int,
                                            contactName:
                                                '${app['adviser_name']} (Adviser)',
                                            contactProfilePhoto:
                                                app['adviser_profile_photo']
                                                    as String?,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat'),
                          style: TextButton.styleFrom(
                            foregroundColor: context.brandPrimary,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      IconButton2(
                        icon: Icons.notifications_none,
                        onPressed: _openBell,
                        tooltip: 'Notifications',
                        backgroundColor:
                            _unread > 0 ? context.brandPrimary : null,
                        foregroundColor: _unread > 0 ? Colors.white : null,
                      ),
                    ],
                  ),
                ),
              ),
              // Content
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: KeyedSubtree(
                        key: ValueKey('${_hasAdviser}_$_index'),
                        child: pages[_index]),
                  ),
                ),
              ),
              // Bottom navigation
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    destinations: destinations,
                    height: 64,
                    backgroundColor: context.surfaceElevated,
                    indicatorColor: context.brandPrimary,
                    labelTextStyle: WidgetStatePropertyAll(TextStyle(
                        color: context.textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                    surfaceTintColor: Colors.transparent,
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
