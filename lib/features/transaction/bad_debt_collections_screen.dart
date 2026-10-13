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
import 'transaction_common.dart';
import 'transaction_models.dart';

const List<Color> _kRose = [Color(0xFFBE123C), Color(0xFFDC2626)];
const List<Color> _kOrange = [Color(0xFFC2410C), Color(0xFFEA580C)];
const List<Color> _kRed = [Color(0xFFB91C1C), Color(0xFFEF4444)];
const List<Color> _kViolet = [Color(0xFF6D28D9), Color(0xFF9333EA)];
const List<Color> _kGreen = [Color(0xFF059669), Color(0xFF16A34A)];

int _daysSince(DateTime? dt) {
  if (dt == null) return 0;
  final now = DateTime.now();
  final day = DateTime(dt.year, dt.month, dt.day);
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(day).inDays;
}

String _monthYear(DateTime dt) => DateFormat('MMM yyyy').format(dt);
String _shortDate(DateTime dt) => DateFormat('M/d/yyyy').format(dt);

/// Flutter counterpart of
/// `client/src/app/(app)/transaction/bad-debt-collections/page.tsx`.
class BadDebtCollectionsScreen extends StatefulWidget {
  const BadDebtCollectionsScreen({super.key});

  @override
  State<BadDebtCollectionsScreen> createState() =>
      _BadDebtCollectionsScreenState();
}

