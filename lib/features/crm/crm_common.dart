import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';

/// Gradient pairs used across the Subscribers Management / CRM section. Kept
/// as top-level constants so screens and dialogs share identical colours.
const List<Color> crmGreenGradient = [Color(0xFF10B981), Color(0xFF16A34A)];
const List<Color> crmAmberGradient = [Color(0xFFF59E0B), Color(0xFFEA580C)];
const List<Color> crmTealGradient = [Color(0xFF14B8A6), Color(0xFF0891B2)];
const List<Color> crmIndigoGradient = [Color(0xFF6366F1), Color(0xFF9333EA)];
const List<Color> crmRoseGradient = [Color(0xFFF43F5E), Color(0xFFDB2777)];
const List<Color> crmEmeraldVioletGradient = [
  Color(0xFF10B981),
  Color(0xFF7C3AED),
];
const List<Color> crmBlueGradient = [Color(0xFF3B82F6), Color(0xFF2563EB)];
const List<Color> crmSlateGradient = [Color(0xFF64748B), Color(0xFF4B5563)];

/// Status colour tokens matching the web badges (`text-green-600`, etc.).
const Color crmStatusActive = Color(0xFF16A34A);
const Color crmStatusInactive = Color(0xFF6B7280);
const Color crmStatusDeactivated = Color(0xFFDC2626);
const Color crmStatusSuspended = Color(0xFFD97706);

/// `Intl.NumberFormat('en-US')` — the web's default number formatting.
final NumberFormat _thousands = NumberFormat.decimalPattern();

/// Web `Number(value).toLocaleString()`.
String crmNumber(num? value) => _thousands.format(value ?? 0);

/// Web decimal formatting for the average widget (`toFixed(1)`).
String crmFixed1(num value) => value.toStringAsFixed(1);

/// Colour for a connection `status` (active / inactive / deactivated /
/// suspended), matching the subscriber-detail table.
Color connStatusColor(String status) {
  switch (status) {
    case 'active':
      return crmStatusActive;
    case 'deactivated':
      return crmStatusDeactivated;
    case 'suspended':
      return crmStatusSuspended;
    default:
      return crmStatusInactive;
  }
}

/// Rounded status pill mirroring the web `<Badge>`.
class CrmBadge extends StatelessWidget {
  const CrmBadge({
    super.key,
    required this.label,
    required this.color,
    this.solid = false,
  });

  final String label;
  final Color color;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: solid ? 1 : 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: solid ? Colors.white : color,
        ),
      ),
    );
  }
}

/// Maps a connection type to its web label.
String connTypeLabel(String type) {
  switch (type) {
    case 'both':
      return 'Both';
    case 'internet':
      return 'Internet';
    case 'tv_cable':
      return 'Cable';
    default:
      return type;
  }
}

/// Maps an inquiry connection type to its web label.
String inquiryTypeLabel(String type) {
  switch (type) {
    case 'both':
      return 'Both';
    case 'internet':
      return 'Internet';
    case 'tv_cable':
      return 'TV Cable';
    default:
      return type;
  }
}

/// Feedback dialog mirroring the web `ActionFeedbackDialog` used after
/// create / update / delete actions.
Future<void> showCrmFeedback(
  BuildContext context, {
  required String type,
  required String title,
  required String message,
}) {
  final Color color;
  final IconData icon;
  switch (type) {
    case 'success':
      color = AppColors.emerald600;
      icon = Icons.check_circle_outline;
    case 'error':
      color = AppColors.destructive;
      icon = Icons.error_outline;
    default:
      color = AppColors.primary;
      icon = Icons.info_outline;
  }
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: dialogContext.surface,
      title: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17))),
        ],
      ),
      content: Text(message, style: const TextStyle(fontSize: 14)),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

String _twoDigits(int n) => n < 10 ? '0$n' : '$n';

/// Formats a [DateTime] as the web's `type=date` value (`yyyy-MM-dd`).
String crmDateValue(DateTime d) =>
    '${d.year}-${_twoDigits(d.month)}-${_twoDigits(d.day)}';

/// Input-decorated date picker field, mirroring the web `<Input type="date">`.
class CrmDateField extends StatelessWidget {
  const CrmDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'yyyy-mm-dd',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hint;

  Future<void> _pick(BuildContext context) async {
    final initial = DateTime.tryParse(value) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(crmDateValue(picked));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          suffixIcon: Icon(
            Icons.calendar_today,
            size: 16,
            color: context.mutedFg,
          ),
        ),
        child: Text(
          value.isEmpty ? hint : value,
          style: TextStyle(
            fontSize: 14,
            color: value.isEmpty ? context.mutedFg : context.fg,
          ),
        ),
      ),
    );
  }
}

/// Padded scroll body shared by the CRM screens.
class CrmScrollBody extends StatelessWidget {
  const CrmScrollBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: children,
    );
  }
}
