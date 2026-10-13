import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'recovery_common.dart';
import 'recovery_models.dart';

/// Flutter counterpart of
/// `client/src/app/(app)/recovery-officers-management/areas/page.tsx` — the
/// "Area Management" page: KPI cards, an area⇄officer assignment transfer panel
/// and the all-areas table.
class AreaAssignmentScreen extends StatefulWidget {
  const AreaAssignmentScreen({super.key});

  @override
  State<AreaAssignmentScreen> createState() => _AreaAssignmentScreenState();
}

class _AreaAssignmentScreenState extends State<AreaAssignmentScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<RecoveryArea> _areas = [];
  List<RecoveryOfficer> _officers = [];
  bool _loading = true;

  String _filter = '';
  final TextEditingController _search = TextEditingController();

  // Transfer state.
  String _officerId = '';
  final Set<String> _leftSelected = {};
  final Set<String> _rightSelected = {};
  List<String> _stagedRight = [];
  List<String> _stagedLeft = [];
  bool _savingAssign = false;
  bool _savingArea = false;

  static void _handleUnauthorized() {
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

  String? get _cid => Session.companyId;

  bool get _canManageAssign =>
      recPage(kAreaAssignmentPermission, 'officer-select');
  bool get _canEditArea => recCrud(kAreaPermission, 'update');
  bool get _canDeleteArea => recCrud(kAreaPermission, 'delete');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final areasJson = await _api.get('/network/areas', query: {'companyId': cid});
      final officersJson =
          await _api.get('/admin/recovery-officers', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _areas = ApiClient.listData(areasJson)
            .whereType<Map<String, dynamic>>()
            .map(RecoveryArea.fromJson)
            .toList();
        _officers = ApiClient.listData(officersJson)
            .whereType<Map<String, dynamic>>()
            .map(RecoveryOfficer.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // -------------------------------------------------------------------------
  // Assignment helpers (mirror the web transfer-list logic).
  // -------------------------------------------------------------------------

  RecoveryOfficer? get _selectedOfficer {
    for (final o in _officers) {
      if (o.id == _officerId) return o;
    }
    return null;
  }

  bool _isAssignedTo(RecoveryArea area, String officerId) =>
      area.recoveryOfficerIds.contains(officerId);

  String _officerNamesFor(RecoveryArea area) {
    final names = <String>[];
    for (final id in area.recoveryOfficerIds) {
      for (final o in _officers) {
        if (o.id == id && o.name.isNotEmpty) names.add(o.name);
      }
    }
    return names.join(', ');
  }

  void _resetStaging() {
    setState(() {
      _stagedRight = [];
      _stagedLeft = [];
      _leftSelected.clear();
      _rightSelected.clear();
    });
  }

  void _stageToRight(List<String> ids) {
    if (_officerId.isEmpty || ids.isEmpty) return;
    final next = List<String>.from(_stagedRight);
    for (final id in ids) {
      RecoveryArea? area;
      for (final a in _areas) {
        if (a.id == id) {
          area = a;
          break;
        }
      }
      if (area == null || _isAssignedTo(area, _officerId)) continue;
      if (!next.contains(id)) next.add(id);
    }
    setState(() {
      _stagedLeft = _stagedLeft.where((id) => !ids.contains(id)).toList();
      _stagedRight = next;
      _leftSelected.clear();
      _rightSelected.clear();
    });
  }

  void _stageToLeft(List<String> ids) {
    if (ids.isEmpty) return;
    final next = List<String>.from(_stagedLeft);
    for (final id in ids) {
      if (!next.contains(id)) next.add(id);
    }
    setState(() {
      _stagedRight = _stagedRight.where((id) => !ids.contains(id)).toList();
      _stagedLeft = next;
      _rightSelected.removeWhere(ids.contains);
      _leftSelected.clear();
    });
  }

  int get _stagedChangeCount => _stagedRight.length + _stagedLeft.length;

  List<RecoveryArea> get _leftAreasForMove => _areas;
  List<RecoveryArea> get _rightAreasForMove {
    final kept = _areas
        .where((a) => _isAssignedTo(a, _officerId) && !_stagedLeft.contains(a.id))
        .toList();
    final added = _areas.where(
      (a) => _stagedRight.contains(a.id) && !_isAssignedTo(a, _officerId),
    );
    return [...kept, ...added];
  }

  Future<void> _saveAssignments() async {
    if (_officerId.isEmpty || _stagedChangeCount == 0) return;
    setState(() => _savingAssign = true);
    var count = 0;
    try {
      for (final id in _stagedRight) {
        await _api.post(
          '/network/areas/$id/assign-officer',
          body: {'recoveryOfficerId': _officerId},
        );
        count++;
      }
      for (final id in _stagedLeft) {
        await _api.post(
          '/network/areas/$id/unassign-officer',
          body: {'recoveryOfficerId': _officerId},
        );
        count++;
      }
      if (mounted) showToast(context, '$count area(s) updated.');
      _resetStaging();
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) {
        showToast(context, 'Failed after $count area(s): ${e.message}', error: true);
      }
    } finally {
      if (mounted) setState(() => _savingAssign = false);
    }
  }

  // -------------------------------------------------------------------------
  // Areas CRUD.
  // -------------------------------------------------------------------------

  List<RecoveryArea> get _filteredAreas => _areas
      .where((a) => netContains(_filter, [a.city, a.zone, a.locality]))
      .toList();

  Future<void> _editArea(RecoveryArea area) async {
    final result = await showDialog<_AreaFormResult>(
      context: context,
      builder: (_) => _AreaFormDialog(area: area),
    );
    if (result == null) return;
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    setState(() => _savingArea = true);
    try {
      await _api.put(
        '/network/areas/${area.id}',
        body: {
          'id': area.id,
          'city': result.city,
          'zone': result.zone,
          'locality': result.locality,
          'subLocality': result.subLocality,
          'recoveryOfficerId': area.recoveryOfficerId,
          'companyId': cid,
        },
      );
      if (mounted) showToast(context, 'Area updated successfully');
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _savingArea = false);
    }
  }

  Future<void> _deleteArea(RecoveryArea area) async {
    await showNetworkDeleteDialog(
      context,
      itemName: '${area.locality}, ${area.city}',
      onConfirm: () async {
        try {
          await _api.delete('/network/areas/${area.id}');
          if (mounted) showToast(context, 'Area deleted successfully');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cities = _areas.map((a) => a.city).toSet().length;
    final assigned = _areas
        .where((a) => a.recoveryOfficerIds.isNotEmpty)
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.map_outlined,
            title: 'Area Management',
            subtitle: 'View and manage areas assigned to recovery officers.',
            gradient: recAreaGradient,
          ),
          NetworkStatGrid(
            children: [
              NetworkStatCard(
                icon: Icons.map_outlined,
                label: 'Total Areas',
                value: '${_areas.length}',
                gradient: recBlueStatGradient,
              ),
              NetworkStatCard(
                icon: Icons.location_city_outlined,
                label: 'Cities',
                value: '$cities',
                gradient: recEmeraldStatGradient,
                valueColor: AppColors.emerald600,
              ),
              NetworkStatCard(
                icon: Icons.groups_outlined,
                label: 'Officers Assigned',
                value: '$assigned',
                gradient: recVioletStatGradient,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_canManageAssign) ...[
              _assignCard(context),
              const SizedBox(height: 24),
            ],
            _areasCard(context),
          ],
        ],
      ),
    );
  }

  Widget _assignCard(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.map_outlined, size: 18, color: AppColors.emerald600),
              const SizedBox(width: 8),
              const Text(
                'Assign Areas to Recovery Officer',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 320,
            child: NetField(
              label: 'Select Recovery Officer',
              child: DropdownButtonFormField<String>(
                key: ValueKey(_officerId),
                initialValue: _officerId.isEmpty ? null : _officerId,
                isExpanded: true,
                style: TextStyle(fontSize: 14, color: context.fg),
                decoration: netInputDecoration(context),
                hint: Text(
                  'Choose a recovery officer',
                  style: TextStyle(fontSize: 14, color: context.mutedFg),
                ),
                items: [
                  for (final o in _officers)
                    DropdownMenuItem(
                      value: o.id,
                      child: Text(
                        o.email.isEmpty ? o.name : '${o.name} - ${o.email}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) {
                  setState(() {
                    _officerId = v ?? '';
                    _stagedRight = [];
                    _stagedLeft = [];
                    _leftSelected.clear();
                    _rightSelected.clear();
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_officerId.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Select a recovery officer above to manage their area assignments.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.mutedFg),
              ),
            )
          else
            _transferPanel(context),
        ],
      ),
    );
  }

  Widget _transferPanel(BuildContext context) {
    final left = _leftAreasForMove;
    final right = _rightAreasForMove;

    final leftBox = _TransferBox(
      title: 'All Areas (${left.length})',
      accent: context.isDark ? AppColors.darkMuted : AppColors.muted,
      emptyText: 'No areas available',
      items: [
        for (final area in left)
          _TransferItem(
            id: area.id,
            label: '${area.locality}, ${area.city}',
            subtitle: _officerNamesFor(area),
          ),
      ],
      selected: _leftSelected,
      onToggle: (id) => setState(() {
        _leftSelected.contains(id)
            ? _leftSelected.remove(id)
            : _leftSelected.add(id);
      }),
    );

    final rightBox = _TransferBox(
      title: 'Areas Assigned to ${_selectedOfficer?.name ?? ''} (${right.length})',
      accent: const Color(0xFFD1FAE5),
      titleColor: const Color(0xFF065F46),
      emptyText: 'No areas assigned',
      items: [
        for (final area in right)
          _TransferItem(
            id: area.id,
            label: '${area.locality}, ${area.city}',
          ),
      ],
      selected: _rightSelected,
      onToggle: (id) => setState(() {
        _rightSelected.contains(id)
            ? _rightSelected.remove(id)
            : _rightSelected.add(id);
      }),
    );

    const spacing = 12.0;
    final buttons = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _moveButton(
          icon: Icons.chevron_right,
          tooltip: 'Move selected (or first) to assigned',
          onTap: left.isEmpty || _savingAssign
              ? null
              : () => _stageToRight(
                    _leftSelected.isNotEmpty
                        ? _leftSelected.toList()
                        : [left.first.id],
                  ),
        ),
        _moveButton(
          icon: Icons.keyboard_double_arrow_right,
          tooltip: 'Move all to assigned',
          onTap: left.isEmpty || _savingAssign
              ? null
              : () => _stageToRight(left.map((a) => a.id).toList()),
        ),
        _moveButton(
          icon: Icons.chevron_left,
          tooltip: 'Move selected (or first) back',
          onTap: right.isEmpty || _savingAssign
              ? null
              : () => _stageToLeft(
                    _rightSelected.isNotEmpty
                        ? _rightSelected.toList()
                        : [right.first.id],
                  ),
        ),
        _moveButton(
          icon: Icons.keyboard_double_arrow_left,
          tooltip: 'Move all back',
          onTap: right.isEmpty || _savingAssign
              ? null
              : () => _stageToLeft(right.map((a) => a.id).toList()),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                children: [
                  leftBox,
                  const SizedBox(height: spacing),
                  buttons,
                  const SizedBox(height: spacing),
                  rightBox,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: leftBox),
                const SizedBox(width: spacing),
                buttons,
                const SizedBox(width: spacing),
                Expanded(child: rightBox),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.line)),
          ),
          padding: const EdgeInsets.only(top: 16),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _stagedChangeCount > 0
                      ? '$_stagedChangeCount pending change(s) - click Save to apply them to ${_selectedOfficer?.name ?? 'this officer'}.'
                      : '',
                  style: TextStyle(fontSize: 12, color: context.mutedFg),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  foregroundColor: context.mutedFg,
                ),
                onPressed: _stagedChangeCount == 0 || _savingAssign
                    ? null
                    : _resetStaging,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset'),
              ),
              GradientButton(
                label: _savingAssign ? 'Saving...' : 'Save Assignments',
                icon: _savingAssign ? null : Icons.save_outlined,
                loading: _savingAssign,
                gradient: recEmeraldStatGradient,
                onPressed: _stagedChangeCount == 0 || _savingAssign
                    ? null
                    : _saveAssignments,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _moveButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 40),
          padding: EdgeInsets.zero,
          foregroundColor: context.mutedFg,
        ),
        child: Tooltip(
          message: tooltip,
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }

  Widget _areasCard(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.map_outlined, size: 18, color: AppColors.emerald600),
              const SizedBox(width: 8),
              const Text(
                'All Areas',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RecFilterBar(
            filters: [
              TextField(
                controller: _search,
                onChanged: (v) => setState(() => _filter = v),
                style: const TextStyle(fontSize: 14),
                decoration: netInputDecoration(
                  context,
                  hint: 'Filter by city, zone, or locality...',
                ).copyWith(
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: context.mutedFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          NetworkTable<RecoveryArea>(
            rows: _filteredAreas,
            emptyIcon: Icons.map_outlined,
            emptyTitle: 'No areas found.',
            emptyHint: 'Add areas from the Network module to assign them.',
            emptyTint: AppColors.emerald600,
            mobileTrailing: (context, area, _) =>
                (_canEditArea || _canDeleteArea)
                    ? NetworkRowActions(
                        onEdit: _canEditArea ? () => _editArea(area) : null,
                        onDelete: _canDeleteArea ? () => _deleteArea(area) : null,
                      )
                    : const SizedBox.shrink(),
            columns: [
              NetColumn(
                label: 'City',
                width: 160,
                builder: (context, area, _) => Text(area.city),
              ),
              NetColumn(
                label: 'Zone',
                width: 150,
                builder: (context, area, _) => Text(area.zone),
              ),
              NetColumn(
                label: 'Locality',
                width: 200,
                builder: (context, area, _) => Text(area.locality),
              ),
              NetColumn(
                label: 'Sub-Locality',
                width: 160,
                builder: (context, area, _) => area.subLocality.isEmpty
                    ? Text('N/A', style: TextStyle(color: context.mutedFg))
                    : Text(area.subLocality),
              ),
              NetColumn(
                label: 'Assigned Officers',
                width: 240,
                builder: (context, area, _) {
                  final names = _officerNamesFor(area);
                  return names.isEmpty
                      ? Text('Unassigned', style: TextStyle(color: context.mutedFg))
                      : Text(area.recoveryOfficerIds
                          .map((id) {
                            for (final o in _officers) {
                              if (o.id == id) return o.name;
                            }
                            return '';
                          })
                          .where((n) => n.isNotEmpty)
                          .join(', '));
                },
              ),
              NetColumn(
                label: '',
                width: 96,
                isActions: true,
                builder: (context, area, _) {
                  if (!_canEditArea && !_canDeleteArea) {
                    return const SizedBox.shrink();
                  }
                  return Align(
                    alignment: Alignment.centerRight,
                    child: NetworkRowActions(
                      onEdit: _canEditArea ? () => _editArea(area) : null,
                      onDelete: _canDeleteArea ? () => _deleteArea(area) : null,
                      editTooltip: 'Edit Area',
                      deleteTooltip: 'Delete Area',
                    ),
                  );
                },
              ),
            ],
          ),
          if (_savingArea)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

class _TransferItem {
  const _TransferItem({
    required this.id,
    required this.label,
    this.subtitle = '',
  });

  final String id;
  final String label;
  final String subtitle;
}

class _TransferBox extends StatelessWidget {
  const _TransferBox({
    required this.title,
    required this.items,
    required this.selected,
    required this.onToggle,
    required this.emptyText,
    required this.accent,
    this.titleColor,
  });

  final String title;
  final List<_TransferItem> items;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String emptyText;
  final Color accent;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: accent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
          ),
          SizedBox(
            height: 280,
            child: items.isEmpty
                ? Center(
                    child: Text(
                      emptyText,
                      style: TextStyle(fontSize: 12, color: context.mutedFg),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(4),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final isSelected = selected.contains(item.id);
                      return InkWell(
                        onTap: () => onToggle(item.id),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFD1FAE5) : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? const Color(0xFF065F46)
                                    : context.fg,
                                fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                              children: [
                                TextSpan(text: item.label),
                                if (item.subtitle.isNotEmpty)
                                  TextSpan(
                                    text: '  (${item.subtitle})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.mutedFg,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AreaFormResult {
  const _AreaFormResult({
    required this.city,
    required this.zone,
    required this.locality,
    required this.subLocality,
  });

  final String city;
  final String zone;
  final String locality;
  final String subLocality;
}

class _AreaFormDialog extends StatefulWidget {
  const _AreaFormDialog({required this.area});

  final RecoveryArea area;

  @override
  State<_AreaFormDialog> createState() => _AreaFormDialogState();
}

class _AreaFormDialogState extends State<_AreaFormDialog> {
  late final TextEditingController _city;
  late final TextEditingController _zone;
  late final TextEditingController _locality;
  late final TextEditingController _subLocality;
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _city = TextEditingController(text: widget.area.city);
    _zone = TextEditingController(text: widget.area.zone);
    _locality = TextEditingController(text: widget.area.locality);
    _subLocality = TextEditingController(text: widget.area.subLocality);
  }

  @override
  void dispose() {
    _city.dispose();
    _zone.dispose();
    _locality.dispose();
    _subLocality.dispose();
    super.dispose();
  }

  void _submit() {
    final errors = <String, String>{};
    if (_city.text.trim().isEmpty) errors['city'] = 'City is required';
    if (_zone.text.trim().isEmpty) errors['zone'] = 'Zone is required';
    if (_locality.text.trim().isEmpty) {
      errors['locality'] = 'Locality is required';
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
    });
    if (errors.isNotEmpty) return;
    Navigator.of(context).pop(
      _AreaFormResult(
        city: _city.text.trim(),
        zone: _zone.text.trim(),
        locality: _locality.text.trim(),
        subLocality: _subLocality.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('Edit Area', style: TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field('City', _city, 'e.g., Karachi', 'city'),
            _field('Zone', _zone, 'e.g., South', 'zone'),
            _field('Locality', _locality, 'e.g., DHA Phase 6', 'locality'),
            _field('Sub-Locality (Optional)', _subLocality, 'e.g., Street 1-10', null),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            foregroundColor: context.mutedFg,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.emerald600,
            minimumSize: const Size(0, 40),
          ),
          onPressed: _submit,
          child: const Text('Save Area'),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String hint,
    String? errorKey,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NetField(
        label: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              style: const TextStyle(fontSize: 14),
              decoration: netInputDecoration(context, hint: hint),
            ),
            if (errorKey != null && _errors[errorKey] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _errors[errorKey]!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
