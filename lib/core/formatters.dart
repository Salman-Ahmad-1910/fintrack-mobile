/// Number / date helpers that reproduce the exact strings the web client
/// renders (JS `toLocaleString`, `formatCurrency`, `toLocaleDateString`).
library;

import 'package:intl/intl.dart';

final NumberFormat _grouped = NumberFormat('#,##0');
final NumberFormat _groupedDecimals = NumberFormat('#,##0.##');

String grouped(num value) => _grouped.format(value);

String groupedDecimals(num value) => _groupedDecimals.format(value);

/// "PKR 1,234,567" — used by the dashboard's financial metric cards.
String pkr(num value) => 'PKR ${grouped(value)}';

/// Compact currency used by the gauge and the charts:
/// PKR 1.2M / PKR 340.5K / PKR 12Cr
String compactCurrency(num value, {bool withCode = true}) {
  final prefix = withCode ? 'PKR ' : '';
  final abs = value.abs();
  if (abs >= 10000000) {
    return '$prefix${(value / 10000000).toStringAsFixed(1)}Cr';
  }
  if (abs >= 1000000) return '$prefix${(value / 1000000).toStringAsFixed(1)}M';
  if (abs >= 1000) return '$prefix${(value / 1000).toStringAsFixed(1)}K';
  return '$prefix${grouped(value)}';
}

const List<String> kMonthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> kShortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> kDayNames = [
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

/// Parses the label formats the Go backend emits:
/// 'YYYY-MM-DD HH24:MI:SS' | 'YYYY-MM-DD' | 'YYYY-MM'
DateTime? parseServerDate(String label) {
  if (label.isEmpty) return null;
  try {
    if (label.contains(' ')) {
      return DateTime.parse(label.replaceFirst(' ', 'T'));
    }
    final parts = label.split('-');
    if (parts.length == 2) {
      return DateTime(int.parse(parts[0]), int.parse(parts[1]));
    }
    return DateTime.parse(label);
  } catch (_) {
    return null;
  }
}

/// Chart tooltip text, matching the web component's `formatTooltipLabel`.
String tooltipLabel(String label, String period) {
  if (period == 'weekly') {
    final d = parseServerDate(label);
    if (d != null) {
      return DateFormat('EEEE, MMM d').format(d);
    }
    return label;
  }
  if (period == 'monthly') {
    final d = parseServerDate(label);
    if (d != null) return DateFormat('MMMM d').format(d);
    return label;
  }
  if (period == 'yearly') {
    final parts = label.split('-');
    if (parts.length >= 2) {
      final monthIndex = int.tryParse(parts[1]);
      if (monthIndex != null && monthIndex >= 1 && monthIndex <= 12) {
        return '${kShortMonths[monthIndex - 1]} ${parts[0]}';
      }
    }
    return label;
  }
  final d = parseServerDate(label);
  if (d != null) return DateFormat('h:mm a').format(d);
  return label;
}

/// Chart axis text, matching the web component's `formatAxisLabel`.
String axisLabel(String label, String period) {
  if (label.isEmpty) return label;
  if (period == 'weekly') {
    final d = parseServerDate(label);
    if (d != null) return kDayNames[d.weekday % 7];
    return label;
  }
  if (period == 'monthly') {
    final d = parseServerDate(label);
    if (d != null) return d.day.toString();
    return label;
  }
  if (period == 'yearly') {
    final parts = label.split('-');
    if (parts.length >= 2) {
      final monthIndex = int.tryParse(parts[1]);
      if (monthIndex != null && monthIndex >= 1 && monthIndex <= 12) {
        return kShortMonths[monthIndex - 1];
      }
    }
    return label;
  }
  return label;
}

/// Complaint dates are rendered like JS `new Date(x).toLocaleDateString()`.
String complaintDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return DateFormat('M/d/y').format(d.toLocal());
}
