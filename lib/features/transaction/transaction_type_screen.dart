import 'package:flutter/material.dart';

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

const List<Color> _kSlateGradient = [Color(0xFF334155), Color(0xFF64748B)];
const List<Color> _kGreenGradient = [Color(0xFF059669), Color(0xFF16A34A)];
const List<Color> _kBlueGradient = [Color(0xFF1D4ED8), Color(0xFF0891B2)];
const List<Color> _kAmberGradient = [Color(0xFFB45309), Color(0xFFFB923C)];

const List<String> _kPaymentChannels = [
  'Al Habib Bank',
  'Allied Bank',
  'Askari Bank',
  'Bank Al-Falah',
  'Bank Al-Habib',
  'Bank Islami',
  'Bank of Punjab',
  'Bank of Khyber',
  'Dubai Islamic Bank',
  'Faysal Bank',
  'Habib Bank (HBL)',
  'Habib Metro',
  'JS Bank',
  'MCB Bank',
  'Meezan Bank',
  'National Bank (NBP)',
  'Samba Bank',
  'Silk Bank',
  'Sindh Bank',
  'Soneri Bank',
  'Standard Chartered',
  'Summit Bank',
  'United Bank (UBL)',
  'Easypaisa',
  'JazzCash',
  'U-Paisa',
  'SadaPay',
  'NayaPay',
  'Keenu',
  'Cash',
  'Other',
];

/// Flutter counterpart of
/// `client/src/app/(app)/transaction/transaction-type/page.tsx`.
class TransactionTypeScreen extends StatefulWidget {
  const TransactionTypeScreen({super.key});

  @override
  State<TransactionTypeScreen> createState() => _TransactionTypeScreenState();
}

