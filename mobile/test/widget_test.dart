import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adviserlink/audio.dart';
import 'package:adviserlink/screens/admin_home.dart';
import 'package:adviserlink/screens/adviser_home.dart';
import 'package:adviserlink/screens/auth.dart';
import 'package:adviserlink/screens/home.dart';
import 'package:adviserlink/screens/student_profile_setup.dart';
import 'package:adviserlink/theme.dart';
import 'package:adviserlink/components/next_action.dart';
import 'package:adviserlink/components/calendar_marker_grid.dart';
import 'package:adviserlink/components/analytics_data_view.dart';
import 'package:adviserlink/screens/settings.dart';
import 'package:adviserlink/util.dart';
import 'package:adviserlink/api.dart';
import 'package:adviserlink/components/buttons.dart';

void main() {
  test('sound preference defaults on and persists changes', () async {
    SharedPreferences.setMockInitialValues({});

    await AppAudio.load();
    expect(AppAudio.enabled, isTrue);

    await AppAudio.setEnabled(false);
    await AppAudio.load();
    expect(AppAudio.enabled, isFalse);
  });

  test('fmtTime formats 24-hour time', () {
    expect(fmtTime('13:30'), '1:30 PM');
    expect(fmtTime('00:05'), '12:05 AM');
  });

  test('meeting links normalize pasted URLs and reject unsafe schemes', () {
    expect(
      meetingUri('meet.google.com/abc-defg-hij').toString(),
      'https://meet.google.com/abc-defg-hij',
    );
    expect(meetingUri('https://zoom.us/j/123')?.scheme, 'https');
    expect(meetingUri('javascript:alert(1)'), isNull);
    expect(meetingUri('https://'), isNull);
  });

  testWidgets('calendar shows separate booking, open-time, and activity dots',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildLight(),
      home: Scaffold(
        body: CalendarMarkerGrid(
          selected: DateTime(2025, 1, 15),
          monthView: true,
          bookedDates: {'2025-01-15'},
          openDates: {'2025-01-16'},
          activityDates: {'2025-01-17'},
          onSelect: (_) {},
          onPrevious: () {},
          onNext: () {},
        ),
      ),
    ));

    expect(
        find.byKey(const ValueKey('booked-marker-2025-01-15')), findsOneWidget);
    expect(find.byKey(const Key('open-marker')), findsOneWidget);
    expect(find.byKey(const Key('activity-marker')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('analytics shows readable labels for coded values',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildLight(),
      home: const Scaffold(
        body: AnalyticsDataCard(
          title: 'Booking Status',
          data: [
            {'name': 'in_progress', 'value': 2},
          ],
        ),
      ),
    ));

    await tester.tap(find.text('Booking Status'));
    await tester.pumpAndSettle();

    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings shows the student group role', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Api.user = {
      'role': 'student',
      'student_group_role': 'member',
      'name': 'Test Student',
      'email': 'student@example.com',
    };
    addTearDown(() => Api.user = null);

    await tester.pumpWidget(MaterialApp(
      theme: buildLight(),
      home: const Scaffold(body: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Student · Group Member'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('approved application opens adviser project tabs', () {
    expect(
      hasApprovedAdviser({
        'has_adviser': false,
        'application': {'status': 'approved'},
      }),
      isTrue,
    );
    expect(
      hasApprovedAdviser({
        'has_adviser': false,
        'application': {'status': 'pending'},
      }),
      isFalse,
    );
    expect(hasApprovedAdviser(null), isFalse);
  });

  test('home routes users to their role workspace', () {
    expect(homeForRole('student'), isNot(isA<AdviserHomeShell>()));
    expect(homeForRole('student'), isNot(isA<AdminHomeShell>()));
    expect(homeForRole('adviser'), isA<AdviserHomeShell>());
    expect(homeForRole('admin'), isA<AdminHomeShell>());
  });

  test('student title setup is required only when a student title is missing',
      () {
    expect(
      needsStudentTitleSetup({'role': 'student', 'thesis_title': 'short'}),
      isTrue,
    );
    expect(
      needsStudentTitleSetup({
        'role': 'student',
        'thesis_title': 'A complete capstone title',
      }),
      isFalse,
    );
    expect(
      needsStudentTitleSetup({'role': 'adviser', 'thesis_title': null}),
      isFalse,
    );
  });

  testWidgets(
      'student title setup blocks continuation until title is long enough',
      (tester) async {
    Api.user = {
      'role': 'student',
      'name': 'Test Student',
      'thesis_title': '',
    };
    addTearDown(() => Api.user = null);

    await tester.pumpWidget(MaterialApp(
      theme: buildLight(),
      home: StudentProfileSetupScreen(onComplete: () {}),
    ));

    final button = find.byType(PrimaryButton);
    expect(find.text('Complete your student profile'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(button).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('student-title')),
      'A complete capstone title',
    );
    await tester.pump();
    expect(tester.widget<PrimaryButton>(button).onPressed, isNotNull);
  });

  testWidgets('approved student does not see Find your adviser card',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildLight(),
      home: Scaffold(
        body: NextActionHome(
          userRole: 'student',
          status: {
            'has_adviser': false,
            'application': {'status': 'approved'},
          },
          notifications: const [],
          applications: const [],
          bookings: const [],
          documents: const [],
          milestones: const [],
          navigate: (_) {},
        ),
      ),
    ));

    expect(find.text('Find your adviser'), findsNothing);
  });

  testWidgets('landing screen fits a short viewport without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(440, 358);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildLight(),
      home: const LandingScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to AdviserLink'), findsOneWidget);
    expect(find.textContaining('=)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landing log-in button opens the login screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildLight(),
      home: const LandingScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('A WORLD OF PROGRESS'), findsOneWidget);
    expect(find.text('Big goals feel lighter together.'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth tabs switch from login to registration', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildLight(),
      home: const LoginScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
