/// Shared helpers for the Transaction modules: permission gating (mirroring
/// the web `usePermissions` hooks), the page-filter widgets, and the gradient
/// palette. Pages reuse the Network widgets (`NetworkTable`, `NetworkStatCard`,
/// `GradientButton`, …) and the Sales `SalesFilterRows` two-row scroll layout so
/// the UI stays 1:1 with the web client.
library;

import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../network/network_common.dart';

// ---------------------------------------------------------------------------
// Permission ids (mirrors `permission-pages.ts` PAGE_PERMISSIONS)
// ---------------------------------------------------------------------------

const String kUserCollectionsPermission = '13304'; // Subscribers Collections
const String kDealerCollectionsPermission = '13321'; // Dealers Collections
const String kAllocatedCollectionsPermission = '13305'; // Allocated Collection
const String kBadDebtCollectionsPermission = '13357'; // Baddebt Collection
const String kTransactionTypePermission = '13324'; // Transaction Type
const String kBillCreatorPermission = '13320'; // Bills Creator
const String kCollectionDetailsPermission = '15388'; // Collection Search

// Global CRUD fallbacks (permissions.ts `PERMISSIONS`).
const String kTxCanCreate = '15362';
const String kTxCanUpdate = '15363';
const String kTxCanDelete = '15364';

const List<String> kTxAdminRoles = ['admin', 'owner', 'manager'];

/// Mirrors the web `baseHasPermission`: admin/owner/manager (and users whose
/// permissions are not configured) always pass; otherwise the id must be in
/// the session's granted permission list.
bool txHasPermission(String id) {
  final isAdmin = kTxAdminRoles.contains(Session.role ?? '');
  if (isAdmin || !Session.permissionsConfigured) return true;
  return Session.permissions.contains(id);
}

/// `hasPagePermission` — a page child key only (no global fallback).
bool txPage(String pageId, String key) => txHasPermission('$pageId:$key');

/// `hasCrudPermission` — the page child key, else the global CRUD id.
bool txCrud(String pageId, String action) {
  if (txHasPermission('$pageId:$action')) return true;
  return txCrudGlobal(action);
}

/// Global-only CRUD check, e.g. when the web page calls `useCrudPermissions()`
/// without a page id (Transaction Type, Bills Creator).
bool txCrudGlobal(String action) {
  final id = switch (action) {
    'create' => kTxCanCreate,
    'update' => kTxCanUpdate,
    _ => kTxCanDelete,
  };
  return txHasPermission(id);
}

// ---------------------------------------------------------------------------
// Gradient palette (matches the web `from-* to-*` button/header gradients)
// ---------------------------------------------------------------------------

const List<Color> kTxViolet = [Color(0xFF6D28D9), Color(0xFF8B5CF6)];
const List<Color> kTxBlue = [Color(0xFF1E40AF), Color(0xFF3B82F6)];
const List<Color> kTxGreen = [Color(0xFF166534), Color(0xFF22C55E)];
const List<Color> kTxEmerald = [Color(0xFF047857), Color(0xFF10B981)];
const List<Color> kTxAmber = [Color(0xFFB45309), Color(0xFFFB923C)];
const List<Color> kTxOrange = [Color(0xFFC2410C), Color(0xFFF97316)];
const List<Color> kTxRose = [Color(0xFFBE123C), Color(0xFFFB7185)];
const List<Color> kTxTeal = [Color(0xFF0F766E), Color(0xFF14B8A6)];
const List<Color> kTxIndigo = [Color(0xFF3730A3), Color(0xFF6366F1)];
const List<Color> kTxFuchsia = [Color(0xFFA21CAF), Color(0xFFD946EF)];
const List<Color> kTxCyan = [Color(0xFF0E7490), Color(0xFF06B6D4)];
const List<Color> kTxSlate = [Color(0xFF334155), Color(0xFF64748B)];

// ---------------------------------------------------------------------------
// Filter widgets (mirror the Sales `_FilterSelect` / `_DateFilterField`)
// ---------------------------------------------------------------------------

