import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'messages_models.dart';

// ---------------------------------------------------------------- gradients --

const List<Color> newMsgGradient = [Color(0xFF10B981), Color(0xFF0D9488)];
const List<Color> sentMsgGradient = [Color(0xFF3B82F6), Color(0xFF0891B2)];
const List<Color> draftMsgGradient = [Color(0xFFF59E0B), Color(0xFFEA580C)];
const List<Color> whatsappGradient = [Color(0xFF22C55E), Color(0xFF059669)];
const List<Color> otherMsgGradient = [Color(0xFF8B5CF6), Color(0xFF9333EA)];
const List<Color> expiredMsgGradient = [Color(0xFFF43F5E), Color(0xFFDC2626)];

const List<Color> blueCyanGradient = [Color(0xFF3B82F6), Color(0xFF0891B2)];
const List<Color> emeraldGreenGradient = [Color(0xFF10B981), Color(0xFF16A34A)];
const List<Color> roseRedGradient = [Color(0xFFF43F5E), Color(0xFFDC2626)];

/// `{param}` chip used in template tables / dialogs.
class ParamChip extends StatelessWidget {
  const ParamChip({super.key, required this.param, this.onRemove});

  final String param;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final bg = context.isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
        : const Color(0xFFDBEAFE);
    final fg = context.isDark
        ? const Color(0xFF60A5FA)
        : const Color(0xFF1D4ED8);
    return Container(
      margin: const EdgeInsets.only(right: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '{$param}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              child: Icon(Icons.close, size: 12, color: fg),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small ghost icon button matching the web row actions (`h-8 w-8`).
class MessageActionIcon extends StatelessWidget {
  const MessageActionIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
    this.size = 18,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}

/// Label + dropdown select matching the web shadcn `Select` used for filters.
class MsgSelect extends StatelessWidget {
  const MsgSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.maxWidth = 220,
    this.displayLabel,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final double maxWidth;
  final String Function(String value)? displayLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: context.line),
              borderRadius: BorderRadius.circular(8),
              color: context.inputFill,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: items.contains(value) ? value : items.first,
                isExpanded: true,
                isDense: true,
                borderRadius: BorderRadius.circular(8),
                style: TextStyle(fontSize: 14, color: context.fg),
                items: [
                  for (final item in items)
                    DropdownMenuItem(
                      value: item,
                      child: Text(
                        displayLabel?.call(item) ?? item,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Filter layout for the Messages screens. Filters are arranged in rows (two
/// rows whenever there are more than two filters) and the whole block scrolls
/// horizontally when the filters don't fit — mirroring the summary-card
/// behaviour of [NetworkStatGrid].
class MsgFilterGrid extends StatelessWidget {
  const MsgFilterGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        const minCell = 200.0;
        final count = children.length;
        if (count == 0) return const SizedBox.shrink();

        final rowsCount = count > 2 ? 2 : 1;
        final perRow = (count / rowsCount).ceil();
        final totalSpacing = spacing * (perRow - 1);
        final bounded = constraints.hasBoundedWidth;
        final fill = bounded
            ? (constraints.maxWidth - totalSpacing) / perRow
            : minCell;
        final cell = fill < minCell ? minCell : fill;
        final contentWidth = cell * perRow + totalSpacing;
        final scrolls = !bounded || contentWidth > constraints.maxWidth + 0.5;

        final rows = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var r = 0; r < rowsCount; r++) ...[
              if (r > 0) const SizedBox(height: spacing),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < perRow; c++) ...[
                    if (c > 0) const SizedBox(width: spacing),
                    SizedBox(
                      width: cell,
                      child: r * perRow + c < count
                          ? children[r * perRow + c]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );

        if (!scrolls) return rows;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: rows,
        );
      },
    );
  }
}

/// Generic preview dialog: a two-column field list plus a message body box.
Future<void> showMessagePreviewDialog(
  BuildContext context, {
  required String title,
  required List<MapEntry<String, String>> fields,
  required String bodyLabel,
  required String body,
  Color? bodyTint,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: dialogContext.surface,
        title: Text(title, style: const TextStyle(fontSize: 18)),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: [
                    for (final field in fields)
                      SizedBox(
                        width: 200,
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: dialogContext.fg,
                            ),
                            children: [
                              TextSpan(
                                text: '${field.key}: ',
                                style: TextStyle(color: dialogContext.mutedFg),
                              ),
                              TextSpan(
                                text: field.value.isEmpty ? '-' : field.value,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bodyTint ?? dialogContext.inputFill,
                    borderRadius: BorderRadius.circular(8),
                    border: bodyTint != null
                        ? Border.all(color: bodyTint.withValues(alpha: 0.5))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bodyLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: dialogContext.mutedFg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(body.isEmpty ? 'No message content' : body),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              foregroundColor: dialogContext.mutedFg,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

/// Confirmation dialog mirroring the web `confirm(...)` prompts.
Future<bool> showMessageConfirmDialog(
  BuildContext context, {
  required String message,
  String title = 'Please confirm',
  String confirmLabel = 'Confirm',
  Color? confirmColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: dialogContext.surface,
        title: Text(title, style: const TextStyle(fontSize: 18)),
        content: Text(message, style: const TextStyle(fontSize: 14)),
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
              backgroundColor: confirmColor ?? AppColors.primary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Compact checkbox matching the web table / list checkboxes.
class MsgCheckbox extends StatelessWidget {
  const MsgCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = AppColors.primary,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Checkbox(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        activeColor: activeColor,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: context.line, width: 1.5),
      ),
    );
  }
}

/// Distinct sorted sub-locality names from the area list (web `sublocalities`).
List<String> sublocalitiesFrom(List<MsgArea> areas) {
  final set = <String>{};
  for (final area in areas) {
    if (area.subLocality.isNotEmpty) set.add(area.subLocality);
  }
  final list = set.toList()..sort();
  return list;
}

/// Resolves the sub-locality label for a message's connected subscriber.
String areaLabelFor(
  Map<String, MsgConnection> connections,
  List<MsgArea> areas,
  String entityId,
) {
  final conn = entityId.isEmpty ? null : connections[entityId];
  if (conn == null) return '';
  for (final area in areas) {
    if (area.id == conn.sublocalityId) {
      return area.subLocality.isNotEmpty ? area.subLocality : area.locality;
    }
  }
  return '';
}

/// Distinct non-empty values in insertion order (web `new Set(...)`).
List<String> distinctValues(Iterable<String> values) {
  final set = <String>{};
  for (final value in values) {
    if (value.isNotEmpty) set.add(value);
  }
  return set.toList();
}

/// Web-style search matcher: numeric queries match entity / internet / mobile
/// prefixes, text queries match name (and optionally messageType).
bool msgMatchesSearch(
  String search, {
  required String entityId,
  required String internetId,
  required String mobileNo,
  required String name,
  String? messageType,
}) {
  final q = search.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (RegExp(r'^[0-9]').hasMatch(q)) {
    return entityId.toLowerCase().startsWith(q) ||
        internetId.toLowerCase().startsWith(q) ||
        mobileNo.toLowerCase().startsWith(q);
  }
  if (name.toLowerCase().startsWith(q)) return true;
  if (messageType != null && messageType.toLowerCase().startsWith(q)) {
    return true;
  }
  return false;
}

/// Redirects to the login screen when the API returns 401.
void messageUnauthorizedHandler() {
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

/// Messages + connections + areas shared by the Sent / Draft / WhatsApp /
/// Other / Expired pages.
class MsgData {
  const MsgData({
    required this.messages,
    required this.connections,
    required this.areas,
  });

  final List<MsgMessage> messages;
  final List<MsgConnection> connections;
  final List<MsgArea> areas;

  Map<String, MsgConnection> get connectionMap => {
    for (final c in connections) c.id: c,
  };

  String areaName(String entityId) =>
      areaLabelFor(connectionMap, areas, entityId);
}

/// Loads messages, connections and areas for the current company.
Future<MsgData> fetchMsgData(ApiClient api, String companyId) async {
  final results = await Future.wait([
    api.get('/messages', query: {'companyId': companyId}),
    api.get('/admin/connections', query: {'companyId': companyId}),
    api.get('/network/areas', query: {'companyId': companyId}),
  ]);
  return MsgData(
    messages: ApiClient.listData(results[0])
        .whereType<Map<String, dynamic>>()
        .map(MsgMessage.fromJson)
        .toList(),
    connections: ApiClient.listData(results[1])
        .whereType<Map<String, dynamic>>()
        .map(MsgConnection.fromJson)
        .toList(),
    areas: ApiClient.listData(results[2])
        .whereType<Map<String, dynamic>>()
        .map(MsgArea.fromJson)
        .toList(),
  );
}

/// Loads the company list (`/companies`) as `{id, name}` maps.
Future<List<Map<String, dynamic>>> fetchCompanies(ApiClient api) async {
  final json = await api.get('/companies');
  return ApiClient.listData(json).whereType<Map<String, dynamic>>().toList();
}
