import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';
import 'brand_logo.dart';

enum _MenuAction { profile, theme, logout }

/// The sticky top bar: green FinTrack ERP logo on the left, the signed-in
/// user's avatar menu (name, email, Profile, dark/light mode, logout) on the
/// right — same layout as `client/src/components/layout/header.tsx`.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.onMenu,
    required this.onSelect,
    required this.onLogout,
  });

  /// Opens the nav drawer; null on wide screens where the sidebar is pinned.
  final VoidCallback? onMenu;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogout;

  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    final narrow = onMenu != null;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 16),
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(bottom: BorderSide(color: context.line)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (narrow)
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu_outlined),
              onPressed: onMenu,
            ),
          if (narrow) const SizedBox(width: 4),
          const BrandLogo(size: 34),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'FinTrack ERP',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: context.fg,
              ),
            ),
          ),
          const Spacer(),
          _AvatarButton(onOpen: (box) => _openMenu(context, box)),
        ],
      ),
    );
  }

  Future<void> _openMenu(BuildContext context, RenderBox box) async {
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screen = MediaQuery.sizeOf(context);
    const menuWidth = 240.0;
    final left = (position.dx + size.width - menuWidth).clamp(
      8.0,
      screen.width - menuWidth - 8.0,
    );

    final action = await showMenu<_MenuAction>(
      context: context,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      position: RelativeRect.fromLTRB(
        left,
        position.dy + size.height + 8,
        screen.width - left - menuWidth,
        8,
      ),
      items: [
        PopupMenuItem<_MenuAction>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _MenuHeader(
            width: menuWidth,
            name: Session.userName,
            company: Session.companyName,
            email: Session.userEmail,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_MenuAction>(
          value: _MenuAction.profile,
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18),
              SizedBox(width: 10),
              Text('Profile', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.theme,
          child: Row(
            children: [
              Icon(
                ThemeController.mode.value == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                ThemeController.mode.value == ThemeMode.dark
                    ? 'Light Mode'
                    : 'Dark Mode',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_MenuAction>(
          value: _MenuAction.logout,
          child: Row(
            children: [
              Icon(Icons.logout_outlined, size: 18, color: context.dangerText),
              const SizedBox(width: 10),
              Text(
                'Log out',
                style: TextStyle(fontSize: 14, color: context.dangerText),
              ),
            ],
          ),
        ),
      ],
    );

    switch (action) {
      case _MenuAction.profile:
        onSelect('/admin/company-profile');
      case _MenuAction.theme:
        ThemeController.toggle();
      case _MenuAction.logout:
        onLogout();
      case null:
        break;
    }
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.onOpen});

  final ValueChanged<RenderBox> onOpen;

  @override
  Widget build(BuildContext context) {
    final key = GlobalKey();
    final name = Session.userName;
    final initial = (name == null || name.trim().isEmpty)
        ? 'U'
        : name.trim()[0].toUpperCase();

    return KeyedSubtree(
      key: key,
      child: Material(
        key: const ValueKey('user-avatar'),
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            final box = key.currentContext?.findRenderObject() as RenderBox?;
            if (box != null && box.hasSize) onOpen(box);
          },
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.emerald500, AppColors.green600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0x3310B981)),
              ),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({
    required this.width,
    required this.name,
    required this.company,
    required this.email,
  });

  final double width;
  final String? name;
  final String? company;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Keeps the column flush with the popup's left edge regardless of the
      // menu item's default padding (which we disabled).
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.emerald500.withValues(alpha: 0.10),
            AppColors.green600.withValues(alpha: 0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (name == null || name!.trim().isEmpty) ? 'User' : name!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.fg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (company == null || company!.trim().isEmpty)
                ? 'Company'
                : '(${company!.trim()})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.emerald600),
          ),
          const SizedBox(height: 4),
          Text(
            (email == null || email!.trim().isEmpty)
                ? 'user@example.com'
                : email!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: context.mutedFg),
          ),
        ],
      ),
    );
  }
}
