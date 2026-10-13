import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'messages_common.dart';
import 'messages_models.dart';

/// Flutter counterpart of `client/src/app/(app)/messages/new/page.tsx` —
/// create and manage message templates and queue messages into the Draft /
/// WhatsApp draft lists.
class NewMessagesScreen extends StatefulWidget {
  const NewMessagesScreen({super.key});

  @override
  State<NewMessagesScreen> createState() => _NewMessagesScreenState();
}

class _NewMessagesScreenState extends State<NewMessagesScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<MsgTemplate> _templates = [];
  List<Map<String, dynamic>> _connections = [];
  List<Map<String, dynamic>> _dealers = [];
  List<Map<String, dynamic>> _recovery = [];
  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;

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

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        _api.get('/messages/templates', query: {'companyId': cid}),
        _api.get('/admin/connections', query: {'companyId': cid}),
        _api.get('/dealers', query: {'companyId': cid}),
        _api.get('/admin/recovery-officers', query: {'companyId': cid}),
        _api.get('/hr/staff', query: {'companyId': cid}),
      ]);
      if (!mounted) return;
      setState(() {
        _templates = _mapList(results[0], MsgTemplate.fromJson);
        _connections = _rawList(results[1]);
        _dealers = _rawList(results[2]);
        _recovery = _rawList(results[3]);
        _staff = _rawList(results[4]);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  static List<Map<String, dynamic>> _rawList(dynamic json) =>
      ApiClient.listData(json).whereType<Map<String, dynamic>>().toList();

  static List<T> _mapList<T>(
    dynamic json,
    T Function(Map<String, dynamic>) f,
  ) =>
      ApiClient.listData(json)
          .whereType<Map<String, dynamic>>()
          .map(f)
          .toList();

  Map<String, List<Map<String, dynamic>>> get _entityLists => {
    'subscribers': _connections,
    'dealers': _dealers,
    'recovery': _recovery,
    'staff': _staff,
  };

  Future<void> _saveTemplate(
    MsgTemplate? editing,
    Map<String, dynamic> values,
  ) async {
    try {
      if (editing != null) {
        await _api.put(
          '/messages/templates/${editing.id}',
          body: {...editing.toJson(), ...values},
        );
        if (mounted) showToast(context, 'Message template updated.');
      } else {
        await _api.post('/messages/templates', body: values);
        if (mounted) showToast(context, 'Message template added.');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _deleteTemplate(MsgTemplate template) async {
    final ok = await showMessageConfirmDialog(
      context,
      message: 'Delete template "${template.title}"?',
      confirmLabel: 'Delete',
      confirmColor: context.dangerText,
    );
    if (!ok) return;
    try {
      await _api.delete('/messages/templates/${template.id}');
      if (mounted) showToast(context, 'Message template deleted.');
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _sendTemplate(
    MsgTemplate template,
    SendCategory cat,
    List<Map<String, dynamic>> targets,
    bool viaWhatsApp,
  ) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    for (final ent in targets) {
      final filled = fillMessageTemplate(template.message, ent, cat.value);
      await _api.post(
        '/messages?companyId=$cid',
        body: {
          'entityId': ent['id']?.toString() ?? '',
          'name': ent['name']?.toString() ?? '',
          'mobileNo': getEntityPhone(ent),
          'messageType': template.title,
          'messageText': filled,
          'sendTo': cat.sendTo,
          'status': viaWhatsApp ? 'whatsapp_draft' : 'draft',
          'companyId': cid,
        },
      );
    }
  }

  Future<void> _openTemplateDialog(MsgTemplate? editing) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TemplateDialog(template: editing),
    );
    if (result != null) await _saveTemplate(editing, result);
  }

  Future<void> _openSendDialog(MsgTemplate template) async {
    final count = await showDialog<int>(
      context: context,
      builder: (_) => _SendDialog(
        template: template,
        entityLists: _entityLists,
        onSend: (cat, targets, via) =>
            _sendTemplate(template, cat, targets, via),
      ),
    );
    if (count != null && mounted) {
      showToast(context, '$count message(s) added.');
      await _load();
    }
  }

  void _previewTemplate(MsgTemplate template) {
    final params = template.paramList;
    showMessagePreviewDialog(
      context,
      title: 'Template Preview',
      fields: [
        MapEntry('Title', template.title),
        if (params.isNotEmpty)
          MapEntry('Parameters', params.map((p) => '{$p}').join('  ')),
      ],
      bodyLabel: 'Message',
      body: template.message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.inbox_outlined,
            title: 'New Messages',
            subtitle: 'Create and manage message templates',
            gradient: newMsgGradient,
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
                    _templatesHeader(context),
                    const SizedBox(height: 16),
                    NetworkTable<MsgTemplate>(
                      rows: _templates,
                      emptyIcon: Icons.description_outlined,
                      emptyTitle: 'No message templates found',
                      emptyHint: 'Click Add Template to create one.',
                      emptyTint: const Color(0xFF3B82F6),
                      mobileTrailing: (context, t, _) =>
                          _templateMenu(context, t),
                      columns: [
                        NetColumn(
                          label: 'ID',
                          width: 70,
                          builder: (context, t, _) => Text(
                            t.id.length >= 6
                                ? t.id.substring(0, 6).toUpperCase()
                                : t.id.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: context.mutedFg,
                            ),
                          ),
                        ),
                        NetColumn(
                          label: 'Title',
                          width: 180,
                          builder: (context, t, _) => Text(
                            t.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        NetColumn(
                          label: 'Message',
                          width: 320,
                          builder: (context, t, _) => Text(
                            t.message,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.mutedFg,
                            ),
                          ),
                        ),
                        NetColumn(
                          label: 'Parameters',
                          width: 220,
                          builder: (context, t, _) {
                            final params = t.paramList;
                            if (params.isEmpty) {
                              return Text(
                                '-',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.mutedFg,
                                ),
                              );
                            }
                            return Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                for (final p in params) ParamChip(param: p),
                              ],
                            );
                          },
                        ),
                        NetColumn(
                          label: 'Action',
                          width: 64,
                          isActions: true,
                          center: true,
                          builder: (context, t, _) =>
                              Center(child: _templateMenu(context, t)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _templatesHeader(BuildContext context) {
    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: blueCyanGradient),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.description_outlined,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Message Templates',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Text(
                'Dynamic parameters inside curly braces e.g. {name}, {balance} '
                'are filled when sending',
                style: TextStyle(fontSize: 12, color: context.mutedFg),
              ),
            ],
          ),
        ),
      ],
    );
    final add = GradientButton(
      label: 'Add Template',
      icon: Icons.add,
      gradient: blueCyanGradient,
      onPressed: () => _openTemplateDialog(null),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 640) {
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              add,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            info,
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: add),
          ],
        );
      },
    );
  }

  Widget _templateMenu(BuildContext context, MsgTemplate t) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz, size: 18, color: context.mutedFg),
      tooltip: 'Actions',
      onSelected: (value) {
        switch (value) {
          case 'send':
            _openSendDialog(t);
          case 'preview':
            _previewTemplate(t);
          case 'edit':
            _openTemplateDialog(t);
          case 'delete':
            _deleteTemplate(t);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'send',
          child: _MenuRow(
            icon: Icons.send,
            color: AppColors.emerald600,
            label: 'Send',
          ),
        ),
        const PopupMenuItem(
          value: 'preview',
          child: _MenuRow(
            icon: Icons.visibility_outlined,
            color: Color(0xFF2563EB),
            label: 'Preview',
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: _MenuRow(
            icon: Icons.edit_outlined,
            color: Color(0xFFD97706),
            label: 'Edit',
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: _MenuRow(
            icon: Icons.delete_outline,
            color: context.dangerText,
            label: 'Delete',
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

/// Add / edit template dialog with parameter chip management.
class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({this.template});

  final MsgTemplate? template;

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _message;
  late List<String> _available;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.template?.title ?? '');
    _message = TextEditingController(text: widget.template?.message ?? '');
    final existing = widget.template?.paramList ?? const <String>[];
    _available = {...newMessageDefaultParams, ...existing}.toList();
    _selected = {...existing};
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'title': _title.text.trim(),
      'message': _message.text.trim(),
      'parameters': _selected.join(', '),
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.template != null;
    final unselected = _available.where((p) => !_selected.contains(p)).toList();
    return AlertDialog(
      backgroundColor: context.surface,
      title: Text(editing ? 'Edit Message Template' : 'Add Message Template'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NetField(
                  label: 'Title',
                  child: TextFormField(
                    controller: _title,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g. COLLECTION, UsersCredentail',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Message',
                  child: TextFormField(
                    controller: _message,
                    maxLines: 6,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g. Dear {name}, Thanks for payment, Cable:{cableAmount}...',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Message is required'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Parameters',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: context.line),
                                borderRadius: BorderRadius.circular(8),
                                color: context.inputFill,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: null,
                                  isExpanded: true,
                                  isDense: true,
                                  hint: Text(
                                    unselected.isEmpty
                                        ? 'No parameters available'
                                        : 'Select parameters...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.mutedFg,
                                    ),
                                  ),
                                  items: [
                                    for (final p in unselected)
                                      DropdownMenuItem(
                                        value: p,
                                        child: Text('{$p}'),
                                      ),
                                  ],
                                  onChanged: unselected.isEmpty
                                      ? null
                                      : (v) {
                                          if (v != null) {
                                            setState(() => _selected.add(v));
                                          }
                                        },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              foregroundColor: context.fg,
                            ),
                            onPressed: () => _manageParams(context),
                            child: const Text('Add Parameters'),
                          ),
                        ],
                      ),
                      if (_selected.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final p in _selected)
                                ParamChip(
                                  param: p,
                                  onRemove: () =>
                                      setState(() => _selected.remove(p)),
                                ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Select parameters from the dropdown or manage the '
                          'list via Add Parameters.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            foregroundColor: context.dangerText,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: editing ? 'Save Changes' : 'Add',
          gradient: blueCyanGradient,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _manageParams(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ParamsDialog(
        initial: _available,
        onChanged: (list) => setState(() {
          _available = list;
          _selected = _selected.where(list.contains).toSet();
        }),
      ),
    );
  }
}

/// Manage (add / remove) the available parameter list.
class _ParamsDialog extends StatefulWidget {
  const _ParamsDialog({required this.initial, required this.onChanged});

  final List<String> initial;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_ParamsDialog> createState() => _ParamsDialogState();
}

class _ParamsDialogState extends State<_ParamsDialog> {
  late List<String> _params;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _params = [...widget.initial];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final p = _controller.text.trim();
    if (p.isEmpty) return;
    if (_params.contains(p)) {
      showToast(context, 'Parameter "$p" already exists.', error: true);
      return;
    }
    setState(() {
      _params.add(p);
      _controller.clear();
    });
    widget.onChanged(_params);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('Manage Parameters'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g. name, balance, bill',
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    foregroundColor: context.fg,
                  ),
                  onPressed: _add,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Parameters shown in the dropdown',
              style: TextStyle(fontSize: 12, color: context.mutedFg),
            ),
            const SizedBox(height: 8),
            if (_params.isEmpty)
              Text(
                'No parameters yet. Add one above.',
                style: TextStyle(color: context.mutedFg),
              )
            else
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final p in _params)
                    ParamChip(
                      param: p,
                      onRemove: () {
                        setState(() => _params.remove(p));
                        widget.onChanged(_params);
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Send dialog: choose a recipient category, select recipients, optionally
/// route to the WhatsApp draft list.
class _SendDialog extends StatefulWidget {
  const _SendDialog({
    required this.template,
    required this.entityLists,
    required this.onSend,
  });

  final MsgTemplate template;
  final Map<String, List<Map<String, dynamic>>> entityLists;
  final Future<void> Function(
    SendCategory category,
    List<Map<String, dynamic>> targets,
    bool viaWhatsApp,
  )
  onSend;

  @override
  State<_SendDialog> createState() => _SendDialogState();
}

class _SendDialogState extends State<_SendDialog> {
  String _category = '';
  String _search = '';
  final Set<String> _selectedIds = {};
  bool _viaWhatsApp = false;
  bool _sending = false;

  List<Map<String, dynamic>> get _entities =>
      widget.entityLists[_category] ?? const [];

  List<Map<String, dynamic>> get _visible {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _entities;
    return _entities.where((e) {
      if (RegExp(r'^[0-9]').hasMatch(q)) {
        return (e['id']?.toString().toLowerCase().startsWith(q) ?? false) ||
            (e['internetId']?.toString().toLowerCase().startsWith(q) ?? false);
      }
      return e['name']?.toString().toLowerCase().startsWith(q) ?? false;
    }).toList();
  }

  bool get _allVisibleSelected =>
      _visible.isNotEmpty &&
      _visible.every((e) => _selectedIds.contains(e['id']));

  Future<void> _send() async {
    final cat = sendCategories.firstWhere((c) => c.value == _category);
    final targets = _entities
        .where((e) => _selectedIds.contains(e['id']))
        .toList();
    if (targets.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(cat, targets, _viaWhatsApp);
      if (mounted) Navigator.of(context).pop(targets.length);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        showToast(context, 'Failed to send messages.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = _category.isEmpty
        ? null
        : sendCategories.firstWhere((c) => c.value == _category);
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('Send Message'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 14, color: context.fg),
                  children: [
                    TextSpan(
                      text: 'Template: ',
                      style: TextStyle(color: context.mutedFg),
                    ),
                    TextSpan(
                      text: widget.template.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.subtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.template.message,
                  style: TextStyle(fontSize: 12, color: context.mutedFg),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.subtle,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.line),
                ),
                child: Row(
                  children: [
                    Icon(
                      _viaWhatsApp
                          ? Icons.chat_bubble_outline
                          : Icons.notifications_none,
                      color: _viaWhatsApp
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _viaWhatsApp
                                ? 'Send via WhatsApp'
                                : 'Send as Notification (SMS)',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _viaWhatsApp
                                ? 'Messages will be added to WhatsApp Draft Messages'
                                : 'Messages will be added to Draft Messages',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.mutedFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _viaWhatsApp,
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0xFF16A34A),
                      onChanged: (v) => setState(() => _viaWhatsApp = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              NetField(
                label: 'Send To',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
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
                        value: _category.isEmpty ? null : _category,
                        isExpanded: true,
                        isDense: true,
                        hint: Text(
                          'Select recipients',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.mutedFg,
                          ),
                        ),
                        items: [
                          for (final c in sendCategories)
                            DropdownMenuItem(
                              value: c.value,
                              child: Text(c.label),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          _category = v ?? '';
                          _search = '';
                          _selectedIds.clear();
                        }),
                      ),
                    ),
                  ),
                ),
              ),
              if (cat != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    MsgCheckbox(
                      value: _allVisibleSelected,
                      onChanged: (checked) => setState(() {
                        for (final e in _visible) {
                          if (checked) {
                            _selectedIds.add(e['id']);
                          } else {
                            _selectedIds.remove(e['id']);
                          }
                        }
                      }),
                    ),
                    const SizedBox(width: 8),
                    Text('Select All (${_visible.length})'),
                    const Spacer(),
                    Text(
                      '${_selectedIds.length} selected',
                      style: TextStyle(color: context.mutedFg),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration:
                      netInputDecoration(
                        context,
                        hint: 'Search ${cat.label.toLowerCase()}...',
                      ).copyWith(
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: context.mutedFg,
                        ),
                      ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(color: context.line),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _visible.isEmpty
                      ? Center(
                          child: Text(
                            'No ${cat.label.toLowerCase()} found.',
                            style: TextStyle(color: context.mutedFg),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _visible.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, color: context.line),
                          itemBuilder: (context, i) {
                            final e = _visible[i];
                            final id = e['id']?.toString() ?? '';
                            return InkWell(
                              onTap: () => setState(() {
                                if (_selectedIds.contains(id)) {
                                  _selectedIds.remove(id);
                                } else {
                                  _selectedIds.add(id);
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    MsgCheckbox(
                                      value: _selectedIds.contains(id),
                                      onChanged: (_) => setState(() {
                                        if (_selectedIds.contains(id)) {
                                          _selectedIds.remove(id);
                                        } else {
                                          _selectedIds.add(id);
                                        }
                                      }),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            e['name']?.toString() ?? '',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            getEntityPhone(e).isEmpty
                                                ? '-'
                                                : getEntityPhone(e),
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.mutedFg,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            foregroundColor: context.mutedFg,
          ),
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Send (${_selectedIds.length})',
          icon: Icons.send,
          gradient: newMsgGradient,
          loading: _sending,
          onPressed: _selectedIds.isEmpty ? null : _send,
        ),
      ],
    );
  }
}
