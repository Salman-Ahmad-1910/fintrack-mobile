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

/// Flutter counterpart of `client/src/app/(app)/accounts/account-head/page.tsx`
/// — manage account heads and their sub heads.
class AccountHeadScreen extends StatefulWidget {
  const AccountHeadScreen({super.key});

  @override
  State<AccountHeadScreen> createState() => _AccountHeadScreenState();
}

class _AccountHeadScreenState extends State<AccountHeadScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  final TextEditingController _searchHead = TextEditingController();
  final TextEditingController _searchSub = TextEditingController();

  List<AccountHead> _heads = [];
  List<SubHead> _subHeads = [];
  bool _loading = true;

  int _headPageSize = 10;
  int _headCurrent = 1;
  int _subPageSize = 10;
  int _subCurrent = 1;

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
    _searchHead.dispose();
    _searchSub.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final refs = await loadAccountRefs(_api, cid);
    if (!mounted) return;
    setState(() {
      _heads = refs.heads;
      _subHeads = refs.subHeads;
      _loading = false;
    });
  }

  AccountHead? _findHead(String id) {
    for (final h in _heads) {
      if (h.id == id) return h;
    }
    return null;
  }

  List<AccountHead> get _filteredHeads => _heads
      .where((h) => netContains(_searchHead.text, [
            h.masterAccount,
            h.accountType,
            h.description,
          ]))
      .toList();

  List<SubHead> get _filteredSubHeads => _subHeads
      .where((s) => netContains(_searchSub.text, [
            s.subMasterAccount,
            s.masterAccount,
            s.accountType,
            s.description,
          ]))
      .toList();

  Future<void> _saveHead(
    ({String masterAccount, String accountType, String description}) value,
    AccountHead? existing,
  ) async {
    try {
      final body = {
        'masterAccount': value.masterAccount,
        'accountType': value.accountType,
        'description': value.description,
        'companyId': _cid ?? '',
      };
      if (existing != null) {
        await _api.put('/accounts/heads/${existing.id}', body: body);
        if (mounted) showToast(context, 'Account head updated.');
      } else {
        await _api.post('/accounts/heads', body: body);
        if (mounted) showToast(context, 'Account head added.');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _deleteHead(AccountHead head) async {
    await showNetworkDeleteDialog(
      context,
      itemName: head.masterAccount,
      onConfirm: () async {
        try {
          await _api.delete('/accounts/heads/${head.id}');
          if (mounted) showToast(context, 'Account head deleted.');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _saveSubHead(
    ({String subMasterAccount, String masterAccountId, String budget, String description})
        value,
    SubHead? existing,
  ) async {
    final head = _findHead(value.masterAccountId);
    try {
      final body = {
        'subMasterAccount': value.subMasterAccount,
        'masterAccountId': value.masterAccountId,
        'masterAccount': head?.masterAccount ?? '',
        'accountType': head?.accountType ?? '',
        'budget': value.budget,
        'description': value.description,
        'companyId': _cid ?? '',
      };
      if (existing != null) {
        await _api.put('/accounts/sub-heads/${existing.id}', body: body);
        if (mounted) showToast(context, 'Sub head updated.');
      } else {
        await _api.post('/accounts/sub-heads', body: body);
        if (mounted) showToast(context, 'Sub head added.');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _deleteSubHead(SubHead sub) async {
    await showNetworkDeleteDialog(
      context,
      itemName: sub.subMasterAccount,
      onConfirm: () async {
        try {
          await _api.delete('/accounts/sub-heads/${sub.id}');
          if (mounted) showToast(context, 'Sub head deleted.');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openHeadForm([AccountHead? head]) async {
    final result =
        await showDialog<({String masterAccount, String accountType, String description})>(
      context: context,
      builder: (_) => _HeadFormDialog(head: head),
    );
    if (result != null) await _saveHead(result, head);
  }

  Future<void> _openSubHeadForm([SubHead? sub]) async {
    final result = await showDialog<
        ({String subMasterAccount, String masterAccountId, String budget, String description})>(
      context: context,
      builder: (_) => _SubHeadFormDialog(sub: sub, heads: _heads),
    );
    if (result != null) await _saveSubHead(result, sub);
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = accCrud('13322', 'create');
    final canUpdate = accCrud('13322', 'update');
    final canDelete = accCrud('13322', 'delete');
    final accountTypes = _heads.map((h) => h.accountType).toSet().length;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.layers_outlined,
            title: 'Account Head',
            subtitle: 'Manage account heads and sub heads',
            gradient: accHeadGradient,
          ),
          NetworkStatGrid(
            children: [
              NetworkStatCard(
                icon: Icons.layers_outlined,
                label: 'Total Heads',
                value: '${_heads.length}',
                gradient: accHeadGradient,
              ),
              NetworkStatCard(
                icon: Icons.account_tree_outlined,
                label: 'Total Sub Heads',
                value: '${_subHeads.length}',
                gradient: const [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                valueColor: const Color(0xFF2563EB),
              ),
              NetworkStatCard(
                icon: Icons.category_outlined,
                label: 'Account Types',
                value: '$accountTypes',
                gradient: const [Color(0xFF10B981), Color(0xFF16A34A)],
                valueColor: AppColors.emerald600,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _headsCard(canCreate, canUpdate, canDelete),
            const SizedBox(height: 24),
            _subHeadsCard(canCreate, canUpdate, canDelete),
          ],
        ],
      ),
    );
  }

  Widget _headsCard(bool canCreate, bool canUpdate, bool canDelete) {
    final filtered = _filteredHeads;
    final totalPages =
        filtered.isEmpty ? 1 : (filtered.length / _headPageSize).ceil();
    final current = _headCurrent.clamp(1, totalPages);
    final pageRows = filtered
        .skip((current - 1) * _headPageSize)
        .take(_headPageSize)
        .toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Account Heads',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              if (canCreate)
                GradientButton(
                  label: 'Add Head',
                  icon: Icons.add_circle_outline,
                  gradient: const [Color(0xFF10B981), Color(0xFF16A34A)],
                  onPressed: () => _openHeadForm(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchHead,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14),
            decoration: netInputDecoration(
              context,
              hint: 'Search heads...',
            ).copyWith(
              prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
            ),
          ),
          const SizedBox(height: 16),
          NetworkTable<AccountHead>(
            rows: pageRows,
            emptyIcon: Icons.layers_outlined,
            emptyTitle: 'No account heads found.',
            emptyHint: 'Get started by adding a new account head.',
            emptyTint: AppColors.emerald600,
            mobileTrailing: (context, head, _) => NetworkRowActions(
              onEdit: canUpdate ? () => _openHeadForm(head) : null,
              onDelete: canDelete ? () => _deleteHead(head) : null,
            ),
            columns: [
              NetColumn(
                label: 'ID',
                width: 70,
                builder: (context, head, index) => Text(
                  '${index + 1 + (current - 1) * _headPageSize}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: context.mutedFg,
                  ),
                ),
              ),
              NetColumn(
                label: 'Master Account',
                width: 200,
                builder: (context, head, _) => Text(
                  head.masterAccount,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              NetColumn(
                label: 'Account Type',
                width: 190,
                builder: (context, head, _) => Text(head.accountType),
              ),
              NetColumn(
                label: 'Description',
                width: 280,
                builder: (context, head, _) => Text(
                  head.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              NetColumn(
                label: 'Action',
                width: 96,
                isActions: true,
                builder: (context, head, _) => Align(
                  alignment: Alignment.centerRight,
                  child: NetworkRowActions(
                    onEdit: canUpdate ? () => _openHeadForm(head) : null,
                    onDelete: canDelete ? () => _deleteHead(head) : null,
                  ),
                ),
              ),
            ],
          ),
          if (filtered.isNotEmpty)
            NetworkPagination(
              currentPage: current,
              pageSize: _headPageSize,
              totalItems: filtered.length,
              noun: 'entries',
              pageSizes: const [5, 10, 25, 50, 100],
              onPageChanged: (p) => setState(() => _headCurrent = p),
              onPageSizeChanged: (s) => setState(() {
                _headPageSize = s;
                _headCurrent = 1;
              }),
            ),
        ],
      ),
    );
  }

  Widget _subHeadsCard(bool canCreate, bool canUpdate, bool canDelete) {
    final filtered = _filteredSubHeads;
    final totalPages =
        filtered.isEmpty ? 1 : (filtered.length / _subPageSize).ceil();
    final current = _subCurrent.clamp(1, totalPages);
    final pageRows = filtered
        .skip((current - 1) * _subPageSize)
        .take(_subPageSize)
        .toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Account Sub Heads',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              if (canCreate)
                GradientButton(
                  label: 'Add Sub Head',
                  icon: Icons.add_circle_outline,
                  gradient: const [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                  onPressed: () => _openSubHeadForm(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchSub,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14),
            decoration: netInputDecoration(
              context,
              hint: 'Search sub heads...',
            ).copyWith(
              prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
            ),
          ),
          const SizedBox(height: 16),
          NetworkTable<SubHead>(
            rows: pageRows,
            emptyIcon: Icons.account_tree_outlined,
            emptyTitle: 'No sub heads found.',
            emptyHint: 'Get started by adding a new sub head.',
            emptyTint: AppColors.primary,
            mobileTrailing: (context, sub, _) => NetworkRowActions(
              onEdit: canUpdate ? () => _openSubHeadForm(sub) : null,
              onDelete: canDelete ? () => _deleteSubHead(sub) : null,
            ),
            columns: [
              NetColumn(
                label: 'ID',
                width: 60,
                builder: (context, sub, index) => Text(
                  '${index + 1 + (current - 1) * _subPageSize}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: context.mutedFg,
                  ),
                ),
              ),
              NetColumn(
                label: 'Sub Master Account',
                width: 170,
                builder: (context, sub, _) => Text(
                  sub.subMasterAccount,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              NetColumn(
                label: 'Master Account',
                width: 160,
                builder: (context, sub, _) => Text(sub.masterAccount),
              ),
              NetColumn(
                label: 'Budget',
                width: 110,
                builder: (context, sub, _) => Text(
                  sub.budget.isEmpty
                      ? '-'
                      : 'Rs. ${accNumber(double.tryParse(sub.budget))}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              NetColumn(
                label: 'Account Type',
                width: 150,
                builder: (context, sub, _) => Text(sub.accountType),
              ),
              NetColumn(
                label: 'Description',
                width: 200,
                builder: (context, sub, _) => Text(
                  sub.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              NetColumn(
                label: 'Action',
                width: 96,
                isActions: true,
                builder: (context, sub, _) => Align(
                  alignment: Alignment.centerRight,
                  child: NetworkRowActions(
                    onEdit: canUpdate ? () => _openSubHeadForm(sub) : null,
                    onDelete: canDelete ? () => _deleteSubHead(sub) : null,
                  ),
                ),
              ),
            ],
          ),
          if (filtered.isNotEmpty)
            NetworkPagination(
              currentPage: current,
              pageSize: _subPageSize,
              totalItems: filtered.length,
              noun: 'entries',
              pageSizes: const [5, 10, 25, 50, 100],
              onPageChanged: (p) => setState(() => _subCurrent = p),
              onPageSizeChanged: (s) => setState(() {
                _subPageSize = s;
                _subCurrent = 1;
              }),
            ),
        ],
      ),
    );
  }
}

class _HeadFormDialog extends StatefulWidget {
  const _HeadFormDialog({this.head});

  final AccountHead? head;

  @override
  State<_HeadFormDialog> createState() => _HeadFormDialogState();
}

class _HeadFormDialogState extends State<_HeadFormDialog> {
  late final TextEditingController _master =
      TextEditingController(text: widget.head?.masterAccount ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.head?.description ?? '');
  late String _accountType = widget.head?.accountType ?? '';

  @override
  void dispose() {
    _master.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _valid => _master.text.trim().isNotEmpty && _accountType.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.head != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: accHeadGradient),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.layers, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEdit ? 'Edit Account Head' : 'Add Account Head',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              NetField(
                label: 'Master Account',
                child: TextField(
                  controller: _master,
                  onChanged: (_) => setState(() {}),
                  decoration: netInputDecoration(
                    context,
                    hint: 'Enter master account name',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AccountSelect(
                label: 'Account Type',
                value: _accountType,
                placeholder: 'Select account type',
                options: [
                  for (final t in accountTypes) AccountOption(t, t),
                ],
                onChanged: (v) => setState(() => _accountType = v),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Description',
                child: TextField(
                  controller: _description,
                  maxLines: 3,
                  decoration: netInputDecoration(
                    context,
                    hint: 'Enter description...',
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
            foregroundColor: context.mutedFg,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: isEdit ? 'Update' : 'Add',
          gradient: const [Color(0xFF10B981), Color(0xFF16A34A)],
          onPressed: _valid
              ? () => Navigator.of(context).pop((
                    masterAccount: _master.text.trim(),
                    accountType: _accountType,
                    description: _description.text,
                  ))
              : null,
        ),
      ],
    );
  }
}

class _SubHeadFormDialog extends StatefulWidget {
  const _SubHeadFormDialog({required this.heads, this.sub});

  final List<AccountHead> heads;
  final SubHead? sub;

  @override
  State<_SubHeadFormDialog> createState() => _SubHeadFormDialogState();
}

class _SubHeadFormDialogState extends State<_SubHeadFormDialog> {
  late final TextEditingController _subMaster =
      TextEditingController(text: widget.sub?.subMasterAccount ?? '');
  late final TextEditingController _budget =
      TextEditingController(text: widget.sub?.budget ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.sub?.description ?? '');
  late String _headId = widget.sub?.masterAccountId ?? '';

  @override
  void dispose() {
    _subMaster.dispose();
    _budget.dispose();
    _description.dispose();
    super.dispose();
  }

  AccountHead? get _selectedHead {
    for (final h in widget.heads) {
      if (h.id == _headId) return h;
    }
    return null;
  }

  bool get _valid => _subMaster.text.trim().isNotEmpty && _headId.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.sub != null;
    final selectedHead = _selectedHead;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.layers, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEdit ? 'Edit Account Sub Head' : 'Add Account Sub Head',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              NetField(
                label: 'Sub Master Account',
                child: TextField(
                  controller: _subMaster,
                  onChanged: (_) => setState(() {}),
                  decoration: netInputDecoration(
                    context,
                    hint: 'Enter sub master account name',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AccountSelect(
                label: 'Master Account',
                value: _headId,
                placeholder: 'Select master account',
                options: [
                  for (final h in widget.heads)
                    AccountOption(h.id, h.masterAccount),
                ],
                onChanged: (v) => setState(() => _headId = v),
              ),
              if (selectedHead != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.subtle,
                    border: Border.all(color: context.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Account Type: ',
                          style: TextStyle(color: context.mutedFg),
                        ),
                        TextSpan(
                          text: selectedHead.accountType,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              NetField(
                label: 'Budget',
                child: TextField(
                  controller: _budget,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: netInputDecoration(
                    context,
                    hint: 'Enter budget amount',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Description',
                child: TextField(
                  controller: _description,
                  maxLines: 3,
                  decoration: netInputDecoration(
                    context,
                    hint: 'Enter description...',
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
            foregroundColor: context.mutedFg,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: isEdit ? 'Update' : 'Add',
          gradient: const [Color(0xFF10B981), Color(0xFF16A34A)],
          onPressed: _valid
              ? () => Navigator.of(context).pop((
                    subMasterAccount: _subMaster.text.trim(),
                    masterAccountId: _headId,
                    budget: _budget.text.trim(),
                    description: _description.text,
                  ))
              : null,
        ),
      ],
    );
  }
}