/// Fixed-height dropdown used across the transaction filter rows.
class TxSelect extends StatelessWidget {
  const TxSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width,
    this.height = 48,
  });

  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.surface,
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.containsKey(value) ? value : (items.keys.isEmpty ? null : items.keys.first),
          isExpanded: true,
          borderRadius: BorderRadius.circular(10),
          items: [
            for (final e in items.entries)
              DropdownMenuItem(
                value: e.key,
                child: Text(
                  e.value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
    return width == null ? child : SizedBox(width: width, child: child);
  }
}

/// Date picker field used in the transaction filter rows.
class TxDateField extends StatelessWidget {
  const TxDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.width = 170,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final now = DateTime.now();
          final initial = DateTime.tryParse(value) ?? now;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(now.year - 5),
            lastDate: DateTime(now.year + 5),
          );
          if (picked == null) return;
          onChanged(
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}',
          );
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.surface,
            border: Border.all(color: context.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: context.mutedFg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value.isEmpty ? label : value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: value.isEmpty ? context.mutedFg : context.fg,
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

/// Standard search text field used in the transaction filter rows.
TextField txSearchField({
  required BuildContext context,
  required TextEditingController controller,
  required ValueChanged<String> onChanged,
  required String hint,
}) {
  return TextField(
    controller: controller,
    onChanged: onChanged,
    style: const TextStyle(fontSize: 14),
    decoration: netInputDecoration(context, hint: hint).copyWith(
      prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
    ),
  );
}

/// One option for [TxSearchableSelect].
class TxPickOption {
  const TxPickOption({
    required this.id,
    required this.name,
    this.secondary,
  });

  final String id;
  final String name;
  final String? secondary;
}

/// Coloured pill matching the web `Badge` component.
class TxBadge extends StatelessWidget {
  const TxBadge({
    super.key,
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Searchable subscriber/payment picker mirroring the web `SearchableSelect`.
/// Tapping the field opens a sheet with a search box and the matching options.
class TxSearchableSelect extends StatelessWidget {
  const TxSearchableSelect({
    super.key,
    required this.label,
    required this.placeholder,
    required this.searchPlaceholder,
    required this.options,
    required this.onChanged,
    this.value,
    this.width,
    this.onOpen,
  });

  final String label;
  final String placeholder;
  final String searchPlaceholder;
  final List<TxPickOption> options;
  final ValueChanged<String?> onChanged;
  final String? value;
  final double? width;

  /// Called before the picker opens (e.g. to lazily load options).
  final VoidCallback? onOpen;

  String? get _selectedName =>
      options.where((o) => o.id == value).map((o) => o.name).firstOrNull;

  @override
  Widget build(BuildContext context) {
    Widget field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _open(context),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.surface,
              border: Border.all(color: context.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedName ?? placeholder,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedName == null ? context.mutedFg : context.fg,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: context.mutedFg),
              ],
            ),
          ),
        ),
      ],
    );
    if (width != null) field = SizedBox(width: width, child: field);
    return field;
  }

  Future<void> _open(BuildContext context) async {
    onOpen?.call();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      builder: (_) => _TxSearchPickerSheet(
        options: options,
        searchPlaceholder: searchPlaceholder,
        value: value,
      ),
    );
    if (selected != null) onChanged(selected);
  }
}

class _TxSearchPickerSheet extends StatefulWidget {
  const _TxSearchPickerSheet({
    required this.options,
    required this.searchPlaceholder,
    required this.value,
  });

  final List<TxPickOption> options;
  final String searchPlaceholder;
  final String? value;

  @override
  State<_TxSearchPickerSheet> createState() => _TxSearchPickerSheetState();
}

class _TxSearchPickerSheetState extends State<_TxSearchPickerSheet> {
  String _query = '';

  List<TxPickOption> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options.where((o) {
      return o.name.toLowerCase().contains(q) ||
          o.id.toLowerCase().contains(q) ||
          (o.secondary ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: netInputDecoration(
                          context,
                          hint: widget.searchPlaceholder,
                        ).copyWith(
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No matches found.',
                          style: TextStyle(color: context.mutedFg),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final option = _filtered[index];
                          final selected = option.id == widget.value;
                          return InkWell(
                            onTap: () => Navigator.of(context).pop(option.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (option.secondary?.isNotEmpty ?? false)
                                          Text(
                                            option.secondary!,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.mutedFg,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      Icons.check_circle,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
