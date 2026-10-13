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

/// Flutter counterpart of
/// `client/src/app/(app)/inventory/stock/page.tsx` (read-only, expandable).
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  static final NumberFormat _money = NumberFormat('#,##0');
  static const List<int> _pageSizes = [5, 10, 20, 50, 100];

  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);
  final TextEditingController _filter = TextEditingController();
  final Set<String> _expanded = {};

  List<StockProduct> _items = [];
  bool _loading = true;
  bool _exporting = false;
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
    _filter.dispose();
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
            .map(StockProduct.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<StockProduct> get _filtered => invSmartSearch(
    _filter.text,
    _items,
    (item) => [
      [item.name],
      [item.serialNumber],
      [item.vendorName],
      [item.purchaseNumber],
    ],
  );

  int _currentPage(int total) {
    final totalPages = total == 0 ? 1 : (total / _pageSize).ceil();
    return _page.clamp(1, totalPages);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final safePage = _currentPage(filtered.length);
    final paged = filtered
        .skip((safePage - 1) * _pageSize)
        .take(_pageSize)
        .toList();
    final totalStock = _items.fold<num>(0, (s, i) => s + i.stock);
    final totalValue = _items.fold<num>(
      0,
      (s, i) => s + i.stock * (i.price != 0 ? i.price : i.purchasePrice),
    );

    return NetworkScrollBody(
      children: [
        const NetworkPageHeader(
          icon: Icons.inventory_2_outlined,
          title: 'Stock',
          subtitle:
              'Products grouped by name. Stock is derived (purchased minus sold) and matches the POS page.',
          gradient: invStockGradient,
        ),
        NetworkStatGrid(
          children: [
            NetworkStatCard(
              icon: Icons.inventory_2_outlined,
              label: 'Total Products',
              value: '${_items.length}',
              gradient: invStockGradient,
            ),
            NetworkStatCard(
              icon: Icons.inventory_outlined,
              label: 'Total Stock',
              value: _num(totalStock),
              gradient: const [Color(0xFF3B82F6), Color(0xFF06B6D4)],
            ),
            NetworkStatCard(
              icon: Icons.attach_money,
              label: 'Total Value',
              value: 'PKR ${_money.format(totalValue)}',
              gradient: const [Color(0xFF8B5CF6), Color(0xFF9333EA)],
              valueColor: context.isDark
                  ? const Color(0xFFA78BFA)
                  : const Color(0xFF7C3AED),
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
              _toolbar(context),
              if (filtered.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Click a row to expand its purchase history. Products bought more than once show a badge under Purchases.',
                    style: TextStyle(fontSize: 12, color: context.mutedFg),
                  ),
                ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                NetworkTable<StockProduct>(
                  emptyIcon: Icons.inventory_2_outlined,
                  emptyTint: const Color(0xFF14B8A6),
                  emptyTitle: 'No stock found',
                  emptyHint: 'Try adjusting your filter.',
                  rows: paged,
                  columns: _columns(context),
                  rowKey: (item) =>
                      item.purchaseItemId.isNotEmpty ? item.purchaseItemId : item.id,
                  rowCanExpand: (item) => item.lines.length > 1,
                  expandedKeys: _expanded,
                  onToggleExpand: (key) => setState(() {
                    if (!_expanded.remove(key)) _expanded.add(key);
                  }),
                  expansionBuilder: (context, item, _) =>
                      _renderVersions(context, item),
                ),
              if (!_loading)
                NetworkPagination(
                  currentPage: safePage,
                  pageSize: _pageSize,
                  totalItems: filtered.length,
                  noun: 'items',
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

  Widget _toolbar(BuildContext context) {
    final filter = TextField(
      controller: _filter,
      onChanged: (_) => setState(() => _page = 1),
      style: const TextStyle(fontSize: 14),
      decoration: netInputDecoration(
        context,
        hint: 'Filter by product, SN/MAC or vendor...',
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
    ];
    return InvFilterBar(
      filterWidth: 320,
      filters: [filter],
      actions: actions,
    );
  }

  List<NetColumn<StockProduct>> _columns(BuildContext context) {
    return [
      NetColumn(
        label: '#',
        width: 48,
        builder: (context, item, index) => Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: context.mutedFg,
          ),
        ),
      ),
      NetColumn(
        label: 'Product',
        width: 170,
        builder: (context, item, _) => Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      NetColumn(
        label: 'Purchases',
        width: 110,
        builder: (context, item, _) {
          final count = item.lines.length;
          if (count <= 1) {
            return Text(
              '\u2014',
              style: TextStyle(fontSize: 12, color: context.mutedFg),
            );
          }
          return _Badge(
            text: '$count entries',
            bg: context.subtle,
            fg: context.fg,
          );
        },
      ),
      NetColumn(
        label: 'Vendor',
        width: 120,
        builder: (context, item, _) => Text(
          item.vendorName.isEmpty ? '\u2014' : item.vendorName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      NetColumn(
        label: 'Last Purchased',
        width: 120,
        builder: (context, item, _) => Text(
          item.purchaseDate.isEmpty ? '\u2014' : item.purchaseDate,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      NetColumn(
        label: 'Purchased',
        width: 90,
        builder: (context, item, _) => Text(
          _num(item.totalPurchased),
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      ),
      NetColumn(
        label: 'Sold',
        width: 80,
        builder: (context, item, _) => Text(
          _num(item.totalSold),
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      ),
      NetColumn(
        label: 'Stock',
        width: 120,
        builder: (context, item, _) {
          final stock = item.stock;
          if (stock <= 0) {
            return const _Badge(
              text: 'Out of stock',
              bg: Color(0xFFFEE2E2),
              fg: Color(0xFFB91C1C),
            );
          }
          if (stock > 10) {
            return _Badge(
              text: '${_num(stock)} in stock',
              bg: const Color(0xFF16A34A),
              fg: Colors.white,
            );
          }
          return _Badge(
            text: '${_num(stock)} in stock',
            bg: context.subtle,
            fg: context.fg,
          );
        },
      ),
      NetColumn(
        label: 'Price (PKR)',
        width: 110,
        builder: (context, item, _) => Text(
          _money.format(item.price),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
    ];
  }

  Widget _renderVersions(BuildContext context, StockProduct row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 12, color: context.fg),
            children: [
              const TextSpan(text: 'Purchase lines for '),
              TextSpan(
                text: row.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _linesTable(context, row.lines),
      ],
    );
  }

  Widget _linesTable(BuildContext context, List<PurchasedProductLine> lines) {
    const widths = <double>[32, 110, 100, 120, 90, 50, 130, 110, 100];
    const headers = <String>[
      '#',
      'Purchase #',
      'Date',
      'Vendor',
      'Batch',
      'Qty',
      'SN / MAC',
      'Model',
      'Unit Price',
    ];
    Widget cell(String text, double width, {bool mono = false, bool right = false}) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            text,
            textAlign: right ? TextAlign.right : TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontFamily: mono ? 'monospace' : null,
              color: mono ? context.mutedFg : null,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: context.subtle,
              child: Row(
                children: [
                  for (var i = 0; i < headers.length; i++)
                    cell(headers[i], widths[i]),
                ],
              ),
            ),
            for (var i = 0; i < lines.length; i++)
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.line)),
                ),
                child: Row(
                  children: [
                    cell('${i + 1}', widths[0], mono: true),
                    cell(
                      lines[i].purchaseNumber.isNotEmpty
                          ? lines[i].purchaseNumber
                          : (lines[i].billId.isNotEmpty ? lines[i].billId : '—'),
                      widths[1],
                    ),
                    cell(
                      lines[i].purchaseDate.isNotEmpty
                          ? lines[i].purchaseDate
                          : '—',
                      widths[2],
                    ),
                    cell(
                      lines[i].vendorName.isNotEmpty
                          ? lines[i].vendorName
                          : '—',
                      widths[3],
                    ),
                    cell(
                      lines[i].batch.isNotEmpty ? lines[i].batch : '—',
                      widths[4],
                    ),
                    cell(_num(lines[i].quantity), widths[5], mono: true, right: true),
                    cell(_firstSn(lines[i].serialNumber), widths[6], mono: true),
                    cell(lines[i].model.isNotEmpty ? lines[i].model : '—', widths[7]),
                    cell(
                      'PKR ${_money.format(lines[i].purchasePrice)}',
                      widths[8],
                      right: true,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final rows = <List<String>>[
        const [
          'Product',
          'SN / MAC',
          'Vendor',
          'Purchase #',
          'Purchased',
          'Sold',
          'Stock',
          'Price (PKR)',
        ],
        for (final item in _filtered)
          [
            item.name,
            _firstSn(item.serialNumber),
            item.vendorName,
            item.purchaseNumber,
            _num(item.totalPurchased),
            _num(item.totalSold),
            _num(item.stock),
            _money.format(item.price),
          ],
      ];
      final ok = await salesWriteCsv(
        context,
        'Stock-${salesToday()}.csv',
        rows,
      );
      if (ok && mounted) showToast(context, 'Exported stock to CSV');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    final filtered = _filtered;
    final safePage = _currentPage(filtered.length);
    final paged = filtered
        .skip((safePage - 1) * _pageSize)
        .take(_pageSize)
        .toList();
    final rows = paged
        .map(
          (s) => '''
        <tr>
          <td>${salesEscapeHtml(s.name)}</td>
          <td>${salesEscapeHtml(s.vendorName)}</td>
          <td>${salesEscapeHtml(s.purchaseDate)}</td>
          <td class="r">${_num(s.totalPurchased)}</td>
          <td class="r">${_num(s.totalSold)}</td>
          <td class="r">${_num(s.stock)}</td>
          <td class="r">PKR ${salesNumber(s.price)}</td>
        </tr>''',
        )
        .join();
    final html = '''<!DOCTYPE html>
<html><head><meta charset="utf-8"/><title>Stock Report</title>
<style>
  body{font-family:'Segoe UI',system-ui,sans-serif;color:#111827;padding:24px;}
  h1{font-size:22px;margin:0;}
  .sub{color:#6b7280;font-size:13px;margin:4px 0 18px;}
  table{width:100%;border-collapse:collapse;}
  th,td{border:1px solid #d1d5db;padding:8px;font-size:12px;text-align:left;}
  thead tr{background:#14B8A6;color:#fff;}
  td.r,th.r{text-align:right;}
  @media print{ .no-print{display:none;} }
</style></head>
<body>
  <h1>Stock Report</h1>
  <div class="sub">As of ${salesEscapeHtml(salesShortDate(DateTime.now().toIso8601String()))}</div>
  <table>
    <thead><tr>
      <th>Product</th><th>Vendor</th><th>Last Purchased</th>
      <th class="r">Purchased</th><th class="r">Sold</th>
      <th class="r">Stock</th><th class="r">Price (PKR)</th>
    </tr></thead>
    <tbody>$rows</tbody>
  </table>
</body></html>''';
    await salesOpenHtml(context, 'Stock-Report-${salesToday()}.html', html);
  }

  static String _num(num? v) {
    if (v == null) return '0';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  static String _firstSn(String? raw) {
    final sns = parseSerialNumbers(raw);
    if (sns.isEmpty) return '—';
    if (sns.length == 1) return sns[0];
    return '${sns[0]} (${sns.length})';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
