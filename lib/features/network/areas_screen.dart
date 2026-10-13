import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import 'network_common.dart';
import 'network_models.dart';

const List<Color> _greenGradient = [Color(0xFF166534), Color(0xFF22C55E)];
const List<Color> _blueGradient = [Color(0xFF1E40AF), Color(0xFF3B82F6)];
const List<Color> _amberGradient = [Color(0xFFB45309), Color(0xFFFB923C)];

/// Flutter counterpart of `client/src/app/(app)/network/areas/page.tsx` —
/// define and manage service coverage areas.
class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key});

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<NetArea> _areas = [];
  bool _loading = true;
  String _filter = '';
  int _page = 1;
  int _pageSize = 10;
  final TextEditingController _search = TextEditingController();

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
      final json = await _api.get(
        '/network/areas',
        query: {'companyId': cid},
      );
      if (!mounted) return;
      setState(() {
        _areas = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(NetArea.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<NetArea> get _filtered => _areas
      .where(
        (a) => netContains(_filter, [a.city, a.zone, a.locality, a.subLocality]),
      )
      .toList();

  List<NetArea> get _pageRows {
    final start = (_page - 1) * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  void _setFilter(String value) {
    setState(() {
      _filter = value;
      _page = 1;
    });
  }

  Future<void> _save(Map<String, dynamic> values, NetArea? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/network/areas/${existing.id}?companyId=$cid',
          body: values,
        );
        if (mounted) showToast(context, 'Area updated successfully.');
      } else {
        await _api.post(
          '/network/areas?companyId=$cid',
          body: {...values, 'companyId': cid},
        );
        if (mounted) showToast(context, 'Area added successfully.');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(NetArea area) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    await showNetworkDeleteDialog(
      context,
      itemName: '${area.locality}, ${area.city}',
      onConfirm: () async {
        try {
          await _api.delete('/network/areas/${area.id}?companyId=$cid');
          if (mounted) showToast(context, 'Area deleted successfully.');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openForm(NetArea? area) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AreaFormDialog(area: area),
    );
    if (result != null) await _save(result, area);
  }

  @override
  Widget build(BuildContext context) {
    final cities = _areas.map((a) => a.city).toSet().length;
    final zones = _areas.map((a) => a.zone).toSet().length;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.layers_outlined,
            title: 'Area Management',
            subtitle: 'Define and manage your service coverage areas.',
            gradient: _greenGradient,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NetworkStatGrid(
                      children: [
                        NetworkStatCard(
                          icon: Icons.location_on_outlined,
                          label: 'Total Areas',
                          value: '${_areas.length}',
                          gradient: _greenGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.apartment_outlined,
                          label: 'Cities',
                          value: '$cities',
                          gradient: _blueGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.layers_outlined,
                          label: 'Zones',
                          value: '$zones',
                          gradient: _amberGradient,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _toolbar(context),
                    const SizedBox(height: 16),
                    NetworkTable<NetArea>(
                      rows: _pageRows,
                      emptyIcon: Icons.location_on_outlined,
                      emptyTitle: 'No areas found.',
                      emptyHint: 'Get started by adding a new area.',
                      emptyTint: AppColors.emerald600,
                      mobileTrailing: (context, area, _) =>
                          NetworkRowActions(
                            onEdit: () => _openForm(area),
                            onDelete: () => _delete(area),
                          ),
                      columns: [
                        NetColumn(
                          label: 'ID',
                          width: 60,
                          builder: (context, area, index) => Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: context.mutedFg,
                            ),
                          ),
                        ),
                        NetColumn(
                          label: 'City',
                          width: 180,
                          builder: (context, area, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppColors.emerald500,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  area.city,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        NetColumn(
                          label: 'Zone',
                          width: 140,
                          builder: (context, area, _) => Text(area.zone),
                        ),
                        NetColumn(
                          label: 'Locality',
                          width: 180,
                          builder: (context, area, _) => Text(area.locality),
                        ),
                        NetColumn(
                          label: 'Sub-Locality',
                          width: 160,
                          builder: (context, area, _) => area.subLocality.isEmpty
                              ? Text(
                                  'N/A',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: context.mutedFg,
                                  ),
                                )
                              : Text(area.subLocality),
                        ),
                        NetColumn(
                          label: '',
                          width: 96,
                          isActions: true,
                          builder: (context, area, _) => Align(
                            alignment: Alignment.centerRight,
                            child: NetworkRowActions(
                              onEdit: () => _openForm(area),
                              onDelete: () => _delete(area),
                              editTooltip: 'Edit Area',
                              deleteTooltip: 'Delete Area',
                            ),
                          ),
                        ),
                      ],
                    ),
                    NetworkPagination(
                      currentPage: _page,
                      pageSize: _pageSize,
                      totalItems: _filtered.length,
                      noun: 'areas',
                      onPageChanged: (p) => setState(() => _page = p),
                      onPageSizeChanged: (s) => setState(() {
                        _pageSize = s;
                        _page = 1;
                      }),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final search = TextField(
      controller: _search,
      onChanged: _setFilter,
      style: const TextStyle(fontSize: 14),
      decoration: netInputDecoration(
        context,
        hint: 'Filter by city, zone, or locality...',
      ).copyWith(
        prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
      ),
    );
    final add = GradientButton(
      label: 'Add New Area',
      icon: Icons.add_circle_outline,
      gradient: _greenGradient,
      onPressed: () => _openForm(null),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              add,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: add),
          ],
        );
      },
    );
  }
}

class _AreaFormDialog extends StatefulWidget {
  const _AreaFormDialog({this.area});

  final NetArea? area;

  @override
  State<_AreaFormDialog> createState() => _AreaFormDialogState();
}

class _AreaFormDialogState extends State<_AreaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _city;
  late final TextEditingController _zone;
  late final TextEditingController _locality;
  late final TextEditingController _subLocality;

  @override
  void initState() {
    super.initState();
    final area = widget.area;
    _city = TextEditingController(text: area?.city ?? '');
    _zone = TextEditingController(text: area?.zone ?? '');
    _locality = TextEditingController(text: area?.locality ?? '');
    _subLocality = TextEditingController(text: area?.subLocality ?? '');
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
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'city': _city.text.trim(),
      'zone': _zone.text.trim(),
      'locality': _locality.text.trim(),
      'subLocality': _subLocality.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.area != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: _greenGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text('${editing ? 'Edit' : 'Add'} Area'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NetField(
                label: 'City',
                child: TextFormField(
                  controller: _city,
                  decoration: netInputDecoration(context, hint: 'e.g., Karachi'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'City is required' : null,
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Zone',
                child: TextFormField(
                  controller: _zone,
                  decoration: netInputDecoration(context, hint: 'e.g., South'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Zone is required' : null,
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Locality',
                child: TextFormField(
                  controller: _locality,
                  decoration: netInputDecoration(
                    context,
                    hint: 'e.g., DHA Phase 6',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Locality is required'
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Sub-Locality (Optional)',
                child: TextFormField(
                  controller: _subLocality,
                  decoration: netInputDecoration(
                    context,
                    hint: 'e.g., Street 1-10',
                  ),
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
            foregroundColor: context.dangerText,
            side: BorderSide(color: context.dangerText.withValues(alpha: 0.3)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Save Area',
          gradient: _greenGradient,
          onPressed: _submit,
        ),
      ],
    );
  }
}
