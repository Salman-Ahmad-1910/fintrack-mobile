import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/features/auth/login_screen.dart';
import 'package:fintrack/features/auth/signup_screen.dart';
import 'package:fintrack/features/landing/landing_screen.dart';
import 'package:fintrack/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the entry screens at phone and desktop sizes so the result can be
/// eyeballed against the web client (`page.tsx`, `login/page.tsx`,
/// `signup/page.tsx`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpScreen(WidgetTester tester, Widget child, Size size) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: child));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('golden: landing (phone)', (tester) async {
    await pumpScreen(tester, const LandingScreen(), const Size(390, 844));
    await expectLater(
      find.byType(LandingScreen),
      matchesGoldenFile('goldens/landing_phone.png'),
    );
  });

  testWidgets('golden: landing (desktop)', (tester) async {
    await pumpScreen(tester, const LandingScreen(), const Size(1440, 900));
    await expectLater(
      find.byType(LandingScreen),
      matchesGoldenFile('goldens/landing_desktop.png'),
    );
  });

  testWidgets('golden: login (phone)', (tester) async {
    await pumpScreen(tester, const LoginScreen(), const Size(390, 844));
    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/login_phone.png'),
    );
  });

  testWidgets('golden: login (desktop)', (tester) async {
    await pumpScreen(tester, const LoginScreen(), const Size(1440, 900));
    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/login_desktop.png'),
    );
  });

  testWidgets('golden: signup (phone)', (tester) async {
    await pumpScreen(tester, const SignupScreen(), const Size(390, 844));
    await expectLater(
      find.byType(SignupScreen),
      matchesGoldenFile('goldens/signup_phone.png'),
    );
  });
}
