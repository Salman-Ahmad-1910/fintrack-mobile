import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../theme/app_theme.dart';
import 'brand_logo.dart';
import 'nav_items.dart';

/// Fixed dark sidebar palette (`--sidebar-*`): the web client keeps the
/// sidebar dark in both light and dark themes, so this widget does not depend
/// on the ambient brightness.
class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.activeId,
    required this.onSelect,
    required this.onLogout,
  });

  final String activeId;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogout;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  /// Titles of the open collapsible groups (single-open, like the web's
  /// `openGroup` state). The Dashboard group is always expanded.
  String? _openGroup;
  final Set<String> _openItems = {};

  static const _activeTint = Color(0x1F10B981);
  static const _hoverTint = Color(0x1410B981);

  @override
  Widget build(BuildContext context) {
    final role = Session.role;
    final sections = <Widget>[];

    for (final group in kNavGroups) {
      final items = group.items.where((i) => navItemVisible(i, role)).toList();
      if (items.isEmpty) continue;

      if (group.title == 'Dashboard') {
        sections
          ..add(_groupLabel(group.title, alwaysOpen: true))
          ..addAll(items.map(_item));
        continue;
      }

      final open = _openGroup == group.title;
      sections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _groupHeader(group.title, open: open),
            if (open) ...items.map(_item),
          ],
        ),
      );
    }

    return Container(
      color: AppColors.sidebar,
      child: Column(
        children: [
          _header(),
          const Divider(color: AppColors.sidebarBorder, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: sections,
            ),
          ),
          const Divider(color: AppColors.sidebarBorder, height: 1),
          _footer(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- pieces ---

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          const BrandLogo(size: 34),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'FinTrack ERP',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.sidebarForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupLabel(String title, {required bool alwaysOpen}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: alwaysOpen ? AppColors.emerald500 : const Color(0xB3F4F4F5),
        ),
      ),
    );
  }

  Widget _groupHeader(String title, {required bool open}) {
    return InkWell(
      onTap: () => setState(() => _openGroup = open ? null : title),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: open ? AppColors.emerald500 : const Color(0xB3F4F4F5),
                ),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: open ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: open
                    ? AppColors.emerald500
                    : AppColors.sidebarMutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(NavItem item) {
    if (item.hasChildren) return _parentItem(item);

    final active = widget.activeId == item.id;
    final color = active ? AppColors.emerald500 : AppColors.sidebarForeground;
    return Container(
      decoration: BoxDecoration(
        color: active ? _activeTint : null,
        border: active
            ? const Border(
                right: BorderSide(color: AppColors.emerald500, width: 2),
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          hoverColor: _hoverTint,
          onTap: () => widget.onSelect(item.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 16,
                  color: active
                      ? AppColors.emerald500
                      : AppColors.sidebarMutedForeground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _parentItem(NavItem item) {
    final open = _openItems.contains(item.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (open) {
              _openItems.remove(item.id);
            } else {
              _openItems.add(item.id);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 16,
                  color: AppColors.sidebarMutedForeground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.sidebarForeground,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: const Icon(
                    Icons.chevron_right,
                    size: 15,
                    color: AppColors.sidebarMutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (open)
          ...item.children!
              .where((c) => navItemVisible(c, Session.role))
              .map(_childItem),
      ],
    );
  }

  Widget _childItem(NavItem item) {
    final active = widget.activeId == item.id;
    return InkWell(
      hoverColor: _hoverTint,
      onTap: () => widget.onSelect(item.id),
      child: Container(
        decoration: BoxDecoration(
          color: active ? _activeTint : null,
          border: active
              ? const Border(
                  right: BorderSide(color: AppColors.emerald500, width: 2),
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 6, 12, 6),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 14,
                color: active
                    ? AppColors.emerald500
                    : AppColors.sidebarMutedForeground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: active
                        ? AppColors.emerald500
                        : AppColors.sidebarForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          _footerItem(
            title: 'Support',
            icon: Icons.support_agent_outlined,
            onTap: () => widget.onSelect('/support'),
          ),
          _footerItem(
            title: 'Logout',
            icon: Icons.logout_outlined,
            onTap: widget.onLogout,
          ),
        ],
      ),
    );
  }

  Widget _footerItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        hoverColor: _hoverTint,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.sidebarMutedForeground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.sidebarForeground,
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
