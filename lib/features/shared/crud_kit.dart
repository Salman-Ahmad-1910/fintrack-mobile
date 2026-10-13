import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import '../transaction/transaction_common.dart';

/// Small shared toolkit for the modules ported after the first wave
/// (Complaints, HR, System Log, Downloads, Subscriber reports). It only wraps
/// widgets that already exist in the app (Network*, Tx*, AppCard, showToast)
/// so the new screens look identical to the existing ones.

// ---------------------------------------------------------------------------
// Gradients (web `from-* to-*` pairs used by these pages)
// ---------------------------------------------------------------------------

const List<Color> kitEmerald = [Color(0xFF10B981), Color(0xFF16A34A)];
const List<Color> kitBlue = [Color(0xFF3B82F6), Color(0xFF0891B2)];
const List<Color> kitAmber = [Color(0xFFF59E0B), Color(0xFFEA580C)];
const List<Color> kitRose = [Color(0xFFEF4444), Color(0xFFE11D48)];
const List<Color> kitSlate = [Color(0xFF6B7280), Color(0xFF475569)];
const List<Color> kitViolet = [Color(0xFF8B5CF6), Color(0xFF9333EA)];
const List<Color> kitIndigo = [Color(0xFF6366F1), Color(0xFF4F46E5)];

// ---------------------------------------------------------------------------
// JSON helpers
// ---------------------------------------------------------------------------

String kitStr(Object? v) => v == null ? '' : v.toString();

double kitNum(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse(kitStr(v)) ?? 0;
}

int kitInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(kitStr(v)) ?? 0;
}

bool kitBool(Object? v) => v == true || kitStr(v).toLowerCase() == 'true';

/// The list carried by a `{success, data: [...]}` envelope as plain maps.
List<Map<String, dynamic>> kitMaps(Map<String, dynamic> envelope) =>
    ApiClient.listData(envelope)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

/// `new Date(x).toLocaleDateString()` equivalent used by the web tables.
String kitDate(String raw) {
  if (raw.isEmpty) return '—';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return DateFormat('dd/MM/yyyy').format(d.toLocal());
}

String kitDateTime(String raw) {
  if (raw.isEmpty) return '—';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return DateFormat('dd/MM/yyyy hh:mm a').format(d.toLocal());
}

String kitToday() => DateFormat('yyyy-MM-dd').format(DateTime.now());

final NumberFormat _money = NumberFormat('#,##0.00');
String kitMoney(num v) => _money.format(v);

/// `capitalize` + `-`→space, e.g. `in-progress` → `In progress`.
String kitTitle(String v) {
  if (v.isEmpty) return v;
  final s = v.replaceAll('-', ' ').replaceAll('_', ' ');
  return s[0].toUpperCase() + s.substring(1);
}

/// Case-insensitive contains across several fields.
bool kitMatch(String query, Iterable<String?> values) =>
    netContains(query, values);

// ---------------------------------------------------------------------------
// Auth / company guards
// ---------------------------------------------------------------------------

/// Shared 401 handler (same behaviour as the existing screens): clear the
/// session and send the user back to the sign-in screen.
void kitHandleUnauthorized() {
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

/// Reports an API failure as a toast, ignoring 401 (already redirected).
void kitReportError(BuildContext context, Object error, {String? fallback}) {
  if (error is ApiException && error.isUnauthorized) return;
  if (!context.mounted) return;
  final message = error is ApiException
      ? error.message
      : (fallback ?? 'Something went wrong. Please try again.');
  showToast(context, message, error: true);
}

// ---------------------------------------------------------------------------
// Layout pieces
// ---------------------------------------------------------------------------

class KitLoading extends StatelessWidget {
  const KitLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 64),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// Error card with a retry button (used when the first load fails).
class KitErrorCard extends StatelessWidget {
  const KitErrorCard({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.cloud_off_outlined, size: 36, color: context.dangerText),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: context.mutedFg),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Please select a company" placeholder (the web pages show the same card).
class KitNoCompany extends StatelessWidget {
  const KitNoCompany({super.key, required this.what});

  final String what;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Please select a company to view $what.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedFg),
        ),
      ),
    );
  }
}

