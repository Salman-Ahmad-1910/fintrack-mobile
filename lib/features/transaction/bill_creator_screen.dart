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
import 'bill_print.dart';
import 'transaction_common.dart';
import 'transaction_models.dart';

const List<String> _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<Color> _kBillGradient = [Color(0xFFA855F7), Color(0xFF7C3AED)];
const List<Color> _kCreateGradient = [Color(0xFF10B981), Color(0xFF16A34A)];
const List<Color> _kDeleteGradient = [Color(0xFFEF4444), Color(0xFFDC2626)];

/// Flutter counterpart of
/// `client/src/app/(app)/transaction/bill-creator/page.tsx`.
class BillCreatorScreen extends StatefulWidget {
  const BillCreatorScreen({super.key});

  @override
  State<BillCreatorScreen> createState() => _BillCreatorScreenState();
}

class _BillCreatorScreenState extends State<BillCreatorScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<TxConnection> _connections = [];
  List<TxArea> _areas = [];
  SalesCompany _company = SalesCompany.empty;
  bool _loading = true;

  late String _filterMonth = _currentMonth;
  late String _filterYear = _currentYear;
  String _filterBillType = 'all';
  String _filterSublocality = 'all';

  int _page = 1;
  int _pageSize = 10;

  bool _isCreating = false;
  bool _isDeleting = false;

  static String get _currentMonth => _kMonths[DateTime.now().month - 1];
  static String get _currentYear => '${DateTime.now().year}';

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

  bool get _canCreate => txHasPermission(kTxCanCreate);
  bool get _canDelete => txHasPermission(kTxCanDelete);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cid = Session.companyId;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait<Object>([
        _api.get('/admin/connections', query: {'companyId': cid}),
        _api.get('/network/areas', query: {'companyId': cid}),
        fetchSalesCompany(_api),
      ]);
      if (!mounted) return;
      setState(() {
        _connections = ApiClient.listData(results[0] as Map<String, dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(TxConnection.fromJson)
            .toList();
        _areas = ApiClient.listData(results[1] as Map<String, dynamic>)
            .whereType<Map<String, dynamic>>()
            .map(TxArea.fromJson)
            .toList();
        _company = results[2] as SalesCompany;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<String> get _availableYears {
    final years = <String>{_currentYear};
    for (final c in _connections) {
      final d = c.rechargeDate;
      if (d != null) years.add('${d.year}');
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  String _sublocalityName(String id) {
    for (final a in _areas) {
      if (a.id == id) {
        if (a.subLocality.isNotEmpty) return a.subLocality;
        if (a.locality.isNotEmpty) return a.locality;
        return 'Unknown';
      }
    }
    return 'Unknown';
  }

  List<BillRow> get _billRows {
    final groups = <String, _BillGroup>{};
    final isDefaultView = _filterSublocality == 'all' && _filterBillType == 'all';
    final selectedMonth = _selectedMonth;
    final selectedYear = _selectedYear;

    for (final c in _connections) {
      if (_filterSublocality != 'all' &&
          c.sublocalityId != _filterSublocality) {
        continue;
      }

      final typeLabel = c.connectionType == 'tv_cable'
          ? 'Cable'
          : (c.connectionType == 'internet' ? 'Internet' : 'Both');

      if (_filterBillType != 'all') {
        const typeMap = {
          'internet': 'Internet',
          'tv_cable': 'Cable',
          'both': 'Both',
        };
        if (typeLabel != typeMap[_filterBillType]) continue;
      }

      String groupKey;
      if (isDefaultView) {
        groupKey = typeLabel;
      } else if (_filterSublocality == 'all') {
        groupKey = '${selectedMonth}_${selectedYear}_$typeLabel';
      } else {
        groupKey =
            '${selectedMonth}_${selectedYear}_${typeLabel}_${c.sublocalityId.isEmpty ? 'all' : c.sublocalityId}';
      }

      final group = groups.putIfAbsent(
        groupKey,
        () => _BillGroup(
          connectionType: typeLabel,
          sublocality: isDefaultView ? 'All' : _sublocalityName(c.sublocalityId),
        ),
      );

      if (c.connectionType == 'tv_cable') {
        group.amount += c.amount;
      } else if (c.connectionType == 'internet') {
        group.amount += c.sameAmount;
      } else {
        group.amount += c.amount + c.sameAmount;
      }
      group.subscribers += 1;
      group.connections.add(c);
    }

    var idx = 0;
    return groups.entries.map((entry) {
      idx += 1;
      final g = entry.value;
      return BillRow(
        id: 'BC-${idx.toString().padLeft(4, '0')}',
        month: selectedMonth,
        year: selectedYear,
        amount: g.amount,
        subscribers: g.subscribers,
        connectionType: g.connectionType,
        sublocality: g.sublocality,
        connections: g.connections,
      );
    }).toList();
  }

  String get _selectedMonth =>
      _filterMonth == 'all' ? _currentMonth : _filterMonth;
  String get _selectedYear =>
      _filterYear == 'all' ? _currentYear : _filterYear;

  Future<bool?> _confirm(String message) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.surface,
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );

  List<Map<String, dynamic>> _grouped(List<BillRow> rows) => [
    for (final r in rows)
      {
        'connectionIds': [for (final c in r.connections) c.id],
        'connectionType': r.connectionType,
        'amount': r.amount,
        'subscribers': r.subscribers,
        'sublocality': r.sublocality,
      },
  ];

  Map<String, dynamic> _filterBody(List<BillRow> rows) => {
    'groupedBills': _grouped(rows),
    if (_filterMonth != 'all') 'month': _filterMonth,
    if (_filterYear != 'all') 'year': _filterYear,
    if (_filterBillType != 'all') 'billType': _filterBillType,
    if (_filterSublocality != 'all') 'sublocalityId': _filterSublocality,
  };

  Future<void> _create() async {
    final rows = _billRows;
    if (rows.isEmpty) {
      showToast(context, 'No subscribers match the current filters.',
          error: true);
      return;
    }
    final totalSubs = rows.fold<int>(0, (s, r) => s + r.subscribers);
    final ok = await _confirm(
      'Create ${rows.length} bill entry(ies) for $totalSubs subscriber(s)?',
    );
    if (ok != true || !mounted) return;

    final cid = Session.companyId;
    setState(() => _isCreating = true);
    try {
      await _api.post(
        '/billing/bills/create?companyId=$cid',
        body: _filterBody(rows),
      );
      if (!mounted) return;
      showToast(
        context,
        '${rows.length} bill entry(ies) created for $totalSubs subscriber(s).',
      );
      _openPrint(rows);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _delete() async {
    final rows = _billRows;
    if (rows.isEmpty) {
      showToast(context, 'No subscribers match the current filters.',
          error: true);
      return;
    }
    final ok = await _confirm('Delete ${rows.length} bill entry(ies)?');
    if (ok != true || !mounted) return;

    final cid = Session.companyId;
    setState(() => _isDeleting = true);
    try {
      await _api.post(
        '/billing/bills/delete?companyId=$cid',
        body: _filterBody(rows),
      );
      if (!mounted) return;
      showToast(context, '${rows.length} bill entry(ies) deleted.');
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _openPrint(List<BillRow> rows) {
    final monthLabel = _filterMonth != 'all' ? _filterMonth : 'All';
    final yearLabel = _filterYear != 'all' ? _filterYear : '';
    final billTypeLabel =
        _filterBillType != 'all' ? _capInit(_filterBillType) : 'All';
    String? subLabel;
    if (_filterSublocality != 'all') {
      subLabel = _sublocalityName(_filterSublocality);
      if (subLabel == 'Unknown') subLabel = _filterSublocality;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BillPrintPreviewScreen(
          rows: rows,
          company: _company,
          monthLabel: monthLabel,
          yearLabel: yearLabel,
          billTypeLabel: billTypeLabel,
          sublocalityLabel: subLabel,
        ),
      ),
    );
  }

  static String _capInit(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final rows = _billRows;
    final totalSubs = rows.fold<int>(0, (s, r) => s + r.subscribers);
    final totalPages =
        rows.isEmpty ? 0 : ((rows.length + _pageSize - 1) ~/ _pageSize);
    final safePage = totalPages == 0 ? 1 : (_page > totalPages ? totalPages : _page);
    final paginated = rows
        .skip((safePage - 1) * _pageSize)
        .take(_pageSize)
        .toList();

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final createdBy = _company.name.isEmpty ? 'Unknown' : _company.name;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.request_quote_outlined,
            title: 'Bill Creator',
            subtitle: 'Create and manage bills for subscribers.',
            gradient: _kBillGradient,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SalesFilterRows(
                    rows: [
                      [
                        TxSelect(
                          width: 150,
                          value: _filterMonth,
                          items: {
                            'all': 'All Months',
                            for (final m in _kMonths) m: m,
                          },
                          onChanged: (v) => setState(() {
                            _filterMonth = v;
                            _page = 1;
                          }),
                        ),
                        TxSelect(
                          width: 120,
                          value: _filterYear,
                          items: {
                            'all': 'All Years',
                            for (final y in _availableYears) y: y,
                          },
                          onChanged: (v) => setState(() {
                            _filterYear = v;
                            _page = 1;
                          }),
                        ),
                        TxSelect(
                          width: 140,
                          value: _filterBillType,
                          items: const {
                            'all': 'All',
                            'both': 'Both',
                            'internet': 'Internet',
                            'tv_cable': 'Cable',
                          },
                          onChanged: (v) => setState(() {
                            _filterBillType = v;
                            _page = 1;
                          }),
                        ),
                        TxSelect(
                          width: 170,
                          value: _filterSublocality,
                          items: {
                            'all': 'All Sublocality',
                            for (final a in _areas)
                              a.id: (_sublocalityLabel(a)),
                          },
                          onChanged: (v) => setState(() {
                            _filterSublocality = v;
                            _page = 1;
                          }),
                        ),
                      ],
                      [
                        Text(
                          '${rows.length} entry(ies) | $totalSubs subscriber(s)',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.mutedFg,
                          ),
                        ),
                        if (_canCreate)
                          GradientButton(
                            label: 'Create',
                            icon: Icons.add_circle_outline,
                            gradient: _kCreateGradient,
                            loading: _isCreating,
                            onPressed:
                                rows.isEmpty ? null : _create,
                          ),
                        if (_canDelete)
                          GradientButton(
                            label: 'Delete',
                            icon: Icons.delete_outline,
                            gradient: _kDeleteGradient,
                            loading: _isDeleting,
                            onPressed: rows.isEmpty ? null : _delete,
                          ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  NetworkTable<BillRow>(
                    rows: paginated,
                    emptyIcon: Icons.request_quote_outlined,
                    emptyTitle: 'No bill entries found.',
                    emptyHint: 'No subscribers match the current filters.',
                    emptyTint: AppColors.emerald600,
                    columns: [
                      NetColumn(
                        label: 'ID',
                        width: 84,
                        builder: (context, row, _) => Text(
                          row.id,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Month',
                        width: 110,
                        builder: (context, row, _) => Text(
                          row.month,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Year',
                        width: 80,
                        builder: (context, row, _) => Text(
                          row.year,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      NetColumn(
                        label: 'Amount',
                        width: 140,
                        builder: (context, row, _) => Text(
                          salesNumber(row.amount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Subscribers',
                        width: 110,
                        center: true,
                        builder: (context, row, _) => Text(
                          '${row.subscribers}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Connection Type',
                        width: 150,
                        center: true,
                        builder: (context, row, _) => _typeBadge(row.connectionType),
                      ),
                      NetColumn(
                        label: 'Sublocality',
                        width: 160,
                        builder: (context, row, _) => Text(
                          row.sublocality,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      NetColumn(
                        label: 'Status',
                        width: 100,
                        builder: (context, row, _) => Text(
                          'Created',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Date',
                        width: 110,
                        builder: (context, row, _) => Text(
                          today,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Created/Deleted by',
                        width: 160,
                        builder: (context, row, _) => Text(
                          createdBy,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  NetworkPagination(
                    currentPage: safePage,
                    pageSize: _pageSize,
                    totalItems: rows.length,
                    noun: 'entries',
                    pageSizes: const [10, 50, 100],
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
}

Widget _typeBadge(String type) {
  switch (type) {
    case 'Internet':
      return const TxBadge(
        label: 'Internet',
        color: Color(0xFF1D4ED8),
        background: Color(0xFFDBEAFE),
      );
    case 'Cable':
      return const TxBadge(
        label: 'Cable',
        color: Color(0xFFC2410C),
        background: Color(0xFFFFEDD5),
      );
    case 'Both':
      return const TxBadge(
        label: 'Both',
        color: Color(0xFF7E22CE),
        background: Color(0xFFF3E8FF),
      );
    default:
      return TxBadge(
        label: type,
        color: const Color(0xFF374151),
        background: const Color(0xFFF3F4F6),
      );
  }
}

String _sublocalityLabel(TxArea a) {
  if (a.subLocality.isNotEmpty) return a.subLocality;
  if (a.locality.isNotEmpty) return a.locality;
  return a.id.length > 8 ? a.id.substring(0, 8) : a.id;
}

class _BillGroup {
  _BillGroup({required this.connectionType, required this.sublocality});

  final String connectionType;
  final String sublocality;
  double amount = 0;
  int subscribers = 0;
  final List<TxConnection> connections = [];
}
