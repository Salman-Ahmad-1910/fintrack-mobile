import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistent session for the shared-backend account:
/// JWT + selected company + permissions, mirroring the keys the web client
/// keeps in localStorage (`token`, `selectedCompanyId`, ...).
class Session {
  Session._();

  static const _kToken = 'token';
  static const _kCompanyId = 'selectedCompanyId';
  static const _kCompanyName = 'selectedCompanyName';
  static const _kUserName = 'userName';
  static const _kUserEmail = 'userEmail';
  static const _kRole = 'userRole';
  static const _kPermissions = 'userPermissions';
  static const _kPermissionsConfigured = 'permissionsConfigured';
  static const _kUserId = 'userId';

  static String? token;
  static String? companyId;
  static String? companyName;
  static String? userName;
  static String? userEmail;
  static String? role;
  static String? userId;
  static List<String> permissions = [];
  static bool permissionsConfigured = false;

  static bool get isAuthenticated => token != null && token!.isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_kToken);
    companyId = prefs.getString(_kCompanyId);
    companyName = prefs.getString(_kCompanyName);
    userName = prefs.getString(_kUserName);
    userEmail = prefs.getString(_kUserEmail);
    role = prefs.getString(_kRole);
    userId = prefs.getString(_kUserId);
    permissions = prefs.getStringList(_kPermissions) ?? [];
    permissionsConfigured = prefs.getBool(_kPermissionsConfigured) ?? false;
  }

  static Future<void> saveAuth({
    required String newToken,
    required String newCompanyId,
    required String newCompanyName,
    required String name,
    required String email,
    required String newRole,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    token = newToken;
    companyId = newCompanyId;
    companyName = newCompanyName;
    userName = name;
    userEmail = email;
    role = newRole;
    await prefs.setString(_kToken, newToken);
    await prefs.setString(_kCompanyId, newCompanyId);
    await prefs.setString(_kCompanyName, newCompanyName);
    await prefs.setString(_kUserName, name);
    await prefs.setString(_kUserEmail, email);
    await prefs.setString(_kRole, newRole);
  }

  static Future<void> selectCompany(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    companyId = id;
    companyName = name;
    await prefs.setString(_kCompanyId, id);
    await prefs.setString(_kCompanyName, name);
  }

  static Future<void> saveProfile({
    required String newRole,
    required List<String> newPermissions,
    required bool configured,
    String? name,
    String? email,
    String? id,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    role = newRole;
    permissions = newPermissions;
    permissionsConfigured = configured;
    await prefs.setString(_kRole, newRole);
    await prefs.setStringList(_kPermissions, newPermissions);
    await prefs.setBool(_kPermissionsConfigured, configured);
    if (name != null) {
      userName = name;
      await prefs.setString(_kUserName, name);
    }
    if (email != null) {
      userEmail = email;
      await prefs.setString(_kUserEmail, email);
    }
    if (id != null && id.isNotEmpty) {
      userId = id;
      await prefs.setString(_kUserId, id);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kCompanyId);
    await prefs.remove(_kCompanyName);
    await prefs.remove(_kUserId);
    await prefs.remove(_kPermissions);
    await prefs.remove(_kPermissionsConfigured);
    token = null;
    userId = null;
    companyId = null;
    companyName = null;
    userName = null;
    userEmail = null;
    role = null;
    permissions = [];
    permissionsConfigured = false;
  }

  // ---- Collection target (same per-company key the web keeps in localStorage)

  static Future<double> collectionTarget() async {
    if (companyId == null) return 0;
    final prefs = await SharedPreferences.getInstance();
    return double.tryParse(
          prefs.getString('collection_target_$companyId') ?? '',
        ) ??
        0;
  }

  static Future<void> saveCollectionTarget(double target) async {
    if (companyId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('collection_target_$companyId', target.toString());
  }

  static String encode(List<String> items) => jsonEncode(items);
}
