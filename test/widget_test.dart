import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/features/auth/login_screen.dart';
import 'package:fintrack/features/auth/signup_screen.dart';
import 'package:fintrack/main.dart';
import 'package:fintrack/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the landing page when signed out', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Desktop-sized surface so the marketing header lays out the same way it
    // does in a browser (the test font is much wider than Inter).
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FintrackApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Complete Business Management'), findsOneWidget);
    expect(find.text('Simplified & Powerful'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });

  testWidgets('shows the login screen with the web copy', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
  });

  testWidgets('shows the signup screen with the web copy', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SignupScreen()),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Company Name'), findsOneWidget);
  });
}
