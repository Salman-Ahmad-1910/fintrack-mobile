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

/// Flutter counterpart of `client/src/app/(app)/inventory/brands/page.tsx` —
/// manage product brands and manufacturers.
class BrandsScreen extends StatefulWidget {
  const BrandsScreen({super.key});

  @override
  State<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends State<BrandsScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<Brand> _brands = [];
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
      final json = await _api.get('/inventory/brands', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _brands = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(Brand.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Brand> get _filtered =>
      _brands.where((b) => netPrefix(_filter, b.name)).toList();

  Future<void> _save(String name, Brand? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put('/inventory/brands/${existing.id}', body: {'name': name});
        if (mounted) showToast(context, 'Brand updated successfully');
      } else {
        await _api.post('/inventory/brands', body: {'name': name});
        if (mounted) showToast(context, 'Brand created successfully');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(Brand brand) async {
    await showNetworkDeleteDialog(
      context,
      itemName: brand.name,
      onConfirm: () async {
        try {
          await _api.delete('/inventory/brands/${brand.id}');
          if (mounted) showToast(context, 'Brand deleted successfully');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openForm(Brand? brand) async {
    final name = await showInventoryNameForm(
      context,
      title: brand == null ? 'Add New Brand' : 'Edit Brand',
      label: 'Brand Name',
      hint: 'e.g., TP-Link',
      gradient: invBrandGradient,
      icon: Icons.sell_outlined,
      initial: brand?.name,
      saveLabel: brand == null ? 'Add' : 'Update',
    );
    if (name != null) await _save(name, brand);
  }

  @override
  Widget build(BuildContext context) {
    final active = _brands
        .where((b) => b.status == 'active' || b.status == 'Active')
        .length;
    final categories =
        _brands.map((b) => b.category).whereType<String>().where((c) => c.isNotEmpty).toSet().length;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.sell_outlined,
            title: 'Brands',
            subtitle: 'Manage product brands and manufacturers.',
            gradient: invBrandGradient,
          ),
          NetworkStatGrid(
            children: [
              NetworkStatCard(
                icon: Icons.layers_outlined,
                label: 'Total Brands',
                value: '${_brands.length}',
                gradient: invBlueStatGradient,
              ),
              NetworkStatCard(
                icon: Icons.check_circle_outline,
                label: 'Active Brands',
                value: '$active',
                gradient: invEmeraldStatGradient,
                valueColor: AppColors.emerald600,
              ),
              NetworkStatCard(
                icon: Icons.sell_outlined,
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
                  NetworkTable<Brand>(
                    rows: _filtered,
                    emptyIcon: Icons.sell_outlined,
                    emptyTitle: 'No brands found.',
                    emptyHint: 'Get started by adding a new brand.',
                    emptyTint: AppColors.emerald600,
                    mobileTrailing: (context, brand, _) => NetworkRowActions(
                      onEdit: () => _openForm(brand),
                      onDelete: () => _delete(brand),
                    ),
                    columns: [
                      NetColumn(
                        label: 'ID',
                        width: 60,
                        builder: (context, brand, index) => Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Brand',
                        width: 280,
                        builder: (context, brand, _) => Text(
                          brand.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      NetColumn(
                        label: '',
                        width: 96,
                        isActions: true,
                        builder: (context, brand, _) => Align(
                          alignment: Alignment.centerRight,
                          child: NetworkRowActions(
                            onEdit: () => _openForm(brand),
                            onDelete: () => _delete(brand),
                            editTooltip: 'Edit Brand',
                            deleteTooltip: 'Delete Brand',
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
        hint: 'Search brands...',
      ).copyWith(
        prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
      ),
    );
    final add = GradientButton(
      label: 'Add Brand',
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
