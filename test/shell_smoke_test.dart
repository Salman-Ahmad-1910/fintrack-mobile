import 'package:fintrack/core/session.dart';
import 'package:fintrack/main.dart';
import 'package:fintrack/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'token': 'test-token',
      'userName': 'Ali Khan',
      'userEmail': 'ali@example.com',
      'selectedCompanyName': 'SkyNet',
      'userRole': 'admin',
    });
    await Session.load();
    await ThemeController.set(ThemeMode.light);
  });

  tearDown(() async {
    await ThemeController.set(ThemeMode.light);
    await Session.clear();
  });

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FintrackApp());
    // Bounded pumps: the dashboard issues real network calls that may never
    // settle inside the test's fake-async zone.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('wide shell shows top bar, sidebar and the user menu', (
    tester,
  ) async {
    await pumpShell(tester, const Size(1440, 900));

    // Branding appears in both the top bar and the pinned sidebar.
    expect(find.text('FinTrack ERP'), findsNWidgets(2));

    // Sidebar nav: group headers are uppercase; Dashboard is always expanded.
    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('NETWORK'), findsOneWidget);
    expect(find.text('SUBSCRIBERS MANAGEMENT'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    // No drawer toggle while the sidebar is pinned.
    expect(find.byIcon(Icons.menu_outlined), findsNothing);

    // Avatar menu: name, company, email, Profile, theme toggle, Log out.
    await tester.tap(find.byKey(const ValueKey('user-avatar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ali Khan'), findsOneWidget);
    expect(find.text('(SkyNet)'), findsOneWidget);
    expect(find.text('ali@example.com'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);

    // Toggling flips the persisted theme preference.
    await tester.tap(find.text('Dark Mode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(ThemeController.mode.value, ThemeMode.dark);

    // Unmount so the dashboard's periodic refresh timers are cancelled.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('narrow shell opens the sidebar as a drawer', (tester) async {
    await pumpShell(tester, const Size(390, 844));

    expect(find.byIcon(Icons.menu_outlined), findsOneWidget);
    expect(find.text('Support'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
