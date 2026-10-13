import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'inventory_common.dart';
import 'inventory_models.dart';

/// Flutter counterpart of
/// `client/src/app/(app)/inventory/statuses/page.tsx` (read-only).
class InventoryStatusScreen extends StatefulWidget {
  const InventoryStatusScreen({super.key});

  @override
  State<InventoryStatusScreen> createState() => _InventoryStatusScreenState();
}

class _InventoryStatusScreenState extends State<InventoryStatusScreen> {
  static const List<int> _pageSizes = [10, 25, 50, 100];
  static final NumberFormat _money = NumberFormat('#,##0');

  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);
  final TextEditingController _search = TextEditingController();
  final TextEditingController _vendor = TextEditingController();
  final TextEditingController _batch = TextEditingController();
  final TextEditingController _maxQty = TextEditingController();

  List<PurchasedProduct> _items = [];
  bool _loading = true;
  int _pageSize = 10;
  int _page = 1;

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
    _vendor.dispose();
    _batch.dispose();
    _maxQty.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await _api.get(
        '/inventory/purchased-products',
        query: {'companyId': cid},
      );
      if (!mounted) return;
      setState(() {
        _items = ApiClient.listData(res)
            .whereType<Map<String, dynamic>>()
            .map(PurchasedProduct.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<PurchasedProduct> get _filtered {
    var result = _items;
    final q = _search.text.trim();
    if (q.isNotEmpty) {
      result = result
          .where((p) => p.name.toLowerCase().startsWith(q.toLowerCase()))
          .toList();
    }
    final v = _vendor.text.trim().toLowerCase();
    if (v.isNotEmpty) {
      result =
          result.where((p) => p.vendorName.toLowerCase().contains(v)).toList();
    }
    final b = _batch.text.trim().toLowerCase();
    if (b.isNotEmpty) {
      result = result.where((p) => p.batch.toLowerCase().contains(b)).toList();
    }
    final rawMax = _maxQty.text.trim();
    if (rawMax.isNotEmpty) {
      final max = int.tryParse(rawMax);
      if (max != null) {
        result = result.where((p) => p.stock < max).toList();
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final safePage = _currentPage(filtered);
    final paged = filtered
        .skip((safePage - 1) * _pageSize)
        .take(_pageSize)
        .toList();
    final inStock = _items.where((p) => p.stock > 0).length;
    final lowStock =
        _items.where((p) => p.stock > 0 && p.stock <= 5).length;

    return NetworkScrollBody(
      children: [
        const NetworkPageHeader(
          icon: Icons.fact_check_outlined,
          title: 'Inventory Status',
          subtitle: 'View stock levels per purchase item.',
          gradient: invStatusGradient,
        ),
        NetworkStatGrid(
          children: [
            NetworkStatCard(
              icon: Icons.inventory_2_outlined,
              label: 'Total Items',
              value: '${_items.length}',
              gradient: invStatusGradient,
            ),
            NetworkStatCard(
              icon: Icons.check_circle_outline,
              label: 'In Stock',
              value: '$inStock',
              gradient: invEmeraldStatGradient,
              valueColor: context.isDark
                  ? const Color(0xFF34D399)
                  : const Color(0xFF059669),
            ),
            NetworkStatCard(
              icon: Icons.warning_amber_rounded,
              label: 'Low Stock',
              value: '$lowStock',
              gradient: invAmberStatGradient,
              valueColor: context.isDark
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFFD97706),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.line),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _filters(context),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                NetworkTable<PurchasedProduct>(
                  emptyIcon: Icons.fact_check_outlined,
                  emptyTint: const Color(0xFFF43F5E),
                  emptyTitle: 'No inventory items found',
                  emptyHint: 'Try adjusting your search or filters.',
                  rows: paged,
                  columns: _columns(context),
                ),
              if (!_loading)
                NetworkPagination(
                  currentPage: safePage,
                  pageSize: _pageSize,
                  totalItems: filtered.length,
                  noun: 'entries',
                  pageSizes: _pageSizes,
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
    );
  }

  int _currentPage(List<PurchasedProduct> filtered) {
    final totalPages =
        filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
    return _page.clamp(1, totalPages);
  }

  List<NetColumn<PurchasedProduct>> _columns(BuildContext context) {
    return [
      NetColumn(
        label: 'Bill ID',
        width: 110,
        builder: (context, p, _) => Text(
          p.displayBillId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      NetColumn(
        label: 'Vendor',
        width: 120,
        builder: (context, p, _) => Text(
          p.vendorName.isEmpty ? '-' : p.vendorName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      NetColumn(
        label: 'Date',
        width: 100,
        builder: (context, p, _) => Text(
          p.purchaseDate.isEmpty ? '-' : p.purchaseDate,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      NetColumn(
        label: 'Batch',
        width: 100,
        builder: (context, p, _) => Text(
          p.batch.isEmpty ? '-' : p.batch,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      NetColumn(
        label: 'SN / MAC',
        width: 150,
        builder: (context, p, _) {
          final sns = parseSerialNumbers(p.serialNumber);
          if (sns.isEmpty) {
            return Text(
              '\u2014',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: context.mutedFg,
              ),
            );
          }
          final display =
              sns.length == 1 ? sns[0] : '${sns[0]} (1/${sns.length})';
          return Tooltip(
            message: sns.join(', '),
            child: Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          );
        },
      ),
      NetColumn(
        label: 'Model',
        width: 120,
        builder: (context, p, _) {
          final models = parseModels(
            p.model.isNotEmpty ? p.model : p.productModel,
          );
          if (models.isEmpty) {
            return Text(
              '\u2014',
              style: TextStyle(fontSize: 12, color: context.mutedFg),
            );
          }
          final display = models.length == 1
              ? models[0]
              : '${models[0]} +${models.length - 1}';
          return Tooltip(
            message: models.join(', '),
            child: Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.isDark
                    ? const Color(0xFF7DD3FC)
                    : const Color(0xFF0369A1),
              ),
            ),
          );
        },
      ),
      NetColumn(
        label: 'Product',
        width: 160,
        builder: (context, p, _) => Text(
          p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      NetColumn(
        label: 'Quantity',
        width: 90,
        builder: (context, p, _) => Text(
          _num(p.stock),
          style: TextStyle(
            fontWeight: p.stock == 0 ? FontWeight.normal : FontWeight.w500,
            color: p.stock == 0 ? context.mutedFg : context.fg,
          ),
        ),
      ),
      NetColumn(
        label: 'Damage Qty',
        width: 100,
        builder: (context, p, _) => const Text('0'),
      ),
      NetColumn(
        label: 'Purchase Price',
        width: 120,
        builder: (context, p, _) =>
            Text('PKR ${_money.format(p.purchasePrice)}'),
      ),
      NetColumn(
        label: 'Selling Price',
        width: 120,
        builder: (context, p, _) => Text('PKR ${_money.format(p.price)}'),
      ),
    ];
  }

  Widget _filters(BuildContext context) {
    Widget field(TextEditingController c, String hint, {bool numeric = false}) {
      return TextField(
        controller: c,
        onChanged: (_) => setState(() => _page = 1),
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 14),
        decoration: netInputDecoration(context, hint: hint).copyWith(
          prefixIcon: Icon(Icons.search, size: 16, color: context.mutedFg),
        ),
      );
    }

    final fields = [
      field(_search, 'Search product name...'),
      field(_vendor, 'Filter vendor...'),
      field(_batch, 'Filter batch...'),
      field(_maxQty, 'Less than qty', numeric: true),
    ];
    return InvFilterBar(filterWidth: 240, filters: fields);
  }

  static String _num(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}
