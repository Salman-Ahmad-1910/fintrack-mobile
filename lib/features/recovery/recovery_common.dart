import 'package:flutter/material.dart';

import '../../core/session.dart';

/// Gradient pairs used across the Recovery Officers section — the Flutter
/// counterparts of the web `bg-gradient-to-br from-* to-*` utilities.
const List<Color> recOfficerGradient = [Color(0xFF2563EB), Color(0xFF4F46E5)];
const List<Color> recAreaGradient = [Color(0xFF2563EB), Color(0xFF4F46E5)];

const List<Color> recBlueStatGradient = [Color(0xFF3B82F6), Color(0xFF06B6D4)];
const List<Color> recEmeraldStatGradient = [Color(0xFF10B981), Color(0xFF16A34A)];
const List<Color> recVioletStatGradient = [Color(0xFF8B5CF6), Color(0xFF9333EA)];
const List<Color> recAmberStatGradient = [Color(0xFFF59E0B), Color(0xFFEA580C)];
const List<Color> recBlueButtonGradient = [Color(0xFF3B82F6), Color(0xFF4F46E5)];

// ---------------------------------------------------------------------------
// Permission ids (mirrors `permission-pages.ts` PAGE_PERMISSIONS)
// ---------------------------------------------------------------------------

const String kRecoveryOfficerPermission = '13317'; // Recovery Officer
const String kAreaPermission = '13309'; // Area (Network)
const String kAreaAssignmentPermission = '13319'; // Area Assignment

/// Global CRUD fallbacks (permissions.ts `PERMISSIONS`).
const String kRecCanCreate = '15362';
const String kRecCanUpdate = '15363';
const String kRecCanDelete = '15364';

const List<String> kRecAdminRoles = ['admin', 'owner', 'manager'];

/// Mirrors the web `baseHasPermission`: admin/owner/manager (and users whose
/// permissions are not configured) always pass; otherwise the id must be in
/// the session's granted permission list.
bool recHasPermission(String id) {
  final isAdmin = kRecAdminRoles.contains(Session.role ?? '');
  if (isAdmin || !Session.permissionsConfigured) return true;
  return Session.permissions.contains(id);
}

/// `hasPagePermission` — a page child key only (no global fallback).
bool recPage(String pageId, String key) => recHasPermission('$pageId:$key');

/// `hasCrudPermission` — the page child key, else the global CRUD id.
bool recCrud(String pageId, String action) {
  if (recHasPermission('$pageId:$action')) return true;
  return recCrudGlobal(action);
}

/// Global-only CRUD check, mirroring the web `useCrudPermissions()` fallback.
bool recCrudGlobal(String action) {
  final id = switch (action) {
    'create' => kRecCanCreate,
    'update' => kRecCanUpdate,
    _ => kRecCanDelete,
  };
  return recHasPermission(id);
}

/// Two-row filter bar shared by the Recovery screens. Filter inputs flow across
/// rows ([filtersPerRow] per row); filters and actions each scroll
/// horizontally so nothing overflows on narrow screens. Mirrors `InvFilterBar`.
class RecFilterBar extends StatelessWidget {
  const RecFilterBar({
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

  @override
  Widget build(BuildContext context) {
    final rows = _filterRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: rowSpacing),
          Row(
            children: [
              for (var j = 0; j < rows[i].length; j++) ...[
                if (j > 0) SizedBox(width: spacing),
                SizedBox(width: filterWidth, child: rows[i][j]),
              ],
            ],
          ),
        ],
        if (actions.isNotEmpty) ...[
          if (rows.isNotEmpty) SizedBox(height: rowSpacing),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) SizedBox(width: spacing),
                  actions[i],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