/// Label + dropdown (wraps [TxSelect]).
class KitSelect extends StatelessWidget {
  const KitSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return NetField(
      label: label,
      child: TxSelect(value: value, items: items, onChanged: onChanged),
    );
  }
}

/// Label + text field.
class KitTextField extends StatelessWidget {
  const KitTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.readOnly = false,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool readOnly;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return NetField(
      label: label,
      child: TextField(
        controller: controller,
        maxLines: obscure ? 1 : maxLines,
        minLines: 1,
        readOnly: readOnly,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14),
        decoration: netInputDecoration(context, hint: hint).copyWith(
          filled: readOnly,
          fillColor: readOnly ? context.subtle : null,
        ),
      ),
    );
  }
}

/// Label + read-only value box.
class KitReadOnly extends StatelessWidget {
  const KitReadOnly({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return NetField(
      label: label,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: context.subtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.line),
        ),
        child: Text(
          value.isEmpty ? '—' : value,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

/// Coloured pill used by status / category columns.
class KitPill extends StatelessWidget {
  const KitPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) =>
      TxBadge(label: label, color: foreground, background: background);
}

/// One web KPI tile (`rounded-xl border p-4` + gradient icon).
NetworkStatCard kitStat(
  String label,
  Object value,
  IconData icon,
  List<Color> gradient,
) => NetworkStatCard(
  icon: icon,
  label: label,
  value: '$value',
  gradient: gradient,
);

/// Overflow menu used for per-row actions (the web `DropdownMenu`).
class KitRowMenu extends StatelessWidget {
  const KitRowMenu({super.key, required this.actions});

  /// label → (icon, callback). Entries with a null callback are hidden.
  final List<KitAction> actions;

  @override
  Widget build(BuildContext context) {
    final visible = actions.where((a) => a.onTap != null).toList();
    if (visible.isEmpty) return const SizedBox(width: 40);
    return PopupMenuButton<int>(
      tooltip: 'Actions',
      icon: Icon(Icons.more_horiz, color: context.mutedFg),
      onSelected: (i) => visible[i].onTap!(),
      itemBuilder: (_) => [
        for (var i = 0; i < visible.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(
                  visible[i].icon,
                  size: 18,
                  color: visible[i].danger ? context.dangerText : null,
                ),
                const SizedBox(width: 10),
                Text(
                  visible[i].label,
                  style: TextStyle(
                    color: visible[i].danger ? context.dangerText : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class KitAction {
  const KitAction(this.label, this.icon, this.onTap, {this.danger = false});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
}

// ---------------------------------------------------------------------------
// Form sheet
// ---------------------------------------------------------------------------

/// Opens a scrollable bottom sheet form (the mobile replacement for the web
/// `Dialog` forms). [onSubmit] returns true to close the sheet; while it runs
/// the submit button shows a spinner and double taps are ignored.
Future<void> showKitForm(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context, StateSetter setState) builder,
  required Future<bool> Function() onSubmit,
  String submitLabel = 'Save',
  List<Color> gradient = kitEmerald,
  IconData icon = Icons.edit_note_outlined,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      var saving = false;
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> submit() async {
            if (saving) return;
            setSheetState(() => saving = true);
            var close = false;
            try {
              close = await onSubmit();
            } finally {
              if (ctx.mounted) setSheetState(() => saving = false);
            }
            if (close && ctx.mounted) Navigator.of(ctx).pop();
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: gradient),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: builder(ctx, setSheetState),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        GradientButton(
                          label: saving ? 'Saving...' : submitLabel,
                          gradient: gradient,
                          loading: saving,
                          onPressed: submit,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Vertical spacing helper for form fields.
const SizedBox kitGap = SizedBox(height: 14);

/// Two fields side by side on wide screens, stacked on phones.
class KitRow extends StatelessWidget {
  const KitRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) kitGap,
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// Simple client-side paging, matching the web pages' `slice()` paging.
List<T> kitPage<T>(List<T> rows, int page, int pageSize) {
  final start = (page - 1) * pageSize;
  if (start >= rows.length || start < 0) {
    return rows.take(pageSize).toList();
  }
  final end = math.min(start + pageSize, rows.length);
  return rows.sublist(start, end);
}
