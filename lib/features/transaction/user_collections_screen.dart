import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../models/models.dart' show DashboardData;
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import '../sales/sales_common.dart';
import 'transaction_common.dart';
import 'transaction_models.dart';
import 'transaction_receipt.dart';

const List<Color> _kBlue = [Color(0xFF3B82F6), Color(0xFF0891B2)];
const List<Color> _kAmber = [Color(0xFFF59E0B), Color(0xFFEA580C)];
const List<Color> _kOrange = [Color(0xFFF97316), Color(0xFFD97706)];
const List<Color> _kRose = [Color(0xFFF43F5E), Color(0xFFDB2777)];
const List<Color> _kEmerald = [Color(0xFF10B981), Color(0xFF059669)];
const List<Color> _kCyan = [Color(0xFF06B6D4), Color(0xFF0D9488)];

const Color _amberText = Color(0xFF92400E);
const Color _amberBg = Color(0xFFFEF3C7);
const Color _greenText = Color(0xFF166534);
const Color _greenBg = Color(0xFFDCFCE7);

int _monthsSince(DateTime? date) {
  if (date == null) return 0;
  final now = DateTime.now();
  return (now.year - date.year) * 12 + (now.month - date.month);
}

double _packagePrice(TxConnection c) {
  final cable = c.amount;
  final internet = c.sameAmount;
  if (c.connectionType == 'tv_cable') return cable;
  if (c.connectionType == 'internet') return internet;
  return cable + internet;
}

String _packageLabel(TxConnection c) {
  final parts = <String>[];
  if (c.packageCable.isNotEmpty) parts.add(c.packageCable);
  if (c.packageInternet.isNotEmpty) parts.add(c.packageInternet);
  return parts.isEmpty ? '---' : parts.join(' + ');
}

double _totalOwed(TxConnection c) {
  final remaining = c.remainingAmount;
  final activeDate = c.lastPaymentDate ?? c.rechargeDate ?? c.createdAt;
  final months = _monthsSince(activeDate);
  return remaining + _packagePrice(c) * (months < 0 ? 0 : months);
}

String _cap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Flutter counterpart of
/// `client/src/app/(app)/transaction/user-collections/page.tsx`.
class UserCollectionsScreen extends StatefulWidget {
  const UserCollectionsScreen({super.key});

  @override
  State<UserCollectionsScreen> createState() => _UserCollectionsScreenState();
}

