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
import 'transaction_receipt.dart';

const List<Color> _kAmber = [Color(0xFFF59E0B), Color(0xFFEA580C)];
const List<Color> _kBlue = [Color(0xFF3B82F6), Color(0xFF0891B2)];
const List<Color> _kEmerald = [Color(0xFF059669), Color(0xFF16A34A)];
const List<Color> _kViolet = [Color(0xFF8B5CF6), Color(0xFF9333EA)];

const List<TxPickOption> _kPaymentTypes = [
  TxPickOption(id: 'cash', name: 'Cash'),
  TxPickOption(id: 'bank', name: 'Bank'),
  TxPickOption(id: 'easypaisa', name: 'Easypaisa'),
  TxPickOption(id: 'jazzcash', name: 'JazzCash'),
];

const List<TxPickOption> _kStatusOptions = [
  TxPickOption(id: 'pending', name: 'Unpaid'),
  TxPickOption(id: 'settled', name: 'Paid'),
];

/// Flutter counterpart of
/// `client/src/app/(app)/transaction/dealers-collections/page.tsx`.
class DealersCollectionsScreen extends StatefulWidget {
  const DealersCollectionsScreen({super.key});

  @override
  State<DealersCollectionsScreen> createState() =>
      _DealersCollectionsScreenState();
}