class _TransactionTypeScreenState extends State<TransactionTypeScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<TxTransactionType> _records = [];
  bool _loading = true;
  String _filter = '';
  int _page = 1;
  int _pageSize = 10;
  final TextEditingController _search = TextEditingController();

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
      final json = await _api.get(
        '/billing/transaction-types',
        query: {'companyId': cid},
      );
      if (!mounted) return;
      setState(() {
        _records = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(TxTransactionType.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<TxTransactionType> get _filtered {
    if (_filter.trim().isEmpty) return _records;
    return salesSmartSearch<TxTransactionType>(
      _filter,
      _records,
      (r) => [
        ['${r.id}'],
        [r.transaction, r.title, r.paymentChannel],
      ],
    );
  }

  List<TxTransactionType> get _pageRows {
    final start = (_page - 1) * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  void _setFilter(String value) {
    setState(() {
      _filter = value;
      _page = 1;
    });
  }

  bool get _canCreate => txHasPermission(kTxCanCreate);
  bool get _canUpdate => txHasPermission(kTxCanUpdate);
  bool get _canDelete => txHasPermission(kTxCanDelete);

  Future<void> _save(Map<String, dynamic> values, TxTransactionType? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/billing/transaction-types/${existing.id}?companyId=$cid',
          body: values,
        );
        if (mounted) showToast(context, 'Transaction type updated.');
      } else {
        await _api.post(
          '/billing/transaction-types?companyId=$cid',
          body: values,
        );
        if (mounted) showToast(context, 'Transaction type created.');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(TxTransactionType record) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    await showNetworkDeleteDialog(
      context,
      itemName: record.transaction,
      onConfirm: () async {
        try {
          await _api.delete(
            '/billing/transaction-types/${record.id}?companyId=$cid',
          );
          if (mounted) showToast(context, 'Transaction type deleted.');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openForm(TxTransactionType? record) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TransactionTypeFormDialog(record: record),
    );
    if (result != null) await _save(result, record);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.settings_applications_outlined,
            title: 'Transaction Type',
            subtitle: 'Manage transaction types and payment channels.',
            gradient: _kSlateGradient,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NetworkStatGrid(
                      children: [
                        NetworkStatCard(
                          icon: Icons.settings_applications_outlined,
                          label: 'Transaction Types',
                          value: '${_records.length}',
                          gradient: _kSlateGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.list_alt_outlined,
                          label: 'Payment Channels',
                          value: '${_kPaymentChannels.length}',
                          gradient: _kBlueGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.search,
                          label: 'Filtered',
                          value: '${_filtered.length}',
                          gradient: _kAmberGradient,
                          valueColor: context.isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SalesFilterRows(
                      rows: [
                        [
                          SizedBox(
                            width: 320,
                            child: txSearchField(
                              context: context,
                              controller: _search,
                              onChanged: _setFilter,
                              hint: 'Search transactions...',
                            ),
                          ),
                        ],
                        [
                          TxSelect(
                            width: 110,
                            value: '$_pageSize',
                            items: {
                              '10': '10',
                              '50': '50',
                              '100': '100',
                            },
                            onChanged: (v) => setState(() {
                              _pageSize = int.parse(v);
                              _page = 1;
                            }),
                          ),
                          if (_canCreate)
                            GradientButton(
                              label: 'Add Transaction',
                              icon: Icons.add,
                              gradient: _kGreenGradient,
                              onPressed: () => _openForm(null),
                            ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    NetworkTable<TxTransactionType>(
                      rows: _pageRows,
                      emptyIcon: Icons.settings_applications_outlined,
                      emptyTitle: _filter.trim().isEmpty
                          ? 'No transaction types found.'
                          : 'No matching transaction types found.',
                      emptyHint: _filter.trim().isEmpty
                          ? 'Get started by adding a transaction type.'
                          : 'Try adjusting your search.',
                      emptyTint: AppColors.emerald600,
                      mobileTrailing: (context, record, _) =>
                          NetworkRowActions(
                            onEdit: _canUpdate ? () => _openForm(record) : null,
                            onDelete: _canDelete ? () => _delete(record) : null,
                          ),
                      columns: [
                        NetColumn(
                          label: 'ID',
                          width: 72,
                          builder: (context, record, index) => Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: context.mutedFg,
                            ),
                          ),
                        ),
                        NetColumn(
                          label: 'Payment Channel',
                          width: 280,
                          builder: (context, record, _) => Text(
                            record.paymentChannel.isEmpty ? '---' : record.paymentChannel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        NetColumn(
                          label: 'Actions',
                          width: 96,
                          isActions: true,
                          builder: (context, record, _) => Align(
                            alignment: Alignment.centerRight,
                            child: NetworkRowActions(
                              onEdit: _canUpdate ? () => _openForm(record) : null,
                              onDelete: _canDelete ? () => _delete(record) : null,
                              editTooltip: 'Edit transaction type',
                              deleteTooltip: 'Delete transaction type',
                            ),
                          ),
                        ),
                      ],
                    ),
                    NetworkPagination(
                      currentPage: _page,
                      pageSize: _pageSize,
                      totalItems: _filtered.length,
                      noun: 'transaction types',
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
            ),
        ],
      ),
    );
  }
}

class _TransactionTypeFormDialog extends StatefulWidget {
  const _TransactionTypeFormDialog({this.record});

  final TxTransactionType? record;

  @override
  State<_TransactionTypeFormDialog> createState() =>
      _TransactionTypeFormDialogState();
}

class _TransactionTypeFormDialogState extends State<_TransactionTypeFormDialog> {
  late final TextEditingController _transaction;
  String _paymentChannel = '';

  bool get _isSaving => false;

  @override
  void initState() {
    super.initState();
    _transaction = TextEditingController(text: widget.record?.transaction ?? '');
    _paymentChannel = widget.record?.paymentChannel ?? '';
  }

  @override
  void dispose() {
    _transaction.dispose();
    super.dispose();
  }

  void _submit() {
    if (_transaction.text.trim().isEmpty) return;
    Navigator.of(context).pop({
      'transaction': _transaction.text.trim(),
      'paymentChannel': _paymentChannel,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.record != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: _kGreenGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.settings_applications_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(editing ? 'Edit Transaction Type' : 'Add Transaction'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NetField(
              label: 'Transaction',
              child: TextFormField(
                controller: _transaction,
                decoration: netInputDecoration(
                  context,
                  hint: 'e.g. Cash Collection',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 14),
            NetField(
              label: 'Payment Channel / Bank',
              child: DropdownButtonFormField<String>(
                initialValue: _paymentChannel,
                isExpanded: true,
                decoration: netInputDecoration(
                  context,
                  hint: 'Select a bank or payment channel...',
                ),
                items: [
                  for (final ch in _kPaymentChannels)
                    DropdownMenuItem(value: ch, child: Text(ch)),
                ],
                onChanged: (v) => setState(() => _paymentChannel = v ?? ''),
              ),
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: 'Save',
              gradient: _kGreenGradient,
              loading: _isSaving,
              onPressed: _transaction.text.trim().isEmpty ? null : _submit,
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
}