class _UserCollectionsScreenState extends State<UserCollectionsScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<TxConnection> _connections = [];
  bool _loading = true;

  List<TxPayment> _payments = [];
  bool _loadingPayments = false;

  List<TxPromise> _promises = [];
  bool _loadingPromises = false;

  List<TxPosPromise> _posPromises = [];

  List<TxArea> _areas = [];
  List<TxRecoveryOfficer> _recoveryOfficers = [];
  List<TxTransactionType> _transactionTypes = [];
  DashboardData? _dash;
  SalesCompany _company = SalesCompany.empty;

  String? _selectedSubscriberId;
  final TextEditingController _search = TextEditingController();
  String _searchText = '';

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

  bool get _canCreate => txCrud(kUserCollectionsPermission, 'create');
  bool get _canUpdate => txCrud(kUserCollectionsPermission, 'update');
  bool get _canDelete => txCrud(kUserCollectionsPermission, 'delete');
  bool get _canViewSummary => txPage(kUserCollectionsPermission, 'summary');
  bool get _canViewSearch => txPage(kUserCollectionsPermission, 'search');

  TxConnection? get _selected =>
      _connections.where((c) => c.id == _selectedSubscriberId).firstOrNull;

  List<TxConnection> get _filteredSubscribers {
    final q = _searchText.trim();
    if (q.isEmpty) return [];
    return salesSmartSearch(q, _connections, (c) => [
      [c.internetId, c.id],
      [c.name],
      [c.cell, c.mobile],
    ]);
  }

  List<TxPayment> get _subscriberPayments => _selectedSubscriberId == null
      ? []
      : _payments
            .where((p) => p.subscriberId == _selectedSubscriberId)
            .toList();

  List<TxPromise> get _subscriberPromises => _selectedSubscriberId == null
      ? []
      : _promises
            .where(
              (p) =>
                  p.subscriberId == _selectedSubscriberId &&
                  p.status != 'completed',
            )
            .toList();

  List<TxPosPromise> get _subscriberPosPromises => _posPromises
      .where((p) => p.status == 'pending' || p.status == 'partial')
      .toList();

  double get _totalPosPending => _subscriberPosPromises.fold<double>(
    0,
    (sum, p) => sum + p.remainingAmount,
  );

  double get _totalAmount =>
      _payments.fold<double>(0, (sum, p) => sum + p.amount);

  String get _recoveryOfficerName {
    final sub = _selected;
    final userName = Session.userName ?? '';
    if (sub == null) return userName.isEmpty ? '---' : userName;
    TxRecoveryOfficer? officer;
    if (sub.sublocalityId.isNotEmpty) {
      final area =
          _areas.where((a) => a.id == sub.sublocalityId).firstOrNull;
      if (area != null) {
        if (area.recoveryOfficerId != null) {
          officer = _recoveryOfficers
              .where((o) => o.id == area.recoveryOfficerId)
              .firstOrNull;
        }
        officer ??=
            _recoveryOfficers.where((o) => o.areaId == area.id).firstOrNull;
      }
    }
    final name = officer?.name ?? '';
    if (name.isNotEmpty) return name;
    return userName.isEmpty ? '---' : userName;
  }

  String get _sublocalityName {
    final sub = _selected;
    if (sub == null || sub.sublocalityId.isEmpty) return '';
    final area = _areas.where((a) => a.id == sub.sublocalityId).firstOrNull;
    if (area == null) return '';
    return area.subLocality.isNotEmpty ? area.subLocality : area.locality;
  }

  double get _packageFee => _selected == null ? 0 : _packagePrice(_selected!);
  String get _packageLabelValue =>
      _selected == null ? '---' : _packageLabel(_selected!);

  double get _storedRemaining =>
      _selected == null ? 0 : _selected!.remainingAmount;
  double get _displayRemaining =>
      _storedRemaining < 0 ? 0 : _storedRemaining;
  double get _advanceAmount =>
      _storedRemaining < 0 ? _storedRemaining.abs() : 0;

  List<TxTransactionType> get _filteredTransactionTypes {
    final seen = <String>{};
    return _transactionTypes.where((t) {
      final name = t.paymentChannel.isNotEmpty ? t.paymentChannel : t.transaction;
      if (name.isEmpty || seen.contains(name)) return false;
      seen.add(name);
      return true;
    }).toList();
  }

  List<TxPickOption> get _mergedPaymentOptions {
    return [
      const TxPickOption(id: 'cash', name: 'Cash'),
      for (final t in _filteredTransactionTypes)
        TxPickOption(
          id: t.paymentChannel.isNotEmpty ? t.paymentChannel : t.transaction,
          name: t.paymentChannel.isNotEmpty ? t.paymentChannel : t.transaction,
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    await Future.wait([
      _loadConnections(),
      _loadCompany(),
      _loadAreas(),
      _loadRecoveryOfficers(),
      _loadTransactionTypes(),
      _loadDashboard(),
    ]);
  }

  Future<void> _loadConnections() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      final json = await _api.get('/admin/connections', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _connections = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(TxConnection.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadCompany() async {
    try {
      final company = await fetchSalesCompany(_api);
      if (!mounted) return;
      setState(() => _company = company);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
    }
  }

  Future<void> _loadAreas() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      final json = await _api.get('/network/areas', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _areas = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(TxArea.fromJson)
            .toList();
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
    }
  }

  Future<void> _loadRecoveryOfficers() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      final json =
          await _api.get('/admin/recovery-officers', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _recoveryOfficers = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(TxRecoveryOfficer.fromJson)
            .toList();
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
    }
  }

  Future<void> _loadTransactionTypes() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      final json =
          await _api.get('/billing/transaction-types', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _transactionTypes = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(TxTransactionType.fromJson)
            .toList();
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
    }
  }

  Future<void> _loadDashboard() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      final json = await _api.get('/dashboard', query: {'companyId': cid});
      final data = json['data'];
      if (!mounted || data is! Map<String, dynamic>) return;
      setState(() => _dash = DashboardData.fromJson(data));
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
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

  Future<void> _loadPromises() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    setState(() => _loadingPromises = true);
    try {
      final json = await _api.get('/billing/promises', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _promises = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(TxPromise.fromJson)
            .toList();
        _loadingPromises = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loadingPromises = false);
    }
  }

  Future<void> _loadPosPromises(String subscriberId) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      final json = await _api.get(
        '/pos/promises',
        query: {
          'subscriberId': subscriberId,
          'status': 'open',
          'companyId': cid,
        },
      );
      if (!mounted) return;
      setState(() {
        _posPromises = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(TxPosPromise.fromJson)
            .toList();
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
    }
  }

  void _selectSubscriber(String? id) {
    setState(() {
      _selectedSubscriberId = id;
      _search.clear();
      _searchText = '';
      _payments = [];
      _promises = [];
      _posPromises = [];
    });
    if (id != null) {
      _loadPayments();
      _loadPromises();
      _loadPosPromises(id);
    }
  }

  Future<void> _handleReceive() async {
    final sub = _selected;
    if (sub == null) return;
    final result = await showDialog<_ReceiveResult>(
      context: context,
      builder: (_) => _ReceiveDialog(
        subscriber: sub,
        packageFee: _packageFee,
        displayRemaining: _displayRemaining,
        recoveryOfficerName: _recoveryOfficerName,
        paymentOptions: _mergedPaymentOptions,
        initialAmount: _displayRemaining,
        fulfillingPromise: false,
      ),
    );
    if (result == null) return;
    await _submitPayment(sub, result, promiseId: null);
  }

  Future<void> _receivePromise(TxPromise promise) async {
    final sub = _selected;
    if (sub == null) return;
    final result = await showDialog<_ReceiveResult>(
      context: context,
      builder: (_) => _ReceiveDialog(
        subscriber: sub,
        packageFee: _packageFee,
        displayRemaining: _displayRemaining,
        recoveryOfficerName: _recoveryOfficerName,
        paymentOptions: _mergedPaymentOptions,
        initialAmount: promise.amount,
        fulfillingPromise: true,
      ),
    );
    if (result == null) return;
    await _submitPayment(sub, result, promiseId: promise.id);
  }

  Future<void> _submitPayment(
    TxConnection sub,
    _ReceiveResult result, {
    required String? promiseId,
  }) async {
    final method = result.method.toLowerCase();
    if (method != 'cash' && result.transactionId.trim().isEmpty) {
      showToast(context, 'Transaction ID is required for this payment type.',
          error: true);
      return;
    }
    try {
      await _api.post('/billing/payments', body: {
        'subscriberId': sub.id,
        'subscriberName': sub.name,
        'amount': result.amount,
        'paymentDate': result.paymentDate,
        'method': method == 'cash' ? 'cash' : result.method,
        'transactionId': result.transactionId.trim(),
        'transactionType': method == 'cash' ? 'cash' : result.method,
      });
      if (promiseId != null) {
        try {
          await _api.put('/billing/promises/$promiseId',
              body: {'status': 'completed'});
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
        }
      }
      if (!mounted) return;
      showToast(context, 'Payment received and recorded.');
      await _loadPayments();
      await _loadPromises();
      await _loadConnections();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _handlePromise() async {
    final sub = _selected;
    if (sub == null) return;
    final result = await showDialog<_PromiseResult>(
      context: context,
      builder: (_) => const _PromiseDialog(),
    );
    if (result == null) return;
    try {
      await _api.post('/billing/promises', body: {
        'subscriberId': sub.id,
        'subscriberName': sub.name,
        'internetId': sub.internetId,
        'phone': sub.cell.isNotEmpty ? sub.cell : sub.mobile,
        'address': sub.address,
        'sublocality': _sublocalityName,
        'connectionType': sub.connectionType,
        'amount': _totalOwed(sub),
        'promiseDate': result.promiseDate,
        'description': result.description.trim(),
        'status': 'pending',
        'collectorName': _recoveryOfficerName,
      });
      if (!mounted) return;
      showToast(context, 'Promise recorded successfully.');
      await _loadPromises();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _collectPos(TxPosPromise promise) async {
    final result = await showDialog<_PosCollectResult>(
      context: context,
      builder: (_) => _PosCollectDialog(promise: promise),
    );
    if (result == null) return;
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      await _api.post(
        '/pos/promises/${promise.id}/collect?companyId=$cid',
        body: {
          'amount': result.amount,
          'paymentMethod': result.method,
        },
      );
      if (!mounted) return;
      showToast(
        context,
        'PKR ${salesNumber(result.amount)} collected against POS promise.',
      );
      if (_selectedSubscriberId != null) _loadPosPromises(_selectedSubscriberId!);
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _deletePayment(TxPayment payment) async {
    await showNetworkDeleteDialog(
      context,
      itemName: 'payment entry #${payment.billNo.isEmpty ? payment.id : payment.billNo}',
      onConfirm: () async {
        try {
          await _api.delete('/billing/payments/${payment.id}');
          if (!mounted) return;
          showToast(context, 'Payment entry deleted.');
          await _loadPayments();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _deletePromise(TxPromise promise) async {
    await showNetworkDeleteDialog(
      context,
      itemName: 'promise entry',
      onConfirm: () async {
        try {
          await _api.delete('/billing/promises/${promise.id}');
          if (!mounted) return;
          showToast(context, 'Promise entry deleted.');
          await _loadPromises();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _editPayment(TxPayment payment) async {
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (_) => _EditPaymentDialog(
        payment: payment,
        transactionTypes: _filteredTransactionTypes,
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    if (result.transactionType.toLowerCase() != 'cash' &&
        result.transactionId.trim().isEmpty) {
      showToast(context, 'Transaction ID is required for this payment type.',
          error: true);
      return;
    }
    try {
      await _api.put('/billing/payments/${payment.id}', body: {
        'subscriberId': payment.subscriberId,
        'subscriberName': payment.subscriberName,
        'amount': result.amount,
        'paymentDate': payment.paymentDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(payment.paymentDate!),
        'method': payment.method,
        'transactionId': result.transactionId.trim(),
        'transactionType': result.transactionType.toLowerCase() == 'cash'
            ? 'cash'
            : result.transactionType,
      });
      if (!mounted) return;
      showToast(context, 'Payment entry updated.');
      await _loadPayments();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  void _printPayment(TxPayment payment, String size) {
    final date = payment.paymentDate;
    final dateRaw = date == null ? '---' : DateFormat('yyyy-MM-dd').format(date);
    final monthLong = date == null ? '---' : DateFormat('MMMM yyyy').format(date);
    final monthShort = date == null ? '---' : DateFormat('MMM yyyy').format(date);
    final name = _selected?.name ?? payment.subscriberName;
    final method = payment.method.isEmpty ? 'cash' : payment.method;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TxReceiptPreviewScreen(
          title: 'Payment Receipt',
          initialSize: size,
          company: _company,
          data: TxReceiptData(
            title: 'RECEIPT',
            accent: TxAccent.blue,
            idLabel: 'Bill ID:',
            idValue: payment.billNo.isEmpty ? '---' : payment.billNo,
            date: dateRaw,
            infoTitle: 'Subscriber Information',
            infoLines: [name],
            a4Rows: [
              ('Payment Method', _cap(method)),
              ('Payment Month', monthLong),
              ('Received By', _recoveryOfficerName),
            ],
            thermalRows: [
              ('Subscriber:', name),
              ('Method:', _cap(method)),
              ('Received By:', _recoveryOfficerName),
            ],
            thermalMonth: monthShort,
            amountLabel: 'AMOUNT RECEIVED',
            amount: payment.amount,
            statusLabel: 'PAID',
            statusPositive: true,
            thermalShowStatus: false,
          ),
        ),
      ),
    );
  }

  void _printPromise(TxPromise promise, String size) {
    final date = promise.promiseDate;
    final dateRaw = date == null ? '---' : DateFormat('yyyy-MM-dd').format(date);
    final dateLong = date == null ? '---' : DateFormat('d MMMM yyyy').format(date);
    final name = _selected?.name ?? promise.subscriberName;
    final type = promise.connectionType.isEmpty ? 'internet' : promise.connectionType;
    final infoLines = <String>[
      name,
      if (promise.subscriberId != null && promise.subscriberId!.isNotEmpty)
        'ID: ${promise.subscriberId!.length > 8 ? promise.subscriberId!.substring(0, 8) : promise.subscriberId}',
      if (promise.phone.isNotEmpty) 'Phone: ${promise.phone}',
      if (promise.address.isNotEmpty) promise.address,
    ];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TxReceiptPreviewScreen(
          title: 'Promise Slip',
          initialSize: size,
          company: _company,
          data: TxReceiptData(
            title: 'PROMISE SLIP',
            accent: TxAccent.amber,
            idLabel: 'Promise ID:',
            idValue: promise.id.length > 8
                ? promise.id.substring(0, 8)
                : promise.id,
            date: dateRaw,
            infoTitle: 'Subscriber Information',
            infoLines: infoLines,
            a4Rows: [
              ('Connection Type', _cap(type)),
              ('Promise Date', dateLong),
              ('Description', promise.description.isEmpty ? '---' : promise.description),
              ('Promised By', _recoveryOfficerName),
            ],
            thermalTitle: 'PROMISE SLIP',
            thermalRows: [
              ('Subscriber:', name),
              ('Type:', _cap(type)),
              ('Promised By:', _recoveryOfficerName),
              ('Description:', promise.description.isEmpty ? '---' : promise.description),
            ],
            amountLabel: 'OUTSTANDING AMOUNT',
            amount: promise.amount,
            statusLabel: 'PENDING',
            statusPositive: false,
            disclaimer:
                'This is a computer-generated slip and does not require a signature',
            thermalFooter: 'Computer generated slip',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _bootstrap,
      child: NetworkScrollBody(
        children: [
          NetworkPageHeader(
            icon: Icons.people_outline,
            title: 'Subscriber Collections',
            subtitle:
                'Receive payments from subscribers. Recovery Officer: $_recoveryOfficerName',
            gradient: _kBlue,
          ),
          if (_canViewSummary) ...[
            NetworkStatGrid(
              maxColumns: 4,
              children: [
                NetworkStatCard(
                  icon: Icons.people_outline,
                  label: 'Total Subscribers',
                  value: '${_connections.length}',
                  gradient: _kBlue,
                ),
                NetworkStatCard(
                  icon: Icons.attach_money_outlined,
                  label: 'Total Collected',
                  value: 'PKR ${salesNumber(_totalAmount)}',
                  gradient: _kAmber,
                  valueColor: context.isDark
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFFD97706),
                ),
                NetworkStatCard(
                  icon: Icons.schedule_outlined,
                  label: 'Pending Subscribers',
                  value: '${_dash?.subscribersStats.pending ?? 0}',
                  gradient: _kOrange,
                ),
                NetworkStatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Pending Amount',
                  value: 'PKR ${salesNumber(_dash?.pendingAmount ?? 0)}',
                  gradient: _kRose,
                  valueColor: context.isDark
                      ? const Color(0xFFFB7185)
                      : const Color(0xFFE11D48),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          _searchCard(context),
        ],
      ),
    );
  }

  Widget _searchCard(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_canViewSearch) _searchSection(context),
          if (_selected == null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(
                    'No Subscriber Selected',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.fg,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Search and select a subscriber to receive payments and view history.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: context.mutedFg),
                  ),
                ],
              ),
            )
          else
            _subscriberPanel(context),
        ],
      ),
    );
  }

  Widget _searchSection(BuildContext context) {
    final matches = _filteredSubscribers;
    final showMatches = _selected == null && _searchText.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Search Subscriber',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() {
                _searchText = v;
                if (_selectedSubscriberId != null) {
                  _selectedSubscriberId = null;
                }
              }),
              style: const TextStyle(fontSize: 14),
              decoration: netInputDecoration(
                context,
                hint: 'Type subscriber ID or name...',
              ).copyWith(
                prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
              ),
            ),
          ),
          if (showMatches && matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  decoration: BoxDecoration(
                    color: context.surface,
                    border: Border.all(color: context.line),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: matches.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: context.line),
                    itemBuilder: (context, i) {
                      final c = matches[i];
                      return InkWell(
                        onTap: () => _selectSubscriber(c.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    flex: 3,
                                    child: Text(
                                      c.displayInternetId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    flex: 4,
                                    child: Text(
                                      c.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13, color: context.mutedFg),
                                    ),
                                  ),
                                  if (c.primaryPhone.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      flex: 3,
                                      child: Text(
                                        '• ${c.primaryPhone}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: context.mutedFg),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '• ${_packageLabel(c)} • PKR ${salesNumber(_packagePrice(c))}'
                                '${c.remainingAmount < 0 ? ' • Advance PKR ${salesMoney(c.remainingAmount.abs())}' : c.remainingAmount > 0 ? ' • Pending PKR ${salesMoney(c.remainingAmount)}' : ''}',
                                style:
                                    TextStyle(fontSize: 12, color: context.mutedFg),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          if (_selected != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: context.subtle,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selected!.displayInternetId,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12),
                        ),
                        const SizedBox(width: 6),
                        Text('•',
                            style: TextStyle(color: context.mutedFg)),
                        const SizedBox(width: 6),
                        Text(_selected!.name,
                            style: const TextStyle(fontSize: 12)),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(left: 6),
                          iconSize: 16,
                          onPressed: () => _selectSubscriber(null),
                          icon: Icon(Icons.close,
                              size: 16, color: context.mutedFg),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _subscriberPanel(BuildContext context) {
    final s = _selected!;
    final history = <_HistoryRow>[
      for (final p in _subscriberPromises) _HistoryRow.promise(p),
      for (var i = 0; i < _subscriberPayments.length; i++)
        _HistoryRow.payment(_subscriberPayments[i], i + 1),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _grid(context, [
          _GridItem('Subscriber ID', s.shortId),
          _GridItem('Name', s.name),
          _GridItem('Internet ID', s.internetId.isEmpty ? '---' : s.internetId),
          _GridItem('Mobile',
              s.mobile.isNotEmpty ? s.mobile : (s.cell.isEmpty ? '---' : s.cell)),
          _GridItem('Address', s.address.isEmpty ? '---' : s.address,
              truncate: true),
        ]),
        Divider(height: 1, color: context.line),
        _grid(context, [
          _GridItem('Package', _packageLabelValue,
              sub: 'PKR ${salesNumber(_packageFee)} / month'),
          _GridItem('Remaining', 'PKR ${salesNumber(_displayRemaining)}',
              color: _displayRemaining == 0
                  ? const Color(0xFF059669)
                  : const Color(0xFFD97706)),
          _GridItem('Advance Amount', 'PKR ${salesNumber(_advanceAmount)}',
              color: _advanceAmount > 0
                  ? const Color(0xFF2563EB)
                  : context.mutedFg),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Text('Status',
                  style: TextStyle(fontSize: 12, color: context.mutedFg)),
              const SizedBox(width: 12),
              _statusBadge(context),
            ],
          ),
        ),
        Divider(height: 1, color: context.line),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_pin_circle_outlined,
                      size: 16, color: context.mutedFg),
                  const SizedBox(width: 6),
                  Text('Receiving as: ',
                      style:
                          TextStyle(fontSize: 13, color: context.mutedFg)),
                  Text(_recoveryOfficerName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
              if (_canCreate)
                GradientButton(
                  label: 'Receive Payment',
                  icon: Icons.attach_money_outlined,
                  gradient: _kEmerald,
                  onPressed: _handleReceive,
                ),
              if (_canCreate)
                OutlinedButton.icon(
                  onPressed: _handlePromise,
                  icon: const Icon(Icons.event_outlined, size: 16),
                  label: const Text('Make Promise'),
                ),
            ],
          ),
        ),
        if (_subscriberPosPromises.isNotEmpty) _posBlock(context),
        Divider(height: 1, color: context.line),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${s.name}'s Payment History",
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (_loadingPayments || _loadingPromises)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No payment history found.',
                        style: TextStyle(color: context.mutedFg)),
                  ),
                )
              else
                NetworkTable<_HistoryRow>(
                  rows: history,
                  emptyIcon: Icons.receipt_long_outlined,
                  emptyTitle: 'No payment history found.',
                  emptyHint: '',
                  emptyTint: AppColors.emerald600,
                  mobileTrailing: (context, row, _) => _rowActions(context, row),
                  columns: _historyColumns(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _posBlock(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _amberBg.withValues(alpha: context.isDark ? 0.08 : 0.6),
        border: Border.all(color: const Color(0xFFFCD34D)),
        borderRadius: BorderRadius.circular(12),
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
                    Row(
                      children: [
                        const Icon(Icons.shopping_cart_outlined,
                            size: 16, color: _amberText),
                        const SizedBox(width: 6),
                        const Text('POS Pending Payments',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _amberText)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_subscriberPosPromises.length} open promise${_subscriberPosPromises.length > 1 ? 's' : ''} from shop sales. This is separate from the monthly bill.',
                      style: TextStyle(fontSize: 12, color: context.mutedFg),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total Pending',
                      style: TextStyle(fontSize: 12, color: context.mutedFg)),
                  Text(
                    'PKR ${salesNumber(_totalPosPending)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _amberText),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final promise in _subscriberPosPromises)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              promise.saleNumber.isEmpty
                                  ? 'POS ${promise.id.length > 8 ? promise.id.substring(0, 8) : promise.id}'
                                  : promise.saleNumber,
                              style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: context.mutedFg),
                            ),
                            const SizedBox(width: 8),
                            TxBadge(
                              label: promise.status,
                              color: _amberText,
                              background: _amberBg,
                            ),
                          ],
                        ),
                        if (promise.description.isNotEmpty)
                          Text(
                            promise.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 12, color: context.mutedFg),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'PKR ${salesNumber(promise.posRemaining)}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  if (_canCreate)
                    OutlinedButton(
                      onPressed: () => _collectPos(promise),
                      child: const Text('Collect'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(BuildContext context) {
    if (_advanceAmount > 0) {
      return TxBadge(
          label: 'Advance', color: _greenText, background: _greenBg);
    }
    if (_displayRemaining > 0) {
      return TxBadge(label: 'Pending', color: _amberText, background: _amberBg);
    }
    if (_packageFee > 0) {
      return TxBadge(label: 'Full', color: _greenText, background: _greenBg);
    }
    return Text('---', style: TextStyle(color: context.mutedFg, fontSize: 13));
  }

  Widget _grid(BuildContext context, List<_GridItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 5
            : (constraints.maxWidth >= 520 ? 3 : 2);
        final width = (constraints.maxWidth - 32 - 12 * (columns - 1)) / columns;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.mutedFg),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.value,
                        maxLines: item.truncate ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: item.color ?? context.fg,
                        ),
                      ),
                      if (item.sub != null)
                        Text(item.sub!,
                            style: TextStyle(
                                fontSize: 11, color: context.mutedFg)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<NetColumn<_HistoryRow>> _historyColumns() {
    return [
      NetColumn(
        label: 'Bill #',
        width: 100,
        builder: (context, row, _) {
          if (row.promise != null) {
            return Text('PROMISE',
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: context.isDark
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFB45309)));
          }
          final p = row.payment!;
          return Text(
            p.billNo.isNotEmpty ? p.billNo : '${row.paymentIndex}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          );
        },
      ),
      NetColumn(
        label: 'Subscriber ID',
        width: 110,
        builder: (context, row, _) => Text(
          row.subscriberShortId,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      NetColumn(
        label: 'Name',
        width: 150,
        builder: (context, row, _) => Text(
          row.promise != null
              ? (_selected?.name ?? '')
              : (row.payment!.subscriberName),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
      NetColumn(
        label: 'Address',
        width: 160,
        builder: (context, row, _) => Text(
          _selected?.address.isNotEmpty == true ? _selected!.address : '---',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: context.mutedFg),
        ),
      ),
      NetColumn(
        label: 'Month/Year',
        width: 100,
        builder: (context, row, _) {
          final d = row.date;
          return Text(d == null ? '---' : DateFormat('MMM yyyy').format(d),
              style: const TextStyle(fontSize: 12));
        },
      ),
      NetColumn(
        label: 'Payment Type',
        width: 110,
        builder: (context, row, _) {
          if (row.promise != null) {
            return TxBadge(
                label: 'Promise', color: _amberText, background: _amberBg);
          }
          return Text(_cap(row.payment!.method.isEmpty ? 'cash' : row.payment!.method),
              style: const TextStyle(fontSize: 12));
        },
      ),
      NetColumn(
        label: 'Transaction ID',
        width: 140,
        builder: (context, row, _) {
          if (row.promise != null) {
            return Text('---',
                style: TextStyle(fontSize: 12, color: context.mutedFg));
          }
          final tx = row.payment!.transactionId;
          return Text(tx.isEmpty ? '---' : tx,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12));
        },
      ),
      NetColumn(
        label: 'Amount',
        width: 110,
        builder: (context, row, _) => Text(
          'PKR ${salesNumber(row.amount)}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      NetColumn(
        label: 'Date',
        width: 100,
        builder: (context, row, _) {
          final d = row.date;
          return Text(d == null ? '---' : DateFormat('M/d/yyyy').format(d),
              style: const TextStyle(fontSize: 12));
        },
      ),
      NetColumn(
        label: 'Comment',
        width: 120,
        builder: (context, row, _) {
          final c = row.promise?.description ?? '';
          return Text(c.isEmpty ? '---' : c,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.mutedFg));
        },
      ),
      NetColumn(
        label: 'Status',
        width: 90,
        center: true,
        builder: (context, row, _) {
          if (row.promise != null) {
            return const TxBadge(
                label: 'Pending',
                color: Color(0xFFFFFFFF),
                background: Color(0xFFF59E0B));
          }
          return const TxBadge(
              label: 'Paid', color: _greenText, background: _greenBg);
        },
      ),
      NetColumn(
        label: 'Received By',
        width: 130,
        builder: (context, row, _) => Text(
          row.promise != null
              ? (row.promise!.collectorName.isEmpty
                  ? _recoveryOfficerName
                  : row.promise!.collectorName)
              : _recoveryOfficerName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
      NetColumn(
        label: '',
        width: 150,
        isActions: true,
        builder: (context, row, _) => _rowActions(context, row),
      ),
    ];
  }

  Widget _rowActions(BuildContext context, _HistoryRow row) {
    if (row.promise != null) {
      final promise = row.promise!;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_canCreate)
            OutlinedButton(
              onPressed: () => _receivePromise(promise),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
                foregroundColor: const Color(0xFF059669),
              ),
              child: const Text('Receive', style: TextStyle(fontSize: 11)),
            ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (value) {
              switch (value) {
                case 'print-a4':
                  _printPromise(promise, 'a4');
                  break;
                case 'print-thermal':
                  _printPromise(promise, 'thermal');
                  break;
                case 'delete':
                  _deletePromise(promise);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'print-a4',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.description_outlined, size: 18),
                  title: Text('Print Slip'),
                ),
              ),
              const PopupMenuItem(
                value: 'print-thermal',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.copy_outlined, size: 18),
                  title: Text('Duplicate Slip'),
                ),
              ),
              if (_canDelete)
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline,
                        size: 18, color: Color(0xFFDC2626)),
                    title: Text('Delete'),
                  ),
                ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.more_horiz, size: 18),
            ),
          ),
        ],
      );
    }

    final payment = row.payment!;
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _editPayment(payment);
            break;
          case 'print-a4':
            _printPayment(payment, 'a4');
            break;
          case 'print-thermal':
            _printPayment(payment, 'thermal');
            break;
          case 'delete':
            _deletePayment(payment);
            break;
        }
      },
      itemBuilder: (context) => [
        if (_canUpdate)
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
          value: 'print-a4',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.print_outlined, size: 18),
            title: Text('Print'),
          ),
        ),
        const PopupMenuItem(
          value: 'print-thermal',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.copy_outlined, size: 18),
            title: Text('Duplicate Print'),
          ),
        ),
        if (_canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading:
                  Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
              title: Text('Delete'),
            ),
          ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(Icons.more_horiz, size: 18),
      ),
    );
  }
}

