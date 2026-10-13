import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Header block shared by the five Network screens. Mirrors the
/// `mb-6 flex items-center gap-3` header + gradient underline in the web
/// `page.tsx` files, but lets each module pass its own gradient pair.
class NetworkPageHeader extends StatelessWidget {
  const NetworkPageHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: context.fg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: context.mutedFg),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradient.first.withValues(alpha: 0.5),
                  gradient.last.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient stat tile (`rounded-xl border bg-card p-4` with a gradient icon
/// chip) shown at the top of each Network screen.
class NetworkStatCard extends StatelessWidget {
  const NetworkStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<Color> gradient;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                    color: context.mutedFg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? context.fg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays out stat cards in a responsive grid on wide screens. On narrow screens
/// the cards keep a compact fixed width and scroll horizontally in a single
/// row instead of stacking vertically.
class NetworkStatGrid extends StatelessWidget {
  const NetworkStatGrid({
    super.key,
    required this.children,
    this.maxColumns = 3,
    this.breakpoint = 640,
    this.compactWidth = 176,
  });

  final List<Widget> children;
  final int maxColumns;
  final double breakpoint;
  final double compactWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        if (constraints.maxWidth < breakpoint) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: spacing),
                  SizedBox(width: compactWidth, child: children[i]),
                ],
              ],
            ),
          );
        }
        final width =
            (constraints.maxWidth - spacing * (maxColumns - 1)) / maxColumns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// Gradient action button matching the web `Button` gradients
/// (`bg-gradient-to-r ... text-white`).
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.gradient,
    this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final List<Color> gradient;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || onPressed == null;
    final colors = disabled
        ? [for (final c in gradient) c.withValues(alpha: 0.55)]
        : gradient;
    return FilledButton(
      onPressed: disabled ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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

/// One column of a [NetworkTable].
class NetColumn<T> {
  const NetColumn({
    required this.label,
    required this.width,
    required this.builder,
    this.center = false,
    this.isActions = false,
    this.headerBuilder,
  });

  final String label;
  final double width;
  final Widget Function(BuildContext context, T item, int index) builder;
  final bool center;

  /// The trailing actions column — excluded from the mobile key/value list and
  /// rendered via [NetworkTable.mobileTrailing] instead.
  final bool isActions;

  /// Optional header widget (e.g. a select-all checkbox) replacing the label.
  final Widget Function(BuildContext context)? headerBuilder;
}

/// Responsive table. On wide layouts it renders a fixed-width table inside a
/// horizontal scroll (matching the web `DataTable`); below [mobileBreakpoint]
/// each row collapses to a key/value card so nothing overflows on phones.
class NetworkTable<T> extends StatelessWidget {
  const NetworkTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyHint,
    required this.emptyTint,
    this.mobileTrailing,
    this.mobileBreakpoint = 620,
    this.expansionBuilder,
    this.rowCanExpand,
    this.rowKey,
    this.expandedKeys = const {},
    this.onToggleExpand,
  });

  final List<NetColumn<T>> columns;
  final List<T> rows;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyHint;
  final Color emptyTint;
  final Widget Function(BuildContext context, T item, int index)? mobileTrailing;
  final double mobileBreakpoint;

  /// When set, rows can show an expand/collapse toggle that reveals
  /// [expansionBuilder] below the row (used by the Products page).
  final Widget Function(BuildContext context, T item, int index)? expansionBuilder;
  final bool Function(T item)? rowCanExpand;
  final String Function(T item)? rowKey;
  final Set<String> expandedKeys;
  final void Function(String key)? onToggleExpand;

  static const double _expandColWidth = 34;

  bool get _expandable => expansionBuilder != null;

  String _keyOf(T item, int index) => rowKey?.call(item) ?? '$index';

  bool _canExpand(T item, int index) =>
      _expandable && (rowCanExpand?.call(item) ?? false);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (rows.isEmpty) return _empty(context);
        if (constraints.maxWidth < mobileBreakpoint) return _cards(context);
        return _table(context, constraints.maxWidth);
      },
    );
  }

  Widget _empty(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: emptyTint.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(emptyIcon, size: 30, color: emptyTint),
          ),
          const SizedBox(height: 12),
          Text(
            emptyTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.mutedFg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            emptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.mutedFg.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, double available) {
    final tableWidth = columns.fold<double>(0, (sum, c) => sum + c.width) +
        (_expandable ? _expandColWidth : 0);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth < available ? available : tableWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: context.isDark
                    ? AppColors.darkMuted.withValues(alpha: 0.6)
                    : AppColors.muted.withValues(alpha: 0.6),
                child: Row(
                  children: [
                    if (_expandable) const SizedBox(width: _expandColWidth),
                    for (final col in columns)
                      SizedBox(
                        width: col.width,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
child: Align(
                          alignment: col.center
                              ? Alignment.center
                              : Alignment.centerLeft,
                          child: col.headerBuilder != null
                              ? col.headerBuilder!(context)
                              : Text(
                                  col.label,
                                  textAlign: col.center
                                      ? TextAlign.center
                                      : TextAlign.start,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.fg,
                                  ),
                                ),
                        ),
                        ),
                      ),
                  ],
                ),
              ),
              for (var i = 0; i < rows.length; i++) _tableRow(context, i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableRow(BuildContext context, int i) {
    final item = rows[i];
    final key = _keyOf(item, i);
    final canExpand = _canExpand(item, i);
    final expanded = canExpand && expandedKeys.contains(key);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (_expandable)
                SizedBox(
                  width: _expandColWidth,
                  child: canExpand
                      ? InkWell(
                          onTap: () => onToggleExpand?.call(key),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Icon(
                              expanded
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_right,
                              size: 18,
                              color: context.mutedFg,
                            ),
                          ),
                        )
                      : null,
                ),
              for (final col in columns)
                SizedBox(
                  width: col.width,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Align(
                      alignment: col.center
                          ? Alignment.center
                          : Alignment.centerLeft,
                      child: col.builder(context, item, i),
                    ),
                  ),
                ),
            ],
          ),
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              color: context.subtle,
              child: expansionBuilder!(context, item, i),
            ),
        ],
      ),
    );
  }

  Widget _cards(BuildContext context) {
    final fields = columns
        .where((c) => !c.isActions && c.label != 'ID')
        .toList();
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) _card(context, fields, i),
      ],
    );
  }

  Widget _card(BuildContext context, List<NetColumn<T>> fields, int i) {
    final item = rows[i];
    final key = _keyOf(item, i);
    final canExpand = _canExpand(item, i);
    final expanded = canExpand && expandedKeys.contains(key);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final col in fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 116,
                    child: Text(
                      col.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.mutedFg,
                      ),
                    ),
                  ),
                  Expanded(
                    child: col.builder(context, item, i),
                  ),
                ],
              ),
            ),
          if (mobileTrailing != null)
            Align(
              alignment: Alignment.centerRight,
              child: mobileTrailing!(context, item, i),
            ),
          if (canExpand)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onToggleExpand?.call(key),
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                ),
                label: Text(expanded ? 'Hide details' : 'Show details'),
              ),
            ),
          if (expanded) expansionBuilder!(context, item, i),
        ],
      ),
    );
  }
}

