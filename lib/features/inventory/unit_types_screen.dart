import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'inventory_common.dart';
import 'inventory_models.dart';

/// Flutter counterpart of `client/src/app/(app)/inventory/unit-types/page.tsx`
/// — manage units of measurement for products.
class UnitTypesScreen extends StatefulWidget {
  const UnitTypesScreen({super.key});

  @override
  State<UnitTypesScreen> createState() => _UnitTypesScreenState();
}

class _UnitTypesScreenState extends State<UnitTypesScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<UnitType> _unitTypes = [];
  bool _loading = true;
  String _filter = '';
  final TextEditingController _search = TextEditingController();

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
      final json =
          await _api.get('/inventory/unit-types', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _unitTypes = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(UnitType.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<UnitType> get _filtered =>
      _unitTypes.where((u) => netPrefix(_filter, u.name)).toList();

  Future<void> _save(String name, UnitType? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/inventory/unit-types/${existing.id}',
          body: {'name': name},
        );
        if (mounted) showToast(context, 'Unit type updated successfully');
      } else {
        await _api.post('/inventory/unit-types', body: {'name': name});
        if (mounted) showToast(context, 'Unit type created successfully');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(UnitType unitType) async {
    await showNetworkDeleteDialog(
      context,
      itemName: unitType.name,
      onConfirm: () async {
        try {
          await _api.delete('/inventory/unit-types/${unitType.id}');
          if (mounted) showToast(context, 'Unit type deleted successfully');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openForm(UnitType? unitType) async {
    final name = await showInventoryNameForm(
      context,
      title: unitType == null ? 'Add New Unit Type' : 'Edit Unit Type',
      label: 'Name *',
      hint: 'e.g., piece',
      gradient: invUnitTypeGradient,
      icon: Icons.straighten_outlined,
      initial: unitType?.name,
      saveLabel: 'Save',
    );
    if (name != null) await _save(name, unitType);
  }

  @override
  Widget build(BuildContext context) {
    final active = _unitTypes
        .where((u) => u.status == 'active' || u.status == 'Active')
        .length;
    final categories = _unitTypes
        .map((u) => u.category)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.straighten_outlined,
            title: 'Unit Types',
            subtitle: 'Manage units of measurement for products.',
            gradient: invUnitTypeGradient,
          ),
          NetworkStatGrid(
            children: [
              NetworkStatCard(
                icon: Icons.straighten_outlined,
                label: 'Total Types',
                value: '${_unitTypes.length}',
                gradient: invUnitTypeGradient,
              ),
              NetworkStatCard(
                icon: Icons.check_circle_outline,
                label: 'Active Types',
                value: '$active',
                gradient: invEmeraldStatGradient,
                valueColor: AppColors.emerald600,
              ),
              NetworkStatCard(
                icon: Icons.scale_outlined,
                label: 'Categories',
                value: '$categories',
                gradient: invAmberStatGradient,
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
                  NetworkTable<UnitType>(
                    rows: _filtered,
                    emptyIcon: Icons.straighten_outlined,
                    emptyTitle: 'No unit types found.',
                    emptyHint: 'Get started by adding a new unit type.',
                    emptyTint: AppColors.emerald600,
                    mobileTrailing: (context, unitType, _) => NetworkRowActions(
                      onEdit: () => _openForm(unitType),
                      onDelete: () => _delete(unitType),
                    ),
                    columns: [
                      NetColumn(
                        label: 'ID',
                        width: 60,
                        builder: (context, unitType, index) => Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Name',
                        width: 280,
                        builder: (context, unitType, _) => Text(
                          unitType.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      NetColumn(
                        label: '',
                        width: 96,
                        isActions: true,
                        builder: (context, unitType, _) => Align(
                          alignment: Alignment.centerRight,
                          child: NetworkRowActions(
                            onEdit: () => _openForm(unitType),
                            onDelete: () => _delete(unitType),
                            editTooltip: 'Edit Unit Type',
                            deleteTooltip: 'Delete Unit Type',
                          ),
                        ),
                      ),
                    ],
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
      onChanged: (v) => setState(() => _filter = v),
      style: const TextStyle(fontSize: 14),
      decoration: netInputDecoration(
        context,
        hint: 'Search unit types...',
      ).copyWith(
        prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
      ),
    );
    final add = GradientButton(
      label: 'Add Unit Type',
      icon: Icons.add_circle_outline,
      gradient: invEmeraldButtonGradient,
      onPressed: () => _openForm(null),
    );
    return InvFilterBar(
      filterWidth: 360,
      filters: [search],
      actions: [add],
    );
  }
}
