import 'package:fintrack/core/session.dart';
import 'package:fintrack/features/admin/company_profile_screen.dart';
import 'package:fintrack/features/admin/roles_screen.dart';
import 'package:fintrack/features/admin/settings_screen.dart';
import 'package:fintrack/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke coverage for the three administration pages: headers, static labels
/// and the offline fallbacks all render without throwing. Form bodies that
/// depend on live API data (e.g. the permissions table) are exercised against
/// a real backend.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'token': 'test-token',
      'userName': 'Ali Khan',
      'userEmail': 'ali@example.com',
      'selectedCompanyName': 'SkyNet',
      'selectedCompanyId': 'company-1',
      'userRole': 'admin',
    });
    await Session.load();
  });

  tearDown(() async {
    await Session.clear();
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: Scaffold(body: screen),
      ),
    );
    // Bounded pumps: the pages issue real network calls that never settle
    // inside the test's fake-async zone.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('company profile page renders its header and fallback card', (
    tester,
  ) async {
    await pumpScreen(tester, const CompanyProfileScreen());

    expect(find.text('Company Profile'), findsWidgets);
    expect(find.textContaining('Manage your company'), findsOneWidget);
    expect(find.text('No Company Selected'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('roles page renders KPIs and the subscriber picker', (
    tester,
  ) async {
    await pumpScreen(tester, const RolesScreen());

    expect(find.text('Role Management'), findsOneWidget);
    expect(find.text('Total Roles'), findsOneWidget);
    expect(find.text('With Subscribers'), findsOneWidget);
    expect(find.text('Permissions'), findsWidgets);
    expect(find.text('Select Subscriber'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
    expect(find.text('Recovery Officer'), findsOneWidget);
    expect(find.text('Dealer'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('roles page has no horizontal overflow at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: RolesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Select Subscriber'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings page renders its header and offline fallback', (
    tester,
  ) async {
    await pumpScreen(tester, const SettingsScreen());

    expect(find.text('System Settings'), findsOneWidget);
    expect(find.text('Could not load settings'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}