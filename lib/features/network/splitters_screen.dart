import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import 'network_common.dart';
import 'network_models.dart';

const List<Color> _orangeGradient = [Color(0xFFF59E0B), Color(0xFFEA580C)];
const List<Color> _cyanGradient = [Color(0xFF3B82F6), Color(0xFF0891B2)];
const List<Color> _emeraldGradient = [Color(0xFF10B981), Color(0xFF16A34A)];
const List<Color> _redGradient = [Color(0xFFF43F5E), Color(0xFFDC2626)];

/// Flutter counterpart of `client/src/app/(app)/network/splitters/page.tsx` —
/// manage splitters, their parent OLT and port utilisation.
class SplittersScreen extends StatefulWidget {
  const SplittersScreen({super.key});

  @override
  State<SplittersScreen> createState() => _SplittersScreenState();
}

class _SplittersScreenState extends State<SplittersScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<NetSplitter> _splitters = [];
  List<NetOlt> _olts = [];
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
      final results = await Future.wait([
        _api.get('/network/splitters', query: {'companyId': cid}),
        _api.get('/network/olts', query: {'companyId': cid}),
      ]);
      if (!mounted) return;
      setState(() {
        _splitters = ApiClient.listData(results[0])
            .whereType<Map<String, dynamic>>()
            .map(NetSplitter.fromJson)
            .toList();
        _olts = ApiClient.listData(results[1])
            .whereType<Map<String, dynamic>>()
            .map(NetOlt.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<NetSplitter> get _filtered => _splitters
      .where((s) => netContains(_filter, [s.name, s.location]))
      .toList();

  List<NetSplitter> get _pageRows {
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

  Future<void> _save(Map<String, dynamic> values, NetSplitter? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/network/splitters/${existing.id}?companyId=$cid',
          body: values,
        );
        if (mounted) showToast(context, 'Splitter updated successfully.');
      } else {
        await _api.post(
          '/network/splitters?companyId=$cid',
          body: {...values, 'companyId': cid},
        );
        if (mounted) showToast(context, 'Splitter added successfully.');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(NetSplitter splitter) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    await showNetworkDeleteDialog(
      context,
      itemName: splitter.name,
      onConfirm: () async {
        try {
          await _api.delete('/network/splitters/${splitter.id}?companyId=$cid');
          if (mounted) showToast(context, 'Splitter deleted successfully.');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openForm(NetSplitter? splitter) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SplitterFormDialog(splitter: splitter, olts: _olts),
    );
    if (result != null) await _save(result, splitter);
  }

  @override
  Widget build(BuildContext context) {
    final totalPorts = _splitters.fold<int>(0, (sum, s) => sum + s.totalPorts);
    final availablePorts = _splitters.fold<int>(
      0,
      (sum, s) => sum + s.availablePorts,
    );
    final usedPorts = totalPorts - availablePorts;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.call_split,
            title: 'Splitter Management',
            subtitle: 'Monitor splitter capacity and port allocation.',
            gradient: _orangeGradient,
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
                      maxColumns: 4,
                      children: [
                        NetworkStatCard(
                          icon: Icons.call_split,
                          label: 'Total Splitters',
                          value: '${_splitters.length}',
                          gradient: _orangeGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.power,
                          label: 'Total Ports',
                          value: '$totalPorts',
                          gradient: _cyanGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.cell_tower,
                          label: 'Available',
                          value: '$availablePorts',
                          gradient: _emeraldGradient,
                          valueColor: AppColors.emerald600,
                        ),
                        NetworkStatCard(
                          icon: Icons.power_off,
                          label: 'Used',
                          value: '$usedPorts',
                          gradient: _redGradient,
                          valueColor: context.dangerText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _toolbar(context),
                    const SizedBox(height: 16),
                    NetworkTable<NetSplitter>(
                      rows: _pageRows,
                      emptyIcon: Icons.call_split,
                      emptyTitle: 'No splitters found',
                      emptyHint: 'Get started by adding a new splitter.',
                      emptyTint: const Color(0xFFF59E0B),
                      mobileTrailing: (context, splitter, _) =>
                          NetworkRowActions(
                            onEdit: () => _openForm(splitter),
                            onDelete: () => _delete(splitter),
                          ),
                      columns: [
                        NetColumn(
                          label: 'ID',
                          width: 60,
                          builder: (context, splitter, index) => Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: context.mutedFg,
                            ),
                          ),
                        ),
                        NetColumn(
                          label: 'Name',
                          width: 170,
                          builder: (context, splitter, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.call_split,
                                size: 14,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  splitter.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        NetColumn(
                          label: 'Location',
                          width: 170,
                          builder: (context, splitter, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: context.mutedFg,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  splitter.location,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: context.mutedFg),
                                ),
                              ),
                            ],
                          ),
                        ),
                        NetColumn(
                          label: 'Parent OLT',
                          width: 140,
                          builder: (context, splitter, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cell_tower,
                                size: 12,
                                color: context.mutedFg,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  splitter.oltId.length > 8
                                      ? splitter.oltId.substring(0, 8)
                                      : splitter.oltId,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: context.mutedFg),
                                ),
                              ),
                            ],
                          ),
                        ),
                        NetColumn(
                          label: 'Total Ports',
                          width: 110,
                          center: true,
                          builder: (context, splitter, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.power,
                                size: 14,
                                color: context.mutedFg,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${splitter.totalPorts}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        NetColumn(
                          label: 'Available',
                          width: 100,
                          center: true,
                          builder: (context, splitter, _) => Text(
                            '${splitter.availablePorts}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald600,
                            ),
                          ),
                        ),
                        NetColumn(
                          label: 'Utilization',
                          width: 190,
                          builder: (context, splitter, _) =>
                              _Utilization(value: splitter.utilization),
                        ),
                        NetColumn(
                          label: '',
                          width: 96,
                          isActions: true,
                          builder: (context, splitter, _) => Align(
                            alignment: Alignment.centerRight,
                            child: NetworkRowActions(
                              onEdit: () => _openForm(splitter),
                              onDelete: () => _delete(splitter),
                            ),
                          ),
                        ),
                      ],
                    ),
                    NetworkPagination(
                      currentPage: _page,
                      pageSize: _pageSize,
                      totalItems: _filtered.length,
                      noun: 'splitters',
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
        hint: 'Filter by name or location...',
      ).copyWith(
        prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
      ),
    );
    final add = GradientButton(
      label: 'Add Splitter',
      icon: Icons.add_circle_outline,
      gradient: _emeraldGradient,
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

class _Utilization extends StatelessWidget {
  const _Utilization({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final color = value > 80
        ? const Color(0xFFF43F5E)
        : value > 50
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 8,
          decoration: BoxDecoration(
            color: context.subtle,
            borderRadius: BorderRadius.circular(999),
          ),
          clipBehavior: Clip.antiAlias,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (value / 100).clamp(0, 1),
            child: Container(color: color),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${value.toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 12, color: context.mutedFg),
        ),
      ],
    );
  }
}

