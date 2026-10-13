import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../network/network_common.dart';
import 'inventory_models.dart';

/// Gradient pairs used across the Inventory section — the Flutter counterparts
/// of the web `bg-gradient-to-r/br from-* to-*` utilities on each screen.
const List<Color> invBrandGradient = [Color(0xFF3B82F6), Color(0xFF06B6D4)];
const List<Color> invUnitTypeGradient = [Color(0xFF3B82F6), Color(0xFF4F46E5)];
const List<Color> invProductTypeGradient = [Color(0xFFF59E0B), Color(0xFFEA580C)];
const List<Color> invProductGradient = [Color(0xFF10B981), Color(0xFF16A34A)];
const List<Color> invVendorGradient = [Color(0xFF06B6D4), Color(0xFF0D9488)];
const List<Color> invVendorInvoiceGradient = [Color(0xFFF59E0B), Color(0xFFEA580C)];
const List<Color> invPurchaseGradient = [Color(0xFF8B5CF6), Color(0xFF9333EA)];
const List<Color> invStatusGradient = [Color(0xFFF43F5E), Color(0xFFE11D48)];
const List<Color> invStockGradient = [Color(0xFF14B8A6), Color(0xFF10B981)];

const List<Color> invBlueStatGradient = [Color(0xFF3B82F6), Color(0xFF06B6D4)];
const List<Color> invEmeraldStatGradient = [Color(0xFF10B981), Color(0xFF16A34A)];
const List<Color> invAmberStatGradient = [Color(0xFFF59E0B), Color(0xFFEA580C)];
const List<Color> invEmeraldButtonGradient = [Color(0xFF10B981), Color(0xFF16A34A)];
const List<Color> invVioletGradient = [Color(0xFF8B5CF6), Color(0xFF9333EA)];

// ---------------------------------------------------------------------------
// Permission ids (mirrors `permission-pages.ts` PAGE_PERMISSIONS)
// ---------------------------------------------------------------------------

const String kVendorInvoicePermission = '15372'; // Vendor Invoice
const String kPurchasePermission = '15313'; // Purchase

/// Global CRUD fallbacks (permissions.ts `PERMISSIONS`).
const String kInvCanCreate = '15362';
const String kInvCanUpdate = '15363';
const String kInvCanDelete = '15364';

const List<String> kInvAdminRoles = ['admin', 'owner', 'manager'];

/// Mirrors the web `baseHasPermission`: admin/owner/manager (and users whose
/// permissions are not configured) always pass; otherwise the id must be in
/// the session's granted permission list.
bool invHasPermission(String id) {
  final isAdmin = kInvAdminRoles.contains(Session.role ?? '');
  if (isAdmin || !Session.permissionsConfigured) return true;
  return Session.permissions.contains(id);
}

/// `hasPagePermission` — a page child key only (no global fallback).
bool invPage(String pageId, String key) => invHasPermission('$pageId:$key');

/// `hasCrudPermission` — the page child key, else the global CRUD id.
bool invCrud(String pageId, String action) {
  if (invHasPermission('$pageId:$action')) return true;
  return invCrudGlobal(action);
}

/// Global-only CRUD check, e.g. when the web page calls `useCrudPermissions()`
/// without a page id (Vendor Invoice).
bool invCrudGlobal(String action) {
  final id = switch (action) {
    'create' => kInvCanCreate,
    'update' => kInvCanUpdate,
    _ => kInvCanDelete,
  };
  return invHasPermission(id);
}

