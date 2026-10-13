import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'sales_common.dart';
import 'sales_models.dart';

/// Flutter counterpart of `client/src/app/(app)/sales/replaced/page.tsx` — the
/// products that were exchanged when a sale was replaced. When a sale is
/// replaced the row keeps its replacement product under `items` while the
/// ORIGINAL products are stored under `replacedFrom`; this page reports on
/// those original entries.
class ReplacedProductsScreen extends StatefulWidget {
  const ReplacedProductsScreen({super.key});

  @override
  State<ReplacedProductsScreen> createState() => _ReplacedProductsScreenState();
}

/// One flattened replaced-product line (web `ReplacedProductRow`).
class _ReplacedRow {
  _ReplacedRow({
    required this.saleId,
    required this.date,
    required this.subscriberName,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.serialNumber,
    required this.model,
  });

  final String saleId;
  final String date;
  final String subscriberName;
  final String productName;
  final int quantity;
  final double price;
  final String serialNumber;
  final String model;

  double get amount => price * quantity;
}

class _ReplacedProductsScreenState extends State<ReplacedProductsScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<_ReplacedRow> _rows = [];
  bool _loading = true;

  String _fromDate = '';
  String _toDate = '';
  final TextEditingController _search = TextEditingController();
  String _filter = '';
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

  bool get _hasFilters =>
      _search.text.isNotEmpty || _fromDate.isNotEmpty || _toDate.isNotEmpty;

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

  /// Parses the original items out of a sale's `replacedFrom` JSON snapshot,
  /// falling back to the sale's own `items` (web `originalItemsOf`).
  List<SalesItem> _originalItems(SalesEntry sale) {
    if (sale.replacedFrom.isNotEmpty) {
      try {
        final parsed = jsonDecode(sale.replacedFrom);
        if (parsed is Map) {
          final items = parsed['items'];
          if (items is List) {
            return items
                .whereType<Map>()
                .map((e) => SalesItem.fromJson(e.cast<String, dynamic>()))
                .toList();
          }
        }
      } catch (_) {
        // fall through to the sale's own items
      }
    }
    return sale.items;
  }

  List<_ReplacedRow> _flatRows(List<SalesEntry> sales) {
    final rows = <_ReplacedRow>[];
    for (final sale in sales) {
      final items = _originalItems(sale);
      for (final item in items) {
        final sns = parseSalesTokens(item.serialNumber, [RegExp(r'[\s,\-]+')]);
        final models = parseSalesTokens(item.model, [RegExp(r'[\s,\n\r\t,]+')]);
        rows.add(
          _ReplacedRow(
            saleId: sale.id,
            date: sale.date,
            subscriberName: sale.customerLabel,
            productName: item.productName,
            quantity: item.quantity,
            price: item.price,
            serialNumber: sns.isEmpty ? '' : sns.join(', '),
            model: models.isEmpty ? item.model : models.join(', '),
          ),
        );
      }
    }
    return rows;
  }

  List<_ReplacedRow> get _filtered {
    var rows = _rows;
    if (_fromDate.isNotEmpty) {
      rows = rows
          .where((r) => _dateOnly(r.date).compareTo(_fromDate) >= 0)
          .toList();
    }
    if (_toDate.isNotEmpty) {
      rows = rows
          .where((r) => _dateOnly(r.date).compareTo(_toDate) <= 0)
          .toList();
    }
    if (_filter.trim().isNotEmpty) {
      rows = rows
          .where(
            (r) => salesSmartMatch(_filter, [
              [r.saleId, r.serialNumber],
              [r.subscriberName, r.productName, r.model],
            ]),
          )
          .toList();
    }
    return rows;
  }

  static String _dateOnly(String raw) =>
      raw.length >= 10 ? raw.substring(0, 10) : raw;

  List<_ReplacedRow> get _paged {
    final start = (_page - 1) * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  double get _totalValue => _rows.fold(0, (sum, r) => sum + r.amount);

  int get _totalQty => _rows.fold(0, (sum, r) => sum + r.quantity);

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final json = await _api.get(
        'pos/sales',
        query: {'companyId': cid, 'salesType': 'replaced'},
      );
      if (!mounted) return;
      final sales = ApiClient.listData(json)
          .whereType<Map<String, dynamic>>()
          .map(SalesEntry.fromJson)
          .toList();
      setState(() {
        _rows = _flatRows(sales);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, e.message, error: true);
    }
  }

  void _clearFilters() {
    setState(() {
      _search.clear();
      _filter = '';
      _fromDate = '';
      _toDate = '';
      _page = 1;
    });
  }

  Future<void> _exportCsv() async {
    final rows = <List<String>>[
      const [
        'Sale ID',
        'Date',
        'Subscriber',
        'Product',
        'Quantity',
        'Unit Price',
        'Amount',
        'SN / MAC',
        'Model',
      ],
      for (final r in _filtered)
        [
          r.saleId,
          salesShortDate(r.date),
          r.subscriberName,
          r.productName,
          '${r.quantity}',
          salesFixed2(r.price),
          salesFixed2(r.amount),
          r.serialNumber,
          r.model,
        ],
    ];
    final ok = await salesWriteCsv(
      context,
      'replaced_products_${salesToday()}.csv',
      rows,
    );
    if (ok && mounted) {
      showToast(context, 'Exported ${_filtered.length} replaced product rows.');
    }
  }

  Future<void> _print() async {
    final rows = _filtered
        .map(
          (r) =>
              '''
        <tr>
          <td>${salesEscapeHtml(r.saleId)}</td>
          <td>${salesEscapeHtml(salesShortDate(r.date))}</td>
          <td>${salesEscapeHtml(r.subscriberName)}</td>
          <td>${salesEscapeHtml(r.productName)}</td>
          <td>${salesEscapeHtml(r.serialNumber.isEmpty ? '—' : r.serialNumber)}</td>
          <td>${salesEscapeHtml(r.model.isEmpty ? '—' : r.model)}</td>
          <td>${r.quantity}</td>
          <td class="r">PKR ${salesNumber(r.amount)}</td>
        </tr>''',
        )
        .join();
    final html =
        '''<!DOCTYPE html>
<html><head><meta charset="utf-8"/>
<title>Replaced Products</title>
<style>
  body{font-family:Arial,sans-serif;padding:24px;color:#111;}
  h1{font-size:20px;margin:0 0 4px;}
  .meta{color:#555;font-size:12px;margin-bottom:16px;}
  table{width:100%;border-collapse:collapse;font-size:12px;}
  th,td{border:1px solid #ddd;padding:6px 8px;text-align:left;}
  th{background:#f3e8ff;font-weight:600;}
  tr:nth-child(even){background:#fafafa;}
  td.r,th.r{text-align:right;}
  @media print{ .no-print{display:none;} }
</style></head><body>
  <h1>Replaced Products Report</h1>
  <div class="meta">Generated ${salesEscapeHtml(salesDateTime(DateTime.now().toIso8601String()))} &middot; ${_filtered.length} row(s)</div>
  <table>
    <thead><tr>
      <th>Sale ID</th><th>Date</th><th>Subscriber</th><th>Product</th>
      <th>SN / MAC</th><th>Model</th><th>Qty</th><th class="r">Amount</th>
    </tr></thead>
    <tbody>$rows</tbody>
  </table>
  <script>window.onload=function(){window.print();};</script>
</body></html>''';
    await salesOpenHtml(context, 'replaced_products_report.html', html);
  }

  @override
  Widget build(BuildContext context) {
    final cid = _cid;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.autorenew,
            title: 'Replaced Products',
            subtitle: 'Track products that were returned and replaced with a new item.',
            gradient: salesVioletGradient,
          ),
          if (cid == null || cid.isEmpty)
            const AppCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Please select a company to view replaced products.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            NetworkStatGrid(
              maxColumns: 3,
              children: [
                NetworkStatCard(
                  icon: Icons.swap_horiz,
                  label: 'Replaced Rows',
                  value: '${_rows.length}',
                  gradient: salesVioletGradient,
                ),
                NetworkStatCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Total Quantity',
                  value: '$_totalQty',
                  gradient: salesIndigoGradient,
                ),
                NetworkStatCard(
                  icon: Icons.payments_outlined,
                  label: 'Total Value',
                  value: 'PKR ${salesNumber(_totalValue)}',
                  gradient: salesEmeraldGradient,
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Replaced Sale Records',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.fg,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SalesFilterRows(
                          rows: [
                            [
                              SizedBox(
                                width: 260,
                                child: TextField(
                                  controller: _search,
                                  onChanged: (v) {
                                    setState(() {
                                      _filter = v;
                                      _page = 1;
                                    });
                                  },
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.fg,
                                  ),
                                  decoration:
                                      netInputDecoration(
                                        context,
                                        hint: 'Search product, customer, SN...',
                                      ).copyWith(
                                        prefixIcon: Icon(
                                          Icons.search,
                                          size: 18,
                                          color: context.mutedFg,
                                        ),
                                      ),
                                ),
                              ),
                              SizedBox(
                                width: 170,
                                child: _DateField(
                                  label: 'From',
                                  value: _fromDate,
                                  onChanged: (v) => setState(() {
                                    _fromDate = v;
                                    _page = 1;
                                  }),
                                ),
                              ),
                              SizedBox(
                                width: 170,
                                child: _DateField(
                                  label: 'To',
                                  value: _toDate,
                                  onChanged: (v) => setState(() {
                                    _toDate = v;
                                    _page = 1;
                                  }),
                                ),
                              ),
                            ],
                            [
                              if (_hasFilters)
                                OutlinedButton.icon(
                                  onPressed: _clearFilters,
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Clear'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 44),
                                  ),
                                ),
                              OutlinedButton.icon(
                                onPressed: _exportCsv,
                                icon: const Icon(
                                  Icons.grid_on,
                                  size: 16,
                                  color: Color(0xFF059669),
                                ),
                                label: const Text('Excel'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _print,
                                icon: const Icon(Icons.print_outlined, size: 16),
                                label: const Text('Print'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_filtered.length} replaced product '
                          '${_filtered.length == 1 ? 'row' : 'rows'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 4),
                  if (_loading && _rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: NetworkTable<_ReplacedRow>(
                        rows: _paged,
                        emptyIcon: Icons.autorenew,
                        emptyTitle: 'No replaced products',
                        emptyHint: 'Products exchanged during a sale replacement appear here.',
                        emptyTint: salesReplacedColor,
                        columns: [
                          NetColumn(
                            label: 'Date',
                            width: 110,
                            builder: (context, r, _) => Text(
                              salesShortDate(r.date),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.mutedFg,
                              ),
                            ),
                          ),
                          NetColumn(
                            label: 'Subscriber',
                            width: 160,
                            builder: (context, r, _) => Text(
                              r.subscriberName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          NetColumn(
                            label: 'Replacement Product',
                            width: 220,
                            builder: (context, r, _) => Text(
                              r.productName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          NetColumn(
                            label: 'SN / MAC',
                            width: 200,
                            builder: (context, r, _) => r.serialNumber.isEmpty
                                ? _dash(context)
                                : Text(
                                    r.serialNumber,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                          ),
                          NetColumn(
                            label: 'Model',
                            width: 140,
                            builder: (context, r, _) => r.model.isEmpty
                                ? _dash(context)
                                : Text(
                                    r.model,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.isDark
                                          ? const Color(0xFF7DD3FC)
                                          : const Color(0xFF0369A1),
                                    ),
                                  ),
                          ),
                          NetColumn(
                            label: 'Qty',
                            width: 70,
                            center: true,
                            builder: (context, r, _) => Text('${r.quantity}'),
                          ),
                          NetColumn(
                            label: 'Amount',
                            width: 130,
                            center: true,
                            builder: (context, r, _) => Text(
                              'PKR ${salesNumber(r.amount)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          NetColumn(
                            label: 'Status',
                            width: 110,
                            center: true,
                            builder: (context, r, _) => const _ReplacedBadge(),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  NetworkPagination(
                    currentPage: _page,
                    pageSize: _pageSize,
                    totalItems: _filtered.length,
                    noun: 'rows',
                    pageSizes: const [10, 20, 50, 100],
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
        ],
      ),
    );
  }

  Widget _dash(BuildContext context) =>
      Text('—', style: TextStyle(fontSize: 12, color: context.mutedFg));
}

class _ReplacedBadge extends StatelessWidget {
  const _ReplacedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: salesReplacedColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Replaced',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: context.isDark
              ? const Color(0xFFC4B5FD)
              : const Color(0xFF6D28D9),
        ),
      ),
    );
  }
}

/// Compact date field mirroring the sales list date filters.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final now = DateTime.now();
        final initial = DateTime.tryParse(value) ?? now;
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        if (picked == null) return;
        onChanged(
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}',
        );
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.surface,
          border: Border.all(color: context.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: context.mutedFg,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value.isEmpty ? '$label date' : value,
                style: TextStyle(
                  fontSize: 14,
                  color: value.isEmpty ? context.mutedFg : context.fg,
                ),
              ),
            ),
            if (value.isNotEmpty)
              GestureDetector(
                onTap: () => onChanged(''),
                child: Icon(Icons.close, size: 16, color: context.mutedFg),
              ),
          ],
        ),
      ),
    );
  }
}
