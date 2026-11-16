import 'package:flutter/material.dart';
import '../design_tokens.dart';
import 'buttons.dart';
import 'cards.dart';
import 'badges.dart';

// Color constants from DesignTokens for static use in NextActionEngine
const _warningLight = DesignTokens.warningLight;
const _warning = DesignTokens.warning;
const _infoLight = DesignTokens.infoLight;
const _info = DesignTokens.info;
const _successLight = DesignTokens.successLight;
const _success = DesignTokens.success;
const _errorLight = DesignTokens.errorLight;
const _error = DesignTokens.error;
const _brandPrimaryLight = DesignTokens.brandPrimaryLight;
const _brandPrimary = DesignTokens.brandPrimary;

enum NextActionType {
  pendingApplication,
  upcomingBooking,
  unreadNotification,
  documentRequired,
  milestoneDue,
  ratingPending,
  adviserApproval,
  scheduleAvailability,
  waitlistOpened,
  none,
}

class NextAction {
  final NextActionType type;
  final int priority;
  final String title;
  final String description;
  final String? route;
  final VoidCallback? onTap;
  final IconData icon;
  final BadgeVariant badgeVariant;
  final String? badgeLabel;
  final Color iconBgColor;
  final Color iconColor;
  final Map<String, dynamic> metadata;

  const NextAction({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    this.route,
    this.onTap,
    required this.icon,
    required this.badgeVariant,
    this.badgeLabel,
    required this.iconBgColor,
    required this.iconColor,
    this.metadata = const {},
  });
}

