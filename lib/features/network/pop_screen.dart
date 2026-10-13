import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import 'network_common.dart';
import 'network_models.dart';

const List<Color> _pinkGradient = [Color(0xFFF43F5E), Color(0xFFDB2777)];
const List<Color> _emeraldGradient = [Color(0xFF10B981), Color(0xFF16A34A)];
const List<Color> _redGradient = [Color(0xFFF43F5E), Color(0xFFDC2626)];

/// Flutter counterpart of `client/src/app/(app)/network/pop/page.tsx` —
/// manage Points of Presence and their online status.
class PopScreen extends StatefulWidget {
  const PopScreen({super.key});

  @override
  State<PopScreen> createState() => _PopScreenState();
}

class _PopScreenState extends State<PopScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

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
      final json = await _api.get('/network/pops', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _pops = ApiClient.listData(json)
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

  List<NetPop> get _filtered =>
      _pops.where((p) => netContains(_filter, [p.name, p.location])).toList();

  List<NetPop> get _pageRows {
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

  Future<void> _save(Map<String, dynamic> values, NetPop? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/network/pops/${existing.id}?companyId=$cid',
          body: values,
        );
        if (mounted) showToast(context, 'POP updated successfully.');
      } else {
        await _api.post(
          '/network/pops?companyId=$cid',
          body: {...values, 'companyId': cid},
        );
        if (mounted) showToast(context, 'POP added successfully.');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(NetPop pop) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    await showNetworkDeleteDialog(
      context,
      itemName: pop.name,
      onConfirm: () async {
        try {
          await _api.delete('/network/pops/${pop.id}?companyId=$cid');
          if (mounted) showToast(context, 'POP deleted successfully.');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openForm(NetPop? pop) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PopFormDialog(pop: pop),
    );
    if (result != null) await _save(result, pop);
  }

  @override
  Widget build(BuildContext context) {
    final online = _pops.where((p) => p.isOnline).length;
    final offline = _pops.length - online;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.cell_tower,
            title: 'POP Management',
            subtitle: 'Manage Points of Presence across your network.',
            gradient: _pinkGradient,
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
                          icon: Icons.cell_tower,
                          label: 'Total POPs',
                          value: '${_pops.length}',
                          gradient: _pinkGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.wifi,
                          label: 'Online',
                          value: '$online',
                          gradient: _emeraldGradient,
                          valueColor: AppColors.emerald600,
                        ),
                        NetworkStatCard(
                          icon: Icons.wifi_off,
                          label: 'Offline',
                          value: '$offline',
                          gradient: _redGradient,
                          valueColor: context.dangerText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _toolbar(context),
                    const SizedBox(height: 16),
                    NetworkTable<NetPop>(
                      rows: _pageRows,
                      emptyIcon: Icons.cell_tower,
                      emptyTitle: 'No POPs found',
                      emptyHint: 'Get started by adding a new POP location.',
                      emptyTint: const Color(0xFFF43F5E),
                      mobileTrailing: (context, pop, _) => NetworkRowActions(
                        onEdit: () => _openForm(pop),
                        onDelete: () => _delete(pop),
                      ),
                      columns: [
                        NetColumn(
                          label: 'ID',
                          width: 60,
                          builder: (context, pop, index) => Text(
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
                          width: 190,
                          builder: (context, pop, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cell_tower,
                                size: 14,
                                color: Color(0xFFF43F5E),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  pop.name,
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
                          width: 200,
                          builder: (context, pop, _) => Row(
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
                                  pop.location,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: context.mutedFg),
                                ),
                              ),
                            ],
                          ),
                        ),
                        NetColumn(
                          label: 'Status',
                          width: 130,
                          builder: (context, pop, _) =>
                              _StatusBadge(online: pop.isOnline),
                        ),
                        NetColumn(
                          label: 'Last Outage',
                          width: 190,
                          builder: (context, pop, _) =>
                              Text(_formatOutage(pop.lastOutage)),
                        ),
                        NetColumn(
                          label: '',
                          width: 96,
                          isActions: true,
                          builder: (context, pop, _) => Align(
                            alignment: Alignment.centerRight,
                            child: NetworkRowActions(
                              onEdit: () => _openForm(pop),
                              onDelete: () => _delete(pop),
                            ),
                          ),
                        ),
                      ],
                    ),
                    NetworkPagination(
                      currentPage: _page,
                      pageSize: _pageSize,
                      totalItems: _filtered.length,
                      noun: 'POPs',
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
      label: 'Add POP',
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

String _formatOutage(String value) {
  if (value.isEmpty) return 'N/A';
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return DateFormat('M/d/y, h:mm a').format(date.toLocal());
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final gradient = online ? _emeraldGradient : _redGradient;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            online ? Icons.wifi : Icons.wifi_off,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            online ? 'online' : 'offline',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PopFormDialog extends StatefulWidget {
  const _PopFormDialog({this.pop});

  final NetPop? pop;

  @override
  State<_PopFormDialog> createState() => _PopFormDialogState();
}

class _PopFormDialogState extends State<_PopFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late String _status;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.pop?.name ?? '');
    _location = TextEditingController(text: widget.pop?.location ?? '');
    _status = (widget.pop?.status.isEmpty ?? true)
        ? 'online'
        : widget.pop!.status;
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'location': _location.text.trim(),
      'status': _status,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.pop != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Text('${editing ? 'Edit' : 'Add'} POP'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NetField(
                label: 'POP Name',
                child: TextFormField(
                  controller: _name,
                  decoration: netInputDecoration(
                    context,
                    hint: 'e.g., DHA Phase 6 POP',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'POP name is required'
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
                    hint: 'e.g., Office 1, Comm. Street 10',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Location is required'
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Status',
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: netInputDecoration(context),
                  items: const [
                    DropdownMenuItem(value: 'online', child: Text('Online')),
                    DropdownMenuItem(value: 'offline', child: Text('Offline')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'online'),
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
          label: 'Save POP',
          gradient: _emeraldGradient,
          onPressed: _submit,
        ),
      ],
    );
  }
}
