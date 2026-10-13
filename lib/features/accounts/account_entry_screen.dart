import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'accounts_common.dart';
import 'accounts_models.dart';

/// Flutter counterpart of `client/src/app/(app)/accounts/account-entry/page.tsx`
/// — manage all account transactions and entries.
class AccountEntryScreen extends StatefulWidget {
  const AccountEntryScreen({super.key});

  @override
  State<AccountEntryScreen> createState() => _AccountEntryScreenState();
}

class _AccountEntryScreenState extends State<AccountEntryScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);
  final TextEditingController _search = TextEditingController();

  List<AccountEntry> _entries = [];
  List<AccountHead> _heads = [];
  List<SubHead> _subHeads = [];
  List<AccountTxnType> _txnTypes = [];
  List<String> _users = [];
  bool _loading = true;

  String _filterHead = 'All';
  String _filterSubHead = 'All';
  String _filterUser = 'All';
  String _filterBy = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;

  int _pageSize = 10;
  int _currentPage = 1;

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
  String get _author => Session.userName ?? 'Admin';

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

    var entries = <AccountEntry>[];
    try {
      final json = await _api.get('/accounts/entries', query: {'companyId': cid});
      entries = ApiClient.listData(json)
          .whereType<Map<String, dynamic>>()
          .map(AccountEntry.fromJson)
          .toList();
    } on ApiException {
      // Keep the previous list; the refs below are still worth refreshing.
    }

    final refs = await refsFuture;
    final users = await usersFuture;
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _heads = refs.heads;
      _subHeads = refs.subHeads;
      _txnTypes = refs.txnTypes;
      _users = users;
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

  /// Non-admin users only see the entries they added (web `displayEntries`).
  List<AccountEntry> get _displayEntries {
    if (kAccAdminRoles.contains(Session.role ?? '')) return _entries;
    final name = Session.userName ?? '';
    return _entries.where((e) => e.addBy == name).toList();
  }

  List<AccountEntry> get _filtered {
    return _displayEntries.where((e) {
      if (_filterHead != 'All' && e.head != _filterHead) return false;
      if (_filterSubHead != 'All' && e.subHead != _filterSubHead) return false;
      if (_filterUser != 'All' && e.addBy != _filterUser) return false;
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

  Future<void> _save(
    AccountEntryFormResult value,
    AccountEntry? existing,
  ) async {
    final amount = double.tryParse(value.amount.trim()) ?? 0;
    final date = value.date != null ? accIso(value.date!) : accTodayIso();
    try {
      final body = {
        'head': value.headId,
        'subHead': value.subHeadId,
        'description': value.description,
        'date': date,
        'addBy': existing?.addBy ?? _author,
        'editBy': existing != null ? _author : '-',
        'amount': amount,
        'transactionType': value.txnTypeId,
        'companyId': _cid ?? '',
      };
      if (existing != null) {
        await _api.put('/accounts/entries/${existing.id}', body: body);
        if (mounted) showToast(context, 'Entry updated.');
      } else {
        await _api.post('/accounts/entries', body: body);
        if (mounted) showToast(context, 'Entry added.');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(AccountEntry entry) async {
    await showNetworkDeleteDialog(
      context,
      itemName: _headName(entry.head),
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

  Future<void> _openForm([AccountEntry? entry]) async {
    final result = await showAccountEntryForm(
      context,
      heads: _heads,
      subHeads: _subHeads,
      txnTypes: _txnTypes,
      entry: entry,
    );
    if (result != null) await _save(result, entry);
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = accCrud('13323', 'create');
    final canUpdate = accCrud('13323', 'update');
    final canDelete = accCrud('13323', 'delete');
    final totalAmount = _displayEntries.fold<double>(0, (s, e) => s + e.amount);
    final txnTypes = _displayEntries
        .map((e) => e.transactionType)
        .where((t) => t.isNotEmpty)
        .toSet()
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.menu_book_outlined,
            title: 'Account Entry',
            subtitle: 'Manage all account transactions and entries',
            gradient: accEntryGradient,
          ),
          NetworkStatGrid(
            children: [
              NetworkStatCard(
                icon: Icons.description_outlined,
                label: 'Total Entries',
                value: '${_displayEntries.length}',
                gradient: accEntryGradient,
              ),
              NetworkStatCard(
                icon: Icons.payments_outlined,
                label: 'Total Amount',
                value: 'PKR ${accNumber(totalAmount)}',
                gradient: accEmeraldStatGradient,
                valueColor: AppColors.emerald600,
              ),
              NetworkStatCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Transaction Types',
                value: '$txnTypes',
                gradient: accAmberStatGradient,
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppCard(child: _filters(canCreate)),
          const SizedBox(height: 24),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            AppCard(child: _table(canUpdate, canDelete)),
        ],
      ),
    );
  }

  Widget _filters(bool canCreate) {
    return AccountFilterBar(
      actions: [
        if (canCreate)
          GradientButton(
            label: 'Add Entry',
            icon: Icons.add_circle_outline,
            gradient: accEmeraldButtonGradient,
            onPressed: () => _openForm(),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: context.mutedFg,
          ),
          onPressed: () => setState(() {
            _filterHead = 'All';
            _filterSubHead = 'All';
            _filterUser = 'All';
            _filterBy = 'All';
            _fromDate = null;
            _toDate = null;
            _search.clear();
            _currentPage = 1;
          }),
          icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
          label: const Text('Reset'),
        ),
      ],
      filters: [
        AccountSelect(
          label: 'Account Head',
          value: _filterHead,
          placeholder: 'All',
          options: [
            const AccountOption('All', 'All'),
            for (final h in _heads) AccountOption(h.id, h.masterAccount),
          ],
          onChanged: (v) => setState(() {
            _filterHead = v;
            _currentPage = 1;
          }),
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
          onChanged: (v) => setState(() {
            _filterSubHead = v;
            _currentPage = 1;
          }),
        ),
        AccountSelect(
          label: 'Users',
          value: _filterUser,
          placeholder: 'All',
          options: [
            const AccountOption('All', 'All'),
            for (final u in _users) AccountOption(u, u),
          ],
          onChanged: (v) => setState(() {
            _filterUser = v;
            _currentPage = 1;
          }),
        ),
        AccountSelect(
          label: 'Filter By',
          value: _filterBy,
          placeholder: 'All',
          options: [
            for (final o in accountFilterByOptions) AccountOption(o, o),
          ],
          onChanged: (v) => setState(() {
            _filterBy = v;
            _currentPage = 1;
          }),
        ),
        AccountDateField(
          label: 'From Date',
          value: _fromDate,
          placeholder: 'Pick date',
          onChanged: (d) => setState(() {
            _fromDate = d;
            _currentPage = 1;
          }),
        ),
        AccountDateField(
          label: 'To Date',
          value: _toDate,
          placeholder: 'Pick date',
          onChanged: (d) => setState(() {
            _toDate = d;
            _currentPage = 1;
          }),
        ),
      ],
    );
  }

  Widget _table(bool canUpdate, bool canDelete) {
    final filtered = _filtered;
    final totalPages =
        filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
    final current = _currentPage.clamp(1, totalPages);
    final pageRows = filtered
        .skip((current - 1) * _pageSize)
        .take(_pageSize)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() => _currentPage = 1),
                    style: const TextStyle(fontSize: 14),
                    decoration: netInputDecoration(
                      context,
                      hint: 'Search by head, sub head or description...',
                    ).copyWith(
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: context.mutedFg,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        NetworkTable<AccountEntry>(
          rows: pageRows,
          emptyIcon: Icons.menu_book_outlined,
          emptyTitle: 'No account entries found.',
          emptyHint: 'Get started by adding a new entry.',
          emptyTint: AppColors.emerald600,
          mobileTrailing: (context, entry, _) => NetworkRowActions(
            onEdit: canUpdate ? () => _openForm(entry) : null,
            onDelete: canDelete ? () => _delete(entry) : null,
          ),
          columns: [
            NetColumn(
              label: 'ID',
              width: 60,
              builder: (context, entry, index) => Text(
                '${index + 1 + (current - 1) * _pageSize}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: context.mutedFg,
                ),
              ),
            ),
            NetColumn(
              label: 'Head',
              width: 150,
              builder: (context, entry, _) => Text(
                _headName(entry.head),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            NetColumn(
              label: 'Sub Head',
              width: 150,
              builder: (context, entry, _) => Text(
                _subHeadName(entry.subHead),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            NetColumn(
              label: 'Description',
              width: 220,
              builder: (context, entry, _) => Text(
                entry.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            NetColumn(
              label: 'Date',
              width: 110,
              builder: (context, entry, _) => Text(entry.date),
            ),
            NetColumn(
              label: 'Add By',
              width: 100,
              builder: (context, entry, _) => Text(entry.addBy),
            ),
            NetColumn(
              label: 'Edit By',
              width: 100,
              builder: (context, entry, _) => Text(entry.editBy),
            ),
            NetColumn(
              label: 'Action',
              width: 96,
              isActions: true,
              builder: (context, entry, _) => Align(
                alignment: Alignment.centerRight,
                child: NetworkRowActions(
                  onEdit: canUpdate ? () => _openForm(entry) : null,
                  onDelete: canDelete ? () => _delete(entry) : null,
                ),
              ),
            ),
          ],
        ),
        if (filtered.isNotEmpty)
          NetworkPagination(
            currentPage: current,
            pageSize: _pageSize,
            totalItems: filtered.length,
            noun: 'entries',
            pageSizes: const [5, 10, 25, 50, 100],
            onPageChanged: (p) => setState(() => _currentPage = p),
            onPageSizeChanged: (s) => setState(() {
              _pageSize = s;
              _currentPage = 1;
            }),
          ),
      ],
    );
  }
}
