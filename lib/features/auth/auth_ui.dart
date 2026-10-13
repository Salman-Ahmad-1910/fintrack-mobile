import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/tailwind.dart';

/// Tailwind breakpoints (the web client is Tailwind v3 defaults).
const double kMdBreakpoint = 768;
const double kLgBreakpoint = 1024;

bool isMdWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kMdBreakpoint;
bool isLgWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kLgBreakpoint;

/// Replicates the web app's split auth layout:
/// `min-h-screen flex bg-gray-50` with a white form pane and — from the `lg`
/// breakpoint up — the dark animated content pane on the right.
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.form, required this.panel});

  /// Left (white) pane content: back link + card.
  final Widget form;

  /// Right (dark gradient) pane content.
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    final wide = isLgWide(context);
    final body = wide
        ? Row(
            children: [
              Expanded(child: _LeftPane(child: form)),
              Expanded(child: _RightPane(child: panel)),
            ],
          )
        : _LeftPane(child: form);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: body),
    );
  }
}

class _LeftPane extends StatelessWidget {
  const _LeftPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: child,
        ),
      ),
    );
  }
}

class _RightPane extends StatelessWidget {
  const _RightPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Tw.gray900, Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(child: _PanelBlobs()),
          Positioned.fill(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 512),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three blurred glow blobs of the auth panes (`animate-pulse`).
class _PanelBlobs extends StatefulWidget {
  const _PanelBlobs();

  @override
  State<_PanelBlobs> createState() => _PanelBlobsState();
}

class _PanelBlobsState extends State<_PanelBlobs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Tailwind's animate-pulse eases opacity between 1 and 0.5.
        final opacity =
            1.0 - 0.5 * Curves.easeInOut.transform(_controller.value);
        return Stack(
          children: [
            _blob(
              top: -160,
              right: -160,
              size: 320,
              opacity: opacity * 0.2,
              colors: const [Tw.gray700, Tw.gray800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            _blob(
              bottom: -160,
              left: -160,
              size: 384,
              opacity: opacity * 0.3,
              colors: const [Tw.gray600, Tw.gray700],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            _blob(
              top: 0,
              bottom: 0,
              left: 0,
              right: 0,
              alignment: Alignment.center,
              size: 600,
              opacity: 0.4,
              colors: const [Tw.gray800, Tw.gray900],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ],
        );
      },
    );
  }

  Widget _blob({
    double? top,
    double? bottom,
    double? left,
    double? right,
    Alignment alignment = Alignment.center,
    required double size,
    required double opacity,
    required List<Color> colors,
    required Alignment begin,
    required Alignment end,
  }) {
    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors.map((c) => c.withValues(alpha: opacity)).toList(),
          begin: begin,
          end: end,
        ),
      ),
    );
    if (top == null && bottom == null && left == null && right == null) {
      return Align(alignment: alignment, child: box);
    }
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: box,
    );
  }
}

/// shadcn `<Label>` + `<Input>` pair, matching the `className`s used on the
/// web login/signup forms (border-gray-300, focus:border-gray-900, h-10).
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.validator,
    this.suffixIcon,
    this.labelAction,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Widget? suffixIcon;

  /// Rendered on the right of the label row (the web app puts the
  /// "Forgot password?" link there).
  final Widget? labelAction;

  @override
  Widget build(BuildContext context) {
    // Web: `text-base md:text-sm`.
    final fontSize = isMdWide(context) ? 14.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelAction == null)
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w500,
              color: Tw.gray700,
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: Tw.gray700,
                ),
              ),
              labelAction!,
            ],
          ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(fontSize: fontSize, color: AppColors.foreground),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: fontSize,
              color: AppColors.mutedForeground,
            ),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            suffixIcon: suffixIcon ?? const SizedBox(width: 12, height: 40),
            suffixIconConstraints: suffixIcon == null
                ? const BoxConstraints.tightFor(width: 12, height: 40)
                : const BoxConstraints.tightFor(width: 40, height: 40),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Tw.gray300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Tw.gray300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Tw.gray900, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.destructive),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.destructive),
            ),
          ),
        ),
      ],
    );
  }
}

/// shadcn `<Card className="w-full border-gray-200 shadow-lg">` with the
/// `CardHeader` / `CardContent` paddings from `components/ui/card.tsx`.
class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Tw.gray200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 15,
            spreadRadius: -3,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            spreadRadius: -4,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1,
                    letterSpacing: -0.6,
                    fontWeight: FontWeight.w700,
                    color: Tw.gray900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Tw.gray600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// `<Button type="submit" className="w-full bg-gray-900 hover:bg-black text-white">`
/// with shadcn's disabled styling (`disabled:opacity-50`).
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
  });

  final VoidCallback? onPressed;
  final String label;
  final String? loadingLabel;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final child = Text(loading ? (loadingLabel ?? label) : label);

    return Opacity(
      opacity: loading ? 0.5 : 1,
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: ElevatedButton(
          onPressed: loading ? () {} : onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            backgroundColor: Tw.gray900,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Tw.gray900,
            disabledForegroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The "← Back to Home" link above the auth cards.
class BackToHomeLink extends StatelessWidget {
  const BackToHomeLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.arrow_back_outlined, size: 16, color: Tw.gray600),
              SizedBox(width: 8),
              Text(
                'Back to Home',
                style: TextStyle(fontSize: 16, color: Tw.gray600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The icon + title + subtitle rows used by both dark auth panes.
class PanelFeature extends StatelessWidget {
  const PanelFeature({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 24, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Tw.gray400),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// shadcn `MessageDialog` (`components/shared/message-dialog.tsx`).
Future<void> showMessageDialog(
  BuildContext context, {
  required bool isError,
  String? title,
  required String message,
  String confirmLabel = 'OK',
  Future<void> Function()? onConfirm,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (context) => _MessageDialog(
      isError: isError,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      onConfirm: onConfirm,
    ),
  );
}

class _MessageDialog extends StatelessWidget {
  const _MessageDialog({
    required this.isError,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final bool isError;
  final String? title;
  final String message;
  final String confirmLabel;
  final Future<void> Function()? onConfirm;

  @override
  Widget build(BuildContext context) {
    final heading = title ?? (isError ? 'Something went wrong' : 'Success');
    final viewportWide = MediaQuery.sizeOf(context).width >= 640;

    final button = SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: () async {
          final confirm = onConfirm;
          Navigator.of(context).pop();
          if (confirm != null) await confirm();
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(confirmLabel),
      ),
    );

    return Dialog(
      backgroundColor: AppColors.background,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 16),
                      color: AppColors.foreground,
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isError
                                ? const [Tw.red500, Tw.red600]
                                : const [Tw.emerald500, Tw.emerald600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isError
                              ? Icons.error_outline
                              : Icons.check_circle_outline,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        heading,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Tw.gray900,
                        ),
                      ),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Tw.gray600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (viewportWide)
                Center(child: button)
              else
                SizedBox(width: double.infinity, child: button),
            ],
          ),
        ),
      ),
    );
  }
}
