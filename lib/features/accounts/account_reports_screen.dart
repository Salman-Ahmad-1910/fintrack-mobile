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
/// `client/src/app/(app)/accounts/account-reports/page.tsx` — filter account
/// entries into a printable report.
class AccountReportsScreen extends StatefulWidget {
  const AccountReportsScreen({super.key});

  @override
  State<AccountReportsScreen> createState() => _AccountReportsScreenState();
}

class _AccountReportsScreenState extends State<AccountReportsScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);
  final TextEditingController _search = TextEditingController();

  List<AccountEntry> _entries = [];
  List<AccountHead> _heads = [];
  List<SubHead> _subHeads = [];
  List<AccountTxnType> _txnTypes = [];
  List<String> _users = [];
  SalesCompany _company = SalesCompany.empty;
  bool _loading = true;

  String _filterHead = 'All';
  String _filterSubHead = 'All';
  String _filterUser = 'All';
  String _filterTxnType = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
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
    final refsFuture = loadAccountRefs(_api, cid);
    final usersFuture = loadAccountUsers(_api, cid);
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
    final users = await usersFuture;
    final company = await companyFuture;
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _heads = refs.heads;
      _subHeads = refs.subHeads;
      _txnTypes = refs.txnTypes;
      _users = {
        ...users,
        for (final e in entries)
          if (e.addBy.isNotEmpty && e.addBy != '-') e.addBy,
      }.toList();
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

  List<AccountEntry> get _filtered {
    return _entries.where((e) {
      if (_filterHead != 'All' && e.head != _filterHead) return false;
      if (_filterSubHead != 'All' && e.subHead != _filterSubHead) return false;
      if (_filterUser != 'All' && e.addBy != _filterUser) return false;
      if (_filterTxnType != 'All' && e.transactionType != _filterTxnType) {
        return false;
      }
      if (_fromDate != null && e.date.compareTo(accIso(_fromDate!)) < 0) {
        return false;
      }
      if (_toDate != null && e.date.compareTo(accIso(_toDate!)) > 0) {
        return false;
      }
      return netContains(_search.text, [
        _headName(e.head),
        _subHeadName(e.subHead),
        e.description,
      ]);
    }).toList();
  }

  Future<void> _show() async {
    await _load();
    if (mounted) setState(() => _showReport = true);
  }

  Future<void> _printAll() async {
    await printAccountReport(
      context,
      _company,
      _filtered,
      _heads,
      _subHeads,
      _txnTypes,
      from: _fromDate != null ? accDdMmmYyyy(_fromDate!) : '',
      to: _toDate != null ? accDdMmmYyyy(_toDate!) : '',
      headFilter: _filterHead == 'All' ? '' : _filterHead,
      userFilter: _filterUser == 'All' ? '' : _filterUser,
    );
  }

  Future<void> _printEntry(AccountEntry entry) async {
    await printAccountEntry(
      context,
      _company,
      entry,
      _heads,
      _subHeads,
      _txnTypes,
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
    final filtered = _filtered;
    final totalAmount = filtered.fold<double>(0, (s, e) => s + e.amount);
    final fd = _fromDate != null ? accDdMmmYyyy(_fromDate!) : '';
    final td = _toDate != null ? accDdMmmYyyy(_toDate!) : '';

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.description_outlined,
            title: 'Account Reports',
            subtitle: 'Filter account entries into a printable report',
            gradient: accReportGradient,
          ),
          NetworkStatGrid(
            children: [
              NetworkStatCard(
                icon: Icons.receipt_long_outlined,
                label: 'Total Entries',
                value: '${filtered.length}',
                gradient: accReportGradient,
              ),
              NetworkStatCard(
                icon: Icons.payments_outlined,
                label: 'Total Amount',
                value: 'PKR ${accNumber(totalAmount)}',
                gradient: accEmeraldStatGradient,
                valueColor: AppColors.emerald600,
              ),
              NetworkStatCard(
                icon: Icons.date_range_outlined,
                label: 'Period',
                value: (fd.isEmpty && td.isEmpty) ? 'All time' : '$fd - $td',
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
            AppCard(child: _report(filtered, totalAmount)),
        ],
      ),
    );
  }

  Widget _filters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountFilterBar(
          filters: [
            AccountSelect(
              label: 'Account Head',
              value: _filterHead,
              placeholder: 'All',
              options: [
                const AccountOption('All', 'All'),
                for (final h in _heads) AccountOption(h.id, h.masterAccount),
              ],
              onChanged: (v) => setState(() => _filterHead = v),
            ),
            AccountSelect(
              label: 'Sub Head',
              value: _filterSubHead,
              placeholder: 'All',
              options: [
                const AccountOption('All', 'All'),
                for (final s in _subHeads)
                  AccountOption(s.id, s.subMasterAccount),
              ],
              onChanged: (v) => setState(() => _filterSubHead = v),
            ),
            AccountSelect(
              label: 'User',
              value: _filterUser,
              placeholder: 'All',
              options: [
                const AccountOption('All', 'All'),
                for (final u in _users) AccountOption(u, u),
              ],
              onChanged: (v) => setState(() => _filterUser = v),
            ),
            AccountSelect(
              label: 'Transaction Type',
              value: _filterTxnType,
              placeholder: 'All',
              options: [
                const AccountOption('All', 'All'),
                for (final t in _txnTypes)
                  AccountOption(t.id, t.paymentChannel),
              ],
              onChanged: (v) => setState(() => _filterTxnType = v),
            ),
            AccountDateField(
              label: 'From Date',
              value: _fromDate,
              placeholder: 'Pick date',
              onChanged: (d) => setState(() => _fromDate = d),
            ),
            AccountDateField(
              label: 'To Date',
              value: _toDate,
              placeholder: 'Pick date',
              onChanged: (d) => setState(() => _toDate = d),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            GradientButton(
              label: 'Show',
              icon: Icons.visibility_outlined,
              gradient: accEmeraldButtonGradient,
              onPressed: _show,
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: context.mutedFg,
              ),
              onPressed: _printAll,
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('Print All'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                foregroundColor: context.mutedFg,
              ),
              onPressed: () =>
                  showToast(context, 'Excel export is not available yet.'),
              icon: const Icon(Icons.download_outlined, size: 16),
              label: const Text('Excel'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _report(List<AccountEntry> filtered, double totalAmount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Account Entries',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14),
                decoration: netInputDecoration(
                  context,
                  hint: 'Search...',
                ).copyWith(
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: context.mutedFg),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        NetworkTable<AccountEntry>(
          rows: filtered,
          emptyIcon: Icons.description_outlined,
          emptyTitle: 'No entries found for the selected filters.',
          emptyHint: 'Adjust the filters and try again.',
          emptyTint: AppColors.primary,
          mobileTrailing: (context, entry, _) => AccountEntryActions(
            onEdit: () => _openEdit(entry),
            onPrint: () => _printEntry(entry),
            onDelete: () => _delete(entry),
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
                  onEdit: () => _openEdit(entry),
                  onPrint: () => _printEntry(entry),
                  onDelete: () => _delete(entry),
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
