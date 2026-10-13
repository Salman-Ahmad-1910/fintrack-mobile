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
import 'accounts_common.dart';
import 'accounts_models.dart';
import 'accounts_print.dart';

/// Flutter counterpart of
/// `client/src/app/(app)/accounts/one-day-balance-sheet/page.tsx` — every
/// account entry for a single day.
class OneDayBalanceSheetScreen extends StatefulWidget {
  const OneDayBalanceSheetScreen({super.key});

  @override
  State<OneDayBalanceSheetScreen> createState() =>
      _OneDayBalanceSheetScreenState();
}

class _OneDayBalanceSheetScreenState extends State<OneDayBalanceSheetScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<AccountEntry> _entries = [];
  List<AccountHead> _heads = [];
  List<SubHead> _subHeads = [];
  List<AccountTxnType> _txnTypes = [];
  SalesCompany _company = SalesCompany.empty;
  bool _loading = true;

  DateTime _selectedDate = DateTime.now();
  String _filterHead = 'All';
  String _filterSubHead = 'All';
  bool _showReport = false;

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

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final refsFuture = loadAccountRefs(_api, cid);
    final companyFuture = fetchSalesCompany(_api);

    var entries = <AccountEntry>[];
    try {
      final json = await _api.get('/accounts/entries', query: {'companyId': cid});
      entries = ApiClient.listData(json)
          .whereType<Map<String, dynamic>>()
          .map(AccountEntry.fromJson)
          .toList();
    } on ApiException {
      // Keep the previous list; refs below are still worth refreshing.
    }

    final refs = await refsFuture;
    final company = await companyFuture;
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _heads = refs.heads;
      _subHeads = refs.subHeads;
      _txnTypes = refs.txnTypes;
      _company = company;
      _loading = false;
    });
  }

  String _headName(String id) {
    for (final h in _heads) {
      if (h.id == id) return h.masterAccount.isEmpty ? id : h.masterAccount;
    }
    return id;
  }

  String _subHeadName(String id) {
    for (final s in _subHeads) {
      if (s.id == id) return s.subMasterAccount.isEmpty ? id : s.subMasterAccount;
    }
    return id;
  }

  String _txnName(String id) {
    for (final t in _txnTypes) {
      if (t.id == id) return t.paymentChannel.isEmpty ? id : t.paymentChannel;
    }
    return id;
  }

  List<SubHead> get _filterHeadSubHeads => _filterHead == 'All'
      ? _subHeads
      : _subHeads.where((s) => s.masterAccountId == _filterHead).toList();

  String get _dateStr => accIso(_selectedDate);

  List<AccountEntry> get _filtered {
    return _entries.where((e) {
      if (e.date != _dateStr) return false;
      if (_filterHead != 'All' && e.head != _filterHead) return false;
      if (_filterSubHead != 'All' && e.subHead != _filterSubHead) return false;
      return true;
    }).toList();
  }

  Future<void> _printAll(List<AccountEntry> filtered) async {
    await printOneDayBalance(
      context,
      _company,
      filtered,
      _heads,
      _subHeads,
      _txnTypes,
      dateLabel: accDdMmmYyyy(_selectedDate),
    );
  }

  Future<void> _openEdit(AccountEntry entry) async {
    final result = await showAccountEntryForm(
      context,
      heads: _heads,
      subHeads: _subHeads,
      txnTypes: _txnTypes,
      entry: entry,
    );
    if (result == null) return;
    try {
      final body = {
        'head': result.headId,
        'subHead': result.subHeadId,
        'description': result.description,
        'date': result.date != null ? accIso(result.date!) : entry.date,
        'addBy': entry.addBy,
        'editBy': 'Admin',
        'amount': double.tryParse(result.amount.trim()) ?? 0,
        'transactionType': result.txnTypeId,
        'companyId': _cid ?? '',
      };
      await _api.put('/accounts/entries/${entry.id}', body: body);
      if (mounted) showToast(context, 'Entry updated.');
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(AccountEntry entry) async {
    await showNetworkDeleteDialog(
      context,
      itemName: '${_headName(entry.head)} — ${_subHeadName(entry.subHead)}',
      onConfirm: () async {
        try {
          await _api.delete('/accounts/entries/${entry.id}');
          if (mounted) showToast(context, 'Entry deleted.');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUpdate = accCrud('13341', 'update');
    final canDelete = accCrud('13341', 'delete');
    final filtered = _filtered;
    final totalAmount = filtered.fold<double>(0, (s, e) => s + e.amount);
    final fd = accDdMmmYyyy(_selectedDate);

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.bar_chart_outlined,
            title: 'One Day Balance Sheet',
            subtitle: 'View all account entries for a specific day',
            gradient: accOneDayGradient,
          ),
          NetworkStatGrid(
            children: [
              NetworkStatCard(
                icon: Icons.event_outlined,
                label: 'Report Date',
                value: fd,
                gradient: accOneDayGradient,
              ),
              NetworkStatCard(
                icon: Icons.receipt_long_outlined,
                label: 'Total Entries',
                value: '${filtered.length}',
                gradient: accEmeraldStatGradient,
              ),
              NetworkStatCard(
                icon: Icons.payments_outlined,
                label: 'Total Amount',
                value: 'PKR ${accNumber(totalAmount)}',
                gradient: accBlueStatGradient,
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppCard(child: _filters()),
          const SizedBox(height: 24),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_showReport)
            AppCard(
              child: _report(filtered, totalAmount, fd, canUpdate, canDelete),
            ),
        ],
      ),
    );
  }

  Widget _filters() {
    return AccountFilterBar(
      actions: [
        GradientButton(
          label: 'Show',
          icon: Icons.visibility_outlined,
          gradient: accEmeraldButtonGradient,
          onPressed: () => setState(() => _showReport = true),
        ),
      ],
      filters: [
        AccountSelect(
          label: 'Account Head',
          value: _filterHead,
          placeholder: 'All Heads',
          options: [
            const AccountOption('All', 'All Heads'),
            for (final h in _heads) AccountOption(h.id, h.masterAccount),
          ],
          onChanged: (v) => setState(() {
            _filterHead = v;
            _filterSubHead = 'All';
          }),
        ),
        AccountSelect(
          label: 'Sub Head',
          value: _filterSubHead,
          placeholder: 'All Sub Heads',
          options: [
            const AccountOption('All', 'All Sub Heads'),
            for (final s in _filterHeadSubHeads)
              AccountOption(s.id, s.subMasterAccount),
          ],
          onChanged: (v) => setState(() => _filterSubHead = v),
        ),
        AccountDateField(
          label: 'Date',
          value: _selectedDate,
          placeholder: 'Pick date',
          onChanged: (d) => setState(() => _selectedDate = d),
        ),
      ],
    );
  }

  Widget _report(
    List<AccountEntry> filtered,
    double totalAmount,
    String fd,
    bool canUpdate,
    bool canDelete,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OD Balance Sheet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'All entries for $fd',
                    style: TextStyle(fontSize: 13, color: context.mutedFg),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                foregroundColor: context.mutedFg,
              ),
              onPressed: filtered.isEmpty ? null : () => _printAll(filtered),
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('Print All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        NetworkTable<AccountEntry>(
          rows: filtered,
          emptyIcon: Icons.bar_chart_outlined,
          emptyTitle: 'No entries found for $fd.',
          emptyHint: 'Try another date or adjust the filters.',
          emptyTint: AppColors.primary,
          mobileTrailing: (context, entry, _) => AccountEntryActions(
            onEdit: canUpdate ? () => _openEdit(entry) : null,
            onPrint: () => printOneDayBalance(
              context,
              _company,
              [entry],
              _heads,
              _subHeads,
              _txnTypes,
              dateLabel: fd,
            ),
            onDelete: canDelete ? () => _delete(entry) : null,
          ),
          columns: [
            NetColumn(
              label: '#',
              width: 50,
              builder: (context, entry, index) => Text(
                '${index + 1}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: context.mutedFg,
                ),
              ),
            ),
            NetColumn(
              label: 'Date',
              width: 110,
              builder: (context, entry, _) => Text(entry.date),
            ),
            NetColumn(
              label: 'Head',
              width: 160,
              builder: (context, entry, _) => Text(
                _headName(entry.head),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            NetColumn(
              label: 'Sub Head',
              width: 150,
              builder: (context, entry, _) => Text(_subHeadName(entry.subHead)),
            ),
            NetColumn(
              label: 'Description',
              width: 200,
              builder: (context, entry, _) => Text(
                entry.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            NetColumn(
              label: 'Amount (PKR)',
              width: 120,
              builder: (context, entry, _) => Text(
                accNumber(entry.amount),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            NetColumn(
              label: 'Transaction Type',
              width: 140,
              builder: (context, entry, _) =>
                  Text(_txnName(entry.transactionType)),
            ),
            NetColumn(
              label: 'Add By',
              width: 100,
              builder: (context, entry, _) => Text(entry.addBy),
            ),
            NetColumn(
              label: 'Action',
              width: 120,
              isActions: true,
              builder: (context, entry, _) => Align(
                alignment: Alignment.centerRight,
                child: AccountEntryActions(
                  onEdit: canUpdate ? () => _openEdit(entry) : null,
                  onPrint: () => printOneDayBalance(
                    context,
                    _company,
                    [entry],
                    _heads,
                    _subHeads,
                    _txnTypes,
                    dateLabel: fd,
                  ),
                  onDelete: canDelete ? () => _delete(entry) : null,
                ),
              ),
            ),
          ],
        ),
        if (filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Total: ',
                      style: TextStyle(color: context.mutedFg),
                    ),
                    TextSpan(
                      text: 'PKR ${accNumber(totalAmount)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: ' (${filtered.length} entries)',
                      style: TextStyle(color: context.mutedFg),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }
}