/// Small pill used by the Inventory tables (counts, statuses, stock levels).
class InventoryBadge extends StatelessWidget {
  const InventoryBadge({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

/// The web `statusVariant` badge for a purchase status
/// (paid = default, unpaid = destructive, partial = secondary).
class PurchaseStatusBadge extends StatelessWidget {
  const PurchaseStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    late final Color bg;
    late final Color fg;
    switch (normalized) {
      case 'paid':
        bg = AppColors.primary;
        fg = Colors.white;
      case 'unpaid':
        bg = const Color(0xFFDC2626);
        fg = Colors.white;
      case 'partial':
        bg = context.subtle;
        fg = context.fg;
      default:
        bg = context.subtle;
        fg = context.fg;
    }
    final label = normalized.isEmpty
        ? status
        : normalized[0].toUpperCase() + normalized.substring(1);
    return InventoryBadge(text: label, background: bg, foreground: fg);
  }
}

/// Web `parseSerialNumbers` — serial numbers are stored as one text field
/// separated by spaces, commas or dashes.
List<String> parseSerialNumbers(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw
      .split(RegExp(r'[\s,\-]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Web `parseModels` — model numbers separated by commas or new lines.
List<String> parseModels(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw
      .split(RegExp(r'[\s,\n\r\t,]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

int _matchGroup(String q, List<String?> values) {
  var substringMatch = -1;
  for (final v in values) {
    if (v == null) continue;
    final s = v.toLowerCase();
    if (s.startsWith(q)) return 0;
    if (substringMatch < 0 && s.contains(q)) substringMatch = 1;
  }
  return substringMatch;
}

/// Web `smartMatchScore` — ranked match, lower is better, -1 = no match.
/// Earlier groups always outrank later groups.
int invSmartMatchScore(String query, List<List<String?>> groups) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return 0;
  for (var i = 0; i < groups.length; i++) {
    final groupScore = _matchGroup(q, groups[i]);
    if (groupScore >= 0) return i * 2 + groupScore;
  }
  return -1;
}

/// Web `smartSearch` — filters [items] to matches and sorts best-first,
/// preserving the original order on ties.
List<T> invSmartSearch<T>(
  String query,
  List<T> items,
  List<List<String?>> Function(T item) groupsOf,
) {
  final scored = <MapEntry<T, int>>[];
  for (var i = 0; i < items.length; i++) {
    final score = invSmartMatchScore(query, groupsOf(items[i]));
    if (score >= 0) scored.add(MapEntry(items[i], i * 1000 + score));
  }
  scored.sort((a, b) => a.value.compareTo(b.value));
  return scored.map((e) => e.key).toList();
}

/// Web `groupedProducts` — dedupes products that share a name/brand/type,
/// aggregating stock, serial numbers and models into a single representative
/// row (the first product's remaining fields are kept).
List<Product> groupProducts(List<Product> products) {
  final map = <String, List<Product>>{};
  for (final p in products) {
    final key =
        '${p.name}|${p.brandName}|${p.productTypeName.isNotEmpty ? p.productTypeName : p.category}';
    map.putIfAbsent(key, () => []).add(p);
  }
  final out = <Product>[];
  for (final group in map.values) {
    if (group.length == 1) {
      out.add(group.first);
      continue;
    }
    final first = group.first;
    final snSet = <String>{};
    for (final p in group) {
      for (final s in p.serialNumber.split(',')) {
        final t = s.trim();
        if (t.isNotEmpty) snSet.add(t);
      }
    }
    final models = <String>[];
    for (final p in group) {
      models.addAll(parseModels(p.model));
    }
    out.add(
      Product(
        id: first.id,
        productId: first.productId,
        name: first.name,
        category: first.category,
        price: first.price,
        stock: group.fold<int>(0, (s, p) => s + p.stock),
        unitType: first.unitType,
        taxPercent: first.taxPercent,
        image: first.image,
        brandId: first.brandId,
        brandName: first.brandName,
        productTypeId: first.productTypeId,
        productTypeName: first.productTypeName,
        purchasePrice: first.purchasePrice,
        salePrice: first.salePrice,
        discount: first.discount,
        serialNumber: snSet.join(', '),
        currentSerialIndex: first.currentSerialIndex,
        noSerialNumber: first.noSerialNumber,
        model: models.join(', '),
        noModel: first.noModel,
        currentModelIndex: first.currentModelIndex,
      ),
    );
  }
  return out;
}

/// Options shown by [InventorySearchDropdown].
class InventoryOption {
  const InventoryOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// Label + searchable select field matching the web `SearchableDropdown`
/// (icon label, a tappable box that opens a search dialog).
class InventorySearchDropdown extends StatelessWidget {
  const InventorySearchDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Select...',
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final List<InventoryOption> items;
  final String? value;
  final ValueChanged<String> onChanged;
  final String placeholder;

  String? get _selectedName {
    if (value == null || value!.isEmpty) return null;
    for (final item in items) {
      if (item.id == value) return item.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final id = await showDialog<String>(
                context: context,
                builder: (_) => _SearchPickerDialog(
                  title: label,
                  items: items,
                  selectedId: value,
                ),
              );
              if (id != null) onChanged(id);
            },
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
                        color: selected == null ? context.mutedFg : context.fg,
                      ),
                    ),
                  ),
                  Icon(Icons.unfold_more, size: 16, color: context.mutedFg),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchPickerDialog extends StatefulWidget {
  const _SearchPickerDialog({
    required this.title,
    required this.items,
    this.selectedId,
  });

  final String title;
  final List<InventoryOption> items;
  final String? selectedId;

  @override
  State<_SearchPickerDialog> createState() => _SearchPickerDialogState();
}

class _SearchPickerDialogState extends State<_SearchPickerDialog> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<InventoryOption> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
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
              decoration: netInputDecoration(context, hint: 'Search...').copyWith(
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
                          title: Text(option.name, style: const TextStyle(fontSize: 14)),
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

/// Simple "single name" form dialog shared by Brand / Unit Type / Product Type,
/// mirroring the web `BrandForm` / `UnitTypeForm` / `ProductTypeForm`.
Future<String?> showInventoryNameForm(
  BuildContext context, {
  required String title,
  required String label,
  required String hint,
  required List<Color> gradient,
  required IconData icon,
  String? initial,
  String saveLabel = 'Save',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameFormDialog(
      title: title,
      label: label,
      hint: hint,
      gradient: gradient,
      icon: icon,
      initial: initial,
      saveLabel: saveLabel,
    ),
  );
}

class _NameFormDialog extends StatefulWidget {
  const _NameFormDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.gradient,
    required this.icon,
    this.initial,
    this.saveLabel = 'Save',
  });

  final String title;
  final String label;
  final String hint;
  final List<Color> gradient;
  final IconData icon;
  final String? initial;
  final String saveLabel;

  @override
  State<_NameFormDialog> createState() => _NameFormDialogState();
}

class _NameFormDialogState extends State<_NameFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18))),
        ],
      ),
      content: Form(
        key: _formKey,
        child: NetField(
          label: widget.label,
          child: TextFormField(
            controller: _name,
            autofocus: true,
            decoration: netInputDecoration(context, hint: widget.hint),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            onFieldSubmitted: (_) => _submit(),
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
          label: widget.saveLabel,
          gradient: widget.gradient,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// One entry in the expandable [InventorySerialEntriesTable].
class InventorySerialEntry {
  const InventorySerialEntry({
    required this.key,
    required this.productName,
    required this.serialNumber,
    this.model,
    this.price,
  });

  final String key;
  final String productName;
  final String serialNumber;
  final String? model;
  final num? price;
}

/// Flutter counterpart of the web `SerialEntriesTable` used by the expanded
/// product row.
class InventorySerialEntriesTable extends StatelessWidget {
  const InventorySerialEntriesTable({super.key, required this.entries});

  final List<InventorySerialEntry> entries;

  static final NumberFormat _plain = NumberFormat('#,##0');

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'No serial entries.',
          style: TextStyle(fontSize: 12, color: context.mutedFg),
        ),
      );
    }
    final hasModel = entries.any((e) => (e.model ?? '').isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: context.mutedFg,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: Text(
                        entries[i].productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: Text(
                        entries[i].serialNumber,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (hasModel)
                      SizedBox(
                        width: 140,
                        child: Text(
                          entries[i].model ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        entries[i].price == null
                            ? '—'
                            : 'PKR ${_plain.format(entries[i].price)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Two-row filter bar used by the Inventory list screens. Filter inputs flow
/// across rows ([filtersPerRow] per row) and every row — filters and actions —
/// scrolls horizontally so nothing overflows on narrow screens.
class InvFilterBar extends StatelessWidget {
  const InvFilterBar({
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

  Widget _scrollRow(List<Widget> children) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            children[i],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filterRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: rowSpacing),
          _scrollRow([
            for (final filter in rows[i])
              SizedBox(width: filterWidth, child: filter),
          ]),
        ],
        if (actions.isNotEmpty) ...[
          if (rows.isNotEmpty) SizedBox(height: rowSpacing),
          _scrollRow(actions),
        ],
      ],
    );
  }
}

/// Flutter counterpart of the web `CollectionPagination` (used by the Purchase
/// and Vendor Invoice pages). Supports the `'all'` page-size option.
class InvCollectionPagination extends StatelessWidget {
  const InvCollectionPagination({
    super.key,
    required this.total,
    required this.pageSize,
    required this.onPageSizeChanged,
    required this.currentPage,
    required this.onPageChanged,
    this.noun = 'entries',
    this.pageSizeOptions = const ['10', '50', '100', 'all'],
  });

  final int total;
  final String pageSize;
  final ValueChanged<String> onPageSizeChanged;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final String noun;
  final List<String> pageSizeOptions;

  @override
  Widget build(BuildContext context) {
    final isAll = pageSize == 'all';
    final size = isAll ? (total < 1 ? 1 : total) : (int.tryParse(pageSize) ?? 10);
    final totalPages = total == 0 ? 1 : (total / size).ceil();
    final start = total == 0 ? 0 : (currentPage - 1) * (isAll ? 0 : size) + 1;
    final end = (currentPage * size).clamp(0, total);

    var startPage = (currentPage - 2).clamp(1, totalPages);
    var endPage = (startPage + 4).clamp(1, totalPages);
    startPage = (endPage - 4).clamp(1, totalPages);
    final pages = [for (var p = startPage; p <= endPage; p++) p];

    void go(int n) => onPageChanged(n.clamp(1, totalPages));

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Show', style: TextStyle(fontSize: 13, color: context.mutedFg)),
              const SizedBox(width: 8),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: context.line),
                  borderRadius: BorderRadius.circular(8),
                  color: context.inputFill,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: pageSize,
                    isDense: true,
                    borderRadius: BorderRadius.circular(8),
                    style: TextStyle(fontSize: 12, color: context.fg),
                    items: [
                      for (final opt in pageSizeOptions)
                        DropdownMenuItem(
                          value: opt,
                          child: Text(opt == 'all' ? 'All' : opt),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) onPageSizeChanged(v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(noun, style: TextStyle(fontSize: 13, color: context.mutedFg)),
            ],
          ),
          Text(
            'Showing $start to $end of $total $noun',
            style: TextStyle(fontSize: 13, color: context.mutedFg),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _navButton(
                context,
                label: 'Previous',
                enabled: currentPage > 1 && total > 0,
                onTap: () => go(currentPage - 1),
              ),
              const SizedBox(width: 6),
              for (final page in pages) ...[
                _pageButton(context, page, page == currentPage, () => go(page)),
                const SizedBox(width: 6),
              ],
              _navButton(
                context,
                label: 'Next',
                enabled: currentPage < totalPages && total > 0,
                onTap: () => go(currentPage + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navButton(
    BuildContext context, {
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: context.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: enabled
                  ? context.fg
                  : context.mutedFg.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageButton(
    BuildContext context,
    int page,
    bool active,
    VoidCallback onTap,
  ) {
    return Material(
      color: active ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          width: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: active ? AppColors.primary : context.line,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$page',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? context.surface : context.fg,
            ),
          ),
        ),
      ),
    );
  }
}
