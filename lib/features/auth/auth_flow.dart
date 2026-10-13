import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../models/models.dart';

/// The post-authentication steps the web client performs after
/// `POST /auth/login` (or `POST /auth/signup`): persist the JWT, resolve the
/// user's companies, pick the matching one, load `/auth/me` for the role and
/// permissions, then land on the dashboard.
class AuthFlow {
  const AuthFlow._();

  static Future<void> continueWithToken(
    BuildContext context, {
    required String token,
    Map<String, dynamic> user = const {},
  }) async {
    final api = ApiClient();
    final userCompanyId = (user['companyId'] ?? user['company_id'] ?? '')
        .toString();

    await Session.saveAuth(
      newToken: token,
      newCompanyId: userCompanyId,
      newCompanyName: '',
      name: (user['name'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      newRole: (user['role'] ?? '').toString(),
    );

    try {
      final companiesJson = await api.get('/companies');
      final rawList = companiesJson['raw'];
      final companies = (rawList is List ? rawList : const [])
          .whereType<Map<String, dynamic>>()
          .map(Company.fromJson)
          .toList();

      final match = companies.firstWhere(
        (c) => c.id == userCompanyId,
        orElse: () =>
            companies.isNotEmpty ? companies.first : Company(id: '', name: ''),
      );
      await Session.selectCompany(
        match.id.isNotEmpty ? match.id : userCompanyId,
        match.name,
      );

      final me = await api.get('/auth/me');
      final profile = MeProfile.fromJson(me);
      await Session.saveProfile(
        newRole: profile.role.isNotEmpty
            ? profile.role
            : (user['role'] ?? '').toString(),
        newPermissions: profile.permissions,
        configured: profile.permissionsConfigured,
        name: profile.name.isNotEmpty ? profile.name : null,
        email: profile.email.isNotEmpty ? profile.email : null,
        id: profile.id,
      );
    } catch (_) {
      // Never leave a half-initialised session behind: it would boot straight
      // into a broken dashboard on the next launch.
      await Session.clear();
      rethrow;
    }

    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
  }
}
