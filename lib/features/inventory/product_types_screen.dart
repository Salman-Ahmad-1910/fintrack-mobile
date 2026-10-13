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

/// Flutter counterpart of
/// `client/src/app/(app)/inventory/product-types/page.tsx` — manage product
/// categories and types.
class ProductTypesScreen extends StatefulWidget {
  const ProductTypesScreen({super.key});

  @override
  State<ProductTypesScreen> createState() => _ProductTypesScreenState();
}

class _ProductTypesScreenState extends State<ProductTypesScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<ProductType> _productTypes = [];
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
      final json = await _api.get(
        '/inventory/product-types',
        query: {'companyId': cid},
      );
      if (!mounted) return;
      setState(() {
        _productTypes = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(ProductType.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<ProductType> get _filtered =>
      _productTypes.where((t) => netPrefix(_filter, t.name)).toList();

  Future<void> _save(String name, ProductType? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/inventory/product-types/${existing.id}',
          body: {'name': name},
        );
        if (mounted) showToast(context, 'Product type updated successfully');
      } else {
        await _api.post('/inventory/product-types', body: {'name': name});
        if (mounted) showToast(context, 'Product type created successfully');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(ProductType productType) async {
    await showNetworkDeleteDialog(
      context,
      itemName: productType.name,
      onConfirm: () async {
        try {
          await _api.delete('/inventory/product-types/${productType.id}');
          if (mounted) showToast(context, 'Product type deleted successfully');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openForm(ProductType? productType) async {
    final name = await showInventoryNameForm(
      context,
      title: productType == null
          ? 'Add New Product Type'
          : 'Edit Product Type',
      label: 'Product Type Name',
      hint: 'e.g., Raw Material',
      gradient: invProductTypeGradient,
      icon: Icons.archive_outlined,
      initial: productType?.name,
      saveLabel: 'Save Product Type',
    );
    if (name != null) await _save(name, productType);
  }

  @override
  Widget build(BuildContext context) {
    final products = _productTypes.fold<int>(0, (s, t) => s + t.productCount);
    final categories = _productTypes
        .map((t) => t.category)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet()
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.archive_outlined,
            title: 'Product Types',
            subtitle: 'Manage product categories and types.',
            gradient: invProductTypeGradient,
          ),
          NetworkStatGrid(
            children: [
              NetworkStatCard(
                icon: Icons.layers_outlined,
                label: 'Total Types',
                value: '${_productTypes.length}',
                gradient: invProductTypeGradient,
              ),
              NetworkStatCard(
                icon: Icons.inventory_2_outlined,
                label: 'Products',
                value: '$products',
                gradient: invEmeraldStatGradient,
                valueColor: AppColors.emerald600,
              ),
              NetworkStatCard(
                icon: Icons.archive_outlined,
                label: 'Categories',
                value: '$categories',
                gradient: invBlueStatGradient,
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
                  NetworkTable<ProductType>(
                    rows: _filtered,
                    emptyIcon: Icons.archive_outlined,
                    emptyTitle: 'No product types found.',
                    emptyHint: 'Get started by adding a new product type.',
                    emptyTint: AppColors.emerald600,
                    mobileTrailing: (context, productType, _) =>
                        NetworkRowActions(
                          onEdit: () => _openForm(productType),
                          onDelete: () => _delete(productType),
                        ),
                    columns: [
                      NetColumn(
                        label: 'ID',
                        width: 60,
                        builder: (context, productType, index) => Text(
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
                        builder: (context, productType, _) => Text(
                          productType.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      NetColumn(
                        label: '',
                        width: 96,
                        isActions: true,
                        builder: (context, productType, _) => Align(
                          alignment: Alignment.centerRight,
                          child: NetworkRowActions(
                            onEdit: () => _openForm(productType),
                            onDelete: () => _delete(productType),
                            editTooltip: 'Edit Product Type',
                            deleteTooltip: 'Delete Product Type',
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
        hint: 'Search product types...',
      ).copyWith(
        prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
      ),
    );
    final add = GradientButton(
      label: 'Add Product Type',
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
