import 'package:flutter/material.dart';

/// Colour tokens taken 1:1 from `client/src/app/globals.css` (`:root` block),
/// so the app renders with the exact palette of the web client.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF5F5F5); // --background
  static const Color foreground = Color(0xFF09090B); // --foreground
  static const Color card = Color(0xFFFFFFFF); // --card
  static const Color cardForeground = Color(0xFF09090B);
  static const Color primary = Color(0xFF008080); // --primary
  static const Color primaryForeground = Color(0xFFFAFAFA);
  static const Color secondary = Color(0xFFF5F5F5);
  static const Color secondaryForeground = Color(0xFF171717);
  static const Color muted = Color(0xFFF5F5F5); // --muted
  static const Color mutedForeground = Color(0xFF71717A); // --muted-foreground
  static const Color accent = Color(0xFF32CD32); // --accent
  static const Color border = Color(0xFFCCCCCC); // --border
  static const Color input = Color(0xFFFFFFFF);
  static const Color destructive = Color(0xFFDC2626);

  // Greys used by shadcn components ( zinc scale )
  static const Color zinc50 = Color(0xFFFAFAFA);
  static const Color zinc100 = Color(0xFFF4F4F5);
  static const Color zinc200 = Color(0xFFE4E4E7);
  static const Color zinc700 = Color(0xFF3F3F46);
  static const Color zinc900 = Color(0xFF18181B);

  // Google-finance style series colours used by the dashboard charts
  static const Color chartUp = Color(0xFF0F9D58);
  static const Color chartDown = Color(0xFFD93025);

  // Dark-mode tokens, taken from the `.dark` block in `client/src/app/globals.css`.
  static const Color darkBackground = Color(0xFF18181B);
  static const Color darkForeground = Color(0xFFFAFAFA);
  static const Color darkCard = Color(0xFF1D1D21);
  static const Color darkMuted = Color(0xFF27272A);
  static const Color darkMutedForeground = Color(0xFFA1A1AA);
  static const Color darkBorder = Color(0xFF27272A);
  static const Color darkInput = Color(0xFF27272A);
  static const Color darkDestructive = Color(0xFFB91C1C);
  static const Color darkPrimary = Color(0xFF00B3B3);

  // Sidebar palette (`--sidebar-*`): dark in BOTH themes, like the web client.
  static const Color sidebar = Color(0xFF18181B);
  static const Color sidebarForeground = Color(0xFFF4F4F5);
  static const Color sidebarMutedForeground = Color(0xFFA1A1AA);
  static const Color sidebarAccent = Color(0xFF27272A);
  static const Color sidebarBorder = Color(0xFF27272A);

  // Emerald brand accents used by the logo gradient + active nav states.
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald600 = Color(0xFF059669);
  static const Color green600 = Color(0xFF16A34A);
  static const Color red400 = Color(0xFFF87171);
}

/// Brightness-aware colour tokens, so widgets can follow the dark/light
/// toggle instead of baking in `AppColors.*` light constants.
extension AppPalette on BuildContext {
  ThemeData get theme => Theme.of(this);
  bool get isDark => theme.brightness == Brightness.dark;
  Color get bg => isDark ? AppColors.darkBackground : AppColors.background;
  Color get fg => isDark ? AppColors.darkForeground : AppColors.foreground;
  Color get surface => isDark ? AppColors.darkCard : AppColors.card;
  Color get mutedFg =>
      isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground;
  Color get line => isDark ? AppColors.darkBorder : AppColors.border;
  Color get subtle => isDark ? AppColors.darkMuted : AppColors.muted;
  Color get inputFill => isDark ? AppColors.darkInput : AppColors.input;
  Color get dangerText => isDark ? AppColors.red400 : AppColors.destructive;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: AppColors.primaryForeground,
        secondary: AppColors.accent,
        surface: AppColors.card,
        onSurface: AppColors.cardForeground,
        error: AppColors.destructive,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.foreground,
        displayColor: AppColors.foreground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.foreground,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.input,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: const TextStyle(color: AppColors.mutedForeground),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.foreground, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.foreground,
          foregroundColor: AppColors.primaryForeground,
          minimumSize: const Size.fromHeight(44),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(40),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.foreground,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.card),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkPrimary,
        primary: AppColors.darkPrimary,
        onPrimary: AppColors.darkForeground,
        secondary: AppColors.emerald500,
        surface: AppColors.darkCard,
        onSurface: AppColors.darkForeground,
        error: AppColors.darkDestructive,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.darkForeground,
        displayColor: AppColors.darkForeground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkCard,
        foregroundColor: AppColors.darkForeground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.darkForeground,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkInput,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: const TextStyle(color: AppColors.darkMutedForeground),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.darkForeground,
            width: 1.4,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.darkForeground,
          foregroundColor: AppColors.darkBackground,
          minimumSize: const Size.fromHeight(44),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkForeground,
          side: const BorderSide(color: AppColors.darkBorder),
          minimumSize: const Size.fromHeight(40),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkMuted,
        contentTextStyle: TextStyle(color: AppColors.darkForeground),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.darkCard),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

/// Shared card shell matching shadcn's `<Card>` (border + soft shadow).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.gradientTint = false,
    this.gradientColors,
    this.borderRadius = 12,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool gradientTint;
  final List<Color>? gradientColors;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    // NOTE: this deliberately avoids a Stack. A Stack's loose fit lays its
    // child out with fully unbounded constraints to measure intrinsic size,
    // which makes Material buttons (e.g. OutlinedButton) assert on
    // "BoxConstraints forces an infinite width" when the card sits inside a
    // scrollable with unbounded height. The 3% gradient tint is therefore
    // painted with a foreground decoration instead.
    final colors = gradientTint ? gradientColors : null;
    final content = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: context.line),
        boxShadow: [
          BoxShadow(
            color: context.isDark
                ? const Color(0x66000000)
                : const Color(0x0A000000),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      foregroundDecoration: colors == null || colors.length < 2
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                colors: [for (final c in colors) c.withValues(alpha: 0.03)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: content,
      ),
    );
  }
}
