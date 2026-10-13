import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'admin_utils.dart';

/// Flutter counterpart of `client/src/app/(app)/admin/settings/page.tsx` —
/// system-wide preferences from the `/admin/config` endpoint.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  Map<String, dynamic>? _config;
  bool _loading = true;
  bool _saving = false;

  static void _handleUnauthorized() {
    Session.clear();
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final cid = Session.companyId;
    if (cid == null || cid.isEmpty) {
      setState(() {
        _loading = false;
        _config = null;
      });
      return;
    }
    try {
      final json = await _api.get('/admin/config', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _config = json;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _config = null;
      });
    }
  }

  void _update(String key, Object value) {
    final config = _config;
    if (config == null) return;
    setState(() => config[key] = value);
  }

  bool get _autoSuspend => (_config?['autoSuspend'] as bool?) ?? false;

  int get _gracePeriod => ((_config?['gracePeriod'] as num?) ?? 3).toInt();

  int get _sessionTimeout =>
      ((_config?['sessionTimeout'] as num?) ?? 60).toInt();

  Future<void> _save() async {
    final config = _config;
    if (config == null) return;
    setState(() => _saving = true);
    try {
      await _api.put('/admin/config/${config['id']}', body: config);
      if (!mounted) return;
      showToast(context, 'System configuration updated successfully.');
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const AdminPageHeader(
            icon: Icons.settings_outlined,
            title: 'System Settings',
            subtitle: 'Manage system-wide settings and preferences',
          ),
          if (_loading)
            const _LoadingCard()
          else if (_config == null)
            _ErrorCard(
              onRetry: () {
                setState(() => _loading = true);
                _fetch();
              },
            )
          else
            _configCard(context),
        ],
      ),
    );
  }

  Widget _configCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'System Configuration',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage system-wide settings and preferences',
            style: TextStyle(fontSize: 14, color: context.mutedFg),
          ),
          const SizedBox(height: 24),
          // Auto-Suspend toggle
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-Suspend Overdue Subscribers',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Automatically suspend subscribers with overdue payments',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.mutedFg,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _switch(context, _autoSuspend, (v) => _update('autoSuspend', v)),
            ],
          ),
          const SizedBox(height: 24),
          _numberField(
            context,
            label: 'Grace Period (Days)',
            hint: 'Number of days before suspension',
            helper:
                'Number of days to wait before suspending overdue subscribers',
            value: _gracePeriod,
            min: 0,
            max: 30,
            onChanged: (v) => _update('gracePeriod', v),
          ),
          const SizedBox(height: 24),
          _numberField(
            context,
            label: 'Session Timeout (Minutes)',
            hint: 'Session timeout in minutes',
            helper:
                'Automatically log out users after this period of inactivity',
            value: _sessionTimeout,
            min: 5,
            max: 1440,
            onChanged: (v) => _update('sessionTimeout', v),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerRight,
            child: EmeraldButton(
              label: _saving ? 'Saving...' : 'Save Configuration',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _switch(
    BuildContext context,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.emerald600,
    );
  }

  Widget _numberField(
    BuildContext context, {
    required String label,
    required String hint,
    required String helper,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    final controller = TextEditingController(text: '$value');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.fg,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (raw) {
            final parsed = int.tryParse(raw);
            if (parsed == null) return;
            onChanged(parsed.clamp(min, max));
          },
          decoration: InputDecoration(hintText: hint),
        ),
        const SizedBox(height: 6),
        Text(helper, style: TextStyle(fontSize: 14, color: context.mutedFg)),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 12),
            Text('Loading settings...'),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load settings',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