class _BadDebtCollectionsScreenState extends State<BadDebtCollectionsScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<TxConnection> _connections = [];
  List<TxDealer> _dealers = [];
  List<TxArea> _areas = [];
  List<TxRecoveryOfficer> _officers = [];
  List<TxPayment> _payments = [];
  List<TxDealerCollection> _dealerCollections = [];

  bool _loading = true;
  bool _loadingPayments = false;

  String _tab = 'subscribers';

  // Subscriber selection
  String _subscriberSearch = '';
  String? _selectedSubscriberId;

  // Dealer selection
  String? _selectedDealerId;

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

  TxConnection? get _selectedSubscriber => _connections
      .where((c) => c.id == _selectedSubscriberId)
      .firstOrNull;

  TxDealer? get _selectedDealer =>
      _dealers.where((d) => d.id == _selectedDealerId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _api.get('/admin/connections', query: {'companyId': cid}),
        _api.get('/dealers', query: {'companyId': cid}),
        _api.get('/network/areas', query: {'companyId': cid}),
        _api.get('/admin/recovery-officers', query: {'companyId': cid}),
      ]);
      if (!mounted) return;
      setState(() {
        _connections = ApiClient.listData(results[0])
            .whereType<Map<String, dynamic>>()
            .map(TxConnection.fromJson)
            .toList();
        _dealers = ApiClient.listData(results[1])
            .whereType<Map<String, dynamic>>()
            .map(TxDealer.fromJson)
            .toList();
        _areas = ApiClient.listData(results[2])
            .whereType<Map<String, dynamic>>()
            .map(TxArea.fromJson)
            .toList();
        _officers = ApiClient.listData(results[3])
            .whereType<Map<String, dynamic>>()
            .map(TxRecoveryOfficer.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadPayments() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    setState(() => _loadingPayments = true);
    try {
      final json = await _api.get('/billing/payments', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _payments = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(TxPayment.fromJson)
            .toList();
        _loadingPayments = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loadingPayments = false);
    }
  }

  Future<void> _loadDealerCollections() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      final json = await _api.get('/dealers/collections', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _dealerCollections = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(TxDealerCollection.fromJson)
            .toList();
      });
    } on ApiException catch (_) {
      // silently ignore: history is an enrichment
    }
  }

  DateTime? _lastActiveDate(TxConnection c) =>
      c.lastPaymentDate ?? c.rechargeDate ?? c.createdAt;

  List<TxConnection> get _overdueConnections => _connections
      .where((c) => c.remainingAmount > 0 && _daysSince(_lastActiveDate(c)) > 30)
      .toList();

  List<TxDealer> get _overdueDealers =>
      _dealers.where((d) => d.walletBalance > 0).toList();

  List<TxConnection> get _filteredSubscribers {
    final q = _subscriberSearch.trim();
    if (q.isEmpty) return const [];
    return salesSmartSearch<TxConnection>(
      q,
      _overdueConnections,
      (c) => [
        [c.internetId, c.id, c.cell, c.mobile],
        [c.name],
      ],
    );
  }

  List<TxPayment> get _subscriberPayments => _payments
      .where((p) => p.subscriberId == _selectedSubscriberId)
      .toList();

  List<TxDealerCollection> get _dealerPayments => _dealerCollections
      .where((c) => c.dealerId == _selectedDealerId)
      .toList();

  String get _subscriberOfficerName {
    final s = _selectedSubscriber;
    if (s == null) return Session.userName ?? '---';
    if (s.sublocalityId.isNotEmpty) {
      final area = _areas.where((a) => a.id == s.sublocalityId).firstOrNull;
      if (area != null) {
        if (area.recoveryOfficerId != null) {
          final o = _officers
              .where((o) => o.id == area.recoveryOfficerId)
              .firstOrNull;
          if (o != null) return o.name;
        }
        final o = _officers.where((o) => o.areaId == area.id).firstOrNull;
        if (o != null) return o.name;
      }
    }
    return Session.userName ?? '---';
  }

  String get _dealerOfficerName {
    final d = _selectedDealer;
    if (d == null) return Session.userName ?? '---';
    if (d.areaId != null) {
      final area = _areas.where((a) => a.id == d.areaId).firstOrNull;
      if (area != null && area.recoveryOfficerId != null) {
        final o = _officers
            .where((o) => o.id == area.recoveryOfficerId)
            .firstOrNull;
        if (o != null) return o.name;
      }
    }
    return Session.userName ?? '---';
  }

  bool get _canCreate => txCrud(kBadDebtCollectionsPermission, 'create');

  void _selectSubscriber(TxConnection c) {
    setState(() {
      _selectedSubscriberId = c.id;
      _subscriberSearch = '';
    });
    _loadPayments();
  }

  void _clearSubscriber() {
    setState(() {
      _selectedSubscriberId = null;
      _payments = [];
    });
  }

  void _selectDealer(String? id) {
    setState(() {
      _selectedDealerId = id;
      _dealerCollections = [];
    });
    if (id != null) _loadDealerCollections();
  }

  Future<void> _receivePayment(double amount) async {
    final s = _selectedSubscriber;
    if (s == null) return;
    try {
      await _api.post('/billing/payments', body: {
        'subscriberId': s.id,
        'subscriberName': s.name,
        'amount': amount,
        'paymentDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'method': 'cash',
      });
      if (!mounted) return;
      showToast(context, 'Payment recorded.');
      await _loadPayments();
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _receiveDealerPayment(double amount) async {
    final d = _selectedDealer;
    if (d == null) return;
    try {
      await _api.post('/dealers/collections', body: {
        'dealerId': d.id,
        'dealerName': d.name,
        'dealerAddress': d.address,
        'amount': amount,
        'collectionDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'settlementStatus': 'settled',
        'transactionType': 'cash',
      });
      if (!mounted) return;
      showToast(context, 'Dealer payment recorded.');
      await _loadDealerCollections();
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.report_problem_outlined,
            title: 'Bad Debt Collections',
            subtitle: 'Collect overdue payments from subscribers and dealers.',
            gradient: _kRose,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _statCards(context),
                const SizedBox(height: 20),
                _tabBar(context),
                const SizedBox(height: 16),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _tab == 'subscribers'
                        ? _subscribersTab(context)
                        : _dealersTab(context),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statCards(BuildContext context) {
    return NetworkStatGrid(
      maxColumns: 4,
      children: [
        NetworkStatCard(
          icon: Icons.warning_amber_outlined,
          label: 'Overdue Subscribers',
          value: '${_overdueConnections.length}',
          gradient: _kRose,
        ),
        NetworkStatCard(
          icon: Icons.people_outline,
          label: 'Overdue Dealers',
          value: '${_overdueDealers.length}',
          gradient: _kOrange,
        ),
        NetworkStatCard(
          icon: Icons.attach_money_outlined,
          label: 'Total Connections',
          value: '${_connections.length}',
          gradient: _kRed,
        ),
        NetworkStatCard(
          icon: Icons.storefront_outlined,
          label: 'Total Dealers',
          value: '${_dealers.length}',
          gradient: _kViolet,
        ),
      ],
    );
  }

  Widget _tabBar(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.subtle,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final (value, label) in [('subscribers', 'Subscribers'), ('dealers', 'Dealers')])
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = value),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == value ? context.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: _tab == value
                        ? const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _tab == value ? context.fg : context.mutedFg,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Subscribers

  Widget _subscribersTab(BuildContext context) {
    final s = _selectedSubscriber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SalesFilterRows(
          rows: [
            [
              SizedBox(
                width: 360,
                child: txSearchField(
                  context: context,
                  controller: TextEditingController(text: _subscriberSearch),
                  onChanged: (v) => setState(() {
                    _subscriberSearch = v;
                    if (_selectedSubscriberId != null) _clearSubscriber();
                  }),
                  hint: 'Type subscriber ID or name...',
                ),
              ),
            ],
            if (s != null) ...[
              [
                _receivingAs(context, _subscriberOfficerName),
                if (_canCreate)
                  GradientButton(
                    label: 'Receive Payment',
                    icon: Icons.add_circle_outline,
                    gradient: _kGreen,
                    onPressed: () => _openReceiveDialog(
                      title: 'Receive Payment',
                      idLabel: 'Subscriber ID',
                      idValue: s.shortId,
                      nameLabel: 'Subscriber Name',
                      nameValue: s.name,
                      officerName: _subscriberOfficerName,
                      onConfirm: _receivePayment,
                    ),
                  ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (_filteredSubscribers.isNotEmpty)
          _searchDropdown(context),
        const SizedBox(height: 12),
        if (s == null)
          _emptyBox(
            context,
            icon: Icons.person_search_outlined,
            title: 'No Subscriber Selected',
            subtitle: 'Search and select an overdue subscriber to receive payment.',
          )
        else ...[
          // Subscriber details
          _subscriberDetails(context, s),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                _receivingAs(context, _subscriberOfficerName),
                const Spacer(),
                if (_canCreate)
                  GradientButton(
                    label: 'Receive Payment',
                    icon: Icons.add_circle_outline,
                    gradient: _kGreen,
                    onPressed: () => _openReceiveDialog(
                      title: 'Receive Payment',
                      idLabel: 'Subscriber ID',
                      idValue: s.shortId,
                      nameLabel: 'Subscriber Name',
                      nameValue: s.name,
                      officerName: _subscriberOfficerName,
                      onConfirm: _receivePayment,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${s.name}'s Payment History",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (_loadingPayments)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_subscriberPayments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No payment history found.',
                        style: TextStyle(color: context.mutedFg),
                      ),
                    ),
                  )
                else
                  NetworkTable<TxPayment>(
                    rows: _subscriberPayments,
                    emptyIcon: Icons.receipt_long_outlined,
                    emptyTitle: 'No payment history found.',
                    emptyHint: '',
                    emptyTint: AppColors.emerald600,
                    columns: [
                      NetColumn(
                        label: '#',
                        width: 48,
                        builder: (context, p, index) => Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Bill #',
                        width: 56,
                        builder: (context, p, index) => Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Name',
                        width: 150,
                        builder: (context, p, _) => Text(
                          p.subscriberName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      NetColumn(
                        label: 'Month/Year',
                        width: 100,
                        builder: (context, p, _) => Text(
                          p.paymentDate == null ? '---' : _monthYear(p.paymentDate!),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      NetColumn(
                        label: 'Type',
                        width: 70,
                        builder: (context, p, _) => Text(
                          p.method.isEmpty ? 'cash' : p.method.toLowerCase(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      NetColumn(
                        label: 'Received',
                        width: 110,
                        builder: (context, p, _) => Text(
                          'PKR ${salesNumber(p.amount)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Pay Date',
                        width: 90,
                        builder: (context, p, _) => Text(
                          p.paymentDate == null ? '---' : _shortDate(p.paymentDate!),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      NetColumn(
                        label: 'Status',
                        width: 66,
                        center: true,
                        builder: (context, p, _) => TxBadge(
                          label: 'Paid',
                          color: const Color(0xFF16A34A),
                          background: const Color(0xFF16A34A).withValues(alpha: 0.12),
                        ),
                      ),
                      NetColumn(
                        label: 'Received By',
                        width: 120,
                        builder: (context, p, _) => Text(
                          _subscriberOfficerName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _subscriberDetails(BuildContext context, TxConnection c) {
    final remaining = c.remainingAmount;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000 ? 7 : 2;
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          final items = <(String, Widget)>[
            ('Subscriber ID', Text(c.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
            ('Name', Text(c.name)),
            (
              'Days Overdue',
              Text(
                '${_daysSince(_lastActiveDate(c))} days',
                style: TextStyle(color: context.dangerText, fontWeight: FontWeight.w500),
              ),
            ),
            (
              'Last Payment',
              Text(_lastActiveDate(c) == null ? '---' : _shortDate(_lastActiveDate(c)!)),
            ),
            ('Mobile', Text(c.primaryPhone.isEmpty ? '---' : c.primaryPhone)),
            ('Address', Text(c.address.isEmpty ? '---' : c.address, overflow: TextOverflow.ellipsis)),
            (
              'Remaining',
              Text(
                'PKR ${salesNumber(remaining)}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: remaining > 0 ? context.dangerText : const Color(0xFF16A34A),
                ),
              ),
            ),
          ];
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: _fieldCell(item.$1, item.$2),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchDropdown(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final c in _filteredSubscribers)
            InkWell(
              onTap: () => _selectSubscriber(c),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      c.displayInternetId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.mutedFg),
                      ),
                    ),
                    if (c.primaryPhone.isNotEmpty)
                      Text(
                        '• ${c.primaryPhone}',
                        style: TextStyle(fontSize: 12, color: context.mutedFg),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- Dealers

  Widget _dealersTab(BuildContext context) {
    final d = _selectedDealer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SalesFilterRows(
          rows: [
            [
              TxSearchableSelect(
                width: 360,
                label: 'Select Dealer',
                placeholder: 'Search overdue dealers...',
                searchPlaceholder: 'Type to search by name...',
                options: [
                  for (final dd in _overdueDealers)
                    TxPickOption(
                      id: dd.id,
                      name: dd.name,
                      secondary:
                          'Rs.${salesNumber(dd.walletBalance)} outstanding • '
                          '${dd.lastPaymentDate == null ? 'Never paid' : '${_daysSince(dd.lastPaymentDate)} days since payment'}',
                    ),
                ],
                value: _selectedDealerId,
                onChanged: _selectDealer,
              ),
            ],
            if (d != null) ...[
              [
                _receivingAs(context, _dealerOfficerName),
                if (_canCreate)
                  GradientButton(
                    label: 'Receive Payment',
                    icon: Icons.add_circle_outline,
                    gradient: _kGreen,
                    onPressed: () => _openReceiveDialog(
                      title: 'Receive Dealer Payment',
                      idLabel: 'Dealer ID',
                      idValue: d.shortId,
                      nameLabel: 'Dealer Name',
                      nameValue: d.name,
                      officerName: _dealerOfficerName,
                      onConfirm: _receiveDealerPayment,
                    ),
                  ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (d == null)
          _emptyBox(
            context,
            icon: Icons.storefront_outlined,
            title: 'No Dealer Selected',
            subtitle: 'Search and select an overdue dealer to receive payment.',
          )
        else ...[
          // Dealer details
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000 ? 6 : 2;
                final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
                final balance = d.walletBalance;
                final remaining = d.remainingAmount;
                final items = <(String, Widget)>[
                  ('Dealer ID', Text(d.shortId, style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
                  ('Name', Text(d.name)),
                  ('Phone', Text(d.phone.isEmpty ? '---' : d.phone)),
                  (
                    'Balance',
                    Text(
                      'PKR ${salesNumber(balance)}',
                      style: TextStyle(color: context.dangerText, fontWeight: FontWeight.w500),
                    ),
                  ),
                  (
                    'Remaining',
                    Text(
                      'PKR ${salesNumber(remaining)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: remaining > 0 ? context.dangerText : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                  (
                    'Last Payment',
                    Text(d.lastPaymentDate == null ? 'Never' : _shortDate(d.lastPaymentDate!)),
                  ),
                ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in items)
                      SizedBox(width: width, child: _fieldCell(item.$1, item.$2)),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                _receivingAs(context, _dealerOfficerName),
                const Spacer(),
                if (_canCreate)
                  GradientButton(
                    label: 'Receive Payment',
                    icon: Icons.add_circle_outline,
                    gradient: _kGreen,
                    onPressed: () => _openReceiveDialog(
                      title: 'Receive Dealer Payment',
                      idLabel: 'Dealer ID',
                      idValue: d.shortId,
                      nameLabel: 'Dealer Name',
                      nameValue: d.name,
                      officerName: _dealerOfficerName,
                      onConfirm: _receiveDealerPayment,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${d.name}'s Payment History",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (_dealerPayments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No payment history found.',
                        style: TextStyle(color: context.mutedFg),
                      ),
                    ),
                  )
                else
                  NetworkTable<TxDealerCollection>(
                    rows: _dealerPayments,
                    emptyIcon: Icons.storefront_outlined,
                    emptyTitle: 'No payment history found.',
                    emptyHint: '',
                    emptyTint: AppColors.emerald600,
                    columns: [
                      NetColumn(
                        label: '#',
                        width: 40,
                        builder: (context, c, index) => Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Bill #',
                        width: 56,
                        builder: (context, c, index) => Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Dealer',
                        width: 150,
                        builder: (context, c, _) => Text(
                          c.dealerName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      NetColumn(
                        label: 'Date',
                        width: 100,
                        builder: (context, c, _) => Text(
                          c.collectionDate == null ? '---' : _shortDate(c.collectionDate!),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      NetColumn(
                        label: 'Type',
                        width: 70,
                        builder: (context, c, _) => Text(
                          c.transactionType.isEmpty
                              ? 'cash'
                              : c.transactionType.toLowerCase(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      NetColumn(
                        label: 'Amount',
                        width: 110,
                        builder: (context, c, _) => Text(
                          'PKR ${salesNumber(c.amount)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Status',
                        width: 80,
                        center: true,
                        builder: (context, c, _) {
                          final settled = c.settlementStatus == 'settled';
                          return TxBadge(
                            label: settled ? 'Settled' : 'Pending',
                            color: settled
                                ? const Color(0xFF16A34A)
                                : context.mutedFg,
                            background: settled
                                ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                                : context.subtle,
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------- shared

  Widget _fieldCell(String label, Widget child) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.mutedFg,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _receivingAs(BuildContext context, String name) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_user_outlined, size: 16, color: context.mutedFg),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: 'Receiving as: ',
              style: TextStyle(fontSize: 13, color: context.mutedFg),
              children: [
                TextSpan(
                  text: name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.fg,
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _emptyBox(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 32, color: context.mutedFg),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: context.fg),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.mutedFg),
          ),
        ],
      ),
    );
  }

  Future<void> _openReceiveDialog({
    required String title,
    required String idLabel,
    required String idValue,
    required String nameLabel,
    required String nameValue,
    required String officerName,
    required Future<void> Function(double) onConfirm,
  }) async {
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _ReceiveAmountDialog(
        title: title,
        idLabel: idLabel,
        idValue: idValue,
        nameLabel: nameLabel,
        nameValue: nameValue,
        officerName: officerName,
      ),
    );
    if (result != null) await onConfirm(result);
  }
}

class _ReceiveAmountDialog extends StatefulWidget {
  const _ReceiveAmountDialog({
    required this.title,
    required this.idLabel,
    required this.idValue,
    required this.nameLabel,
    required this.nameValue,
    required this.officerName,
  });

  final String title;
  final String idLabel;
  final String idValue;
  final String nameLabel;
  final String nameValue;
  final String officerName;

  @override
  State<_ReceiveAmountDialog> createState() => _ReceiveAmountDialogState();
}

class _ReceiveAmountDialogState extends State<_ReceiveAmountDialog> {
  final TextEditingController _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text.trim()) ?? 0;
  bool get _valid => _value > 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: NetField(
                    label: widget.idLabel,
                    child: _readonly(widget.idValue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NetField(
                    label: widget.nameLabel,
                    child: _readonly(widget.nameValue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            NetField(
              label: 'Received By',
              child: _readonly(widget.officerName),
            ),
            const SizedBox(height: 14),
            NetField(
              label: 'Amount (PKR)',
              child: TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14),
                decoration: netInputDecoration(
                  context,
                  hint: 'Enter amount',
                ),
              ),
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: 'Receive',
              gradient: _kGreen,
              onPressed: _valid
                  ? () => Navigator.of(context).pop(_value)
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            foregroundColor: context.dangerText,
            side: BorderSide(color: context.dangerText.withValues(alpha: 0.3)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _readonly(String value) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: context.inputFill,
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}