/// Pagination footer mirroring the web "Showing X to Y of Z" block, the page
/// size picker, numbered pages (±3 with ellipsis + last page) and a "Go to"
/// jump box. Wraps onto multiple lines on narrow screens.
class NetworkPagination extends StatefulWidget {
  const NetworkPagination({
    super.key,
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.noun,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.pageSizes = const [5, 10, 20, 50, 100],
  });

  final int currentPage;
  final int pageSize;
  final int totalItems;
  final String noun;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final List<int> pageSizes;

  @override
  State<NetworkPagination> createState() => _NetworkPaginationState();
}

class _NetworkPaginationState extends State<NetworkPagination> {
  final TextEditingController _goto = TextEditingController();

  @override
  void dispose() {
    _goto.dispose();
    super.dispose();
  }

  int get _totalPages =>
      widget.totalItems == 0 ? 0 : (widget.totalItems / widget.pageSize).ceil();

  List<int> get _visiblePages {
    final total = _totalPages;
    if (total == 0) return const [];
    final start = (widget.currentPage - 3).clamp(1, total);
    final end = (widget.currentPage + 3).clamp(1, total);
    return [for (var i = start; i <= end; i++) i];
  }

  void _submitGoto() {
    final page = int.tryParse(_goto.text.trim());
    if (page != null && page >= 1 && page <= _totalPages) {
      widget.onPageChanged(page);
      _goto.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.currentPage;
    final total = _totalPages;
    final from = widget.totalItems == 0 ? 0 : (current - 1) * widget.pageSize + 1;
    final to = (current * widget.pageSize).clamp(0, widget.totalItems);

    final info = Text(
      'Showing $from to $to of ${widget.totalItems} ${widget.noun}',
      style: TextStyle(fontSize: 13, color: context.mutedFg),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final controls = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: constraints.maxWidth >= 720
                ? WrapAlignment.end
                : WrapAlignment.start,
            children: [
              _pageSizePicker(context),
              _navButton(
                context,
                label: 'Previous',
                icon: Icons.chevron_left,
                enabled: current > 1,
                onTap: () => widget.onPageChanged(current - 1),
              ),
              for (final page in _visiblePages)
                _pageButton(context, page, page == current),
              if (current + 3 < total) ...[
                Text('...', style: TextStyle(color: context.mutedFg)),
                _pageButton(context, total, false),
              ],
              _gotoBox(context),
              _navButton(
                context,
                label: 'Next',
                icon: Icons.chevron_right,
                iconRight: true,
                enabled: current < total,
                onTap: () => widget.onPageChanged(current + 1),
              ),
            ],
          );

          if (constraints.maxWidth >= 720) {
            return Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 12),
                controls,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [info, const SizedBox(height: 10), controls],
          );
        },
      ),
    );
  }

  Widget _pageSizePicker(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(8),
        color: context.inputFill,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: widget.pageSize,
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          style: TextStyle(fontSize: 12, color: context.fg),
          items: [
            for (final size in widget.pageSizes)
              DropdownMenuItem(value: size, child: Text('$size')),
          ],
          onChanged: (v) {
            if (v != null) widget.onPageSizeChanged(v);
          },
        ),
      ),
    );
  }

  Widget _navButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    bool iconRight = false,
  }) {
    final color = enabled ? context.fg : context.mutedFg.withValues(alpha: 0.5);
    final children = [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 2),
      Text(label, style: TextStyle(fontSize: 13, color: color)),
    ];
    return _chip(
      context,
      onTap: enabled ? onTap : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: iconRight ? children.reversed.toList() : children,
      ),
    );
  }

  Widget _pageButton(BuildContext context, int page, bool active) {
    return _chip(
      context,
      onTap: () => widget.onPageChanged(page),
      active: active,
      child: Text(
        '$page',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: active ? context.surface : context.fg,
        ),
      ),
      square: true,
    );
  }

  Widget _gotoBox(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 32,
          child: TextField(
            controller: _goto,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
            onSubmitted: (_) => _submitGoto(),
            decoration: InputDecoration(
              hintText: 'Go to',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              hintStyle: TextStyle(fontSize: 12, color: context.mutedFg),
            ),
          ),
        ),
        const SizedBox(width: 4),
        _chip(
          context,
          onTap: _submitGoto,
          square: true,
          child: Icon(Icons.arrow_forward, size: 15, color: context.fg),
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context, {
    required Widget child,
    VoidCallback? onTap,
    bool active = false,
    bool square = false,
  }) {
    return Material(
      color: active ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          width: square ? 32 : null,
          alignment: Alignment.center,
          padding: square ? null : const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: active ? AppColors.primary : context.line,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Confirmation dialog mirroring the web `DeleteAlertDialog`.
Future<void> showNetworkDeleteDialog(
  BuildContext context, {
  required String itemName,
  required Future<void> Function() onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: dialogContext.surface,
        title: const Text('Are you sure?', style: TextStyle(fontSize: 18)),
        content: Text(
          'This will permanently delete "$itemName". '
          'This action cannot be undone.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              foregroundColor: dialogContext.mutedFg,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: dialogContext.dangerText,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed == true) {
    await onConfirm();
  }
}

/// Trailing edit / delete icon pair shared by every Network table row.
class NetworkRowActions extends StatelessWidget {
  const NetworkRowActions({
    super.key,
    this.onEdit,
    this.onDelete,
    this.editTooltip = 'Edit',
    this.deleteTooltip = 'Delete',
  });

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String editTooltip;
  final String deleteTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          _actionIcon(
            context,
            icon: Icons.edit_outlined,
            color: AppColors.emerald600,
            tooltip: editTooltip,
            onTap: onEdit!,
          ),
        const SizedBox(width: 4),
        if (onDelete != null)
          _actionIcon(
            context,
            icon: Icons.delete_outline,
            color: context.dangerText,
            tooltip: deleteTooltip,
            onTap: onDelete!,
          ),
      ],
    );
  }

  Widget _actionIcon(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

/// Label + field wrapper used by every Network form dialog.
class NetField extends StatelessWidget {
  const NetField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Shared input decoration for Network form fields.
InputDecoration netInputDecoration(BuildContext context, {String? hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: context.mutedFg, fontSize: 14),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

/// Case-insensitive "contains" filter used by most list searches.
bool netContains(String query, Iterable<String?> values) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  for (final value in values) {
    if ((value ?? '').toLowerCase().contains(q)) return true;
  }
  return false;
}

/// Case-insensitive "starts with" filter (matches the web `prefixMatch` used by
/// the Box / Media page).
bool netPrefix(String query, String value) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return value.toLowerCase().startsWith(q);
}

/// Padded scroll body used by the Network screens.
class NetworkScrollBody extends StatelessWidget {
  const NetworkScrollBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: children,
    );
  }
}
