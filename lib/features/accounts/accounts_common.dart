import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../network/network_common.dart';
import 'accounts_models.dart';

/// Gradient pairs used across the Accounts section — the Flutter counterparts
/// of the web `bg-gradient-to-br from-* to-*` utilities on each page.
const List<Color> accHeadGradient = [Color(0xFFA855F7), Color(0xFF4F46E5)];
const List<Color> accEntryGradient = [Color(0xFF3B82F6), Color(0xFF4F46E5)];
const List<Color> accReportGradient = [Color(0xFF8B5CF6), Color(0xFF9333EA)];
const List<Color> accOneDayGradient = [Color(0xFF14B8A6), Color(0xFF10B981)];

const List<Color> accEmeraldStatGradient = [Color(0xFF10B981), Color(0xFF16A34A)];
const List<Color> accBlueStatGradient = [Color(0xFF3B82F6), Color(0xFF06B6D4)];
const List<Color> accAmberStatGradient = [Color(0xFFF59E0B), Color(0xFFEA580C)];
const List<Color> accTealStatGradient = [Color(0xFF14B8A6), Color(0xFF10B981)];
const List<Color> accVioletStatGradient = [Color(0xFF8B5CF6), Color(0xFF9333EA)];
const List<Color> accEmeraldButtonGradient = [Color(0xFF10B981), Color(0xFF16A34A)];

// ---------------------------------------------------------------------------
// Permission ids (mirrors `permission-pages.ts` PAGE_PERMISSIONS)
// ---------------------------------------------------------------------------

const String kAccountHeadPermission = '13322'; // Account Head
const String kAccountEntryPermission = '13323'; // Account Entry
const String kOneDayBalancePermission = '13341'; // One Day Accounts

/// Global CRUD fallbacks (permissions.ts `PERMISSIONS`).
const String kAccCanCreate = '15362';
const String kAccCanUpdate = '15363';
const String kAccCanDelete = '15364';

const List<String> kAccAdminRoles = ['admin', 'owner', 'manager'];

/// Mirrors the web `baseHasPermission`: admin/owner/manager (and users whose
/// permissions are not configured) always pass; otherwise the id must be in
/// the session's granted permission list.
bool accHasPermission(String id) {
  final isAdmin = kAccAdminRoles.contains(Session.role ?? '');
  if (isAdmin || !Session.permissionsConfigured) return true;
  return Session.permissions.contains(id);
}

/// `hasPagePermission` — a page child key only (no global fallback).
bool accPage(String pageId, String key) => accHasPermission('$pageId:$key');

/// `hasCrudPermission` — the page child key, else the global CRUD id.
bool accCrud(String pageId, String action) {
  if (accHasPermission('$pageId:$action')) return true;
  return accCrudGlobal(action);
}

/// Global-only CRUD check, mirroring the web `useCrudPermissions()` fallback.
bool accCrudGlobal(String action) {
  final id = switch (action) {
    'create' => kAccCanCreate,
    'update' => kAccCanUpdate,
    _ => kAccCanDelete,
  };
  return accHasPermission(id);
}

// ---------------------------------------------------------------------------
// Formatting helpers (match the web `toLocaleString` / date-fns output)
// ---------------------------------------------------------------------------

final NumberFormat _accPlain = NumberFormat.decimalPattern();

/// Web `Number(value).toLocaleString()` — grouped, no decimals.
String accNumber(num? value) => _accPlain.format(value ?? 0);

/// Web `Number(value).toFixed(2)`.
String accFixed2(num value) => value.toStringAsFixed(2);

/// Web `String(value)` for a numeric input — no grouping, no trailing `.0`.
String accPlainAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

/// Web `format(date, 'yyyy-MM-dd')`.
String accIso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Web `format(date, 'dd MMM yyyy')`.
String accDdMmmYyyy(DateTime d) => DateFormat('dd MMM yyyy').format(d);

/// Web `format(date, 'PPP')` (en-US → "October 12, 2026").
String accPpp(DateTime d) => DateFormat.yMMMMd().format(d);