class NextActionEngine {
  static List<NextAction> generate({
    required String userRole,
    required Map<String, dynamic>? status,
    required List<dynamic> notifications,
    required List<dynamic> applications,
    required List<dynamic> bookings,
    required List<dynamic> documents,
    required List<dynamic> milestones,
    required Function(String) navigate,
  }) {
    final acts = <NextAction>[];
    final now = DateTime.now();
    final in30Min = now.add(const Duration(minutes: 30));
    final in24Hours = now.add(const Duration(hours: 24));
    final in7Days = now.add(const Duration(days: 7));

    // 1. Unread urgent notifications
    final unreadUrgent = notifications
        .where((n) =>
            n['is_read'] != true &&
            ['booking_confirmed', 'application_approved', 'booking_cancelled']
                .contains(n['type']))
        .toList();

    if (unreadUrgent.isNotEmpty) {
      acts.add(NextAction(
        type: NextActionType.unreadNotification,
        priority: 100,
        title: unreadUrgent.length == 1
            ? 'New notification'
            : '${unreadUrgent.length} new notifications',
        description:
            unreadUrgent.first['message'] ?? 'Check your notifications',
        route: '/notifications',
        icon: Icons.notifications_active,
        badgeVariant: BadgeVariant.warning,
        badgeLabel: unreadUrgent.length > 1 ? '${unreadUrgent.length}' : null,
        iconBgColor: _warningLight,
        iconColor: _warning,
      ));
    }

    // 2. Upcoming booking in 30 min
    final upcomingBooking = bookings.firstWhere(
      (b) =>
          b['status'] == 'confirmed' &&
          DateTime.parse('${b['booking_date']}T${b['start_time']}')
              .isAfter(now) &&
          DateTime.parse('${b['booking_date']}T${b['start_time']}')
              .isBefore(in30Min),
      orElse: () => null,
    );

    if (upcomingBooking != null) {
      final start = DateTime.parse(
          '${upcomingBooking['booking_date']}T${upcomingBooking['start_time']}');
      final mins = start.difference(now).inMinutes;
      acts.add(NextAction(
        type: NextActionType.upcomingBooking,
        priority: 95,
        title: 'Consultation starting soon',
        description:
            '${upcomingBooking['adviser_name']} in $mins min (${upcomingBooking['mode'] == 'online' ? 'Online' : 'In-person'})',
        onTap: () =>
            navigate('/schedule?booking=${upcomingBooking['booking_id']}'),
        icon: Icons.calendar_today,
        badgeVariant: BadgeVariant.info,
        badgeLabel: '${mins}m',
        iconBgColor: _infoLight,
        iconColor: _info,
        metadata: {'bookingId': upcomingBooking['booking_id']},
      ));
    }

    // 3. Pending application
    if (userRole == 'adviser') {
      final pendingApps =
          applications.where((a) => a['status'] == 'pending').toList();
      if (pendingApps.isNotEmpty) {
        acts.add(NextAction(
          type: NextActionType.pendingApplication,
          priority: 90,
          title: pendingApps.length == 1
              ? 'Application to review'
              : '${pendingApps.length} applications pending',
          description: pendingApps.first['student_name'] != null
              ? 'From ${pendingApps.first['student_name']}'
              : 'Review student requests',
          route: '/applications',
          icon: Icons.person_add,
          badgeVariant: BadgeVariant.defaultBadge,
          badgeLabel: pendingApps.length > 1 ? '${pendingApps.length}' : null,
          iconBgColor: _brandPrimaryLight,
          iconColor: _brandPrimary,
        ));
      }
    } else if (userRole == 'student') {
      final myPending = applications
          .where((a) =>
              a['student_id'] == status?['user_id'] && a['status'] == 'pending')
          .toList();
      if (myPending.isNotEmpty) {
        acts.add(NextAction(
          type: NextActionType.pendingApplication,
          priority: 85,
          title: 'Application submitted',
          description:
              'Waiting for ${myPending.first['adviser_name'] ?? 'adviser'} to respond',
          route: '/advisers',
          icon: Icons.hourglass_empty,
          badgeVariant: BadgeVariant.info,
          iconBgColor: _infoLight,
          iconColor: _info,
        ));
      }
    }

    // 4. Adviser approval (admin)
    if (userRole == 'admin' && (status?['pending_advisers'] ?? 0) > 0) {
      acts.add(NextAction(
        type: NextActionType.adviserApproval,
        priority: 88,
        title: 'Adviser awaiting approval',
        description:
            '${status!['pending_advisers']} adviser${status['pending_advisers'] > 1 ? 's' : ''} pending review',
        route: '/users',
        icon: Icons.verified_user,
        badgeVariant: BadgeVariant.defaultBadge,
        badgeLabel: '${status['pending_advisers']}',
        iconBgColor: _brandPrimaryLight,
        iconColor: _brandPrimary,
      ));
    }

    // 5. Document required for upcoming booking
    final confirmedBookings = bookings
        .where((b) =>
            b['status'] == 'confirmed' &&
            DateTime.parse('${b['booking_date']}T${b['start_time']}')
                .isAfter(now) &&
            DateTime.parse('${b['booking_date']}T${b['start_time']}')
                .isBefore(in24Hours))
        .toList();

    final docsNeeded = confirmedBookings
        .where((b) => !documents.any((d) =>
            d['booking_id'] == b['booking_id'] && d['category'] == 'draft'))
        .toList();

    if (docsNeeded.isNotEmpty && userRole == 'student') {
      acts.add(NextAction(
        type: NextActionType.documentRequired,
        priority: 80,
        title: 'Upload draft before consultation',
        description:
            '${docsNeeded.length} booking${docsNeeded.length > 1 ? 's' : ''} in 24h need draft upload',
        route: '/schedule',
        icon: Icons.upload_file,
        badgeVariant: BadgeVariant.warning,
        badgeLabel: '${docsNeeded.length}',
        iconBgColor: _warningLight,
        iconColor: _warning,
      ));
    }

    // 6. Milestone due soon
    final dueMilestones = milestones
        .where((m) =>
            !['completed', 'cancelled'].contains(m['status']) &&
            DateTime.parse(m['due_date']).isAfter(now) &&
            DateTime.parse(m['due_date']).isBefore(in7Days))
        .toList();

    if (dueMilestones.isNotEmpty) {
      dueMilestones.sort((a, b) => DateTime.parse(a['due_date'])
          .compareTo(DateTime.parse(b['due_date'])));
      final nearest = dueMilestones.first;
      final days = DateTime.parse(nearest['due_date']).difference(now).inDays;
      acts.add(NextAction(
        type: NextActionType.milestoneDue,
        priority: 75,
        title: 'Milestone deadline approaching',
        description:
            '${nearest['title']} due in $days day${days > 1 ? 's' : ''}',
        route: '/milestones',
        icon: Icons.warning_amber,
        badgeVariant:
            days <= 2 ? BadgeVariant.destructive : BadgeVariant.warning,
        badgeLabel: '${days}d',
        iconBgColor: days <= 2 ? _errorLight : _warningLight,
        iconColor: days <= 2 ? _error : _warning,
      ));
    }

    // 7. Rating pending
    final completedNoRating = bookings
        .where((b) => b['status'] == 'completed' && b['rating'] == null)
        .toList();
    if (completedNoRating.isNotEmpty && userRole == 'student') {
      acts.add(NextAction(
        type: NextActionType.ratingPending,
        priority: 60,
        title: 'Rate your consultation',
        description:
            '${completedNoRating.length} completed session${completedNoRating.length > 1 ? 's' : ''} awaiting feedback',
        route: '/schedule',
        icon: Icons.star_rate,
        badgeVariant: BadgeVariant.success,
        badgeLabel: '${completedNoRating.length}',
        iconBgColor: _successLight,
        iconColor: _success,
      ));
    }

    // 8. Schedule availability (adviser with no slots)
    if (userRole == 'adviser' && (status?['advisee_count'] ?? 0) > 0) {
      final hasAvailability = (status?['weekly_slots'] ?? 0) > 0 ||
          (status?['specific_slots'] ?? 0) > 0;
      if (!hasAvailability) {
        acts.add(NextAction(
          type: NextActionType.scheduleAvailability,
          priority: 70,
          title: 'Set your availability',
          description: 'You have advisees but no available slots set',
          route: '/schedule',
          icon: Icons.schedule,
          badgeVariant: BadgeVariant.info,
          iconBgColor: _infoLight,
          iconColor: _info,
        ));
      }
    }

    // 9. Waitlist opened
    if (userRole == 'student' &&
        notifications.any(
            (n) => n['is_read'] != true && n['type'] == 'waitlist_opened')) {
      acts.add(NextAction(
        type: NextActionType.waitlistOpened,
        priority: 82,
        title: 'Slot opened from waitlist',
        description: 'A spot opened for an adviser you waitlisted',
        route: '/advisers',
        icon: Icons.notifications_active,
        badgeVariant: BadgeVariant.success,
        iconBgColor: _successLight,
        iconColor: _success,
      ));
    }

    // Sort by priority
    acts.sort((a, b) => b.priority.compareTo(a.priority));
    return acts;
  }
}