class _DealersCollectionsScreenState extends State<DealersCollectionsScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<TxDealer> _dealers = [];
  List<TxDealerCollection> _collections = [];
  List<TxArea> _areas = [];
  List<TxRecoveryOfficer> _officers = [];
  SalesCompany _company = SalesCompany.empty;

  bool _loading = true;
  bool _loadingCollections = false;

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

  TxDealer? get _selectedDealer =>
      _dealers.where((d) => d.id == _selectedDealerId).firstOrNull;

  List<TxDealerCollection> get _dealerCollections {
    final id = _selectedDealerId;
    if (id == null) return const [];
    return _collections.where((c) => c.dealerId == id).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _load();
  }

  Future<void> _loadCredentials() async {
    try {
      final company = await fetchSalesCompany(_api);
      if (!mounted) return;
      setState(() => _company = company);
    } on ApiException catch (_) {
      // ignore: company details only affect receipts
    }
  }

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _api.get('/dealers', query: {'companyId': cid}),
        _api.get('/network/areas', query: {'companyId': cid}),
        _api.get('/admin/recovery-officers', query: {'companyId': cid}),
      ]);
      if (!mounted) return;
      setState(() {
        _dealers = ApiClient.listData(results[0])
            .whereType<Map<String, dynamic>>()
            .map(TxDealer.fromJson)
            .toList();
        _areas = ApiClient.listData(results[1])
            .whereType<Map<String, dynamic>>()
            .map(TxArea.fromJson)
            .toList();
        _officers = ApiClient.listData(results[2])
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

  Future<void> _loadCollections() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    setState(() => _loadingCollections = true);
    try {
      final json =
          await _api.get('/dealers/collections', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _collections = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(TxDealerCollection.fromJson)
            .toList();
        _loadingCollections = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loadingCollections = false);
    }
  }

  void _selectDealer(String? id) {
    setState(() {
      _selectedDealerId = id;
      _collections = [];
    });
    if (id != null) _loadCollections();
  }

  String get _recoveryOfficerName {
    final d = _selectedDealer;
    if (d == null) return Session.userName ?? '---';
    if (d.areaId != null) {
      final area = _areas.where((a) => a.id == d.areaId).firstOrNull;
      if (area != null && area.recoveryOfficerId != null) {
        final o =
            _officers.where((o) => o.id == area.recoveryOfficerId).firstOrNull;
        if (o != null) return o.name;
      }
    }
    return Session.userName ?? '---';
  }

  double get _totalAmount =>
      _collections.fold(0.0, (sum, c) => sum + c.amount);

  double get _totalWalletBalance =>
      _dealers.fold(0.0, (sum, d) => sum + d.walletBalance);

  bool get _canCreate => txCrud(kDealerCollectionsPermission, 'create');
  bool get _canUpdate => txCrud(kDealerCollectionsPermission, 'update');
  bool get _canDelete => txCrud(kDealerCollectionsPermission, 'delete');

  Future<void> _handleReceive({
    required double amount,
    required String date,
    required String status,
    required String txType,
    required String comment,
  }) async {
    final d = _selectedDealer;
    if (d == null) return;
    try {
      await _api.post('/dealers/collections', body: {
        'dealerId': d.id,
        'dealerName': d.name,
        'dealerAddress': d.address,
        'amount': amount,
        'collectionDate': date,
        'settlementStatus': status,
        'transactionType': txType,
        'comment': comment,
        'receivedByName': _recoveryOfficerName,
      });
      if (!mounted) return;
      showToast(context, 'Payment received and recorded.');
      await _loadCollections();
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _handleEditSave(
    TxDealerCollection col, {
    required double amount,
    required String comment,
    required String status,
  }) async {
    try {
      await _api.put('/dealers/collections/${col.id}', body: {
        'dealerId': col.dealerId,
        'dealerName': col.dealerName,
        'dealerAddress': col.dealerAddress,
        'amount': amount,
        'collectionDate': col.collectionDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(col.collectionDate!),
        'settlementStatus': status,
        'transactionType': col.transactionType,
        'comment': comment,
        'receivedByName': col.receivedByName,
      });
      if (!mounted) return;
      showToast(context, 'Collection entry updated.');
      await _loadCollections();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _handleToggleStatus(TxDealerCollection col) async {
    final newStatus = col.settlementStatus == 'settled' ? 'pending' : 'settled';
    try {
      await _api.put('/dealers/collections/${col.id}', body: {
        'settlementStatus': newStatus,
      });
      if (!mounted) return;
      showToast(context, 'Status changed to $newStatus.');
      await _loadCollections();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _handleDelete(TxDealerCollection col) async {
    await showNetworkDeleteDialog(
      context,
      itemName: 'collection entry #${col.id}',
      onConfirm: () async {
        try {
          await _api.delete('/dealers/collections/${col.id}');
          if (!mounted) return;
          showToast(context, 'Collection entry deleted.');
          await _loadCollections();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  void _openPrint(TxDealerCollection col, int billNo, String size) {
    final d = col.dealerId ?? '';
    final dealerId = d.length > 8 ? d.substring(0, 8) : d;
    final dateStr = col.collectionDate == null
        ? '---'
        : DateFormat('yyyy-MM-dd').format(col.collectionDate!);
    final monthLong = col.collectionDate == null
        ? 'N/A'
        : DateFormat('MMMM yyyy').format(col.collectionDate!);
    final monthShort = col.collectionDate == null
        ? 'N/A'
        : DateFormat('MMM yyyy').format(col.collectionDate!);
    final payType =
        col.transactionType.isEmpty ? 'cash' : col.transactionType;
    final receivedBy = col.receivedByName.isEmpty
        ? _recoveryOfficerName
        : col.receivedByName;
    final paid = col.settlementStatus.toUpperCase() == 'PAID';

    final a4Rows = <(String, String)>[
      ('Dealer ID', dealerId),
      ('Dealer Name', col.dealerName),
      ('Address', col.dealerAddress),
      ('Payment Type', payType),
      ('Payment Month', monthLong),
      ('Received By', receivedBy),
      if (col.comment.isNotEmpty) ('Comment', col.comment),
    ];
    final thermalRows = <(String, String)>[
      ('Dealer ID', dealerId),
      ('Dealer', col.dealerName),
      ('Address', col.dealerAddress),
      ('Type', payType),
      ('Received By', receivedBy),
      if (col.comment.isNotEmpty) ('Comment', col.comment),
    ];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TxReceiptPreviewScreen(
          title: 'Dealer Receipt #$billNo',
          initialSize: size,
          company: _company,
          data: TxReceiptData(
            title: 'RECEIPT',
            accent: TxAccent.emerald,
            idLabel: 'Bill ID:',
            idValue: '$billNo',
            date: dateStr,
            a4Rows: a4Rows,
            thermalRows: thermalRows,
            thermalMonth: monthShort,
            amountLabel: 'AMOUNT RECEIVED',
            amount: col.amount,
            statusLabel: col.settlementStatus,
            statusPositive: paid,
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
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          NetworkPageHeader(
            icon: Icons.handshake_outlined,
            title: 'Dealer Collections',
            subtitle:
                'Receive payments from dealers. Recovery Officer: $_recoveryOfficerName',
            gradient: _kAmber,
          ),
          _statCards(context),
          const SizedBox(height: 20),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SalesFilterRows(
                    rows: [
                      [
                        TxSearchableSelect(
                          width: 420,
                          label: 'Select Dealer',
                          placeholder: 'Search and select a dealer...',
                          searchPlaceholder:
                              'Type to search by name, phone, or CNIC...',
                          options: [
                            for (final d in _dealers)
                              TxPickOption(
                                id: d.id,
                                name: d.name,
                                secondary: '${d.phone} • ${d.cnic}',
                              ),
                          ],
                          value: _selectedDealerId,
                          onChanged: _selectDealer,
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (_selectedDealer == null)
                  _emptySelection(context)
                else
                  _dealerPanel(context, _selectedDealer!),
              ],
            ),
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
          icon: Icons.handshake_outlined,
          label: 'Total Dealers',
          value: '${_dealers.length}',
          gradient: _kAmber,
        ),
        NetworkStatCard(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Collections',
          value: '${_collections.length}',
          gradient: _kBlue,
        ),
        NetworkStatCard(
          icon: Icons.payments_outlined,
          label: 'Total Collected',
          value: 'PKR ${salesNumber(_totalAmount)}',
          gradient: _kEmerald,
          valueColor: const Color(0xFF059669),
        ),
        NetworkStatCard(
          icon: Icons.person_outline,
          label: 'Remaining Amount',
          value: 'PKR ${salesNumber(_totalWalletBalance)}',
          gradient: _kViolet,
          valueColor: const Color(0xFF7C3AED),
        ),
      ],
    );
  }

  Widget _emptySelection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.storefront_outlined, size: 40, color: context.mutedFg),
          const SizedBox(height: 12),
          Text(
            'No Dealer Selected',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: context.fg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Search and select a dealer to receive payments and view history.',
            style: TextStyle(fontSize: 13, color: context.mutedFg),
          ),
        ],
      ),
    );
  }

  Widget _dealerPanel(BuildContext context, TxDealer d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 7
                  : constraints.maxWidth >= 700
                      ? 4
                      : 2;
              final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
              final items = <(String, Widget)>[
                (
                  'Dealer ID',
                  Text(
                    d.shortId.isEmpty ? '---' : d.shortId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ('Name', Text(d.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                (
                  'Phone',
                  Text(
                    d.phone.isEmpty ? '---' : d.phone,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                (
                  'CNIC',
                  Text(
                    d.cnic.isEmpty ? '---' : d.cnic,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                (
                  'Address',
                  Text(
                    d.address.isEmpty ? '---' : d.address,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                (
                  'Balance',
                  Text(
                    'PKR ${salesNumber(d.walletBalance)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                (
                  'Remaining',
                  Text(
                    'PKR ${salesNumber(d.remainingAmount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: d.remainingAmount > 0
                          ? context.dangerText
                          : AppColors.emerald600,
                    ),
                  ),
                ),
              ];
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.mutedFg,
                            ),
                          ),
                          const SizedBox(height: 2),
                          item.$2,
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: context.mutedFg),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: 'Receiving as: ',
                    style: TextStyle(fontSize: 13, color: context.mutedFg),
                    children: [
                      TextSpan(
                        text: _recoveryOfficerName,
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
              const Spacer(),
              if (_canCreate)
                GradientButton(
                  label: 'Receive Payment',
                  icon: Icons.payments_outlined,
                  gradient: _kEmerald,
                  onPressed: _openReceiveDialog,
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${d.name}'s Payment History",
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (_loadingCollections)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_dealerCollections.isEmpty)
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
                _historyTable(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _historyTable(BuildContext context) {
    final rows = _dealerCollections;
    return NetworkTable<TxDealerCollection>(
      rows: rows,
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: 'No payment history found.',
      emptyHint: '',
      emptyTint: AppColors.emerald600,
      columns: [
        NetColumn(
          label: 'Bill #',
          width: 50,
          builder: (context, c, index) => Text(
            '${index + 1}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        NetColumn(
          label: 'Dealer ID',
          width: 80,
          builder: (context, c, _) {
            final id = c.dealerId ?? '';
            return Text(
              id.length > 8 ? id.substring(0, 8) : (id.isEmpty ? '---' : id),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            );
          },
        ),
        NetColumn(
          label: 'Name',
          width: 140,
          builder: (context, c, _) =>
              Text(c.dealerName, overflow: TextOverflow.ellipsis),
        ),
        NetColumn(
          label: 'Address',
          width: 120,
          builder: (context, c, _) => Text(
            c.dealerAddress.isEmpty ? '---' : c.dealerAddress,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        NetColumn(
          label: 'Month/Year',
          width: 100,
          builder: (context, c, _) => Text(
            c.collectionDate == null
                ? '---'
                : DateFormat('MMM yyyy').format(c.collectionDate!),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        NetColumn(
          label: 'Payment Type',
          width: 100,
          builder: (context, c, _) => Text(
            c.transactionType.isEmpty ? 'cash' : c.transactionType,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        NetColumn(
          label: 'Received',
          width: 110,
          builder: (context, c, _) => Text(
            'PKR ${salesNumber(c.amount)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        NetColumn(
          label: 'Pay Date',
          width: 100,
          builder: (context, c, _) => Text(
            c.collectionDate == null
                ? '---'
                : DateFormat('M/d/yyyy').format(c.collectionDate!),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        NetColumn(
          label: 'Comment',
          width: 100,
          builder: (context, c, _) => Text(
            c.comment.isEmpty ? '---' : c.comment,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        NetColumn(
          label: 'Status',
          width: 80,
          center: true,
          builder: (context, c, _) {
            final settled = c.settlementStatus == 'settled';
            return TxBadge(
              label: settled ? 'Paid' : 'Unpaid',
              color: settled ? AppColors.emerald600 : context.mutedFg,
              background:
                  settled ? const Color(0xFFDCFCE7) : context.subtle,
            );
          },
        ),
        NetColumn(
          label: 'Received By',
          width: 120,
          builder: (context, c, _) => Text(
            c.receivedByName.isEmpty ? '---' : c.receivedByName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        NetColumn(
          label: '',
          width: 44,
          builder: (context, c, index) =>
              _rowMenu(context, c, index + 1),
        ),
      ],
    );
  }

  Widget _rowMenu(BuildContext context, TxDealerCollection c, int billNo) {
    return PopupMenuButton<String>(
      tooltip: '',
      icon: Icon(Icons.more_horiz, size: 18, color: context.mutedFg),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _openEditDialog(c, billNo);
            break;
          case 'toggle':
            _handleToggleStatus(c);
            break;
          case 'print':
            _openPrint(c, billNo, 'a4');
            break;
          case 'duplicate':
            _openPrint(c, billNo, 'thermal');
            break;
          case 'delete':
            _handleDelete(c);
            break;
        }
      },
      itemBuilder: (context) => [
        if (_canUpdate)
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (_canUpdate)
          PopupMenuItem(
            value: 'toggle',
            child: Text(
              c.settlementStatus == 'settled' ? 'Mark Unpaid' : 'Mark Paid',
            ),
          ),
        const PopupMenuItem(value: 'print', child: Text('Print')),
        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate Print')),
        if (_canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete', style: TextStyle(color: Color(0xFFDC2626))),
          ),
      ],
    );
  }

  Future<void> _openReceiveDialog() async {
    final result = await showDialog<_ReceiveResult>(
      context: context,
      builder: (_) => _ReceiveDialog(
        dealerName: _selectedDealer?.name ?? '',
        dealerId: _selectedDealer?.shortId ?? '',
        dealerAddress: _selectedDealer?.address ?? '---',
        walletBalance: _selectedDealer?.walletBalance ?? 0,
        officerName: _recoveryOfficerName,
        saving: false,
      ),
    );
    if (result == null) return;
    await _handleReceive(
      amount: result.amount,
      date: result.date,
      status: result.status,
      txType: result.txType,
      comment: result.comment,
    );
  }

  Future<void> _openEditDialog(TxDealerCollection c, int billNo) async {
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (_) => _EditDialog(
        billNo: billNo,
        dealerName: c.dealerName,
        amount: c.amount,
        status: c.settlementStatus,
        comment: c.comment,
      ),
    );
    if (result == null) return;
    await _handleEditSave(
      c,
      amount: result.amount,
      comment: result.comment,
      status: result.status,
    );
  }
}

// ===========================================================================
// Dialogs
// ===========================================================================

class _ReceiveResult {
  _ReceiveResult({
    required this.amount,
    required this.date,
    required this.status,
    required this.txType,
    required this.comment,
  });
  final double amount;
  final String date;
  final String status;
  final String txType;
  final String comment;
}

class _ReceiveDialog extends StatefulWidget {
  const _ReceiveDialog({
    required this.dealerName,
    required this.dealerId,
    required this.dealerAddress,
    required this.walletBalance,
    required this.officerName,
    required this.saving,
  });

  final String dealerName;
  final String dealerId;
  final String dealerAddress;
  final double walletBalance;
  final String officerName;
  final bool saving;

  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _comment = TextEditingController();
  late String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _status = 'pending';
  String _txType = 'cash';

  @override
  void dispose() {
    _amount.dispose();
    _comment.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('Receive Payment'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: NetField(
                      label: 'Dealer ID',
                      child: _readonly(widget.dealerId),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NetField(
                      label: 'Dealer Name',
                      child: _readonly(widget.dealerName),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: NetField(
                      label: 'Address',
                      child: _readonly(
                          widget.dealerAddress.isEmpty ? '---' : widget.dealerAddress),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NetField(
                      label: 'Wallet Balance',
                      child: _readonly('PKR ${salesNumber(widget.walletBalance)}'),
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
                  decoration: netInputDecoration(context, hint: 'Enter amount'),
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Pay Date',
                child: _dateField(context),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Payment Type',
                child: TxSearchableSelect(
                  label: '',
                  placeholder: 'Select payment type...',
                  searchPlaceholder: 'Search payment type...',
                  options: _kPaymentTypes,
                  value: _txType,
                  onChanged: (v) => setState(() => _txType = v ?? 'cash'),
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Status',
                child: TxSearchableSelect(
                  label: '',
                  placeholder: 'Select status...',
                  searchPlaceholder: 'Search status...',
                  options: _kStatusOptions,
                  value: _status,
                  onChanged: (v) => setState(() => _status = v ?? 'pending'),
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Comment',
                child: TextField(
                  controller: _comment,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14),
                  decoration: netInputDecoration(context, hint: 'Add a comment...'),
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: 'Receive',
                gradient: _kEmerald,
                onPressed: _value <= 0
                    ? null
                    : () => Navigator.of(context).pop(
                          _ReceiveResult(
                            amount: _value,
                            date: _date,
                            status: _status,
                            txType: _txType,
                            comment: _comment.text.trim(),
                          ),
                        ),
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

  Widget _dateField(BuildContext context) {
    return InkWell(
      onTap: () async {
        final initial = DateTime.tryParse(_date) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
        }
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.inputFill,
          border: Border.all(color: context.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 16, color: context.mutedFg),
            const SizedBox(width: 8),
            Text(_date, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
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

class _EditResult {
  _EditResult({
    required this.amount,
    required this.status,
    required this.comment,
  });
  final double amount;
  final String status;
  final String comment;
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.billNo,
    required this.dealerName,
    required this.amount,
    required this.status,
    required this.comment,
  });

  final int billNo;
  final String dealerName;
  final double amount;
  final String status;
  final String comment;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _amount =
      TextEditingController(text: widget.amount.toString());
  late final TextEditingController _comment =
      TextEditingController(text: widget.comment);
  late String _status = widget.status;

  @override
  void dispose() {
    _amount.dispose();
    _comment.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('Edit Collection Entry'),
      content: SizedBox(
        width: 440,
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
                      child: _readonly('${widget.billNo}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NetField(
                      label: 'Dealer',
                      child: _readonly(widget.dealerName),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Amount (PKR)',
                child: TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14),
                  decoration: netInputDecoration(context),
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Status',
                child: TxSearchableSelect(
                  label: '',
                  placeholder: 'Select status...',
                  searchPlaceholder: 'Search status...',
                  options: _kStatusOptions,
                  value: _status,
                  onChanged: (v) => setState(() => _status = v ?? 'pending'),
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Comment',
                child: TextField(
                  controller: _comment,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14),
                  decoration: netInputDecoration(context, hint: 'Add a comment...'),
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: 'Save Changes',
                gradient: _kEmerald,
                onPressed: _value <= 0
                    ? null
                    : () => Navigator.of(context).pop(
                          _EditResult(
                            amount: _value,
                            status: _status,
                            comment: _comment.text.trim(),
                          ),
                        ),
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
      child: Text(value, overflow: TextOverflow.ellipsis),
    );
  }
}