String accTodayIso() => DateFormat('yyyy-MM-dd').format(DateTime.now());

DateTime? accTryParse(String raw) {
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

/// `${api.defaults.baseURL}/uploads/company_images/{id}` used by the prints.
String accCompanyImageUrl(String kind, String id) =>
    '${ApiConfig.base}/uploads/$kind/$id';

// ---------------------------------------------------------------------------
// Reference data shared by every accounts screen.
// ---------------------------------------------------------------------------

class AccountRefs {
  const AccountRefs({
    this.heads = const [],
    this.subHeads = const [],
    this.txnTypes = const [],
  });

  final List<AccountHead> heads;
  final List<SubHead> subHeads;
  final List<AccountTxnType> txnTypes;
}

/// Loads heads, sub heads and transaction types (all scoped to the company).
/// Each request is tolerated independently so a missing offline cache for one
/// collection never blanks the others.
Future<AccountRefs> loadAccountRefs(OfflineApi api, String cid) async {
  Future<List<T>> load<T>(String path, T Function(Map<String, dynamic>) f) async {
    try {
      final json = await api.get(path, query: {'companyId': cid});
      return ApiClient.listData(json)
          .whereType<Map<String, dynamic>>()
          .map(f)
          .toList();
    } on ApiException {
      return const [];
    }
  }

  final headsFuture = load('/accounts/heads', AccountHead.fromJson);
  final subHeadsFuture = load('/accounts/sub-heads', SubHead.fromJson);
  final txnTypesFuture =
      load('/billing/transaction-types', AccountTxnType.fromJson);
  return AccountRefs(
    heads: await headsFuture,
    subHeads: await subHeadsFuture,
    txnTypes: await txnTypesFuture,
  );
}

/// Distinct user names from HR staff + recovery officers (web `usersList`).
Future<List<String>> loadAccountUsers(OfflineApi api, String cid) async {
  final names = <String>{};
  try {
    final staff = await api.get('/hr/staff', query: {'companyId': cid});
    for (final s in ApiClient.listData(staff).whereType<Map<String, dynamic>>()) {
      final name = s['name']?.toString() ?? '';
      if (name.isNotEmpty) names.add(name);
    }
  } on ApiException {
    // Optional reference data — ignore failures.
  }
  try {
    final officers = await api.get(
      '/admin/recovery-officers',
      query: {'companyId': cid},
    );
    for (final o in ApiClient.listData(officers).whereType<Map<String, dynamic>>()) {
      final name = o['name']?.toString() ?? '';
      if (name.isNotEmpty) names.add(name);
    }
  } on ApiException {
    // Optional reference data — ignore failures.
  }
  return names.toList();
}

// ---------------------------------------------------------------------------
// Dropdown
// ---------------------------------------------------------------------------

class AccountOption {
  const AccountOption(this.id, this.name);

  final String id;
  final String name;
}

/// Label + select used by the accounts forms and filter bars. Opens a search
/// picker dialog (mirrors the web shadcn `<Select>`).
class AccountSelect extends StatelessWidget {
  const AccountSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.placeholder = 'Select',
    this.icon,
    this.enabled = true,
  });

  final String label;
  final String value;
  final List<AccountOption> options;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final IconData? icon;
  final bool enabled;

  String? get _selectedName {
    if (value.isEmpty) return null;
    for (final o in options) {
      if (o.id == value) return o.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedName;
    final effectiveEnabled = enabled && options.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: context.mutedFg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: effectiveEnabled ? 1 : 0.6,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: effectiveEnabled
                  ? () async {
                      final id = await showDialog<String>(
                        context: context,
                        builder: (_) => _AccountPickerDialog(
                          title: label,
                          options: options,
                          selectedId: value,
                        ),
                      );
                      if (id != null) onChanged(id);
                    }
                  : null,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: context.inputFill,
                  border: Border.all(color: context.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected ?? placeholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: selected == null
                              ? context.mutedFg
                              : context.fg,
                        ),
                      ),
                    ),
                    Icon(Icons.unfold_more, size: 16, color: context.mutedFg),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountPickerDialog extends StatefulWidget {
  const _AccountPickerDialog({
    required this.title,
    required this.options,
    this.selectedId,
  });

  final String title;
  final List<AccountOption> options;
  final String? selectedId;

  @override
  State<_AccountPickerDialog> createState() => _AccountPickerDialogState();
}

