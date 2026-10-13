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
import '../sales/sales_common.dart';
import 'inventory_common.dart';
import 'inventory_models.dart';
import 'inventory_print.dart';
import 'purchase_dialogs.dart';
import 'purchase_form.dart';

/// Flutter counterpart of
/// `client/src/app/(app)/inventory/purchases/page.tsx`.
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  static final NumberFormat _money = NumberFormat('#,##0');

  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);
  final TextEditingController _search = TextEditingController();
  final Set<String> _expanded = {};

  List<Purchase> _purchases = [];
  List<Vendor> _vendors = [];
  List<Product> _products = [];
  List<VendorInvoice> _vendorInvoices = [];
  bool _loading = true;
  bool _exporting = false;
  String _pageSize = '10';
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
        _api.get('/inventory/purchases', query: {'companyId': cid}),
        _api.get('/inventory/vendors', query: {'companyId': cid}),
        _api.get('/inventory/products', query: {'companyId': cid}),
        _api.get('/inventory/vendor-invoices', query: {'companyId': cid}),
      ]);
      if (!mounted) return;
      setState(() {
        _purchases = _list<Purchase>(results[0], Purchase.fromJson);
        _vendors = _list<Vendor>(results[1], Vendor.fromJson);
        _products = _list<Product>(results[2], Product.fromJson);
        _vendorInvoices =
            _list<VendorInvoice>(results[3], VendorInvoice.fromJson);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  static List<T> _list<T>(
    Map<String, dynamic> envelope,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return ApiClient.listData(envelope)
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList();
  }

  List<Purchase> get _filtered {
    final q = _search.text.trim();
    if (q.isEmpty) return _purchases;
    return invSmartSearch(q, _purchases, (p) => [
      [p.purchaseNumber, p.billId],
      [p.vendorName, ...p.items.map((i) => i.productName)],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final safePage = _currentPage(filtered.length);
    final paged = _pagedRows(filtered, safePage);
    final totalAmount = _purchases.fold<num>(0, (s, p) => s + p.totalAmount);
    final avg = _purchases.isEmpty ? 0 : (totalAmount / _purchases.length);
    final canCreate = invCrud(kPurchasePermission, 'create');
    final canUpdate = invCrud(kPurchasePermission, 'update');
    final canDelete = invCrud(kPurchasePermission, 'delete');

    return NetworkScrollBody(
      children: [
        const NetworkPageHeader(
          icon: Icons.shopping_cart_outlined,
          title: 'Purchases',
          subtitle: 'Manage purchase orders from vendors.',
          gradient: invPurchaseGradient,
        ),
        NetworkStatGrid(
          children: [
            NetworkStatCard(
              icon: Icons.shopping_cart_outlined,
              label: 'Total Purchases',
              value: '${_purchases.length}',
              gradient: invVioletGradient,
            ),
            NetworkStatCard(
              icon: Icons.attach_money,
              label: 'Total Amount',
              value: 'PKR ${_money.format(totalAmount)}',
              gradient: invEmeraldStatGradient,
            ),
            NetworkStatCard(
              icon: Icons.receipt_outlined,
              label: 'Avg Per Purchase',
              value: 'PKR ${_money.format(avg)}',
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
              _toolbar(context, canCreate),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                NetworkTable<Purchase>(
                  emptyIcon: Icons.shopping_cart_outlined,
                  emptyTint: const Color(0xFF8B5CF6),
                  emptyTitle: 'No purchases found',
                  emptyHint: 'Try adjusting your search.',
                  rows: paged,
                  columns: _columns(context, canUpdate, canDelete),
                  rowKey: (p) => p.id,
                  rowCanExpand: (p) => p.items.any(
                    (item) =>
                        item.history.isNotEmpty ||
                        parseSerialNumbers(item.serialNumber).length > 1,
                  ),
                  expandedKeys: _expanded,
                  onToggleExpand: (key) => setState(() {
                    if (!_expanded.remove(key)) _expanded.add(key);
                  }),
                  expansionBuilder: (context, p, _) => _expansion(context, p),
                ),
              if (!_loading)
                InvCollectionPagination(
                  total: _filtered.length,
                  pageSize: _pageSize,
                  currentPage: _currentPage(_filtered.length),
                  onPageSizeChanged: (v) => setState(() {
                    _pageSize = v;
                    _page = 1;
                  }),
                  onPageChanged: (p) => setState(() => _page = p),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context, bool canCreate) {
    final search = TextField(
      controller: _search,
      onChanged: (_) => setState(() => _page = 1),
      style: const TextStyle(fontSize: 14),
      decoration:
          netInputDecoration(context, hint: 'Search purchases...').copyWith(
        prefixIcon: Icon(Icons.search, size: 16, color: context.mutedFg),
      ),
    );
    final actions = <Widget>[
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
        onPressed: _exporting ? null : _exportCsv,
        icon: const Icon(Icons.table_chart_outlined, size: 16),
        label: const Text('Excel'),
      ),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
        onPressed: _exporting ? null : _exportPdf,
        icon: const Icon(Icons.file_download_outlined, size: 16),
        label: const Text('PDF'),
      ),
      if (canCreate)
        GradientButton(
          label: 'Add Purchase',
          icon: Icons.add_circle_outline,
          gradient: invEmeraldButtonGradient,
          onPressed: () => _openForm(null),
        ),
    ];
    return InvFilterBar(
      filterWidth: 320,
      filters: [search],
      actions: actions,
    );
  }

  int _currentPage(int total) {
    final isAll = _pageSize == 'all';
    final size = isAll ? (total < 1 ? 1 : total) : (int.tryParse(_pageSize) ?? 10);
    final totalPages = total == 0 ? 1 : (total / size).ceil();
    return _page.clamp(1, totalPages);
  }

  List<Purchase> _pagedRows(List<Purchase> filtered, int page) {
    if (_pageSize == 'all') return filtered;
    final size = int.tryParse(_pageSize) ?? 10;
    return filtered.skip((page - 1) * size).take(size).toList();
  }

  List<NetColumn<Purchase>> _columns(
    BuildContext context,
    bool canUpdate,
    bool canDelete,
  ) {
    return [
      NetColumn(
        label: 'Bill ID',
        width: 120,
        builder: (context, p, _) => Text(
          p.displayBillId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      NetColumn(
        label: 'Vendor',
        width: 130,
        builder: (context, p, _) => Text(
          p.vendorName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      NetColumn(
        label: 'Products',
        width: 210,
        builder: (context, p, _) {
          final names = p.items
              .map((i) => i.productName)
              .where((n) => n.isNotEmpty)
              .toList();
          if (names.isEmpty) {
            return Text('-', style: TextStyle(color: context.mutedFg));
          }
          final display = names.length > 2
              ? '${names.take(2).join(', ')} +${names.length - 2} more'
              : names.join(', ');
          return Tooltip(
            message: names.join(', '),
            child: Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          );
        },
      ),
      NetColumn(
        label: 'Date',
        width: 110,
        builder: (context, p, _) => Text(
          p.purchaseDate,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      NetColumn(
        label: 'SN / MAC',
        width: 130,
        builder: (context, p, _) {
          final all = <String>[];
          for (final item in p.items) {
            all.addAll(parseSerialNumbers(item.serialNumber));
          }
          if (all.isEmpty) {
            return Text('\u2014', style: TextStyle(color: context.mutedFg));
          }
          final display =
              all.length == 1 ? all[0] : '${all[0]} (1/${all.length})';
          return Tooltip(
            message: all.join(', '),
            child: Text(
              display,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          );
        },
      ),
      NetColumn(
        label: 'Total Amount',
        width: 130,
        builder: (context, p, _) => Text(
          'PKR ${_money.format(p.totalAmount)}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      NetColumn(
        label: 'Quantity',
        width: 90,
        builder: (context, p, _) => Text(
          _num(p.items.fold<num>(0, (s, i) => s + i.effectiveQuantity)),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      NetColumn(
        label: 'Status',
        width: 90,
        builder: (context, p, _) => PurchaseStatusBadge(status: p.status),
      ),
      NetColumn(
        label: '',
        width: 56,
        isActions: true,
        builder: (context, p, _) => _rowMenu(context, p, canUpdate, canDelete),
      ),
    ];
  }

  Widget _rowMenu(
    BuildContext context,
    Purchase p,
    bool canUpdate,
    bool canDelete,
  ) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: Icon(Icons.more_horiz, size: 20, color: context.mutedFg),
      onSelected: (value) {
        switch (value) {
          case 'pay':
            _pay(p);
          case 'edit':
            _openForm(p);
          case 'add':
            _addQuantity(p);
          case 'print-a4':
          case 'print-thermal':
            showPurchasePrintDialog(context, p, _api);
          case 'delete':
            _delete(p);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'pay',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.attach_money, size: 18, color: Color(0xFF16A34A)),
            title: Text('Pay'),
          ),
        ),
        if (canUpdate)
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined, size: 18),
              title: Text('Edit'),
            ),
          ),
        const PopupMenuItem(
          value: 'add',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add_box_outlined,
                size: 18, color: Color(0xFF10B981)),
            title: Text('Add Quantity'),
          ),
        ),
        const PopupMenuItem(
          value: 'print-a4',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.print_outlined, size: 18),
            title: Text('Print A4 Invoice'),
          ),
        ),
        const PopupMenuItem(
          value: 'print-thermal',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.receipt_outlined, size: 18),
            title: Text('Print Thermal Receipt'),
          ),
        ),
        if (canDelete)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading:
                  Icon(Icons.delete_outline, size: 18, color: context.dangerText),
              title: const Text('Delete'),
            ),
          ),
      ],
    );
  }

  Widget _expansion(BuildContext context, Purchase purchase) {
    final historyRows = purchaseHistoryRows(purchase);
    if (historyRows.isNotEmpty) {
      return PurchaseQuantityHistoryTable(rows: historyRows);
    }
    final entries = <InventorySerialEntry>[];
    for (final item in purchase.items) {
      final sns = parseSerialNumbers(item.serialNumber);
      final models = parseModels(item.model);
      for (var i = 0; i < sns.length; i++) {
        entries.add(
          InventorySerialEntry(
            key: '${item.productId}-${sns[i]}',
            productName: item.productName,
            serialNumber: sns[i],
            model: models.length == 1
                ? models[0]
                : (i < models.length ? models[i] : ''),
            price: item.purchasePrice,
          ),
        );
      }
    }
    return InventorySerialEntriesTable(entries: entries);
  }

  Future<void> _openForm(Purchase? purchase) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PurchaseFormDialog(
        purchase: purchase,
        vendors: _vendors,
        products: _products,
        purchases: _purchases,
        vendorInvoices: _vendorInvoices,
      ),
    );
    if (payload == null || !mounted) return;
    try {
      if (purchase != null) {
        await _api.put('/inventory/purchases/${purchase.id}', body: payload);
      } else {
        await _api.post('/inventory/purchases', body: payload);
      }
      if (!mounted) return;
      showToast(
        context,
        purchase != null
            ? 'Purchase updated successfully'
            : 'Purchase created successfully',
      );
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      showToast(context, e.message, error: true);
    }
  }

  Future<void> _pay(Purchase purchase) async {
    final newStatus = purchase.status == 'paid' ? 'unpaid' : 'paid';
    try {
      await _api.patch(
        '/inventory/purchases/${purchase.id}/status',
        body: {'status': newStatus},
      );
      if (!mounted) return;
      showToast(context, 'Purchase status updated');
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      showToast(context, e.message, error: true);
    }
  }

  Future<void> _addQuantity(Purchase purchase) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AddQuantityDialog(purchase: purchase),
    );
    if (payload == null || !mounted) return;
    try {
      await _api.post(
        '/inventory/purchases/${purchase.id}/add-quantity',
        body: payload,
      );
      if (!mounted) return;
      showToast(context, 'Quantity added to purchase');
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(Purchase purchase) async {
    await showNetworkDeleteDialog(
      context,
      itemName: purchase.purchaseNumber,
      onConfirm: () async {
        try {
          await _api.delete('/inventory/purchases/${purchase.id}');
          if (!mounted) return;
          showToast(context, 'Purchase deleted successfully');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final rows = <List<String>>[
        const [
          'Bill #',
          'Vendor',
          'Products',
          'Qty',
          'Total Amount',
          'Date',
          'Status',
        ],
        for (final p in _filtered)
          [
            p.displayBillId,
            p.vendorName,
            p.items.map((i) => i.productName).join(', '),
            _num(p.items.fold<num>(0, (s, i) => s + i.effectiveQuantity)),
            _money.format(p.totalAmount),
            p.purchaseDate,
            p.status,
          ],
      ];
      final ok =
          await salesWriteCsv(context, 'Purchases-${salesToday()}.csv', rows);
      if (ok && mounted) showToast(context, 'Exported purchases to CSV');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    final filtered = _filtered;
    final page = _currentPage(filtered.length);
    final rowsData = _pagedRows(filtered, page);
    final rows = rowsData
        .map(
          (p) => '''
        <tr>
          <td>${salesEscapeHtml(p.displayBillId)}</td>
          <td>${salesEscapeHtml(p.vendorName)}</td>
          <td>${salesEscapeHtml(p.items.map((i) => i.productName).join(', '))}</td>
          <td class="r">${_num(p.items.fold<num>(0, (s, i) => s + i.effectiveQuantity))}</td>
          <td class="r">PKR ${salesNumber(p.totalAmount)}</td>
          <td>${salesEscapeHtml(p.purchaseDate)}</td>
          <td>${salesEscapeHtml(p.status)}</td>
        </tr>''',
        )
        .join();
    final html = '''<!DOCTYPE html>
<html><head><meta charset="utf-8"/><title>Purchases Report</title>
<style>
  body{font-family:'Segoe UI',system-ui,sans-serif;color:#111827;padding:24px;}
  h1{font-size:22px;margin:0;}
  .sub{color:#6b7280;font-size:13px;margin:4px 0 18px;}
  table{width:100%;border-collapse:collapse;}
  th,td{border:1px solid #d1d5db;padding:8px;font-size:12px;text-align:left;}
  thead tr{background:#8B5CF6;color:#fff;}
  td.r,th.r{text-align:right;}
  @media print{ .no-print{display:none;} }
</style></head>
<body>
  <h1>Purchases Report</h1>
  <div class="sub">As of ${salesEscapeHtml(salesShortDate(DateTime.now().toIso8601String()))}</div>
  <table>
    <thead><tr>
      <th>Bill #</th><th>Vendor</th><th>Products</th><th class="r">Qty</th>
      <th class="r">Total</th><th>Date</th><th>Status</th>
    </tr></thead>
    <tbody>$rows</tbody>
  </table>
</body></html>''';
    await salesOpenHtml(context, 'Purchases-Report-${salesToday()}.html', html);
  }

  static String _num(num? v) {
    if (v == null) return '0';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }
}
