import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import 'network_common.dart';
import 'network_models.dart';

const List<Color> _cyanGradient = [Color(0xFF3B82F6), Color(0xFF0891B2)];
const List<Color> _violetGradient = [Color(0xFF8B5CF6), Color(0xFF9333EA)];
const List<Color> _orangeGradient = [Color(0xFFF59E0B), Color(0xFFEA580C)];
const List<Color> _emeraldGradient = [Color(0xFF10B981), Color(0xFF16A34A)];

final RegExp _ipv4 = RegExp(
  r'^(25[0-5]|2[0-4]\d|1?\d?\d)(\.(25[0-5]|2[0-4]\d|1?\d?\d)){3}$',
);

/// Flutter counterpart of `client/src/app/(app)/network/olt/page.tsx` —
/// manage Optical Line Terminals, their ports and parent POP.
class OltScreen extends StatefulWidget {
  const OltScreen({super.key});

  @override
  State<OltScreen> createState() => _OltScreenState();
}

class _OltScreenState extends State<OltScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<NetOlt> _olts = [];
  List<NetPop> _pops = [];
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
        _api.get('/network/olts', query: {'companyId': cid}),
        _api.get('/network/pops', query: {'companyId': cid}),
      ]);
      if (!mounted) return;
      setState(() {
        _olts = ApiClient.listData(results[0])
            .whereType<Map<String, dynamic>>()
            .map(NetOlt.fromJson)
            .toList();
        _pops = ApiClient.listData(results[1])
            .whereType<Map<String, dynamic>>()
            .map(NetPop.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<NetOlt> get _filtered => _olts
      .where((o) => netContains(_filter, [o.name, o.location, o.ipAddress]))
      .toList();

  List<NetOlt> get _pageRows {
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

  Future<void> _save(Map<String, dynamic> values, NetOlt? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/network/olts/${existing.id}?companyId=$cid',
          body: values,
        );
        if (mounted) showToast(context, 'OLT updated successfully.');
      } else {
        await _api.post(
          '/network/olts?companyId=$cid',
          body: {...values, 'companyId': cid},
        );
        if (mounted) showToast(context, 'OLT added successfully.');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(NetOlt olt) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    await showNetworkDeleteDialog(
      context,
      itemName: olt.name,
      onConfirm: () async {
        try {
          await _api.delete('/network/olts/${olt.id}?companyId=$cid');
          if (mounted) showToast(context, 'OLT deleted successfully.');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openForm(NetOlt? olt) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _OltFormDialog(olt: olt, pops: _pops),
    );
    if (result != null) await _save(result, olt);
  }

  @override
  Widget build(BuildContext context) {
    final totalPorts = _olts.fold<int>(0, (sum, o) => sum + o.ports);
    final locations = _olts.map((o) => o.location).toSet().length;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.dns_outlined,
            title: 'OLT Management',
            subtitle: 'Track Optical Line Terminals and capacity.',
            gradient: _cyanGradient,
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
                          icon: Icons.dns_outlined,
                          label: 'Total OLTs',
                          value: '${_olts.length}',
                          gradient: _cyanGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.layers_outlined,
                          label: 'Total Ports',
                          value: '$totalPorts',
                          gradient: _violetGradient,
                          valueColor: const Color(0xFF7C3AED),
                        ),
                        NetworkStatCard(
                          icon: Icons.public,
                          label: 'Locations',
                          value: '$locations',
                          gradient: _orangeGradient,
                          valueColor: const Color(0xFFD97706),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _toolbar(context),
                    const SizedBox(height: 16),
                    NetworkTable<NetOlt>(
                      rows: _pageRows,
                      emptyIcon: Icons.dns_outlined,
                      emptyTitle: 'No OLTs found',
                      emptyHint: 'Get started by adding a new OLT.',
                      emptyTint: const Color(0xFF3B82F6),
                      mobileTrailing: (context, olt, _) => NetworkRowActions(
                        onEdit: () => _openForm(olt),
                        onDelete: () => _delete(olt),
                      ),
                      columns: [
                        NetColumn(
                          label: 'ID',
                          width: 60,
                          builder: (context, olt, index) => Text(
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
                          width: 180,
                          builder: (context, olt, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.dns_outlined,
                                size: 14,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  olt.name,
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
                          width: 180,
                          builder: (context, olt, _) => Text(olt.location),
                        ),
                        NetColumn(
                          label: 'IP Address',
                          width: 170,
                          builder: (context, olt, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.public,
                                size: 12,
                                color: context.mutedFg,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  olt.ipAddress,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        NetColumn(
                          label: 'Ports',
                          width: 90,
                          center: true,
                          builder: (context, olt, _) => Text(
                            '${olt.ports}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: context.mutedFg,
                            ),
                          ),
                        ),
                        NetColumn(
                          label: '',
                          width: 96,
                          isActions: true,
                          builder: (context, olt, _) => Align(
                            alignment: Alignment.centerRight,
                            child: NetworkRowActions(
                              onEdit: () => _openForm(olt),
                              onDelete: () => _delete(olt),
                            ),
                          ),
                        ),
                      ],
                    ),
                    NetworkPagination(
                      currentPage: _page,
                      pageSize: _pageSize,
                      totalItems: _filtered.length,
                      noun: 'OLTs',
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
        hint: 'Filter by name, location, or IP...',
      ).copyWith(
        prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
      ),
    );
    final add = GradientButton(
      label: 'Add OLT',
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

class _OltFormDialog extends StatefulWidget {
  const _OltFormDialog({this.olt, required this.pops});

  final NetOlt? olt;
  final List<NetPop> pops;

  @override
  State<_OltFormDialog> createState() => _OltFormDialogState();
}

class _OltFormDialogState extends State<_OltFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _ipAddress;
  late final TextEditingController _ports;
  late String _popId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.olt?.name ?? '');
    _location = TextEditingController(text: widget.olt?.location ?? '');
    _ipAddress = TextEditingController(text: widget.olt?.ipAddress ?? '');
    _ports = TextEditingController(
      text: widget.olt == null ? '16' : '${widget.olt!.ports}',
    );
    _popId = widget.olt?.popId ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _ipAddress.dispose();
    _ports.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'location': _location.text.trim(),
      'ipAddress': _ipAddress.text.trim(),
      'ports': int.tryParse(_ports.text.trim()) ?? 0,
      'popId': _popId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.olt != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Text('${editing ? 'Edit' : 'Add'} OLT'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NetField(
                label: 'OLT Name',
                child: TextFormField(
                  controller: _name,
                  decoration: netInputDecoration(
                    context,
                    hint: 'e.g., DHA-OLT-1',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'OLT name is required'
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
                    hint: 'e.g., DHA Phase 6 PoP',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Location is required'
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'POP',
                child: DropdownButtonFormField<String>(
                  initialValue: _popId.isEmpty ? null : _popId,
                  decoration: netInputDecoration(context),
                  hint: const Text('Select POP'),
                  items: [
                    for (final pop in widget.pops)
                      DropdownMenuItem(value: pop.id, child: Text(pop.name)),
                  ],
                  onChanged: (v) => setState(() => _popId = v ?? ''),
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final ip = NetField(
                    label: 'IP Address',
                    child: TextFormField(
                      controller: _ipAddress,
                      decoration: netInputDecoration(
                        context,
                        hint: 'e.g., 10.10.1.1',
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'IP address is required';
                        if (!_ipv4.hasMatch(value)) return 'Invalid IP address';
                        return null;
                      },
                    ),
                  );
                  final ports = NetField(
                    label: 'Total Ports',
                    child: TextFormField(
                      controller: _ports,
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
                  if (constraints.maxWidth >= 420) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: ip),
                        const SizedBox(width: 12),
                        Expanded(child: ports),
                      ],
                    );
                  }
                  return Column(
                    children: [ip, const SizedBox(height: 14), ports],
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
          label: 'Save OLT',
          gradient: _emeraldGradient,
          onPressed: _submit,
        ),
      ],
    );
  }
}
