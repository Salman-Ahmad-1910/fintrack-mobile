import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/features/auth/login_screen.dart';
import 'package:fintrack/features/auth/signup_screen.dart';
import 'package:fintrack/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('capture login', (tester) async {
    await pumpScreen(tester, const LoginScreen(), const Size(390, 844));
    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/tmp_login.png'),
    );
  });

  testWidgets('capture signup', (tester) async {
    await pumpScreen(tester, const SignupScreen(), const Size(390, 844));
    await expectLater(
      find.byType(SignupScreen),
      matchesGoldenFile('goldens/tmp_signup.png'),
    );
  });
}