class _SplitterFormDialog extends StatefulWidget {
  const _SplitterFormDialog({this.splitter, required this.olts});

  final NetSplitter? splitter;
  final List<NetOlt> olts;

  @override
  State<_SplitterFormDialog> createState() => _SplitterFormDialogState();
}

class _SplitterFormDialogState extends State<_SplitterFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _totalPorts;
  late final TextEditingController _availablePorts;
  late String _oltId;

  @override
  void initState() {
    super.initState();
    final splitter = widget.splitter;
    _name = TextEditingController(text: splitter?.name ?? '');
    _location = TextEditingController(text: splitter?.location ?? '');
    _totalPorts = TextEditingController(
      text: splitter == null ? '8' : '${splitter.totalPorts}',
    );
    _availablePorts = TextEditingController(
      text: splitter == null ? '8' : '${splitter.availablePorts}',
    );
    _oltId = splitter?.oltId ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _totalPorts.dispose();
    _availablePorts.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'location': _location.text.trim(),
      'oltId': _oltId,
      'totalPorts': int.tryParse(_totalPorts.text.trim()) ?? 0,
      'availablePorts': int.tryParse(_availablePorts.text.trim()) ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.splitter != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Text('${editing ? 'Edit' : 'Add'} Splitter'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NetField(
                label: 'Splitter Name',
                child: TextFormField(
                  controller: _name,
                  decoration: netInputDecoration(
                    context,
                    hint: 'e.g., DHA-P6-S1',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Splitter name is required'
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Location',
                child: TextFormField(
                  controller: _location,
                  decoration: netInputDecoration(
                    context,
                    hint: 'e.g., Street 5, DHA P6',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Location is required'
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Parent OLT',
                child: DropdownButtonFormField<String>(
                  initialValue: _oltId.isEmpty ? null : _oltId,
                  decoration: netInputDecoration(context),
                  hint: const Text('Select an OLT'),
                  items: [
                    for (final olt in widget.olts)
                      DropdownMenuItem(value: olt.id, child: Text(olt.name)),
                  ],
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'OLT ID is required' : null,
                  onChanged: (v) => setState(() => _oltId = v ?? ''),
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final total = NetField(
                    label: 'Total Ports',
                    child: TextFormField(
                      controller: _totalPorts,
                      keyboardType: TextInputType.number,
                      decoration: netInputDecoration(context),
                      validator: (v) {
                        final value = int.tryParse(v?.trim() ?? '');
                        if (value == null || value <= 0) {
                          return 'Must be positive';
                        }
                        return null;
                      },
                    ),
                  );
                  final available = NetField(
                    label: 'Available Ports',
                    child: TextFormField(
                      controller: _availablePorts,
                      keyboardType: TextInputType.number,
                      decoration: netInputDecoration(context),
                      validator: (v) {
                        final value = int.tryParse(v?.trim() ?? '');
                        if (value == null || value < 0) {
                          return 'Cannot be negative';
                        }
                        final totalValue =
                            int.tryParse(_totalPorts.text.trim()) ?? 0;
                        if (value > totalValue) {
                          return 'Exceeds total ports';
                        }
                        return null;
                      },
                    ),
                  );
                  if (constraints.maxWidth >= 420) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: total),
                        const SizedBox(width: 12),
                        Expanded(child: available),
                      ],
                    );
                  }
                  return Column(
                    children: [total, const SizedBox(height: 14), available],
                  );
                },
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
          label: 'Save Splitter',
          gradient: _emeraldGradient,
          onPressed: _submit,
        ),
      ],
    );
  }
}