class _AccountPickerDialogState extends State<_AccountPickerDialog> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AccountOption> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((o) => o.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: Text(widget.title, style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: netInputDecoration(
                context,
                hint: 'Search...',
              ).copyWith(
                prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No matches.',
                        style: TextStyle(fontSize: 13, color: context.mutedFg),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final option = _filtered[i];
                        final active = option.id == widget.selectedId;
                        return ListTile(
                          dense: true,
                          title: Text(
                            option.name,
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: active
                              ? const Icon(Icons.check, size: 16)
                              : null,
                          onTap: () => Navigator.of(context).pop(option.id),
                        );
                      },
                    ),
            ),
          ],
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
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared add/edit account entry dialog.
// ---------------------------------------------------------------------------

class AccountEntryFormResult {
  const AccountEntryFormResult({
    required this.headId,
    required this.subHeadId,
    required this.date,
    required this.description,
    required this.amount,
    required this.txnTypeId,
  });

  final String headId;
  final String subHeadId;
  final DateTime? date;
  final String description;
  final String amount;
  final String txnTypeId;
}

/// Flutter counterpart of the web add/edit account entry dialog. Returns null
/// when cancelled.
Future<AccountEntryFormResult?> showAccountEntryForm(
  BuildContext context, {
  required List<AccountHead> heads,
  required List<SubHead> subHeads,
  required List<AccountTxnType> txnTypes,
  AccountEntry? entry,
}) {
  return showDialog<AccountEntryFormResult>(
    context: context,
    builder: (_) => _AccountEntryFormDialog(
      heads: heads,
      subHeads: subHeads,
      txnTypes: txnTypes,
      entry: entry,
    ),
  );
}

class _AccountEntryFormDialog extends StatefulWidget {
  const _AccountEntryFormDialog({
    required this.heads,
    required this.subHeads,
    required this.txnTypes,
    this.entry,
  });

  final List<AccountHead> heads;
  final List<SubHead> subHeads;
  final List<AccountTxnType> txnTypes;
  final AccountEntry? entry;

  @override
  State<_AccountEntryFormDialog> createState() =>
      _AccountEntryFormDialogState();
}

class _AccountEntryFormDialogState extends State<_AccountEntryFormDialog> {
  late String _headId = widget.entry?.head ?? '';
  late String _subHeadId = widget.entry?.subHead ?? '';
  late DateTime? _date = accTryParse(widget.entry?.date ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.entry?.description ?? '');
  late final TextEditingController _amount = TextEditingController(
    text: widget.entry == null ? '' : accPlainAmount(widget.entry!.amount),
  );
  late String _txnTypeId = widget.entry?.transactionType ?? '';

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  List<SubHead> get _subHeadOptions =>
      widget.subHeads.where((s) => s.masterAccountId == _headId).toList();

