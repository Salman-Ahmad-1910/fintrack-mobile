import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

/// Flutter counterpart of `client/src/app/(app)/inventory/products/page.tsx`.
/// Products that share a name/brand/type are grouped into a single row whose
/// serial numbers and models can be expanded, with advanced pagination.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);
  static final NumberFormat _money = NumberFormat('#,##0.##');

  List<Product> _products = [];
  List<Brand> _brands = [];
  List<ProductType> _productTypes = [];
  List<UnitType> _unitTypes = [];
  bool _loading = true;

  String _filter = '';
  final TextEditingController _search = TextEditingController();
  int _page = 1;
  int _pageSize = 10;
  final Set<String> _expanded = {};

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
      final results = await Future.wait([
        _api.get('/inventory/products', query: {'companyId': cid}),
        _api.get('/inventory/brands', query: {'companyId': cid}),
        _api.get('/inventory/product-types', query: {'companyId': cid}),
        _api.get('/inventory/unit-types', query: {'companyId': cid}),
      ]);
      if (!mounted) return;
      setState(() {
        _products = ApiClient.listData(results[0])
            .whereType<Map<String, dynamic>>()
            .map(Product.fromJson)
            .toList();
        _brands = ApiClient.listData(results[1])
            .whereType<Map<String, dynamic>>()
            .map(Brand.fromJson)
            .toList();
        _productTypes = ApiClient.listData(results[2])
            .whereType<Map<String, dynamic>>()
            .map(ProductType.fromJson)
            .toList();
        _unitTypes = ApiClient.listData(results[3])
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

  bool _matches(Product p) {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return true;
    for (final s in parseSerialNumbers(p.serialNumber)) {
      if (s.toLowerCase().contains(q)) return true;
    }
    return p.name.toLowerCase().contains(q) ||
        p.category.toLowerCase().contains(q) ||
        p.brandName.toLowerCase().contains(q);
  }

  Future<void> _save(Map<String, dynamic> values, Product? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/inventory/products/${existing.id}',
          body: values,
        );
        if (mounted) showToast(context, 'Product updated successfully');
      } else {
        await _api.post(
          '/inventory/products',
          body: {...values, 'companyId': cid, 'stock': 0},
        );
        if (mounted) showToast(context, 'Product created successfully');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(Product product) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    await showNetworkDeleteDialog(
      context,
      itemName: product.name,
      onConfirm: () async {
        try {
          await _api.delete('/inventory/products/${product.id}');
          if (mounted) showToast(context, 'Product deleted successfully');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openForm(Product? product) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ProductFormDialog(
        product: product,
        brands: _brands,
        productTypes: _productTypes,
        unitTypes: _unitTypes,
      ),
    );
    if (result != null) await _save(result, product);
  }

  void _toggle(String key) {
    setState(() {
      if (_expanded.contains(key)) {
        _expanded.remove(key);
      } else {
        _expanded.add(key);
      }
    });
  }

  List<Product> get _grouped => groupProducts(_products);

  List<Product> get _filteredGrouped => _grouped.where(_matches).toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredGrouped;
    final totalPages = filtered.isEmpty
        ? 1
        : (filtered.length / _pageSize).ceil();
    final page = _page.clamp(1, totalPages);
    final paged = filtered
        .skip((page - 1) * _pageSize)
        .take(_pageSize)
        .toList();
    final lowStock = _products.where((p) => p.stock > 0 && p.stock < 5).length;
    final noStock = _products.where((p) => p.stock <= 0).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.inventory_2_outlined,
            title: 'Products',
            subtitle: 'Manage your inventory products and stock levels.',
            gradient: invProductGradient,
          ),
          NetworkStatGrid(
            children: [
              NetworkStatCard(
                icon: Icons.inventory_2_outlined,
                label: 'Total Products',
                value: '${_products.length}',
                gradient: invProductGradient,
              ),
              NetworkStatCard(
                icon: Icons.warning_amber_outlined,
                label: 'Low Stock',
                value: '$lowStock',
                gradient: invAmberStatGradient,
              ),
              NetworkStatCard(
                icon: Icons.remove_shopping_cart_outlined,
                label: 'Out of Stock',
                value: '$noStock',
                gradient: invEmeraldStatGradient,
                valueColor: AppColors.emerald600,
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
                  NetworkTable<Product>(
                    rows: paged,
                    emptyIcon: Icons.inventory_2_outlined,
                    emptyTitle: 'No products found.',
                    emptyHint: 'Get started by adding a new product.',
                    emptyTint: AppColors.emerald600,
                    expandedKeys: _expanded,
                    onToggleExpand: _toggle,
                    rowKey: (p) => p.id,
                    rowCanExpand: (p) =>
                        parseSerialNumbers(p.serialNumber).isNotEmpty,
                    expansionBuilder: (context, product, _) =>
                        _expansion(context, product),
                    mobileTrailing: (context, product, _) => NetworkRowActions(
                      onEdit: () => _openForm(product),
                      onDelete: () => _delete(product),
                    ),
                    columns: [
                      NetColumn(
                        label: 'Product ID',
                        width: 110,
                        builder: (context, p, _) => Text(
                          p.productId.isNotEmpty ? p.productId : p.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Product Name',
                        width: 190,
                        builder: (context, p, _) => Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      NetColumn(
                        label: 'Brand',
                        width: 130,
                        builder: (context, p, _) => Text(
                          p.brandName.isEmpty ? '-' : p.brandName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      NetColumn(
                        label: 'Product Type',
                        width: 130,
                        builder: (context, p, _) => Text(
                          p.productTypeName.isNotEmpty
                              ? p.productTypeName
                              : (p.category.isEmpty ? '-' : p.category),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      NetColumn(
                        label: 'SN/MAC',
                        width: 170,
                        builder: (context, p, _) => _serialCell(context, p),
                      ),
                      NetColumn(
                        label: 'Model',
                        width: 140,
                        builder: (context, p, _) => _modelCell(context, p),
                      ),
                      NetColumn(
                        label: 'Discount',
                        width: 100,
                        builder: (context, p, _) => Text(
                          _money.format(p.discount),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      NetColumn(
                        label: 'Actions',
                        width: 90,
                        isActions: true,
                        builder: (context, p, _) => Align(
                          alignment: Alignment.centerRight,
                          child: NetworkRowActions(
                            onEdit: () => _openForm(p),
                            onDelete: () => _delete(p),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (filtered.isNotEmpty)
                    NetworkPagination(
                      currentPage: page,
                      pageSize: _pageSize,
                      totalItems: filtered.length,
                      noun: 'products',
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

  Widget _serialCell(BuildContext context, Product p) {
    final sns = parseSerialNumbers(p.serialNumber);
    if (sns.isEmpty) {
      return Text('-', style: TextStyle(color: context.mutedFg));
    }
    final label = sns.length > 1 ? '${sns.first} (${sns.length})' : sns.first;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    );
  }

  Widget _modelCell(BuildContext context, Product p) {
    final models = parseModels(p.model);
    if (models.isEmpty) {
      return Text('-', style: TextStyle(color: context.mutedFg));
    }
    final label = models.length > 1
        ? '${models.first} +${models.length - 1}'
        : models.first;
    return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _expansion(BuildContext context, Product p) {
    final sns = parseSerialNumbers(p.serialNumber);
    final models = parseModels(p.model);
    final entries = <InventorySerialEntry>[
      for (var i = 0; i < sns.length; i++)
        InventorySerialEntry(
          key: '$i',
          productName: p.name,
          serialNumber: sns[i],
          model: i < models.length ? models[i] : null,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Serial entries (${entries.length})',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.mutedFg,
          ),
        ),
        const SizedBox(height: 8),
        InventorySerialEntriesTable(entries: entries),
      ],
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
        hint: 'Search products...',
      ).copyWith(
        prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
      ),
    );
    final add = GradientButton(
      label: 'Add Product',
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

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    this.product,
    required this.brands,
    required this.productTypes,
    required this.unitTypes,
  });

  final Product? product;
  final List<Brand> brands;
  final List<ProductType> productTypes;
  final List<UnitType> unitTypes;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name =
      TextEditingController(text: widget.product?.name ?? '');
  final TextEditingController _serial = TextEditingController();
  final TextEditingController _model = TextEditingController();

  String _brandId = '';
  String _brandName = '';
  String _productTypeId = '';
  String _productTypeName = '';
  String _unitType = 'piece';
  bool _noSerialNumber = false;
  bool _noModel = false;

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _brandId = p.brandId;
      _brandName = p.brandName;
      _productTypeId = p.productTypeId;
      _productTypeName = p.productTypeName.isNotEmpty
          ? p.productTypeName
          : p.category;
      _unitType = p.unitType.isEmpty ? 'piece' : p.unitType;
      _noSerialNumber = p.noSerialNumber;
      _noModel = p.noModel;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _serial.dispose();
    _model.dispose();
    super.dispose();
  }

  String _merge(String existingRaw, String addedRaw, bool noValue) {
    if (noValue) return existingRaw;
    final parsed = parseSerialNumbers(addedRaw);
    final next = parseSerialNumbers(existingRaw);
    final set = <String>{...next, ...parsed};
    return set.join(', ');
  }

  String _mergeModels(String existingRaw, String addedRaw, bool noValue) {
    if (noValue) return existingRaw;
    final parsed = parseModels(addedRaw);
    final next = parseModels(existingRaw);
    final list = <String>[...next];
    for (final m in parsed) {
      if (!list.contains(m)) list.add(m);
    }
    return list.join(', ');
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final p = widget.product;
    final existingSerial = p?.serialNumber ?? '';
    final addedSerial = _serial.text.trim();
    final serialNumber = _noSerialNumber || addedSerial.isEmpty
        ? existingSerial
        : _merge(existingSerial, addedSerial, false);
    final existingModel = p?.model ?? '';
    final addedModel = _model.text.trim();
    final model = _noModel || addedModel.isEmpty
        ? existingModel
        : _mergeModels(existingModel, addedModel, false);
    Navigator.of(context).pop({
      'productId': p?.productId ?? '',
      'name': _name.text.trim(),
      'brandId': _brandId,
      'brandName': _brandName,
      'productTypeId': _productTypeId,
      'productTypeName': _productTypeName,
      'category': _productTypeName,
      'unitType': _unitType,
      'serialNumber': serialNumber,
      'noSerialNumber': _noSerialNumber,
      'model': model,
      'noModel': _noModel,
      'price': p?.price ?? 0,
      'stock': p?.stock ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final brandOptions = [
      for (final b in widget.brands) InventoryOption(id: b.id, name: b.name),
    ];
    final typeOptions = [
      for (final t in widget.productTypes)
        InventoryOption(id: t.id, name: t.name),
    ];
    final unitOptions = [
      for (final u in widget.unitTypes) u.name,
      if (widget.unitTypes.isEmpty) 'piece',
    ];
    final currentUnit =
        unitOptions.contains(_unitType) ? _unitType : unitOptions.first;

    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: invProductGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _editing ? 'Edit Product' : 'Add New Product',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NetField(
                  label: 'Product ID',
                  child: TextFormField(
                    readOnly: true,
                    initialValue: widget.product?.productId.isNotEmpty == true
                        ? widget.product!.productId
                        : 'Auto-generated',
                    decoration: netInputDecoration(context),
                    style: TextStyle(color: context.mutedFg),
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Product Name *',
                  child: TextFormField(
                    controller: _name,
                    autofocus: true,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g., Fiber Router',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Product name is required'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: InventorySearchDropdown(
                        label: 'Brand',
                        icon: Icons.sell_outlined,
                        iconColor: AppColors.emerald600,
                        items: brandOptions,
                        value: _brandId,
                        placeholder: 'Select a brand',
                        onChanged: (id) => setState(() {
                          _brandId = id;
                          _brandName = widget.brands
                              .firstWhere((b) => b.id == id)
                              .name;
                        }),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InventorySearchDropdown(
                        label: 'Product Type',
                        icon: Icons.archive_outlined,
                        iconColor: AppColors.emerald600,
                        items: typeOptions,
                        value: _productTypeId,
                        placeholder: 'Select a type',
                        onChanged: (id) => setState(() {
                          _productTypeId = id;
                          _productTypeName = widget.productTypes
                              .firstWhere((t) => t.id == id)
                              .name;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Unit Type',
                  child: DropdownButtonFormField<String>(
                    initialValue: currentUnit,
                    decoration: netInputDecoration(context),
                    items: [
                      for (final u in unitOptions)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (v) => setState(() => _unitType = v ?? _unitType),
                  ),
                ),
                const SizedBox(height: 14),
                if (_editing && widget.product!.serialNumber.isNotEmpty)
                  NetField(
                    label: 'Current Serial Number(s)',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.inputFill,
                        border: Border.all(color: context.line),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.product!.serialNumber,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                if (_editing && widget.product!.serialNumber.isNotEmpty)
                  const SizedBox(height: 14),
                NetField(
                  label: _editing ? 'Add More Serial Numbers' : 'Serial Number (SN/MAC)',
                  child: TextFormField(
                    controller: _serial,
                    maxLines: 2,
                    enabled: !_noSerialNumber,
                    decoration: netInputDecoration(
                      context,
                      hint: 'Enter serial numbers separated by spaces, commas or dashes',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _checkbox(
                  value: _noSerialNumber,
                  label: 'Add without serial number',
                  onChanged: (v) => setState(() => _noSerialNumber = v),
                ),
                const SizedBox(height: 10),
                NetField(
                  label: _editing ? 'Add More Models' : 'Model',
                  child: TextFormField(
                    controller: _model,
                    maxLines: 2,
                    enabled: !_noModel,
                    decoration: netInputDecoration(
                      context,
                      hint: 'Enter models separated by commas or new lines',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _checkbox(
                  value: _noModel,
                  label: 'Add without model',
                  onChanged: (v) => setState(() => _noModel = v),
                ),
              ],
            ),
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
        GradientButton(
          label: _editing ? 'Update Product' : 'Add Product',
          gradient: invEmeraldButtonGradient,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _checkbox({
    required bool value,
    required String label,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          visualDensity: VisualDensity.compact,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