/// One row of the payment history table — either a promise or a payment.
class _HistoryRow {
  _HistoryRow.promise(TxPromise p)
      : promise = p,
        payment = null,
        paymentIndex = 0;
  _HistoryRow.payment(TxPayment p, this.paymentIndex)
      : payment = p,
        promise = null;

  final TxPromise? promise;
  final TxPayment? payment;
  final int paymentIndex;

  String get subscriberShortId {
    final id = promise?.subscriberId ?? payment?.subscriberId ?? '';
    return id.length > 8 ? id.substring(0, 8) : (id.isEmpty ? '---' : id);
  }

  DateTime? get date => promise?.promiseDate ?? payment?.paymentDate;
  double get amount => promise?.amount ?? payment?.amount ?? 0;
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

class _ReceiveResult {
  _ReceiveResult({
    required this.amount,
    required this.paymentDate,
    required this.method,
    required this.transactionId,
  });

  final double amount;
  final String paymentDate;
  final String method;
  final String transactionId;
}

class _ReceiveDialog extends StatefulWidget {
  const _ReceiveDialog({
    required this.subscriber,
    required this.packageFee,
    required this.displayRemaining,
    required this.recoveryOfficerName,
    required this.paymentOptions,
    required this.initialAmount,
    required this.fulfillingPromise,
  });