  void _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool get _valid =>
      _headId.isNotEmpty && _subHeadId.isNotEmpty && _amount.text.trim().isNotEmpty;

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop(
      AccountEntryFormResult(
        headId: _headId,
        subHeadId: _subHeadId,
        date: _date,
        description: _description.text,
        amount: _amount.text.trim(),
        txnTypeId: _txnTypeId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entry != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: accEntryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.menu_book, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEdit ? 'Edit Account Entry' : 'Add Account Entry',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AccountSelect(
                      label: 'Account Head',
                      value: _headId,
                      placeholder: 'Select head',
                      options: [
                        for (final h in widget.heads)
                          AccountOption(h.id, h.masterAccount),
                      ],
                      onChanged: (v) {
                        final matching = widget.subHeads
                            .where((s) => s.masterAccountId == v)
                            .toList();
                        setState(() {
                          _headId = v;
                          _subHeadId =
                              matching.isNotEmpty ? matching.first.id : '';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AccountSelect(
                      label: 'Sub Account Head',
                      value: _subHeadId,
                      placeholder: 'Select sub head',
                      enabled: _headId.isNotEmpty,
                      options: [
                        for (final s in _subHeadOptions)
                          AccountOption(s.id, s.subMasterAccount),
                      ],
                      onChanged: (v) => setState(() => _subHeadId = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Date',
                child: _DateField(
                  value: _date,
                  placeholder: 'Pick date',
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Description',
                child: TextField(
                  controller: _description,
                  maxLines: 4,
                  decoration: netInputDecoration(
                    context,
                    hint: 'Enter description...',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: NetField(
                      label: 'Amount',
                      child: TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        decoration: netInputDecoration(
                          context,
                          hint: 'Enter amount',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AccountSelect(
                      label: 'Transaction Type',
                      value: _txnTypeId,
                      placeholder: 'Select type',
                      options: [
                        for (final t in widget.txnTypes)
                          AccountOption(t.id, t.paymentChannel),
                      ],
                      onChanged: (v) => setState(() => _txnTypeId = v),
                    ),
                  ),
                ],
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
          onPressed: _valid ? _submit : null,
        ),
      ],
    );
  }
}

/// A calendar-styled trigger button used by the accounts filters/forms.
class AccountDateField extends StatelessWidget {
  const AccountDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Pick date',
    this.icon,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String placeholder;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return NetField(
      label: label,
      child: _DateField(
        value: value,
        placeholder: placeholder,
        icon: icon,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(picked);
        },
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.icon,
  });

  final DateTime? value;
  final String placeholder;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.inputFill,
            border: Border.all(color: context.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon ?? Icons.calendar_today, size: 16, color: context.mutedFg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasValue ? accDdMmmYyyy(value!) : placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: hasValue ? context.fg : context.mutedFg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-row filter bar used by the Accounts screens. Filter inputs flow across
/// rows ([filtersPerRow] per row) and every row — filters and actions — scrolls
/// horizontally so nothing overflows on narrow screens. Mirrors `InvFilterBar`.
class AccountFilterBar extends StatelessWidget {
  const AccountFilterBar({
    super.key,
    this.filters = const [],
    this.actions = const [],
    this.filterWidth = 260,
    this.spacing = 12,
    this.rowSpacing = 10,
    this.filtersPerRow = 2,
  });

  final List<Widget> filters;
  final List<Widget> actions;
  final double filterWidth;
  final double spacing;
  final double rowSpacing;
  final int filtersPerRow;

  List<List<Widget>> get _filterRows {
    final rows = <List<Widget>>[];
    final perRow = filtersPerRow < 1 ? 1 : filtersPerRow;
    for (var i = 0; i < filters.length; i += perRow) {
      final end = (i + perRow) > filters.length ? filters.length : i + perRow;
      rows.add(filters.sublist(i, end));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filterRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: rowSpacing),
          Row(
            children: [
              for (var j = 0; j < rows[i].length; j++) ...[
                if (j > 0) SizedBox(width: spacing),
                SizedBox(width: filterWidth, child: rows[i][j]),
              ],
            ],
          ),
        ],
        if (actions.isNotEmpty) ...[
          if (rows.isNotEmpty) SizedBox(height: rowSpacing),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) SizedBox(width: spacing),
                  actions[i],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Row action trio (edit / print / delete) used by the account entry tables.
class AccountEntryActions extends StatelessWidget {
  const AccountEntryActions({
    super.key,
    this.onEdit,
    this.onPrint,
    this.onDelete,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onPrint;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          _action(context, Icons.edit_outlined, AppColors.emerald600,
              'Edit Entry', onEdit!),
        if (onPrint != null)
          _action(context, Icons.print_outlined, AppColors.primary,
              'Print Entry', onPrint!),
        if (onDelete != null)
          _action(context, Icons.delete_outline, context.dangerText,
              'Delete Entry', onDelete!),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
