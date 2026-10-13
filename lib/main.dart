import 'package:flutter/material.dart';

import 'core/api_config.dart';
import 'core/local/local_store.dart';
import 'core/local/sync_engine.dart';
import 'core/navigation.dart';
import 'core/session.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/landing/landing_screen.dart';
import 'features/shell/app_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Session.load();
  await ThemeController.load();
  // Offline-first: open the Hive cache/outbox and start the connectivity-aware
  // sync engine so queued mutations replay as soon as the network returns.
  await LocalStore.init();
  await SyncEngine.start();
  // Kick off the backend health probe in the background; the login screen
  // shows the resolved server URL as soon as it lands.
  // ignore: unawaited_futures
  ApiConfig.resolve();
  runApp(const FintrackApp());
}

class FintrackApp extends StatefulWidget {
  const FintrackApp({super.key});

  @override
  State<FintrackApp> createState() => _FintrackAppState();
}

class _FintrackAppState extends State<FintrackApp> {
  @override
  void initState() {
    super.initState();
    ThemeController.mode.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.mode.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinTrack ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeController.mode.value,
      navigatorKey: rootNavigatorKey,
      // Same routing model as the web client: signed-out visitors land on the
      // marketing page, signed-in ones go straight to the dashboard shell.
      home: Session.isAuthenticated ? const AppShell() : const LandingScreen(),
      routes: {
        Routes.landing: (_) => const LandingScreen(),
        Routes.login: (_) => const LoginScreen(),
        Routes.signup: (_) => const SignupScreen(),
        ForgotPasswordScreen.routeName: (_) => const ForgotPasswordScreen(),
        Routes.dashboard: (_) => const AppShell(),
      },
    );
  }
}