  final TxConnection subscriber;
  final double packageFee;
  final double displayRemaining;
  final String recoveryOfficerName;
  final List<TxPickOption> paymentOptions;
  final double initialAmount;
  final bool fulfillingPromise;

  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  late final TextEditingController _amount =
      TextEditingController(text: _fmt(widget.initialAmount));
  late String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _method = 'cash';
  late final TextEditingController _txId =
      TextEditingController(text: widget.subscriber.transactionId);
  final TextEditingController _comment = TextEditingController();

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double get _amountValue => double.tryParse(_amount.text.trim()) ?? 0;
  double get _afterPayment {
    final r = widget.displayRemaining - _amountValue;
    return r < 0 ? 0 : r;
  }

  @override
  void dispose() {
    _amount.dispose();
    _txId.dispose();
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    if (_amountValue <= 0) return;
    final m = _method.toLowerCase();
    if (m != 'cash' && _txId.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Transaction ID is required for this payment type.')));
      return;
    }
    Navigator.of(context).pop(_ReceiveResult(
      amount: _amountValue,
      paymentDate: _date,
      method: _method,
      transactionId: _txId.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subscriber;
    final isCash = _method.toLowerCase() == 'cash';
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('Receive Payment'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.fulfillingPromise)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _amberBg,
                    border: Border.all(color: const Color(0xFFFCD34D)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Fulfilling a pending promise (amount pre-filled).',
                    style: TextStyle(fontSize: 12, color: _amberText),
                  ),
                ),
              _pair(
                NetField(
                  label: 'Subscriber ID',
                  child: _readonly(s.shortId),
                ),
                NetField(label: 'Subscriber Name', child: _readonly(s.name)),
              ),
              const SizedBox(height: 12),
              NetField(
                label: 'Mobile',
                child: _readonly(s.mobile.isNotEmpty
                    ? s.mobile
                    : (s.cell.isEmpty ? '---' : s.cell)),
              ),
              const SizedBox(height: 12),
              NetField(
                label: 'Received By',
                child: _readonly(widget.recoveryOfficerName),
              ),
              const SizedBox(height: 12),
              NetField(
                label: 'Package Fee (PKR)',
                child: _readonly(salesNumber(widget.packageFee)),
              ),
              const SizedBox(height: 12),
              NetField(
                label: 'Remaining (PKR)',
                child: _readonly(salesNumber(widget.displayRemaining)),
              ),
              const SizedBox(height: 12),
              NetField(
                label: 'Amount (PKR)',
                child: TextField(
                  keyboardType: TextInputType.number,
                  controller: _amount,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14),
                  decoration: netInputDecoration(context, hint: 'Enter amount'),
                ),
              ),
              if (_amountValue > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _afterPayment == 0
                        ? _greenBg
                        : (_amountValue > widget.displayRemaining
                            ? const Color(0xFFDBEAFE)
                            : _amberBg),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _afterPayment == 0
                        ? 'Fully Paid — PKR ${salesNumber(_amountValue)} covers the remaining'
                        : _amountValue > widget.displayRemaining
                            ? 'Advance — PKR ${salesNumber(_amountValue - widget.displayRemaining)} extra will be credited'
                            : 'After Payment — PKR ${salesNumber(_afterPayment)} remaining',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              NetField(
                label: 'Pay Date',
                child: TxDateField(
                  label: 'Select date...',
                  value: _date,
                  onChanged: (v) => setState(() => _date = v),
                  width: double.infinity,
                ),
              ),
              const SizedBox(height: 12),
              NetField(
                label: 'Payment Type',
                child: TxSelect(
                  value: _method,
                  items: {
                    for (final o in widget.paymentOptions) o.id: o.name,
                  },
                  onChanged: (v) => setState(() {
                    _method = v;
                    if (v.toLowerCase() != 'cash' &&
                        s.transactionId.isNotEmpty) {
                      _txId.text = s.transactionId;
                    } else {
                      _txId.text = '';
                    }
                  }),
                ),
              ),
              if (!isCash) ...[
                const SizedBox(height: 12),
                NetField(
                  label: 'Transaction ID *',
                  child: TextField(
                    controller: _txId,
                    readOnly: s.transactionId.isNotEmpty,
                    style: const TextStyle(fontSize: 14),
                    decoration: netInputDecoration(
                      context,
                      hint: s.transactionId.isNotEmpty
                          ? 'Auto-filled from subscriber'
                          : 'Enter transaction ID / reference number',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              NetField(
                label: 'Comment',
                child: TextField(
                  controller: _comment,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14),
                  decoration:
                      netInputDecoration(context, hint: 'Add a comment...'),
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: 'Receive',
                gradient: _kEmerald,
                onPressed: _amountValue > 0 ? _submit : null,
              ),
            ],
          ),
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

  Widget _readonly(String value) => Container(
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

  Widget _pair(Widget a, Widget b) => Row(
        children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ],
      );
}

class _PromiseResult {
  _PromiseResult({required this.promiseDate, required this.description});
  final String promiseDate;
  final String description;
}

class _PromiseDialog extends StatefulWidget {
  const _PromiseDialog();

  @override
  State<_PromiseDialog> createState() => _PromiseDialogState();
}

class _PromiseDialogState extends State<_PromiseDialog> {
  late String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final TextEditingController _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (_description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Please enter a description for the promise.')));
      return;
    }
    Navigator.of(context).pop(_PromiseResult(
      promiseDate: _date,
      description: _description.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('Make a Promise'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NetField(
                label: 'Promise Date',
                child: TxDateField(
                  label: 'Select date...',
                  value: _date,
                  onChanged: (v) => setState(() => _date = v),
                  width: double.infinity,
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Description',
                child: TextField(
                  controller: _description,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14),
                  decoration: netInputDecoration(
                    context,
                    hint: 'e.g. I will pay the outstanding amount on this date.',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: 'Save Promise',
                gradient: _kCyan,
                onPressed: _save,
              ),
            ],
          ),
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
}

class _PosCollectResult {
  _PosCollectResult({required this.amount, required this.method});
  final double amount;
  final String method;
}

class _PosCollectDialog extends StatefulWidget {
  const _PosCollectDialog({required this.promise});

  final TxPosPromise promise;

  @override
  State<_PosCollectDialog> createState() => _PosCollectDialogState();
}

class _PosCollectDialogState extends State<_PosCollectDialog> {
  late final TextEditingController _amount =
      TextEditingController(text: _fmt(widget.promise.posRemaining));
  String _method = 'cash';

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final remaining = widget.promise.posRemaining;
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Enter an amount greater than zero.')));
      return;
    }
    if (amount > remaining) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content:
                Text('Amount cannot be more than PKR ${salesNumber(remaining)}.')));
      return;
    }
    Navigator.of(context)
        .pop(_PosCollectResult(amount: amount, method: _method));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.promise;
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('Collect POS Pending'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _amberBg.withValues(alpha: 0.6),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _row('Sale',
                        p.saleNumber.isEmpty ? 'POS ${p.id}' : p.saleNumber),
                    _row('Outstanding', 'PKR ${salesNumber(p.posRemaining)}'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Amount Collected',
                child: TextField(
                  keyboardType: TextInputType.number,
                  controller: _amount,
                  style: const TextStyle(fontSize: 14),
                  decoration: netInputDecoration(context),
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Payment Method',
                child: TxSelect(
                  value: _method,
                  items: const {
                    'cash': 'Cash',
                    'card': 'Card',
                    'bank': 'Bank',
                  },
                  onChanged: (v) => setState(() => _method = v),
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: 'Record Collection',
                gradient: _kAmber,
                onPressed: _submit,
              ),
            ],
          ),
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

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 13, color: context.mutedFg)),
            Text(value, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
}

class _EditResult {
  _EditResult({
    required this.amount,
    required this.transactionId,
    required this.transactionType,
  });
  final double amount;
  final String transactionId;
  final String transactionType;
}

class _EditPaymentDialog extends StatefulWidget {
  const _EditPaymentDialog({
    required this.payment,
    required this.transactionTypes,
  });

  final TxPayment payment;
  final List<TxTransactionType> transactionTypes;

  @override
  State<_EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends State<_EditPaymentDialog> {
  late final TextEditingController _amount =
      TextEditingController(text: _fmt(widget.payment.amount));
  late final TextEditingController _txId =
      TextEditingController(text: widget.payment.transactionId);
  late String _type = widget.payment.transactionType.isNotEmpty
      ? widget.payment.transactionType
      : (widget.payment.method.isEmpty ? 'cash' : widget.payment.method);

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _amount.dispose();
    _txId.dispose();
    super.dispose();
  }

  void _save() {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0 || _type.isEmpty) return;
    Navigator.of(context).pop(_EditResult(
      amount: amount,
      transactionId: _txId.text,
      transactionType: _type,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('Edit Payment Entry'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: NetField(
                      label: 'Bill #',
                      child: _readonly(
                          p.billNo.isEmpty ? '---' : p.billNo),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NetField(
                      label: 'Subscriber',
                      child: _readonly(p.subscriberName),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Amount (PKR)',
                child: TextField(
                  keyboardType: TextInputType.number,
                  controller: _amount,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14),
                  decoration: netInputDecoration(context),
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Transaction ID *',
                child: TextField(
                  controller: _txId,
                  style: const TextStyle(fontSize: 14),
                  decoration: netInputDecoration(
                    context,
                    hint: 'Enter transaction ID / reference number',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Transaction Type',
                child: TxSelect(
                  value: _type,
                  items: {
                    for (final t in widget.transactionTypes)
                      (t.paymentChannel.isNotEmpty
                              ? t.paymentChannel
                              : t.transaction):
                          (t.paymentChannel.isNotEmpty
                              ? t.paymentChannel
                              : t.transaction),
                  },
                  onChanged: (v) => setState(() => _type = v),
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: 'Save Changes',
                gradient: _kEmerald,
                onPressed: (double.tryParse(_amount.text.trim()) ?? 0) > 0 &&
                        _type.isNotEmpty
                    ? _save
                    : null,
              ),
            ],
          ),
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

  Widget _readonly(String value) => Container(
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

class _GridItem {
  const _GridItem(this.label, this.value, {this.truncate = false, this.sub, this.color});

  final String label;
  final String value;
  final bool truncate;
  final String? sub;
  final Color? color;
}