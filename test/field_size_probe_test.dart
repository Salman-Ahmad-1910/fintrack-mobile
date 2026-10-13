import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fintrack/features/auth/login_screen.dart';
import 'package:fintrack/features/auth/signup_screen.dart';
import 'package:fintrack/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, Widget child) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: child));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('measure field heights on login', (tester) async {
    await pump(tester, const LoginScreen());
    for (final f in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
      final box = tester.renderObject<RenderBox>(
        find.byWidgetPredicate((w) => identical(w, f)),
      );
      // ignore: avoid_print
      print('login field size=${box.size}');
    }
    final inputs = tester.widgetList<TextField>(find.byType(TextField));
    for (final t in inputs) {
      final box = tester.renderObject<RenderBox>(find.byWidgetPredicate((w) => identical(w, t)));
      // ignore: avoid_print
      print('login TextField size=${box.size}');
    }
  });

  testWidgets('measure field heights on signup', (tester) async {
    await pump(tester, const SignupScreen());
    final inputs = tester.widgetList<TextField>(find.byType(TextField));
    for (final t in inputs) {
      final box = tester.renderObject<RenderBox>(find.byWidgetPredicate((w) => identical(w, t)));
      // ignore: avoid_print
      print('signup TextField size=${box.size}');
    }
  });
}
