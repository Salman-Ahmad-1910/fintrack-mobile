import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'recovery_common.dart';
import 'recovery_models.dart';

/// Flutter counterpart of
/// `client/src/app/(app)/recovery-officers-management/officers/page.tsx` —
/// manage recovery officers for the company.
class RecoveryOfficersScreen extends StatefulWidget {
  const RecoveryOfficersScreen({super.key});

  @override
  State<RecoveryOfficersScreen> createState() => _RecoveryOfficersScreenState();
}

class _RecoveryOfficersScreenState extends State<RecoveryOfficersScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<RecoveryOfficer> _officers = [];
  List<RecoveryArea> _areas = [];
  bool _loading = true;
  String _filter = '';
  final TextEditingController _search = TextEditingController();

  int _page = 1;
  int _pageSize = 10;

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

  String? get _cid => Session.companyId;

  bool get _canCreate => recCrud(kRecoveryOfficerPermission, 'create');
  bool get _canUpdate => recCrud(kRecoveryOfficerPermission, 'update');
  bool get _canDelete => recCrud(kRecoveryOfficerPermission, 'delete');
  bool get _canSeeSummary => recPage(kRecoveryOfficerPermission, 'summary');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final officersJson =
          await _api.get('/admin/recovery-officers', query: {'companyId': cid});
      final areasJson =
          await _api.get('/network/areas', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _officers = ApiClient.listData(officersJson)
            .whereType<Map<String, dynamic>>()
            .map(RecoveryOfficer.fromJson)
            .toList();
        _areas = ApiClient.listData(areasJson)
            .whereType<Map<String, dynamic>>()
            .map(RecoveryArea.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<RecoveryOfficer> get _filtered => _officers
      .where((o) => netContains(_filter, [o.name, o.email]))
      .toList();

  List<RecoveryOfficer> get _paged {
    final start = (_page - 1) * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  Future<void> _openForm([RecoveryOfficer? existing]) async {
    final result = await showDialog<_OfficerFormResult>(
      context: context,
      builder: (_) =>
          _OfficerFormDialog(officer: existing, areas: _areas),
    );
    if (result == null) return;
    await _save(result, existing);
  }

  Future<void> _save(
    _OfficerFormResult result,
    RecoveryOfficer? existing,
  ) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    final body = <String, dynamic>{
      'name': result.name,
      'email': result.email,
      'phone': result.phone,
      'secondaryPhone': result.secondaryPhone,
      'areaId': result.areaId,
      'role': 'recovery_officer',
      'companyId': cid,
    };
    if (result.password.isNotEmpty) body['password'] = result.password;
    try {
      if (existing != null) {
        body['id'] = existing.id;
        await _api.put('/admin/recovery-officers/${existing.id}', body: body);
        if (mounted) showToast(context, 'Recovery officer updated successfully');
      } else {
        await _api.post('/admin/recovery-officers', body: body);
        if (mounted) showToast(context, 'Recovery officer added successfully');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(RecoveryOfficer officer) async {
    await showNetworkDeleteDialog(
      context,
      itemName: officer.name,
      onConfirm: () async {
        try {
          await _api.delete('/admin/recovery-officers/${officer.id}');
          if (mounted) showToast(context, 'Recovery officer deleted successfully');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _officers.where((o) => o.status == 'active').length;
    final withAreas = _officers.where((o) => o.areaId != null).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.shield_outlined,
            title: 'Recovery Officers',
            subtitle: 'Manage recovery officers for your company.',
            gradient: recOfficerGradient,
          ),
          if (_canSeeSummary)
            NetworkStatGrid(
              children: [
                NetworkStatCard(
                  icon: Icons.groups_outlined,
                  label: 'Total Officers',
                  value: '${_officers.length}',
                  gradient: recBlueStatGradient,
                ),
                NetworkStatCard(
                  icon: Icons.verified_user_outlined,
                  label: 'Active',
                  value: '$active',
                  gradient: recEmeraldStatGradient,
                  valueColor: AppColors.emerald600,
                ),
                NetworkStatCard(
                  icon: Icons.map_outlined,
                  label: 'With Areas',
                  value: '$withAreas',
                  gradient: recVioletStatGradient,
                ),
              ],
            ),
          const SizedBox(height: 24),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _toolbar(context),
                  const SizedBox(height: 16),
                  NetworkTable<RecoveryOfficer>(
                    rows: _paged,
                    emptyIcon: Icons.shield_outlined,
                    emptyTitle: 'No recovery officers found.',
                    emptyHint: 'Get started by adding a recovery officer.',
                    emptyTint: AppColors.emerald600,
                    mobileTrailing: (context, officer, _) => NetworkRowActions(
                      onEdit: _canUpdate ? () => _openForm(officer) : null,
                      onDelete: _canDelete ? () => _delete(officer) : null,
                    ),
                    columns: [
                      NetColumn(
                        label: 'ID',
                        width: 60,
                        builder: (context, officer, index) => Text(
                          '${(_page - 1) * _pageSize + index + 1}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Name',
                        width: 200,
                        builder: (context, officer, _) => Text(
                          officer.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      NetColumn(
                        label: 'Email',
                        width: 240,
                        builder: (context, officer, _) => Text(officer.email),
                      ),
                      NetColumn(
                        label: 'Phone',
                        width: 160,
                        builder: (context, officer, _) => Text(officer.phone),
                      ),
                      NetColumn(
                        label: 'Status',
                        width: 120,
                        builder: (context, officer, _) =>
                            _StatusBadge(status: officer.status),
                      ),
                      NetColumn(
                        label: '',
                        width: 96,
                        isActions: true,
                        builder: (context, officer, _) {
                          if (!_canUpdate && !_canDelete) {
                            return const SizedBox.shrink();
                          }
                          return Align(
                            alignment: Alignment.centerRight,
                            child: NetworkRowActions(
                              onEdit: _canUpdate ? () => _openForm(officer) : null,
                              onDelete: _canDelete ? () => _delete(officer) : null,
                              editTooltip: 'Edit Officer',
                              deleteTooltip: 'Delete Officer',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  NetworkPagination(
                    currentPage: _page,
                    pageSize: _pageSize,
                    totalItems: _filtered.length,
                    noun: 'recovery officers',
                    onPageChanged: (p) => setState(() => _page = p),
                    onPageSizeChanged: (s) => setState(() {
                      _pageSize = s;
                      _page = 1;
                    }),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final search = TextField(
      controller: _search,
      onChanged: (v) => setState(() {
        _filter = v;
        _page = 1;
      }),
      style: const TextStyle(fontSize: 14),
      decoration: netInputDecoration(
        context,
        hint: 'Filter by name or email...',
      ).copyWith(
        prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
      ),
    );
    final add = GradientButton(
      label: 'Add Recovery Officer',
      icon: Icons.add_circle_outline,
      gradient: recEmeraldStatGradient,
      onPressed: _canCreate ? () => _openForm() : null,
    );
    return RecFilterBar(
      filters: [search],
      actions: [add],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    final bg = isActive
        ? AppColors.emerald600
        : (context.isDark ? AppColors.darkMuted : AppColors.muted);
    final fg = isActive ? Colors.white : context.mutedFg;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _OfficerFormResult {
  const _OfficerFormResult({
    required this.name,
    required this.email,
    required this.phone,
    required this.secondaryPhone,
    required this.password,
    required this.areaId,
  });

  final String name;
  final String email;
  final String phone;
  final String secondaryPhone;
  final String password;
  final String? areaId;
}

class _OfficerFormDialog extends StatefulWidget {
  const _OfficerFormDialog({this.officer, this.areas = const []});

  final RecoveryOfficer? officer;
  final List<RecoveryArea> areas;

  @override
  State<_OfficerFormDialog> createState() => _OfficerFormDialogState();
}

class _OfficerFormDialogState extends State<_OfficerFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _secondaryPhone;
  late final TextEditingController _password;
  late String _areaId;
  bool _showPassword = false;

  final Map<String, String> _errors = {};

  bool get _isEdit => widget.officer != null;

  @override
  void initState() {
    super.initState();
    final o = widget.officer;
    _name = TextEditingController(text: o?.name ?? '');
    _email = TextEditingController(text: o?.email ?? '');
    _phone = TextEditingController(text: o?.phone ?? '');
    _secondaryPhone = TextEditingController(text: o?.secondaryPhone ?? '');
    _password = TextEditingController();
    _areaId = o?.areaId ?? 'unassigned';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _secondaryPhone.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validate() {
    final errors = <String, String>{};
    if (_name.text.trim().isEmpty) errors['name'] = 'Name is required';
    final email = _email.text.trim();
    if (email.isEmpty) {
      errors['email'] = 'Invalid email address';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      errors['email'] = 'Invalid email address';
    }
    if (_phone.text.trim().isEmpty) errors['phone'] = 'Phone number is required';
    final pwd = _password.text;
    if (!_isEdit) {
      if (pwd.isEmpty) {
        errors['password'] = 'Password is required for new recovery officers';
      } else if (pwd.length < 6) {
        errors['password'] = 'Password must be at least 6 characters';
      }
    } else if (pwd.isNotEmpty && pwd.length < 6) {
      errors['password'] = 'Password must be at least 6 characters';
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    return errors.isEmpty;
  }

  void _submit() {
    if (!_validate()) return;
    Navigator.of(context).pop(
      _OfficerFormResult(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        secondaryPhone: _secondaryPhone.text.trim(),
        password: _password.text,
        areaId: _areaId == 'unassigned' || _areaId.isEmpty ? null : _areaId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: Text(
        '${_isEdit ? 'Edit' : 'Add'} Recovery Officer',
        style: const TextStyle(fontSize: 18),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(
                context,
                label: 'Name *',
                controller: _name,
                hint: 'Enter recovery officer name',
                error: _errors['name'],
              ),
              _field(
                context,
                label: 'Email *',
                controller: _email,
                hint: 'Enter email address',
                error: _errors['email'],
                keyboardType: TextInputType.emailAddress,
              ),
              _field(
                context,
                label: 'Primary Phone *',
                controller: _phone,
                hint: 'Enter primary phone number',
                error: _errors['phone'],
                keyboardType: TextInputType.phone,
              ),
              _field(
                context,
                label: 'Secondary Phone',
                controller: _secondaryPhone,
                hint: 'Enter secondary phone number',
                keyboardType: TextInputType.phone,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NetField(
                  label: 'Password ${_isEdit ? '' : '*'}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _password,
                        obscureText: !_showPassword,
                        style: const TextStyle(fontSize: 14),
                        decoration: netInputDecoration(
                          context,
                          hint: _isEdit
                              ? 'Leave blank to keep current'
                              : 'Enter password',
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: context.mutedFg,
                            ),
                            onPressed: () => setState(
                              () => _showPassword = !_showPassword,
                            ),
                          ),
                        ),
                      ),
                      if (_errors['password'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _errors['password']!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              NetField(
                label: 'Area',
                child: DropdownButtonFormField<String>(
                  initialValue: _areaId,
                  isExpanded: true,
                  style: TextStyle(fontSize: 14, color: context.fg),
                  decoration: netInputDecoration(context),
                  items: [
                    const DropdownMenuItem(
                      value: 'unassigned',
                      child: Text('Unassigned'),
                    ),
                    for (final area in widget.areas)
                      DropdownMenuItem(
                        value: area.id,
                        child: Text(
                          '${area.locality} - ${area.city}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _areaId = v ?? 'unassigned'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            foregroundColor: context.mutedFg,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.emerald600,
            minimumSize: const Size(0, 40),
          ),
          onPressed: _submit,
          child: Text(_isEdit ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  Widget _field(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    String? hint,
    String? error,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NetField(
        label: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 14),
              decoration: netInputDecoration(context, hint: hint),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  error,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
