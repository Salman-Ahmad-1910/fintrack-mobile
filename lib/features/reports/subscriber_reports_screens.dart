import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../inventory/inventory_common.dart';
import '../network/network_common.dart';
import '../sales/sales_common.dart';
import '../shared/crud_kit.dart';
import '../transaction/transaction_common.dart';

String _pkr(num v) => 'PKR ${kitMoney(v)}';

String _phone(Map<String, dynamic> c) =>
    kitStr(c['cell']).isNotEmpty ? kitStr(c['cell']) : kitStr(c['mobile']);

String _pkg(Map<String, dynamic> c) {
  final i = kitStr(c['packageInternet']);
  return i.isNotEmpty ? i : kitStr(c['packageCable']);
}

/// Web `resolveAreaName`: `city, zone, locality` of the connection's area.
String _areaName(Map<String, Map<String, dynamic>> areas, String id) {
  final a = areas[id];
  if (a == null) return '';
  return [kitStr(a['city']), kitStr(a['zone']), kitStr(a['locality'])]
      .where((p) => p.isNotEmpty)
      .join(', ');
}

const Map<String, String> _kConnTypes = {
  'both': 'All Types',
  'internet': 'Internet',
  'tv_cable': 'TV Cable',
};

// ===========================================================================
// Pending Subscribers — server-side filtered/paged
// (`GET /collection/pending-subscribers`, collection/pending-subscribers)
// ===========================================================================

class PendingSubscribersScreen extends StatefulWidget {
  const PendingSubscribersScreen({super.key});

  @override
  State<PendingSubscribersScreen> createState() =>
      _PendingSubscribersScreenState();
}

