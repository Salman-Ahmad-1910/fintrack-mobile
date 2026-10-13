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

/// Flutter counterpart of `client/src/app/(app)/network/boxes/page.tsx` —
/// maintain the Box / Media numbers used on connections.
class BoxesScreen extends StatefulWidget {
  const BoxesScreen({super.key});

  @override
  State<BoxesScreen> createState() => _BoxesScreenState();
}

class _BoxesScreenState extends State<BoxesScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<NetBox> _boxes = [];
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
      final json = await _api.get('/network/boxes', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _boxes = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(NetBox.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<NetBox> get _filtered =>
      _boxes.where((b) => netPrefix(_filter, b.name)).toList();

  List<NetBox> get _pageRows {
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

  Future<void> _save(Map<String, dynamic> values, NetBox? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/network/boxes/${existing.id}?companyId=$cid',
          body: values,
        );
        if (mounted) showToast(context, 'Box/Media updated successfully.');
      } else {
        await _api.post(
          '/network/boxes?companyId=$cid',
          body: {...values, 'companyId': cid},
        );
        if (mounted) showToast(context, 'Box/Media added successfully.');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(NetBox box) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    await showNetworkDeleteDialog(
      context,
      itemName: box.name,
      onConfirm: () async {
        try {
          await _api.delete('/network/boxes/${box.id}?companyId=$cid');
          if (mounted) showToast(context, 'Box/Media deleted successfully.');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openForm(NetBox? box) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _BoxFormDialog(box: box),
    );
    if (result != null) await _save(result, box);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.inventory_2_outlined,
            title: 'Box / Media Management',
            subtitle: 'Maintain the box and media numbers for connections.',
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
                    SizedBox(
                      width: 320,
                      child: NetworkStatCard(
                        icon: Icons.inventory_2_outlined,
                        label: 'Total Boxes / Media',
                        value: '${_boxes.length}',
                        gradient: _greenGradient,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _toolbar(context),
                    const SizedBox(height: 16),
                    NetworkTable<NetBox>(
                      rows: _pageRows,
                      emptyIcon: Icons.inventory_2_outlined,
                      emptyTitle: 'No boxes found',
                      emptyHint:
                          'Get started by adding a new box / media number.',
                      emptyTint: const Color(0xFF14B8A6),
                      mobileTrailing: (context, box, _) => NetworkRowActions(
                        onEdit: () => _openForm(box),
                        onDelete: () => _delete(box),
                      ),
                      columns: [
                        NetColumn(
                          label: 'ID',
                          width: 60,
                          builder: (context, box, index) => Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: context.mutedFg,
                            ),
                          ),
                        ),
                        NetColumn(
                          label: 'Box / Media Number',
                          width: 260,
                          builder: (context, box, _) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 14,
                                color: Color(0xFF14B8A6),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  box.name,
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
                          label: '',
                          width: 96,
                          isActions: true,
                          builder: (context, box, _) => Align(
                            alignment: Alignment.centerRight,
                            child: NetworkRowActions(
                              onEdit: () => _openForm(box),
                              onDelete: () => _delete(box),
                            ),
                          ),
                        ),
                      ],
                    ),
                    NetworkPagination(
                      currentPage: _page,
                      pageSize: _pageSize,
                      totalItems: _filtered.length,
                      noun: 'boxes',
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
        hint: 'Filter by box number...',
      ).copyWith(
        prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
      ),
    );
    final add = GradientButton(
      label: 'Add Box Number',
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

class _BoxFormDialog extends StatefulWidget {
  const _BoxFormDialog({this.box});

  final NetBox? box;

  @override
  State<_BoxFormDialog> createState() => _BoxFormDialogState();
}

class _BoxFormDialogState extends State<_BoxFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.box?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({'name': _name.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.box != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Text('${editing ? 'Edit' : 'Add'} Box / Media Number'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: NetField(
            label: 'Box / Media Number',
            child: TextFormField(
              controller: _name,
              decoration: netInputDecoration(context, hint: 'e.g., BX-001'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Box/Media number is required'
                  : null,
            ),
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
          label: editing ? 'Save' : 'Add',
          gradient: _greenGradient,
          onPressed: _submit,
        ),
      ],
    );
  }
}