/// Main widget - shows primary action + secondary actions
class NextActionNudge extends StatelessWidget {
  final String userRole;
  final Map<String, dynamic>? status;
  final List<dynamic> notifications;
  final List<dynamic> applications;
  final List<dynamic> bookings;
  final List<dynamic> documents;
  final List<dynamic> milestones;
  final Function(String) navigate;
  final EdgeInsets? padding;

  const NextActionNudge({
    super.key,
    required this.userRole,
    required this.status,
    required this.notifications,
    required this.applications,
    required this.bookings,
    required this.documents,
    required this.milestones,
    required this.navigate,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final actions = NextActionEngine.generate(
      userRole: userRole,
      status: status,
      notifications: notifications,
      applications: applications,
      bookings: bookings,
      documents: documents,
      milestones: milestones,
      navigate: navigate,
    );

    if (actions.isEmpty) {
      return _buildEmptyState(context);
    }

    final primary = actions.first;
    final secondaries = actions.skip(1).take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary Action
        _PrimaryActionCard(action: primary, navigate: navigate),

        // Secondary Actions
        if (secondaries.isNotEmpty) ...[
          SizedBox(height: context.space3),
          Row(
            children: secondaries
                .map((action) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: secondaries.indexOf(action) <
                                    secondaries.length - 1
                                ? context.space2
                                : 0),
                        child: _SecondaryActionCard(
                            action: action, navigate: navigate),
                      ),
                    ))
                .toList(),
          ),
        ],

        // More indicator
        if (actions.length > 3) ...[
          SizedBox(height: context.space3),
          Center(
            child: GhostButton(
              label: '+${actions.length - 3} more in Notifications',
              onPressed: () => navigate('/notifications'),
              iconLeft: Icons.notifications_none,
              color: context.textMuted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final application = status?['application'];
    final hasAdviser = status?['has_adviser'] == true ||
        (application is Map && application['status'] == 'approved');
    if (userRole == 'student' && !hasAdviser) {
      return AppCard(
        variant: CardVariant.glass,
        padding: CardPadding.lg,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.brandPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(context.radius2xl),
              ),
              child: Icon(Icons.search, color: context.brandPrimary, size: 24),
            ),
            SizedBox(width: context.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Find your adviser',
                      style: context.textLg.copyWith(
                          fontWeight: DesignTokens.weightBold,
                          color: context.textColor)),
                  SizedBox(height: context.space1),
                  Text(
                      'Browse available advisers, check schedules, and send an application to get started.',
                      style: context.textSm.copyWith(color: context.textMuted)),
                  SizedBox(height: context.space4),
                  PrimaryButton(
                      label: 'Find Adviser',
                      onPressed: () => navigate('/advisers'),
                      fullWidth: false,
                      iconRight: Icons.arrow_forward),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (userRole == 'adviser' && (status?['advisee_count'] ?? 0) == 0) {
      return AppCard(
        variant: CardVariant.glass,
        padding: CardPadding.lg,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.successColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(context.radius2xl),
              ),
              child: Icon(Icons.person_add,
                  color: context.successColor(), size: 24),
            ),
            SizedBox(width: context.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Waiting for students',
                      style: context.textLg.copyWith(
                          fontWeight: DesignTokens.weightBold,
                          color: context.textColor)),
                  SizedBox(height: context.space1),
                  Text(
                      'Your profile is active. Students will send applications once they find your expertise matching.',
                      style: context.textSm.copyWith(color: context.textMuted)),
                  SizedBox(height: context.space4),
                  SecondaryButton(
                      label: 'Complete Profile',
                      onPressed: () => navigate('/settings'),
                      fullWidth: false,
                      iconRight: Icons.arrow_forward),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      variant: CardVariant.glass,
      padding: CardPadding.lg,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.surfaceHover,
              borderRadius: BorderRadius.circular(context.radius2xl),
            ),
            child: Icon(Icons.check_circle, color: context.textMuted, size: 24),
          ),
          SizedBox(width: context.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All caught up!',
                    style: context.textLg.copyWith(
                        fontWeight: DesignTokens.weightBold,
                        color: context.textColor)),
                SizedBox(height: context.space1),
                Text(
                    'No immediate actions needed. Check back later or browse your schedule.',
                    style: context.textSm.copyWith(color: context.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  final NextAction action;
  final Function(String) navigate;

  const _PrimaryActionCard({required this.action, required this.navigate});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: CardVariant.elevated,
      padding: CardPadding.lg,
      hover: true,
      onTap: action.onTap ??
          (action.route != null ? () => navigate(action.route!) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: action.iconBgColor,
              borderRadius: BorderRadius.circular(context.radius2xl),
            ),
            child: Icon(action.icon, color: action.iconColor, size: 24),
          ),
          SizedBox(width: context.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(action.title,
                          style: context.textLg.copyWith(
                              fontWeight: DesignTokens.weightBold,
                              color: context.textColor)),
                    ),
                    if (action.badgeLabel != null)
                      AppBadge(
                        label: action.badgeLabel!,
                        variant: action.badgeVariant,
                        size: BadgeSize.sm,
                      ),
                  ],
                ),
                SizedBox(height: context.space2),
                Text(action.description,
                    style: context.textSm.copyWith(color: context.textMuted)),
                SizedBox(height: context.space4),
                if (action.onTap != null || action.route != null)
                  PrimaryButton(
                    label: 'Take Action',
                    onPressed: action.onTap ?? () => navigate(action.route!),
                    fullWidth: false,
                    iconRight: Icons.arrow_forward,
                    backgroundColor: action.iconColor,
                    foregroundColor: Colors.white,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryActionCard extends StatelessWidget {
  final NextAction action;
  final Function(String) navigate;

  const _SecondaryActionCard({required this.action, required this.navigate});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: CardVariant.outlined,
      padding: CardPadding.md,
      hover: true,
      onTap: action.onTap ??
          (action.route != null ? () => navigate(action.route!) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: action.iconBgColor,
              borderRadius: BorderRadius.circular(context.radiusXl),
            ),
            child: Icon(action.icon, color: action.iconColor, size: 18),
          ),
          SizedBox(width: context.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action.title,
                    style: context.textSm.copyWith(
                        fontWeight: DesignTokens.weightSemibold,
                        color: context.textColor)),
                SizedBox(height: context.space1),
                Text(action.description,
                    style: context.textXs.copyWith(color: context.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (action.badgeLabel != null) ...[
                  SizedBox(height: context.space2),
                  AppBadge(
                      label: action.badgeLabel!,
                      variant: action.badgeVariant,
                      size: BadgeSize.sm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience widget for home screen integration
class NextActionHome extends StatelessWidget {
  final String userRole;
  final Map<String, dynamic>? status;
  final List<dynamic> notifications;
  final List<dynamic> applications;
  final List<dynamic> bookings;
  final List<dynamic> documents;
  final List<dynamic> milestones;
  final Function(String) navigate;

  const NextActionHome({
    super.key,
    required this.userRole,
    required this.status,
    required this.notifications,
    required this.applications,
    required this.bookings,
    required this.documents,
    required this.milestones,
    required this.navigate,
  });

  @override
  Widget build(BuildContext context) {
    return NextActionNudge(
      userRole: userRole,
      status: status,
      notifications: notifications,
      applications: applications,
      bookings: bookings,
      documents: documents,
      milestones: milestones,
      navigate: navigate,
    );
  }
}