class _PendingSubscribersScreenState extends State<PendingSubscribersScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: kitHandleUnauthorized);
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _meta = const {};
  bool _loading = true;
  String? _error;
  String _query = '';
  String _type = 'all';
  String _status = 'all';
  String _sortBy = 'createdAt';
  String _from = '';
  String _to = '';
  int _page = 1;
  int _pageSize = 10;
  int _requestId = 0;

  String get _cid => Session.companyId ?? '';

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

  Map<String, String> _params({int? page, String? pageSize}) => {
    'companyId': _cid,
    if (_query.isNotEmpty) 'search': _query,
    'status': _status,
    'type': _type,
    'sortBy': _sortBy,
    if (_from.isNotEmpty) 'dateFrom': _from,
    if (_to.isNotEmpty) 'dateTo': _to,
    'page': '${page ?? _page}',
    'pageSize': pageSize ?? '$_pageSize',
  };

  Future<void> _load() async {
    if (_cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final id = ++_requestId;
    setState(() => _loading = true);
    try {
      final json = await _api.get('/collection/pending-subscribers', query: _params());
      if (!mounted || id != _requestId) return; // stale response
      final subs = json['subscribers'];
      setState(() {
        _rows = subs is List
            ? subs.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
            : [];
        _meta = json;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _changed() {
    setState(() => _page = 1);
    _load();
  }

  Future<List<Map<String, dynamic>>> _all() async {
    final json = await _api.get(
      '/collection/pending-subscribers',
      query: _params(page: 1, pageSize: 'all'),
    );
    final subs = json['subscribers'];
    return subs is List
        ? subs.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : [];
  }

  List<List<String>> _table(List<Map<String, dynamic>> rows) => [
    ['#', 'Internet ID', 'Subscriber', 'Contact', 'Address', 'Package', 'Remaining'],
    for (var i = 0; i < rows.length; i++)
      [
        '${i + 1}',
        kitStr(rows[i]['internetId']),
        kitStr(rows[i]['name']),
        _phone(rows[i]),
        kitStr(rows[i]['address']),
        _pkg(rows[i]),
        kitMoney(kitNum(rows[i]['remainingAmount'])),
      ],
  ];

  Future<void> _export() async {
    try {
      final rows = await _all();
      if (!mounted) return;
      final ok = await salesWriteCsv(context, 'pending-subscribers-${kitToday()}.csv', _table(rows));
      if (ok && mounted) showToast(context, 'Exported ${rows.length} subscribers');
    } catch (e) {
      if (mounted) kitReportError(context, e, fallback: 'Could not load pending subscribers.');
    }
  }

  Future<void> _print() async {
    try {
      final rows = await _all();
      if (!mounted) return;
      await salesOpenHtml(
        context,
        'pending-subscribers.html',
        kitReportHtml('Pending Subscribers List', _table(rows)),
      );
    } catch (e) {
      if (mounted) kitReportError(context, e, fallback: 'Could not load pending subscribers.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = kitInt(_meta['totalCount']);
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.pending_actions_outlined,
            title: 'Pending Subscribers',
            subtitle: 'Subscribers with an outstanding balance.',
            gradient: kitAmber,
          ),
          if (_cid.isEmpty)
            const KitNoCompany(what: 'pending subscribers')
          else ...[
            NetworkStatGrid(
              maxColumns: 3,
              children: [
                kitStat('Total Pending', total, Icons.people_outline, kitAmber),
                kitStat('Pending Amount', _pkr(kitNum(_meta['totalPendingAmount'])), Icons.payments_outlined, kitRose),
                kitStat('Internet', kitInt(_meta['internetCount']), Icons.wifi, kitBlue),
                kitStat('TV Cable', kitInt(_meta['tvCableCount']), Icons.tv, kitViolet),
                kitStat('Both', kitInt(_meta['bothCount']), Icons.devices_other, kitEmerald),
              ],
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InvFilterBar(
                    filterWidth: 200,
                    filtersPerRow: 3,
                    filters: [
                      txSearchField(
                        context: context,
                        controller: _search,
                        hint: 'Name, ID, phone...',
                        onChanged: (v) {
                          _debounce?.cancel();
                          _debounce = Timer(const Duration(milliseconds: 400), () {
                            _query = v.trim();
                            _changed();
                          });
                        },
                      ),
                      TxSelect(
                        value: _type,
                        items: const {'all': 'All Types', 'internet': 'Internet', 'tv_cable': 'TV Cable', 'both': 'Both'},
                        onChanged: (v) {
                          _type = v;
                          _changed();
                        },
                      ),
                      TxSelect(
                        value: _status,
                        items: const {
                          'all': 'All Status',
                          'active': 'Active',
                          'inactive': 'Inactive',
                          'suspended': 'Suspended',
                          'deactivated': 'Deactivated',
                        },
                        onChanged: (v) {
                          _status = v;
                          _changed();
                        },
                      ),
                      TxSelect(
                        value: _sortBy,
                        items: const {
                          'createdAt': 'Newest first',
                          'name': 'Name',
                          'internetId': 'Internet ID',
                          'installationDate': 'Installation date',
                        },
                        onChanged: (v) {
                          _sortBy = v;
                          _changed();
                        },
                      ),
                      TxDateField(label: 'From', value: _from, width: 200, onChanged: (v) {
                        _from = v;
                        _changed();
                      }),
                      TxDateField(label: 'To', value: _to, width: 200, onChanged: (v) {
                        _to = v;
                        _changed();
                      }),
                    ],
                    actions: [
                      OutlinedButton.icon(onPressed: _print, icon: const Icon(Icons.print_outlined, size: 18), label: const Text('Print')),
                      OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download_outlined, size: 18), label: const Text('Export CSV')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const KitLoading()
                  else if (_error != null)
                    KitErrorCard(message: _error!, onRetry: _load)
                  else ...[
                    NetworkTable<Map<String, dynamic>>(
                      rows: _rows,
                      emptyIcon: Icons.check_circle_outline,
                      emptyTitle: 'No pending subscribers.',
                      emptyHint: '',
                      emptyTint: AppColors.emerald600,
                      columns: [
                        NetColumn(label: 'Internet ID', width: 110, builder: (c, r, _) => Text(kitStr(r['internetId']))),
                        NetColumn(label: 'Subscriber', width: 170, builder: (c, r, _) => Text(kitStr(r['name']), style: const TextStyle(fontWeight: FontWeight.w600))),
                        NetColumn(label: 'Contact', width: 120, builder: (c, r, _) => Text(_phone(r))),
                        NetColumn(label: 'Address', width: 180, builder: (c, r, _) => Text(kitStr(r['address']), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        NetColumn(label: 'Package', width: 130, builder: (c, r, _) => Text(_pkg(r))),
                        NetColumn(
                          label: 'Remaining',
                          width: 120,
                          builder: (c, r, _) => Text(
                            _pkr(kitNum(r['remainingAmount'])),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                          ),
                        ),
                      ],
                    ),
                    if (total > 0) ...[
                      const SizedBox(height: 12),
                      NetworkPagination(
                        currentPage: _page,
                        pageSize: _pageSize,
                        totalItems: total,
                        noun: 'subscribers',
                        onPageChanged: (p) {
                          setState(() => _page = p);
                          _load();
                        },
                        onPageSizeChanged: (s) {
                          setState(() {
                            _pageSize = s;
                            _page = 1;
                          });
                          _load();
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Simple printable HTML table used by the report screens.
String kitReportHtml(String title, List<List<String>> table, {String? subtitle}) {
  final head = table.first.map((h) => '<th>${salesEscapeHtml(h)}</th>').join();
  final body = table
      .skip(1)
      .map((r) => '<tr>${r.map((c) => '<td>${salesEscapeHtml(c)}</td>').join()}</tr>')
      .join();
  return '''<!doctype html><html><head><meta charset="utf-8"><title>${salesEscapeHtml(title)}</title>
<style>body{font-family:sans-serif;padding:24px;color:#111827}h1{font-size:22px;margin:0}
p{color:#6b7280}table{width:100%;border-collapse:collapse;font-size:12px;margin-top:16px}
th{background:#059669;color:#fff;text-align:left;padding:8px}td{border:1px solid #e5e7eb;padding:7px}</style></head><body>
<h1>${salesEscapeHtml(title)}</h1><p>${salesEscapeHtml(Session.companyName ?? '')} — ${salesEscapeHtml(subtitle ?? 'As of ${kitToday()}')}</p>
<table><thead><tr>$head</tr></thead><tbody>$body</tbody></table></body></html>''';
}

// ===========================================================================
// Connection-based reports (all derived from `GET /admin/connections`, exactly
// like the web pages, which filter the full connection list client-side)
// ===========================================================================

enum ConnectionReportKind {
  advance,
  deactivated,
  expiryDefaulters,
  newSubscribers,
  packageWise,
  creatorSummary,
}

class ConnectionReportScreen extends StatefulWidget {
  const ConnectionReportScreen({super.key, required this.kind});

  final ConnectionReportKind kind;

  @override
  State<ConnectionReportScreen> createState() => _ConnectionReportScreenState();
}

class _ReportColumn {
  const _ReportColumn(this.label, this.width, this.value, {this.bold = false});
  final String label;
  final double width;
  final String Function(Map<String, dynamic> row) value;
  final bool bold;
}

class _ConnectionReportScreenState extends State<ConnectionReportScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: kitHandleUnauthorized);
  final TextEditingController _search = TextEditingController();

  List<Map<String, dynamic>> _connections = [];
  Map<String, Map<String, dynamic>> _areas = {};
  List<Map<String, dynamic>> _packages = [];
  Map<String, Map<String, dynamic>> _users = {};
  bool _loading = true;
  String? _error;
  String? _busyId;

  String _filter = '';
  String _connType = 'both';
  String _status = 'all';
  String _badDebt = 'all';
  String _sublocality = 'all';
  late String _from = _monthStart();
  String _to = kitToday();
  int _page = 1;
  int _pageSize = 10;

  ConnectionReportKind get _kind => widget.kind;
  String get _cid => Session.companyId ?? '';

  static String _monthStart() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-01';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ConnectionReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      _page = 1;
      _filter = '';
      _search.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _needsAreas => const [
    ConnectionReportKind.expiryDefaulters,
    ConnectionReportKind.newSubscribers,
  ].contains(_kind);

  bool get _needsUsers => const [
    ConnectionReportKind.newSubscribers,
    ConnectionReportKind.creatorSummary,
  ].contains(_kind);

  Future<void> _load() async {
    if (_cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final q = {'companyId': _cid};
    try {
      final conns = kitMaps(await _api.get('/admin/connections', query: q));
      var areas = <String, Map<String, dynamic>>{};
      var packages = <Map<String, dynamic>>[];
      var users = <String, Map<String, dynamic>>{};
      if (_needsAreas) {
        try {
          areas = {
            for (final a in kitMaps(await _api.get('/network/areas', query: q)))
              kitStr(a['id']): a,
          };
        } catch (_) {}
      }
      if (_kind == ConnectionReportKind.packageWise) {
        packages = kitMaps(await _api.get('/billing/packages', query: q));
      }
      if (_needsUsers) {
        try {
          users = {
            for (final u in kitMaps(
              await _api.get('/admin/users', query: {...q, 'includeAdmin': 'true'}),
            ))
              kitStr(u['id']): u,
          };
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _connections = conns;
        _areas = areas;
        _packages = packages;
        _users = users;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool _inRange(String raw) {
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return false;
    final from = DateTime.tryParse(_from);
    final to = DateTime.tryParse(_to);
    if (from != null && d.isBefore(from)) return false;
    if (to != null && d.isAfter(to.add(const Duration(days: 1)))) return false;
    return true;
  }

  // ---- row building per report (mirrors each web page) ---------------------

  List<Map<String, dynamic>> get _rows {
    switch (_kind) {
      case ConnectionReportKind.advance:
        return _connections
            .where((c) => kitStr(c['paymentStatus']) == 'advance')
            .where((c) => _connType == 'both' || kitStr(c['connectionType']) == _connType)
            .where((c) => kitMatch(_filter, [kitStr(c['name']), kitStr(c['internetId']), _phone(c)]))
            .toList();
      case ConnectionReportKind.deactivated:
        return _connections
            .where((c) => kitStr(c['status']) == 'deactivated')
            .where((c) => _connType == 'both' || kitStr(c['connectionType']) == _connType)
            .where((c) => _badDebt == 'all' || (_badDebt == 'yes') == kitBool(c['badDebt']))
            .where((c) => kitMatch(_filter, [kitStr(c['internetId']), kitStr(c['cnic']), kitStr(c['name'])]))
            .toList();
      case ConnectionReportKind.expiryDefaulters:
        return _connections
            .where((c) => kitNum(c['remainingAmount']) > 0)
            .where((c) => _sublocality == 'all' || _areaName(_areas, kitStr(c['sublocalityId'])) == _sublocality)
            .where((c) => _inRange(kitStr(c['updatedAt']).isNotEmpty ? kitStr(c['updatedAt']) : kitStr(c['rechargeDate'])))
            .toList();
      case ConnectionReportKind.newSubscribers:
        return _connections.where((c) {
          final created = kitStr(c['createdAt']).isNotEmpty ? kitStr(c['createdAt']) : kitStr(c['installationDate']);
          if (!_inRange(created)) return false;
          if (_sublocality != 'all' && _areaName(_areas, kitStr(c['sublocalityId'])) != _sublocality) return false;
          final type = kitStr(c['connectionType']).isEmpty ? 'both' : kitStr(c['connectionType']);
          if (_connType != 'both' && type != _connType) return false;
          final status = kitStr(c['status']).isEmpty ? 'active' : kitStr(c['status']);
          if (_status != 'all' && status != _status) return false;
          return true;
        }).toList();
      case ConnectionReportKind.packageWise:
        return [
          for (final p in _packages)
            if (kitStr(p['name']).isNotEmpty)
              {
                'packageName': kitStr(p['name']),
                'amount': kitNum(p['salePrice']) > 0 ? kitNum(p['salePrice']) : kitNum(p['price']),
                'count': _connections.where((c) {
                  final name = kitStr(p['name']);
                  final inet = kitStr(c['packageInternet']) == name;
                  final cable = kitStr(c['packageCable']) == name;
                  final typeOk = _connType == 'both' ||
                      (_connType == 'internet' && inet) ||
                      (_connType == 'tv_cable' && cable);
                  return typeOk && (inet || cable);
                }).length,
              },
        ].where((r) => kitMatch(_filter, [kitStr(r['packageName'])])).toList();
      case ConnectionReportKind.creatorSummary:
        final counts = <String, int>{};
        for (final c in _connections) {
          final by = kitStr(c['createdBy']);
          if (by.isNotEmpty) counts[by] = (counts[by] ?? 0) + 1;
        }
        final rows = [
          for (final e in counts.entries)
            {
              'name': kitStr(_users[e.key]?['name']).isEmpty ? 'Unknown' : kitStr(_users[e.key]?['name']),
              'email': kitStr(_users[e.key]?['email']),
              'role': kitStr(_users[e.key]?['role']),
              'status': kitStr(_users[e.key]?['status']).isEmpty ? 'inactive' : kitStr(_users[e.key]?['status']),
              'total': e.value,
            },
        ].where((r) => kitMatch(_filter, [kitStr(r['name']), kitStr(r['email'])])).toList()
          ..sort((a, b) => kitInt(b['total']).compareTo(kitInt(a['total'])));
        return rows;
    }
  }

  List<_ReportColumn> get _columns {
    switch (_kind) {
      case ConnectionReportKind.advance:
        return [
          _ReportColumn('Internet ID', 110, (r) => kitStr(r['internetId'])),
          _ReportColumn('Subscriber', 170, (r) => kitStr(r['name']), bold: true),
          _ReportColumn('Contact', 120, _phone),
          _ReportColumn('Package', 130, _pkg),
          _ReportColumn('Advance', 110, (r) => kitMoney(kitNum(r['remainingAmount']).abs())),
          _ReportColumn('Status', 90, (r) => kitTitle(kitStr(r['status']))),
        ];
      case ConnectionReportKind.deactivated:
        return [
          _ReportColumn('Internet ID', 110, (r) => kitStr(r['internetId'])),
          _ReportColumn('Name', 160, (r) => kitStr(r['name']), bold: true),
          _ReportColumn('CNIC', 130, (r) => kitStr(r['cnic'])),
          _ReportColumn('Mobile', 120, (r) => kitStr(r['mobile']).isNotEmpty ? kitStr(r['mobile']) : kitStr(r['cell'])),
          _ReportColumn('Leaving Date', 110, (r) => kitDate(kitStr(r['leavingDate']).isNotEmpty ? kitStr(r['leavingDate']) : kitStr(r['updatedAt']))),
          _ReportColumn('Reason', 160, (r) => kitStr(r['deactivationReason'])),
          _ReportColumn('Type', 90, (r) => kitTitle(kitStr(r['connectionType']).isEmpty ? 'both' : kitStr(r['connectionType']))),
          _ReportColumn('Amount', 100, (r) => kitMoney(kitNum(r['remainingAmount']))),
          _ReportColumn('Bad Debt', 80, (r) => kitBool(r['badDebt']) ? 'Yes' : 'No'),
        ];
      case ConnectionReportKind.expiryDefaulters:
        return [
          _ReportColumn('Subscriber', 160, (r) => kitStr(r['name']), bold: true),
          _ReportColumn('Subscriber ID', 110, (r) => kitStr(r['internetId'])),
          _ReportColumn('Phone', 120, _phone),
          _ReportColumn('Sublocality', 170, (r) => _areaName(_areas, kitStr(r['sublocalityId']))),
          _ReportColumn('Recharge Date', 110, (r) => kitDate(kitStr(r['updatedAt']).isNotEmpty ? kitStr(r['updatedAt']) : kitStr(r['rechargeDate']))),
          _ReportColumn('Amount', 100, (r) => kitMoney(kitNum(r['remainingAmount']))),
          _ReportColumn('Status', 90, (r) => kitTitle(kitStr(r['status']))),
        ];
      case ConnectionReportKind.newSubscribers:
        return [
          _ReportColumn('Subscriber', 160, (r) => kitStr(r['name']), bold: true),
          _ReportColumn('Subscriber ID', 110, (r) => kitStr(r['internetId'])),
          _ReportColumn('Phone', 120, _phone),
          _ReportColumn('Sublocality', 170, (r) => _areaName(_areas, kitStr(r['sublocalityId']))),
          _ReportColumn('Type', 90, (r) => kitTitle(kitStr(r['connectionType']).isEmpty ? 'both' : kitStr(r['connectionType']))),
          _ReportColumn('Created', 100, (r) => kitDate(kitStr(r['createdAt']).isNotEmpty ? kitStr(r['createdAt']) : kitStr(r['installationDate']))),
          _ReportColumn('Created By', 130, (r) => kitStr(_users[kitStr(r['createdBy'])]?['name'])),
          _ReportColumn('Status', 90, (r) => kitTitle(kitStr(r['status']).isEmpty ? 'active' : kitStr(r['status']))),
        ];
      case ConnectionReportKind.packageWise:
        return [
          _ReportColumn('Package', 200, (r) => kitStr(r['packageName']), bold: true),
          _ReportColumn('Amount', 120, (r) => kitMoney(kitNum(r['amount']))),
          _ReportColumn('Subscribers', 110, (r) => '${kitInt(r['count'])}'),
        ];
      case ConnectionReportKind.creatorSummary:
        return [
          _ReportColumn('Creator', 170, (r) => kitStr(r['name']), bold: true),
          _ReportColumn('Email', 200, (r) => kitStr(r['email'])),
          _ReportColumn('Role', 110, (r) => kitTitle(kitStr(r['role']))),
          _ReportColumn('Status', 90, (r) => kitTitle(kitStr(r['status']))),
          _ReportColumn('Total Created', 110, (r) => '${kitInt(r['total'])}'),
        ];
    }
  }

  (String, String, IconData, List<Color>) get _header => switch (_kind) {
    ConnectionReportKind.advance => ('Advance Subscribers', 'Subscribers who paid more than the package fee', Icons.trending_up, kitEmerald),
    ConnectionReportKind.deactivated => ('Deactivate Users List', 'Subscribers whose connection was deactivated', Icons.person_off_outlined, kitRose),
    ConnectionReportKind.expiryDefaulters => ('Expiry Wise Defaulters', 'Subscribers with an unpaid balance by recharge date', Icons.event_busy_outlined, kitAmber),
    ConnectionReportKind.newSubscribers => ('New Subscribers List', 'Connections created in the selected period', Icons.person_add_alt_1_outlined, kitBlue),
    ConnectionReportKind.packageWise => ('Package Wise List', 'Subscriber count per package', Icons.inventory_2_outlined, kitViolet),
    ConnectionReportKind.creatorSummary => ('Subscribers Creator Summary', 'Who created how many subscribers', Icons.leaderboard_outlined, kitIndigo),
  };

  Future<void> _resetAdvance(Map<String, dynamic> c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset advance status?'),
        content: Text('Reset payment status for ${kitStr(c['name'])}? This will clear their advance status.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyId = kitStr(c['id']));
    try {
      // Same full-record PUT as the web page.
      await _api.put(
        '/admin/connections/${kitStr(c['id'])}',
        body: {...c, 'paymentStatus': '', 'remainingAmount': 0},
      );
      if (mounted) showToast(context, '${kitStr(c['name'])} advance status has been cleared.');
      await _load();
    } catch (e) {
      if (mounted) kitReportError(context, e, fallback: 'Failed to reset payment status.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  List<List<String>> _table(List<Map<String, dynamic>> rows) {
    final cols = _columns;
    return [
      ['#', for (final c in cols) c.label],
      for (var i = 0; i < rows.length; i++) ['${i + 1}', for (final c in cols) c.value(rows[i])],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, icon, gradient) = _header;
    final rows = _loading ? const <Map<String, dynamic>>[] : _rows;
    final cols = _columns;
    final usesDate = _kind == ConnectionReportKind.expiryDefaulters || _kind == ConnectionReportKind.newSubscribers;
    final usesSublocality = usesDate;
    final usesType = const [
      ConnectionReportKind.advance,
      ConnectionReportKind.deactivated,
      ConnectionReportKind.newSubscribers,
      ConnectionReportKind.packageWise,
    ].contains(_kind);
    final usesSearch = !usesDate;
    final sublocalities = {
      for (final c in _connections) _areaName(_areas, kitStr(c['sublocalityId'])),
    }.where((s) => s.isNotEmpty).toList()
      ..sort();
    final amountTotal = rows.fold<double>(0, (a, r) => a + kitNum(r['remainingAmount']).abs());

    final stats = <Widget>[
      kitStat('Total Records', rows.length, Icons.list_alt, gradient),
      if (_kind == ConnectionReportKind.packageWise)
        kitStat('Total Subscribers', rows.fold<int>(0, (a, r) => a + kitInt(r['count'])), Icons.people_outline, kitEmerald)
      else if (_kind == ConnectionReportKind.creatorSummary)
        kitStat('Total Created', rows.fold<int>(0, (a, r) => a + kitInt(r['total'])), Icons.people_outline, kitEmerald)
      else if (_kind != ConnectionReportKind.newSubscribers)
        kitStat('Total Amount', _pkr(amountTotal), Icons.payments_outlined, kitEmerald)
      else
        kitStat('Active', rows.where((r) => (kitStr(r['status']).isEmpty ? 'active' : kitStr(r['status'])) == 'active').length, Icons.check_circle_outline, kitEmerald),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          NetworkPageHeader(icon: icon, title: title, subtitle: subtitle, gradient: gradient),
          if (_cid.isEmpty)
            KitNoCompany(what: title.toLowerCase())
          else if (_loading)
            const KitLoading()
          else if (_error != null && _connections.isEmpty)
            KitErrorCard(message: _error!, onRetry: _load)
          else ...[
            NetworkStatGrid(children: stats),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InvFilterBar(
                    filterWidth: 200,
                    filtersPerRow: 3,
                    filters: [
                      if (usesSearch)
                        txSearchField(
                          context: context,
                          controller: _search,
                          hint: 'Search...',
                          onChanged: (v) => setState(() {
                            _filter = v;
                            _page = 1;
                          }),
                        ),
                      if (usesType)
                        TxSelect(
                          value: _connType,
                          items: _kConnTypes,
                          onChanged: (v) => setState(() {
                            _connType = v;
                            _page = 1;
                          }),
                        ),
                      if (_kind == ConnectionReportKind.deactivated)
                        TxSelect(
                          value: _badDebt,
                          items: const {'all': 'Bad debt: All', 'yes': 'Bad debt: Yes', 'no': 'Bad debt: No'},
                          onChanged: (v) => setState(() {
                            _badDebt = v;
                            _page = 1;
                          }),
                        ),
                      if (_kind == ConnectionReportKind.newSubscribers)
                        TxSelect(
                          value: _status,
                          items: const {'all': 'All Status', 'active': 'Active', 'inactive': 'Inactive', 'suspended': 'Suspended', 'deactivated': 'Deactivated'},
                          onChanged: (v) => setState(() {
                            _status = v;
                            _page = 1;
                          }),
                        ),
                      if (usesSublocality)
                        TxSelect(
                          value: _sublocality,
                          items: {'all': 'All Sublocalities', for (final s in sublocalities) s: s},
                          onChanged: (v) => setState(() {
                            _sublocality = v;
                            _page = 1;
                          }),
                        ),
                      if (usesDate) ...[
                        TxDateField(label: 'From', value: _from, width: 200, onChanged: (v) => setState(() {
                          _from = v;
                          _page = 1;
                        })),
                        TxDateField(label: 'To', value: _to, width: 200, onChanged: (v) => setState(() {
                          _to = v;
                          _page = 1;
                        })),
                      ],
                    ],
                    actions: [
                      if (rows.isNotEmpty) ...[
                        OutlinedButton.icon(
                          onPressed: () => salesOpenHtml(context, 'report.html', kitReportHtml(title, _table(rows))),
                          icon: const Icon(Icons.print_outlined, size: 18),
                          label: const Text('Print'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await salesWriteCsv(context, '${title.toLowerCase().replaceAll(' ', '-')}-${kitToday()}.csv', _table(rows));
                            if (ok && context.mounted) showToast(context, 'Report exported');
                          },
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Export CSV'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  NetworkTable<Map<String, dynamic>>(
                    rows: kitPage(rows, _page, _pageSize),
                    emptyIcon: icon,
                    emptyTitle: 'No records found for the selected criteria.',
                    emptyHint: '',
                    emptyTint: AppColors.emerald600,
                    mobileTrailing: _kind == ConnectionReportKind.advance ? (c, r, _) => _resetButton(r) : null,
                    columns: [
                      for (final col in cols)
                        NetColumn<Map<String, dynamic>>(
                          label: col.label,
                          width: col.width,
                          builder: (c, r, _) => Text(
                            col.value(r).isEmpty ? '—' : col.value(r),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: col.bold ? const TextStyle(fontWeight: FontWeight.w600) : null,
                          ),
                        ),
                      if (_kind == ConnectionReportKind.advance)
                        NetColumn<Map<String, dynamic>>(
                          label: '',
                          width: 90,
                          isActions: true,
                          builder: (c, r, _) => _resetButton(r),
                        ),
                    ],
                  ),
                  if (rows.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    NetworkPagination(
                      currentPage: _page,
                      pageSize: _pageSize,
                      totalItems: rows.length,
                      noun: 'records',
                      onPageChanged: (p) => setState(() => _page = p),
                      onPageSizeChanged: (s) => setState(() {
                        _pageSize = s;
                        _page = 1;
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resetButton(Map<String, dynamic> r) => TextButton(
    onPressed: _busyId == null ? () => _resetAdvance(r) : null,
    child: Text(_busyId == kitStr(r['id']) ? 'Resetting…' : 'Reset'),
  );
}
