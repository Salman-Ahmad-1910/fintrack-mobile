import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'receipt_preview_screen.dart';
import 'sales_common.dart';
import 'sales_models.dart';

/// Flutter counterpart of `client/src/app/(app)/sales/page.tsx` — the POS
/// transaction history with server-side filters, stats, expandable SN rows,
/// receipt printing, returns, replacements and hold-bill payment.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

const String _kSalesPermission = '15315';
const String _kCanCreate = '15362';
const String _kCanUpdate = '15363';
const String _kCanDelete = '15364';
const List<String> _adminRoles = ['admin', 'owner', 'manager'];

const Color _kFiber = Color(0xFF0284C7);
const Color _kPromise = Color(0xFFC026D3);

class _SalesScreenState extends State<SalesScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<SalesEntry> _sales = [];
  SalesCompany _company = SalesCompany.empty;
  bool _loading = true;
  bool _addingToCollection = false;

  String _fromDate = '';
  String _toDate = '';
  String _salesType = 'all';
  String _paymentType = 'all';
  String _serviceType = 'all';
  String _fiberPaymentStatus = 'all';
  final TextEditingController _search = TextEditingController();
  String _debouncedSearch = '';
  Timer? _debounce;

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

  bool get _hasFilters =>
      _fromDate.isNotEmpty ||
      _toDate.isNotEmpty ||
      _salesType != 'all' ||
      _paymentType != 'all' ||
      _serviceType != 'all' ||
      _fiberPaymentStatus != 'all' ||
      _search.text.isNotEmpty;

  bool _hasPermission(String id) {
    final isAdmin = _adminRoles.contains(Session.role ?? '');
    if (isAdmin || !Session.permissionsConfigured) return true;
    return Session.permissions.contains(id);
  }

  bool _crud(String action) {
    if (_hasPermission('$_kSalesPermission:$action')) return true;
    final global = switch (action) {
      'create' => _kCanCreate,
      'update' => _kCanUpdate,
      _ => _kCanDelete,
    };
    return _hasPermission(global);
  }

  Map<String, String> get _params {
    final p = <String, String>{};
    if (_fromDate.isNotEmpty) p['fromDate'] = _fromDate;
    if (_toDate.isNotEmpty) p['toDate'] = _toDate;
    if (_salesType != 'all') p['salesType'] = _salesType;
    if (_paymentType != 'all') p['paymentType'] = _paymentType;
    if (_serviceType != 'all') p['serviceType'] = _serviceType;
    if (_fiberPaymentStatus != 'all') p['paymentStatus'] = _fiberPaymentStatus;
    if (_debouncedSearch.trim().isNotEmpty) {
      p['search'] = _debouncedSearch.trim();
    }
    return p;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _debouncedSearch = value;
        _page = 1;
      });
      _load();
    });
  }

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final params = _params;
      final results = await Future.wait([
        _api.get('pos/sales', query: params.isEmpty ? null : params),
        fetchSalesCompany(_api),
      ]);
      if (!mounted) return;
      setState(() {
        _sales = ApiClient.listData(results[0] as Map<String, dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(SalesEntry.fromJson)
            .toList();
        _company = results[1] as SalesCompany;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, e.message, error: true);
    }
  }

  void _resetFilters() {
    setState(() {
      _fromDate = '';
      _toDate = '';
      _salesType = 'all';
      _paymentType = 'all';
      _serviceType = 'all';
      _fiberPaymentStatus = 'all';
      _search.clear();
      _debouncedSearch = '';
      _page = 1;
    });
    _load();
  }

  List<SalesEntry> get _paged {
    if (_pageSize == 'all') return _sales;
    final size = int.tryParse(_pageSize) ?? 10;
    final start = (_page - 1) * size;
    if (start >= _sales.length) return const [];
    final end = (start + size).clamp(0, _sales.length);
    return _sales.sublist(start, end);
  }

  SaleReceiptData _receiptFor(
    SalesEntry sale, {
    SubscriberInstallment? installment,
  }) {
    return SaleReceiptData(
      id: sale.id,
      invoiceNumber: _sales.indexOf(sale) + 1,
      subscriberName: sale.subscriberName,
      totalAmount: sale.totalAmount,
      taxAmount: sale.taxAmount,
      discount: sale.discount,
      paymentMethod: sale.paymentMethod,
      date: sale.date,
      isInstallment: sale.isInstallment,
      items: sale.items,
      installmentInfo: installment == null
          ? null
          : ReceiptInstallmentInfo(
              planName: installment.planName,
              totalInstallments: installment.totalInstallments,
              paidInstallments: installment.paidInstallments,
              installmentAmount: installment.installmentAmount,
              totalAmount: installment.totalAmount,
              remainingInstallments: installment.remaining,
              status: installment.status,
            ),
    );
  }

  Future<SubscriberInstallment?> _fetchInstallment(SalesEntry sale) async {
    final cid = _cid;
    if (!sale.isInstallment || sale.subscriberId.isEmpty || cid == null) {
      return null;
    }
    try {
      final json = await _api.get(
        'pos/installment/${sale.subscriberId}',
        query: {'companyId': cid, 'saleId': sale.id},
      );
      final payload = json['raw'] is Map
          ? json['raw'] as Map
          : (json['data'] is Map ? json['data'] as Map : json);
      final inst = payload['installment'] is Map
          ? payload['installment'] as Map
          : payload;
      if (inst['id'] == null) return null;
      return SubscriberInstallment.fromJson(inst.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> _openReceipt(SalesEntry sale, String size) async {
    final inst = await _fetchInstallment(sale);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReceiptPreviewScreen(
          sale: _receiptFor(sale, installment: inst),
          company: _company,
          initialSize: size,
        ),
      ),
    );
  }

  Future<void> _payHold(SalesEntry sale) async {
    try {
      await _api.patch(
        'pos/sales/${sale.id}/status',
        body: {
          'status': 'completed',
          'paymentMethod': sale.paymentMethod == 'hold'
              ? 'cash'
              : sale.paymentMethod,
        },
      );
      if (mounted) {
        showToast(
          context,
          'Hold bill ${sale.id} has been paid. The sale is now permanent.',
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(SalesEntry sale) async {
    await showNetworkDeleteDialog(
      context,
      itemName: 'this sale',
      onConfirm: () async {
        try {
          await _api.delete('pos/sales/${sale.id}');
          if (mounted) showToast(context, 'Sale entry deleted.');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _return(SalesEntry sale) async {
    final cid = _cid;
    if (cid == null) return;
    final confirmed = await _confirmReturn(sale);
    if (confirmed != true) return;
    try {
      await _api.post('pos/sales/${sale.id}/return?companyId=$cid');
      if (mounted) {
        await _showFeedback(
          'Sale Returned',
          'The sale has been marked as returned and all items/SNs have been '
              'restored to stock.',
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) {
        await _showFeedback('Error', e.message, error: true);
      }
    }
  }

  Future<void> _addToCollection(SalesEntry sale) async {
    final cid = _cid;
    if (cid == null || sale.subscriberId.isEmpty) return;
    setState(() => _addingToCollection = true);
    try {
      await _api.post(
        'billing/payments?companyId=$cid',
        body: {
          'subscriberId': sale.subscriberId,
          'subscriberName': sale.customerLabel,
          'amount': sale.totalAmount,
          'paymentDate': sale.date.isEmpty
              ? DateTime.now().toIso8601String()
              : sale.date,
          'method': sale.paymentMethod.isEmpty ? 'cash' : sale.paymentMethod,
        },
      );
      if (mounted) {
        showToast(
          context,
          'PKR ${salesNumber(sale.totalAmount)} has been added to the '
          'subscriber collection.',
        );
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _addingToCollection = false);
    }
  }

  Future<bool?> _confirmReturn(SalesEntry sale) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF97316), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.rotate_left,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Return Sale'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Confirm the customer returned this sale. All items/SNs will be '
              'restored to stock and the sale will be marked as returned.',
              style: TextStyle(fontSize: 13, color: context.mutedFg),
            ),
            const SizedBox(height: 16),
            _kv(context, 'Customer', sale.customerLabel),
            _kv(context, 'Date', salesShortDate(sale.date)),
            _kv(
              context,
              'Items',
              sale.items
                  .map((i) => '${i.productName} x${i.quantity}')
                  .join(', '),
            ),
            _kv(context, 'Total', 'PKR ${salesNumber(sale.totalAmount)}'),
          ],
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
              minimumSize: const Size(0, 40),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: context.mutedFg),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFeedback(
    String title,
    String message, {
    bool error = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        title: Text(
          title,
          style: TextStyle(color: error ? context.dangerText : null),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openReplace(SalesEntry sale) async {
    final replaced = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ReplaceSaleDialog(api: _api, companyId: _cid ?? '', sale: sale),
    );
    if (replaced == true) await _load();
  }

  Future<void> _openDetails(SalesEntry sale) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Transaction Details',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim, sec) => Align(
        alignment: Alignment.centerRight,
        child: _SaleDetailsPanel(
          sale: sale,
          addingToCollection: _addingToCollection,
          onPrint: () => _showPrintDialog(sale),
          onAddToCollection: () => _addToCollection(sale),
          fetchInstallment: () => _fetchInstallment(sale),
        ),
      ),
      transitionBuilder: (context, animation, _, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
    );
  }

  Future<void> _showPrintDialog(SalesEntry sale) async {
    final size = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        title: const Text('Print Receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose your paper size to print the sale receipt.',
              style: TextStyle(fontSize: 13, color: context.mutedFg),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () => Navigator.of(context).pop('a4'),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('A4 Size'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              onPressed: () => Navigator.of(context).pop('thermal'),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Thermal / 80mm'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (size != null) await _openReceipt(sale, size);
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _exportCsv() async {
    final rows = <List<String>>[
      const [
        'Sale ID',
        'Customer',
        'Date',
        'Amount',
        'Tax',
        'Payment',
        'Type',
        'Status',
      ],
      for (final s in _sales)
        [
          s.id,
          s.subscriberName,
          s.date,
          salesNumber(s.totalAmount),
          salesNumber(s.taxAmount),
          s.paymentMethod,
          s.isFiber ? 'Fiber Jointing' : 'POS',
          s.status,
        ],
    ];
    final ok = await salesWriteCsv(context, 'Sales-${salesToday()}.csv', rows);
    if (ok && mounted) showToast(context, 'Exported sales to CSV');
  }

  Future<void> _exportPdf() async {
    final rows = _paged
        .map(
          (s) =>
              '''
        <tr>
          <td>${salesEscapeHtml(s.id)}</td>
          <td>${salesEscapeHtml(s.customerLabel)}</td>
          <td>${salesEscapeHtml(salesShortDate(s.date))}</td>
          <td class="r">PKR ${salesNumber(s.totalAmount)}</td>
          <td class="r">PKR ${salesNumber(s.taxAmount)}</td>
          <td>${salesEscapeHtml(s.paymentMethod)}</td>
          <td>${salesEscapeHtml(s.isFiber ? 'Fiber Jointing' : 'POS')}</td>
          <td>${salesEscapeHtml(s.status)}</td>
        </tr>''',
        )
        .join();
    final html =
        '''<!DOCTYPE html>
<html><head><meta charset="utf-8"/>
<title>Sales Report</title>
<style>
  body{font-family:'Segoe UI',system-ui,sans-serif;color:#111827;padding:24px;}
  h1{font-size:22px;margin:0;}
  .sub{color:#6b7280;font-size:13px;margin:4px 0 18px;}
  table{width:100%;border-collapse:collapse;}
  th,td{border:1px solid #d1d5db;padding:8px;font-size:12px;text-align:left;}
  thead tr{background:#059669;color:#fff;}
  td.r,th.r{text-align:right;}
  @media print{ .no-print{display:none;} }
</style></head>
<body>
  <h1>${salesEscapeHtml(_company.name.isEmpty ? 'Sales Report' : _company.name)}</h1>
  <div class="sub">Sales Report &middot; As of ${salesEscapeHtml(salesShortDate(DateTime.now().toIso8601String()))}</div>
  <table>
    <thead><tr>
      <th>Sale ID</th><th>Customer</th><th>Date</th>
      <th class="r">Amount</th><th class="r">Tax</th>
      <th>Payment</th><th>Type</th><th>Status</th>
    </tr></thead>
    <tbody>$rows</tbody>
  </table>
</body></html>''';
    await salesOpenHtml(context, 'Sales-Report-${salesToday()}.html', html);
  }

  @override
  Widget build(BuildContext context) {
    final cid = _cid;
    final canUpdate = _crud('update');
    final canDelete = _crud('delete');
    final totalRevenue = _sales.fold<double>(0, (s, e) => s + e.totalAmount);
    final transactions = _sales.length;
    final avg = transactions > 0 ? (totalRevenue / transactions).round() : 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.shopping_cart_outlined,
            title: 'Sales',
            subtitle: 'View and manage all point-of-sale transactions.',
            gradient: salesEmeraldGradient,
          ),
          if (cid == null || cid.isEmpty)
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: const Text(
                  'Please select a company to view sales.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            NetworkStatGrid(
              maxColumns: 3,
              children: [
                NetworkStatCard(
                  icon: Icons.trending_up,
                  label: 'Total Revenue',
                  value: 'PKR ${salesNumber(totalRevenue)}',
                  gradient: salesEmeraldGradient,
                ),
                NetworkStatCard(
                  icon: Icons.receipt_outlined,
                  label: 'Transactions',
                  value: '$transactions',
                  gradient: salesBlueGradient,
                ),
                NetworkStatCard(
                  icon: Icons.attach_money,
                  label: 'Avg Per Transaction',
                  value: 'PKR ${salesNumber(avg)}',
                  gradient: salesAmberGradient,
                  valueColor: salesHoldColor,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading && _sales.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else
              _historyCard(context, canUpdate: canUpdate, canDelete: canDelete),
          ],
        ],
      ),
    );
  }

  Widget _historyCard(
    BuildContext context, {
    required bool canUpdate,
    required bool canDelete,
  }) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Transaction History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.fg,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _filterBar(context),
          ),
          Divider(color: context.line, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _SalesTable(
              rows: _paged,
              allRows: _sales,
              canUpdate: canUpdate,
              canDelete: canDelete,
              onTap: _openDetails,
              onPay: _payHold,
              onDelete: _delete,
              onReturn: _return,
              onReplace: _openReplace,
              onPrint: _showPrintDialog,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: NetworkPagination(
              currentPage: _page,
              pageSize: _pageSize == 'all'
                  ? (_sales.isEmpty ? 10 : _sales.length)
                  : (int.tryParse(_pageSize) ?? 10),
              totalItems: _sales.length,
              noun: transactionsNoun(_sales.length),
              pageSizes: const [10, 50, 100],
              onPageChanged: (p) => setState(() => _page = p),
              onPageSizeChanged: (s) => setState(() {
                _pageSize = '$s';
                _page = 1;
              }),
            ),
          ),
        ],
      ),
    );
  }

  static String transactionsNoun(int n) => n == 1 ? 'sale' : 'sales';

  Widget _filterBar(BuildContext context) {
    // Two rows of filters; each row slides horizontally when it doesn't fit.
    final rowOne = <Widget>[
      SizedBox(
        width: 260,
        child: TextField(
          controller: _search,
          onChanged: _onSearchChanged,
          style: const TextStyle(fontSize: 14),
          decoration: netInputDecoration(
            context,
            hint: 'Search by sale ID or customer name...',
          ),
        ),
      ),
      SizedBox(
        width: 170,
        child: _DateFilterField(
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
        child: _DateFilterField(
          label: 'To',
          value: _toDate,
          onChanged: (v) => setState(() {
            _toDate = v;
            _page = 1;
          }),
        ),
      ),
      SizedBox(
        width: 180,
        child: _FilterSelect(
          value: _salesType,
          items: const {
            'all': 'All Sales',
            'good': 'Good Sales',
            'bad': 'Bad Sales',
            'replaced': 'Replaced',
          },
          onChanged: (v) => setState(() {
            _salesType = v;
            _page = 1;
          }),
        ),
      ),
    ];

    final rowTwo = <Widget>[
      SizedBox(
        width: 180,
        child: _FilterSelect(
          value: _paymentType,
          items: const {
            'all': 'All Payments',
            'normal': 'Normal',
            'installment': 'Installments',
            'promise': 'Promises',
            'hold': 'Hold',
          },
          onChanged: (v) => setState(() {
            _paymentType = v;
            _page = 1;
          }),
        ),
      ),
      SizedBox(
        width: 190,
        child: _FilterSelect(
          value: _serviceType,
          items: const {
            'all': 'All Service Types',
            'pos': 'POS / Product',
            'fiber_jointing': 'Fiber Jointing',
          },
          onChanged: (v) => setState(() {
            _serviceType = v;
            _page = 1;
          }),
        ),
      ),
      SizedBox(
        width: 190,
        child: _FilterSelect(
          value: _fiberPaymentStatus,
          items: const {
            'all': 'All Statuses',
            'paid': 'Paid',
            'partial': 'Partially Paid',
            'promise': 'Promise to Pay',
            'unpaid': 'Unpaid',
          },
          onChanged: (v) => setState(() {
            _fiberPaymentStatus = v;
            _page = 1;
          }),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _horizontalFilterRow(rowOne),
        const SizedBox(height: 12),
        _horizontalFilterRow(rowTwo),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text(
                'Showing ${_sales.length} ${transactionsNoun(_sales.length)}',
                style: TextStyle(fontSize: 12, color: context.mutedFg),
              ),
              const SizedBox(width: 12),
              _outlineButton(
                context,
                icon: Icons.grid_on,
                label: 'Excel',
                onPressed: _exportCsv,
              ),
              const SizedBox(width: 8),
              _outlineButton(
                context,
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF',
                onPressed: _exportPdf,
              ),
              if (_hasFilters) ...[
                const SizedBox(width: 8),
                _outlineButton(
                  context,
                  icon: Icons.filter_alt_off_outlined,
                  label: 'Clear Filters',
                  onPressed: _resetFilters,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _horizontalFilterRow(List<Widget> children) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _outlineButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

// -----------------------------------------------------------------------------
// Small filter controls
// -----------------------------------------------------------------------------

class _FilterSelect extends StatelessWidget {
  const _FilterSelect({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.surface,
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(10),
          items: [
            for (final e in items.entries)
              DropdownMenuItem(
                value: e.key,
                child: Text(e.value, style: const TextStyle(fontSize: 14)),
              ),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}

class _DateFilterField extends StatelessWidget {
  const _DateFilterField({
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

// -----------------------------------------------------------------------------
// Tag / badge
// -----------------------------------------------------------------------------

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color, {this.outline = false});

  final String label;
  final Color color;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : color.withValues(alpha: 0.14),
        border: Border.all(
          color: color.withValues(alpha: outline ? 0.6 : 0.35),
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

Widget _paymentBadges(BuildContext context, SalesEntry sale) {
  final badges = <Widget>[];
  if (sale.isFiber) badges.add(const _Tag('Fiber Jointing', _kFiber));
  if (sale.isFiber) {
    switch (sale.paymentStatus) {
      case 'paid':
        badges.add(_Tag('Paid', salesGoodSaleColor));
        break;
      case 'partial':
        badges.add(_Tag('Partially Paid', salesInstallmentColor));
        break;
      case 'promise':
        badges.add(_Tag('Promise to Pay', _kPromise));
        break;
      case 'unpaid':
        badges.add(const _Tag('Unpaid', Color(0xFFE11D48)));
        break;
    }
  }
  if (sale.isHold) {
    badges.add(_Tag('Hold', salesHoldColor));
  } else if (sale.isReturned) {
    badges.add(_Tag('Returned', salesReturnedColor));
  } else if (sale.isReplaced) {
    badges.add(_Tag('Replaced', salesReplacedColor));
  } else {
    badges.add(
      _Tag(
        sale.paymentMethod.isEmpty ? '-' : sale.paymentMethod,
        _grayTag(context),
      ),
    );
  }
  if (sale.isGoodSale) badges.add(_Tag('Good Sale', salesGoodSaleColor));
  if (sale.isInstallment) {
    badges.add(_Tag('Installment', salesInstallmentColor));
  }
  final promise = sale.promiseInfo;
  if (promise != null) {
    if (sale.isOpenPromise) {
      badges.add(
        _Tag('Pending PKR ${salesNumber(promise.remainingAmount)}', _kPromise),
      );
    } else {
      badges.add(
        _Tag(sale.promisePayment ? 'Paid' : 'Promise Paid', _grayTag(context)),
      );
    }
  }
  return Wrap(spacing: 4, runSpacing: 4, children: badges);
}

Color _grayTag(BuildContext context) =>
    context.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

// -----------------------------------------------------------------------------
// Sales table (custom: row tap + expandable SN rows + mobile cards)
// -----------------------------------------------------------------------------

class _SalesTable extends StatefulWidget {
  const _SalesTable({
    required this.rows,
    required this.allRows,
    required this.canUpdate,
    required this.canDelete,
    required this.onTap,
    required this.onPay,
    required this.onDelete,
    required this.onReturn,
    required this.onReplace,
    required this.onPrint,
  });

  final List<SalesEntry> rows;
  final List<SalesEntry> allRows;
  final bool canUpdate;
  final bool canDelete;
  final ValueChanged<SalesEntry> onTap;
  final ValueChanged<SalesEntry> onPay;
  final ValueChanged<SalesEntry> onDelete;
  final ValueChanged<SalesEntry> onReturn;
  final ValueChanged<SalesEntry> onReplace;
  final ValueChanged<SalesEntry> onPrint;

  @override
  State<_SalesTable> createState() => _SalesTableState();
}

class _SalesTableState extends State<_SalesTable> {
  final Set<String> _expanded = {};

  bool _canExpand(SalesEntry sale) => sale.items.any(
    (i) => parseSalesTokens(i.serialNumber, [RegExp(r'[\s,\-]+')]).length > 1,
  );

  List<_SerialRow> _serialRows(SalesEntry sale) {
    final out = <_SerialRow>[];
    for (final item in sale.items) {
      final sns = parseSalesTokens(item.serialNumber, [RegExp(r'[\s,\-]+')]);
      final models = parseSalesTokens(item.model, [RegExp(r'[\s,\n\r\t]+')]);
      for (var j = 0; j < sns.length; j++) {
        out.add(
          _SerialRow(
            productName: item.productName,
            serialNumber: sns[j],
            model: j < models.length ? models[j] : '',
            price: item.price,
          ),
        );
      }
    }
    return out;
  }

  void _toggle(SalesEntry sale) {
    setState(() {
      if (!_expanded.remove(sale.id)) _expanded.add(sale.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: salesEmeraldGradient.first.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 30,
                color: salesEmeraldGradient.first,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No sales found.',
              style: TextStyle(fontSize: 14, color: context.mutedFg),
            ),
            const SizedBox(height: 2),
            Text(
              'Try adjusting your filters or record a sale in Point of Sale.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: context.mutedFg.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1000) return _cards(context);
        return _table(context, constraints.maxWidth);
      },
    );
  }

  static const _cols = <(String, double)>[
    ('ID', 54),
    ('Date', 110),
    ('Customer', 150),
    ('Payment Method', 220),
    ('Items', 160),
    ('SN / MAC', 170),
    ('Model', 130),
    ('Total Amount', 140),
    ('Tax', 110),
    ('', 60),
  ];

  Widget _table(BuildContext context, double available) {
    const expandWidth = 34.0;
    final tableWidth = _cols.fold<double>(0, (s, c) => s + c.$2) + expandWidth;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth < available ? available : tableWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerRow(context, expandWidth),
              for (var i = 0; i < widget.rows.length; i++) ...[
                _dataRow(context, widget.rows[i], i, expandWidth),
                if (_expanded.contains(widget.rows[i].id))
                  Container(
                    width: double.infinity,
                    color: context.isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.black.withValues(alpha: 0.015),
                    padding: const EdgeInsets.fromLTRB(50, 10, 16, 14),
                    child: _SerialEntries(entries: _serialRows(widget.rows[i])),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerRow(BuildContext context, double expandWidth) {
    return Container(
      color: context.isDark
          ? AppColors.darkMuted.withValues(alpha: 0.6)
          : AppColors.muted.withValues(alpha: 0.6),
      child: Row(
        children: [
          SizedBox(width: expandWidth),
          for (final col in _cols)
            SizedBox(
              width: col.$2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  col.$1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.fg,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dataRow(
    BuildContext context,
    SalesEntry sale,
    int index,
    double expandWidth,
  ) {
    final expandable = _canExpand(sale);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.line)),
      ),
      child: InkWell(
        onTap: () => widget.onTap(sale),
        child: Row(
          children: [
            SizedBox(
              width: expandWidth,
              child: expandable
                  ? IconButton(
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      tooltip: 'Show items',
                      icon: Icon(
                        _expanded.contains(sale.id)
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: context.mutedFg,
                      ),
                      onPressed: () => _toggle(sale),
                    )
                  : null,
            ),
            _cell(
              context,
              54,
              Text(
                '${index + 1}',
                style: TextStyle(fontSize: 12, color: context.mutedFg),
              ),
            ),
            _cell(context, 110, Text(salesShortDate(sale.date))),
            _cell(
              context,
              150,
              Text(
                sale.customerLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            _cell(context, 220, _paymentBadges(context, sale)),
            _cell(
              context,
              160,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${sale.totalQty} item${sale.totalQty == 1 ? '' : 's'}'),
                  if (sale.items.isNotEmpty)
                    Text(
                      '${sale.items.take(2).map((i) => '${i.productName} x${i.quantity}').join(', ')}'
                      '${sale.items.length > 2 ? '...' : ''}',
                      style: TextStyle(fontSize: 11, color: context.mutedFg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            _cell(
              context,
              170,
              _tokenList(context, sale.uniqueSerials, mono: true),
            ),
            _cell(
              context,
              130,
              _tokenList(context, sale.uniqueModels, model: true),
            ),
            _cell(
              context,
              140,
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PKR ${salesNumber(sale.displayAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (sale.isInstallment && sale.increasePercent > 0)
                    Text(
                      '+${sale.increasePercent}% increase',
                      style: TextStyle(fontSize: 10, color: context.mutedFg),
                    ),
                ],
              ),
              alignRight: true,
            ),
            _cell(
              context,
              110,
              Text(
                'PKR ${salesNumber(sale.taxAmount)}',
                style: TextStyle(fontSize: 13, color: context.mutedFg),
              ),
              alignRight: true,
            ),
            SizedBox(
              width: 60,
              child: Align(
                alignment: Alignment.centerRight,
                child: _actions(sale),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    double width,
    Widget child, {
    bool alignRight = false,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }

  Widget _tokenList(
    BuildContext context,
    List<String> tokens, {
    bool mono = false,
    bool model = false,
  }) {
    if (tokens.isEmpty) {
      return Text('—', style: TextStyle(fontSize: 12, color: context.mutedFg));
    }
    final shown = tokens.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in shown.take(2))
          Text(
            t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontFamily: mono ? 'monospace' : null,
              color: model ? const Color(0xFF0369A1) : null,
            ),
          ),
        if (tokens.length > 2)
          Text(
            '+${tokens.length - 2} more (total ${tokens.length})',
            style: TextStyle(fontSize: 10, color: context.mutedFg),
          ),
      ],
    );
  }

  Widget _actions(SalesEntry sale) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (v) {
        switch (v) {
          case 'pay':
            widget.onPay(sale);
            break;
          case 'edit':
            widget.onTap(sale);
            break;
          case 'delete':
            widget.onDelete(sale);
            break;
          case 'return':
            widget.onReturn(sale);
            break;
          case 'replace':
            widget.onReplace(sale);
            break;
          case 'print':
            widget.onPrint(sale);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'print',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.print_outlined, size: 18),
            title: Text('Print'),
          ),
        ),
        if (sale.isHold)
          const PopupMenuItem(
            value: 'pay',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.badge_outlined,
                size: 18,
                color: salesGoodSaleColor,
              ),
              title: Text('Mark as Paid'),
            ),
          ),
        if (widget.canUpdate)
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined, size: 18),
              title: Text('Edit'),
            ),
          ),
        if (widget.canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.destructive,
              ),
              title: Text('Delete'),
            ),
          ),
        if (!sale.isHold &&
            !sale.isReturned &&
            !sale.isReplaced &&
            !sale.isInstallment)
          const PopupMenuItem(
            value: 'return',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.rotate_left,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              title: Text('Return'),
            ),
          ),
        if (!sale.isHold &&
            !sale.isReturned &&
            !sale.isReplaced &&
            !sale.isInstallment)
          const PopupMenuItem(
            value: 'replace',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.refresh, size: 18, color: salesReplacedColor),
              title: Text('Replace'),
            ),
          ),
      ],
      child: Icon(Icons.more_horiz, size: 18, color: context.mutedFg),
    );
  }

  Widget _cards(BuildContext context) {
    return Column(
      children: [
        for (final sale in widget.rows)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => widget.onTap(sale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              sale.customerLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            'PKR ${salesNumber(sale.displayAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _salesDateAndId(sale),
                        style: TextStyle(fontSize: 12, color: context.mutedFg),
                      ),
                      const SizedBox(height: 8),
                      _paymentBadges(context, sale),
                      const SizedBox(height: 8),
                      Text(
                        '${sale.totalQty} item${sale.totalQty == 1 ? '' : 's'}: '
                        '${sale.items.map((i) => '${i.productName} x${i.quantity}').join(', ')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_canExpand(sale)) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: () => _toggle(sale),
                    icon: Icon(
                      _expanded.contains(sale.id)
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                    ),
                    label: Text(
                      _expanded.contains(sale.id)
                          ? 'Hide items'
                          : 'View items (${sale.uniqueSerials.length} SNs)',
                    ),
                  ),
                  if (_expanded.contains(sale.id))
                    _SerialEntries(entries: _serialRows(sale)),
                ],
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: _actions(sale)),
              ],
            ),
          ),
      ],
    );
  }

  String _salesDateAndId(SalesEntry sale) {
    final date = salesShortDate(sale.date);
    return '$date · #${sale.id}';
  }
}

class _SerialRow {
  _SerialRow({
    required this.productName,
    required this.serialNumber,
    required this.model,
    required this.price,
  });

  final String productName;
  final String serialNumber;
  final String model;
  final double price;
}

class _SerialEntries extends StatelessWidget {
  const _SerialEntries({required this.entries});

  final List<_SerialRow> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: context.isDark
                ? AppColors.darkMuted.withValues(alpha: 0.5)
                : AppColors.muted.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: _th(context, 'Product')),
                Expanded(flex: 3, child: _th(context, 'SN / MAC')),
                Expanded(flex: 2, child: _th(context, 'Model')),
                Expanded(flex: 2, child: _th(context, 'Price', right: true)),
              ],
            ),
          ),
          for (final e in entries)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.line)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 3, child: _td(context, e.productName)),
                  Expanded(
                    flex: 3,
                    child: _td(
                      context,
                      e.serialNumber.isEmpty ? '—' : e.serialNumber,
                      mono: true,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _td(
                      context,
                      e.model.isEmpty ? '—' : e.model,
                      sky: true,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _td(
                      context,
                      'PKR ${salesNumber(e.price)}',
                      right: true,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _th(BuildContext context, String label, {bool right = false}) => Text(
    label,
    textAlign: right ? TextAlign.right : TextAlign.left,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: context.mutedFg,
    ),
  );

  Widget _td(
    BuildContext context,
    String value, {
    bool right = false,
    bool mono = false,
    bool sky = false,
  }) => Text(
    value,
    textAlign: right ? TextAlign.right : TextAlign.left,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 11,
      fontFamily: mono ? 'monospace' : null,
      color: sky ? const Color(0xFF0369A1) : null,
    ),
  );
}

// -----------------------------------------------------------------------------
// Transaction details side panel
// -----------------------------------------------------------------------------

class _SaleDetailsPanel extends StatefulWidget {
  const _SaleDetailsPanel({
    required this.sale,
    required this.addingToCollection,
    required this.onPrint,
    required this.onAddToCollection,
    required this.fetchInstallment,
  });

  final SalesEntry sale;
  final bool addingToCollection;
  final Future<void> Function() onPrint;
  final Future<void> Function() onAddToCollection;
  final Future<SubscriberInstallment?> Function() fetchInstallment;

  @override
  State<_SaleDetailsPanel> createState() => _SaleDetailsPanelState();
}

class _SaleDetailsPanelState extends State<_SaleDetailsPanel> {
  SubscriberInstallment? _installment;

  @override
  void initState() {
    super.initState();
    if (widget.sale.isInstallment) {
      widget.fetchInstallment().then((value) {
        if (mounted) setState(() => _installment = value);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final width = (MediaQuery.of(context).size.width * 0.92).clamp(
      320.0,
      460.0,
    );
    final subtotal = sale.totalAmount - sale.taxAmount;
    return Material(
      color: context.surface,
      child: SizedBox(
        width: width,
        height: MediaQuery.of(context).size.height,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Transaction Details',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Text(
                    '${sale.customerLabel} · ${salesShortDate(sale.date)}',
                    style: TextStyle(fontSize: 13, color: context.mutedFg),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Tag(
                        sale.paymentMethod.isEmpty ? '-' : sale.paymentMethod,
                        _grayTag(context),
                        outline: true,
                      ),
                      _Tag('#${sale.id}', _grayTag(context), outline: true),
                      if (sale.isHold) _Tag('Hold', salesHoldColor),
                      if (sale.isReturned) _Tag('Returned', salesReturnedColor),
                      if (sale.isReplaced) _Tag('Replaced', salesReplacedColor),
                      if (sale.isGoodSale)
                        _Tag('Good Sale', salesGoodSaleColor),
                      if (sale.isInstallment)
                        _Tag('Installment', salesInstallmentColor),
                      if (sale.isFiber) const _Tag('Fiber Jointing', _kFiber),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  for (var idx = 0; idx < sale.items.length; idx++)
                    _itemCard(context, sale.items[idx], idx),
                  if (sale.isInstallment && _installment != null) ...[
                    const SizedBox(height: 4),
                    _installmentCard(context, _installment!),
                  ],
                  const SizedBox(height: 4),
                  _summaryCard(context, sale, subtotal),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.line)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: widget.onPrint,
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed:
                        widget.addingToCollection || sale.subscriberId.isEmpty
                        ? null
                        : widget.onAddToCollection,
                    child: widget.addingToCollection
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Add to Collection'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(BuildContext context, SalesItem item, int idx) {
    final net = item.price * item.quantity;
    final sst = net * (item.taxPercent / 100);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: context.isDark
                ? AppColors.darkMuted.withValues(alpha: 0.5)
                : AppColors.muted.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SN / MAC',
                  style: TextStyle(fontSize: 11, color: context.mutedFg),
                ),
                Text(
                  item.serialNumber.isEmpty ? '—' : item.serialNumber,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _detailRow(
                  context,
                  'Model',
                  item.model.isEmpty ? '—' : item.model,
                  sky: true,
                ),
                _detailRow(
                  context,
                  'Product',
                  '${item.productName}${item.quantity != 1 ? ' ×${item.quantity}' : ''}',
                ),
                _detailRow(
                  context,
                  'Unit Price',
                  'PKR ${salesNumber(item.price)}',
                ),
                _detailRow(context, 'Amount', 'PKR ${salesNumber(net)}'),
                if (sst > 0)
                  _detailRow(
                    context,
                    'Tax (${item.taxPercent}%)',
                    'PKR ${salesNumber(sst)}',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _installmentCard(BuildContext context, SubscriberInstallment i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: salesInstallmentColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: salesInstallmentColor.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              'INSTALLMENT DETAILS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: salesInstallmentColor,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _detailRow(context, 'Plan', i.planName),
                _detailRow(
                  context,
                  'Total Amount (incl. increase)',
                  'PKR ${salesNumber(i.totalAmount)}',
                ),
                _detailRow(
                  context,
                  'Amount per Installment',
                  'PKR ${salesNumber(i.installmentAmount)}',
                  valueColor: salesInstallmentColor,
                ),
                const Divider(height: 18),
                _detailRow(
                  context,
                  'Total Installments',
                  '${i.totalInstallments}',
                ),
                _detailRow(
                  context,
                  'Paid',
                  '${i.paidInstallments} / ${i.totalInstallments}',
                  valueColor: salesGoodSaleColor,
                ),
                _detailRow(
                  context,
                  'Remaining',
                  '${i.remaining} / ${i.totalInstallments}',
                  valueColor: salesHoldColor,
                ),
                if (i.nextInstallment > 0)
                  _detailRow(
                    context,
                    'Next Installment #',
                    '${i.nextInstallment}',
                  ),
                const Divider(height: 18),
                _detailRow(
                  context,
                  'Paid Amount',
                  'PKR ${salesNumber(i.paidInstallments * i.installmentAmount)}',
                  valueColor: salesGoodSaleColor,
                ),
                _detailRow(
                  context,
                  'Remaining Amount',
                  'PKR ${salesNumber(i.remaining * i.installmentAmount)}',
                  valueColor: salesHoldColor,
                ),
                _detailRow(
                  context,
                  'Status',
                  i.isCompleted
                      ? 'Completed'
                      : (i.status.isEmpty ? '-' : i.status),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, SalesEntry sale, double subtotal) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: context.isDark
                ? AppColors.darkMuted.withValues(alpha: 0.5)
                : AppColors.muted.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              'ORDER SUMMARY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: context.mutedFg,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _detailRow(context, 'Items', '${sale.totalQty}'),
                _detailRow(context, 'Subtotal', 'PKR ${salesNumber(subtotal)}'),
                _detailRow(
                  context,
                  'Tax',
                  'PKR ${salesNumber(sale.taxAmount)}',
                ),
                if (sale.discount > 0)
                  _detailRow(
                    context,
                    'Discount',
                    '- PKR ${salesNumber(sale.discount)}',
                  ),
                const Divider(height: 18),
                _detailRow(
                  context,
                  'Total',
                  'PKR ${salesNumber(sale.totalAmount)}',
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    bool sky = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: context.mutedFg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? (sky ? const Color(0xFF0369A1) : null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Replace sale dialog
// -----------------------------------------------------------------------------

class _ReplaceLine {
  _ReplaceLine({
    required this.product,
    required this.quantity,
    required this.price,
    required this.selectedSns,
    required this.selectedModels,
  });

  final PosProduct product;
  int quantity;
  double price;
  final List<String> selectedSns;
  final List<String> selectedModels;
}

class _ReplaceSaleDialog extends StatefulWidget {
  const _ReplaceSaleDialog({
    required this.api,
    required this.companyId,
    required this.sale,
  });

  final ApiClient api;
  final String companyId;
  final SalesEntry sale;

  @override
  State<_ReplaceSaleDialog> createState() => _ReplaceSaleDialogState();
}

class _ReplaceSaleDialogState extends State<_ReplaceSaleDialog> {
  final TextEditingController _search = TextEditingController();
  List<PosProduct> _products = [];
  bool _loadingProducts = true;
  bool _submitting = false;

  final List<_ReplaceLine> _lines = [];
  String _paymentMethod = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final json = await widget.api.get(
        'inventory/purchased-products',
        query: {'companyId': widget.companyId},
      );
      if (!mounted) return;
      setState(() {
        _products = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(PosProduct.fromJson)
            .toList();
        _loadingProducts = false;
      });
    } on ApiException {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  List<PosProduct> get _filteredProducts {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _products.take(20).toList();
    return _products
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.id.toLowerCase().contains(q),
        )
        .take(20)
        .toList();
  }

  void _addProduct(PosProduct product) {
    _ReplaceLine? existing;
    for (final l in _lines) {
      if (l.product.id == product.id) {
        existing = l;
        break;
      }
    }
    if (product.stock <= 0) {
      showToast(
        context,
        '${product.name} is currently out of stock.',
        error: true,
      );
      return;
    }
    setState(() {
      if (existing == null) {
        _lines.add(
          _ReplaceLine(
            product: product,
            quantity: 1,
            price: product.price,
            selectedSns: [],
            selectedModels: [],
          ),
        );
      } else if (existing.quantity < product.stock) {
        existing.quantity++;
      } else {
        showToast(
          context,
          'You cannot add more of ${product.name}.',
          error: true,
        );
      }
      _search.clear();
    });
  }

  void _toggleSn(_ReplaceLine line, String sn) {
    setState(() {
      if (line.selectedSns.contains(sn)) {
        line.selectedSns.remove(sn);
      } else if (line.selectedSns.length < line.quantity) {
        line.selectedSns.add(sn);
      }
    });
  }

  void _toggleModel(_ReplaceLine line, String model) {
    setState(() {
      if (line.selectedModels.contains(model)) {
        line.selectedModels.remove(model);
      } else if (line.selectedModels.length < line.quantity) {
        line.selectedModels.add(model);
      }
    });
  }

  double get _subtotal => _lines.fold(0, (s, l) => s + l.price * l.quantity);
  double get _tax => _lines.fold(
    0,
    (s, l) => s + (l.price * l.quantity) * (l.product.taxPercent / 100),
  );

  bool _validateSns() {
    for (final l in _lines) {
      final sns = l.product.availableSerialNumbers;
      if (sns.isEmpty) continue;
      if (l.quantity != l.selectedSns.length) {
        showToast(
          context,
          'Please select ${l.quantity} of ${sns.length} serial number(s) for ${l.product.name}.',
          error: true,
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) {
      showToast(context, 'Add at least one replacement product.', error: true);
      return;
    }
    if (_paymentMethod.isEmpty) {
      showToast(context, 'Please select a payment method.', error: true);
      return;
    }
    if (!_validateSns()) return;

    setState(() => _submitting = true);
    try {
      final expanded = <Map<String, dynamic>>[];
      for (final l in _lines) {
        final sns = l.selectedSns.isNotEmpty
            ? l.selectedSns
            : l.product.availableSerialNumbers;
        final models = l.selectedModels;
        if (sns.isEmpty) {
          expanded.add({
            'productId': l.product.id,
            'productName': l.product.name,
            'quantity': l.quantity,
            'price': l.price,
            'originalPrice': l.product.price,
            'taxPercent': l.product.taxPercent,
            'serialNumber': '',
            'model': models.isNotEmpty ? models.first : '',
          });
        } else {
          for (var i = 0; i < sns.length; i++) {
            expanded.add({
              'productId': l.product.id,
              'productName': l.product.name,
              'quantity': 1,
              'price': l.price,
              'originalPrice': l.product.price,
              'taxPercent': l.product.taxPercent,
              'serialNumber': sns[i],
              'model': i < models.length ? models[i] : '',
            });
          }
        }
      }
      await widget.api.post(
        'pos/sales/${widget.sale.id}/replace?companyId=${widget.companyId}',
        body: {
          'subscriberId': widget.sale.subscriberId,
          'subscriberName': widget.sale.customerLabel,
          'totalAmount': _subtotal + _tax,
          'taxAmount': _tax,
          'discount': widget.sale.discount,
          'paymentMethod': _paymentMethod,
          'date': DateTime.now().toIso8601String(),
          'isInstallment': false,
          'status': 'replaced',
          'items': expanded,
        },
      );
      if (!mounted) return;
      showToast(context, 'Sale replaced successfully.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) {
        setState(() => _submitting = false);
        showToast(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: context.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: salesVioletGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.refresh,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Replace Sale',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.line),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Restore the original sale to stock and record a '
                    'replacement product for ${widget.sale.customerLabel}.',
                    style: TextStyle(fontSize: 13, color: context.mutedFg),
                  ),
                  const SizedBox(height: 14),
                  _originalSummary(context),
                  const SizedBox(height: 16),
                  _productSearch(context),
                  const SizedBox(height: 12),
                  for (final l in _lines) _lineCard(context, l),
                  if (_lines.isNotEmpty) _totals(context),
                ],
              ),
            ),
            Divider(height: 1, color: context.line),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: salesVioletGradient.last,
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: _submitting || _lines.isEmpty ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add, size: 18),
                    label: Text(
                      _submitting ? 'Replacing...' : 'Replace Product',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _originalSummary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.line),
      ),
      child: Column(
        children: [
          _row(context, 'Customer', widget.sale.customerLabel),
          _row(
            context,
            'Original Items (being returned)',
            widget.sale.items
                .map((i) => '${i.productName} x${i.quantity}')
                .join(', '),
          ),
          _row(
            context,
            'Original Total',
            'PKR ${salesNumber(widget.sale.totalAmount)}',
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: context.mutedFg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productSearch(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 15,
              color: salesVioletGradient.last,
            ),
            const SizedBox(width: 6),
            const Text(
              'Replacement Product',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14),
          decoration:
              netInputDecoration(
                context,
                hint: 'Search products by name...',
              ).copyWith(
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: context.mutedFg,
                ),
              ),
        ),
        if (_loadingProducts)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_search.text.trim().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              border: Border.all(color: context.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _filteredProducts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: Center(
                      child: Text(
                        'No products found',
                        style: TextStyle(fontSize: 13, color: context.mutedFg),
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in _filteredProducts)
                        InkWell(
                          onTap: () => _addProduct(p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'PKR ${salesNumber(p.price)} · Stock ${p.stock}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: context.mutedFg,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _Tag(
                                  '${p.availableSerialNumbers.length} SNs',
                                  salesVioletGradient.last,
                                  outline: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _lineCard(BuildContext context, _ReplaceLine line) {
    final sns = line.product.availableSerialNumbers;
    final models = line.product.availableModels;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.product.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'PKR ${salesNumber(line.product.price)} · Stock ${line.product.stock}',
                      style: TextStyle(fontSize: 11, color: context.mutedFg),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: context.dangerText,
                ),
                onPressed: () => setState(() => _lines.remove(line)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: '${line.quantity}',
                  decoration: netInputDecoration(context, hint: 'Qty'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final q = int.tryParse(v) ?? 1;
                    setState(() {
                      line.quantity = q.clamp(1, line.product.stock);
                      if (line.selectedSns.length > line.quantity) {
                        line.selectedSns.removeRange(
                          line.quantity,
                          line.selectedSns.length,
                        );
                      }
                      if (line.selectedModels.length > line.quantity) {
                        line.selectedModels.removeRange(
                          line.quantity,
                          line.selectedModels.length,
                        );
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: '${line.price}',
                  decoration: netInputDecoration(context, hint: 'Unit Price'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) => setState(() {
                    line.price = (double.tryParse(v) ?? 0).clamp(
                      0,
                      double.infinity,
                    );
                  }),
                ),
              ),
            ],
          ),
          if (sns.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'SN / MAC (${line.selectedSns.length}/${line.quantity})',
              style: TextStyle(fontSize: 11, color: context.mutedFg),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final sn in sns.take(24))
                  _chip(
                    context,
                    sn,
                    selected: line.selectedSns.contains(sn),
                    disabled:
                        !line.selectedSns.contains(sn) &&
                        line.selectedSns.length >= line.quantity,
                    mono: true,
                    color: salesVioletGradient.last,
                    onTap: () => _toggleSn(line, sn),
                  ),
              ],
            ),
          ] else if (models.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Model',
              style: TextStyle(fontSize: 11, color: context.mutedFg),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in models.take(12))
                  _chip(
                    context,
                    m,
                    selected: line.selectedModels.contains(m),
                    disabled: false,
                    color: const Color(0xFF0284C7),
                    onTap: () => _toggleModel(line, m),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label, {
    required bool selected,
    required bool disabled,
    required Color color,
    required VoidCallback onTap,
    bool mono = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : context.surface,
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.6) : context.line,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontFamily: mono ? 'monospace' : null,
              color: selected ? color : context.mutedFg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _totals(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _paymentMethod.isEmpty ? null : _paymentMethod,
              isExpanded: true,
              decoration: netInputDecoration(context, hint: 'Payment method'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
                DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
              ],
              onChanged: (v) => setState(() => _paymentMethod = v ?? ''),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row(context, 'Subtotal', 'PKR ${salesNumber(_subtotal)}'),
                _row(context, 'Tax', 'PKR ${salesNumber(_tax)}'),
                const Divider(height: 14),
                _row(
                  context,
                  'Replacement Total',
                  'PKR ${salesNumber(_subtotal + _tax)}',
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
