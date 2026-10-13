import 'package:flutter/material.dart';

/// Global navigator used to bounce the user back to login on any 401,
/// regardless of which screen issued the request.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Route names for the entry screens (`MaterialApp.routes` in `main.dart`).
abstract final class Routes {
  static const landing = '/landing';
  static const login = '/login';
  static const signup = '/signup';
  static const dashboard = '/dashboard';
}
