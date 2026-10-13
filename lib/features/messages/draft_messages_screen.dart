import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../network/network_common.dart';
import 'messages_common.dart';
import 'messages_models.dart';

/// Flutter counterpart of `client/src/app/(app)/messages/draft/page.tsx`.
class DraftMessagesScreen extends StatefulWidget {
  const DraftMessagesScreen({super.key});

  @override
  State<DraftMessagesScreen> createState() => _DraftMessagesScreenState();
}

class _DraftMessagesScreenState extends State<DraftMessagesScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: messageUnauthorizedHandler);

  MsgData _data = const MsgData(messages: [], connections: [], areas: []);
  bool _loading = true;
  bool _sending = false;

  String _title = 'All';
  String _sublocality = 'all';
  String _sendTo = 'All';
  String _dateFilter = 'all';
  int _pageSize = 10;
  int _page = 1;
  final TextEditingController _search = TextEditingController();
  String _searchText = '';
  final Set<String> _selected = {};

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
    final cid = Session.companyId;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await fetchMsgData(_api, cid);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<MsgMessage> get _drafts =>
      _data.messages.where((m) => m.status == 'draft').toList();

  List<String> get _dateOptions {
    final set = <String>{};
    for (final m in _drafts) {
      final k = toDateKey(m.createdAt);
      if (k.isNotEmpty) set.add(k);
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  List<MsgMessage> get _filtered => _drafts.where((m) {
    if (_title != 'All' && m.messageType != _title) return false;
    if (_sendTo != 'All' && m.sendTo != _sendTo) return false;
    if (_dateFilter != 'all' && toDateKey(m.createdAt) != _dateFilter) {
      return false;
    }
    if (_sublocality != 'all' && _data.areaName(m.entityId) != _sublocality) {
      return false;
    }
    return msgMatchesSearch(
      _searchText,
      entityId: m.entityId,
      internetId: m.internetId,
      mobileNo: m.mobileNo,
      name: m.name,
    );
  }).toList();

  List<MsgMessage> get _pageRows {
    final start = (_page - 1) * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  bool get _allPageSelected =>
      _pageRows.isNotEmpty && _pageRows.every((m) => _selected.contains(m.id));

  void _toggleAll(bool checked) {
    setState(() {
      for (final m in _pageRows) {
        if (checked) {
          _selected.add(m.id);
        } else {
          _selected.remove(m.id);
        }
      }
    });
  }

  Future<void> _sendSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final ok = await showMessageConfirmDialog(
      context,
      message:
          'Send ${ids.length} message(s)? Sent expiry reminders go to Expiry '
          'Messages, others to Other Messages.',
      confirmLabel: 'Send',
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    final cid = Session.companyId;
    try {
      for (final id in ids) {
        final msg = _data.messages.firstWhere(
          (m) => m.id == id,
          orElse: () => const MsgMessage(id: '', status: '', name: ''),
        );
        if (msg.id.isEmpty) continue;
        await _api.put(
          '/messages/$id?companyId=$cid',
          body: {
            ...msg.toJson(),
            'status': 'sent',
            'sentBy': Session.userName ?? 'Admin',
            'sendedAt': DateTime.now().toUtc().toIso8601String(),
          },
        );
      }
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _sending = false;
      });
      showToast(context, '${ids.length} message(s) sent.');
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _sending = false);
      showToast(context, e.message, error: true);
    }
  }

  Future<void> _createDraft() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _NewDraftDialog(),
    );
    if (result == null) return;
    final cid = Session.companyId;
    try {
      await _api.post(
        '/messages?companyId=$cid',
        body: {
          'name': result['name'],
          'mobileNo': result['mobileNo'],
          if ((result['messageType'] as String).isNotEmpty)
            'messageType': result['messageType'],
          'messageText': result['messageText'],
          'sendTo': result['sendTo'],
          'status': 'draft',
          'companyId': cid,
        },
      );
      if (mounted) showToast(context, 'Draft created successfully.');
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _deleteDraft(MsgMessage m) async {
    final ok = await showMessageConfirmDialog(
      context,
      message: 'Delete this draft message?',
      confirmLabel: 'Delete',
      confirmColor: context.dangerText,
    );
    if (!ok) return;
    try {
      await _api.delete('/messages/${m.id}?companyId=${Session.companyId}');
      if (!mounted) return;
      setState(() => _selected.remove(m.id));
      showToast(context, 'Draft deleted.');
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _clearDrafts() async {
    if (_drafts.isEmpty) return;
    final ok = await showMessageConfirmDialog(
      context,
      message: 'Are you sure you want to clear all draft messages?',
      confirmLabel: 'Clear',
      confirmColor: context.dangerText,
    );
    if (!ok) return;
    try {
      for (final d in _drafts) {
        await _api.delete('/messages/${d.id}?companyId=${Session.companyId}');
      }
      if (!mounted) return;
      setState(() => _selected.clear());
      showToast(context, 'All draft messages cleared.');
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  void _preview(MsgMessage m) {
    showMessagePreviewDialog(
      context,
      title: 'Draft Message Preview',
      fields: [
        MapEntry('Name', m.name),
        MapEntry('Phone', m.preferPhone.isEmpty ? '-' : m.preferPhone),
        MapEntry('Message Type', m.messageType.isEmpty ? '-' : m.messageType),
        MapEntry('Send To', m.sendTo.isEmpty ? '-' : m.sendTo),
        MapEntry('Send By', m.sentBy.isEmpty ? '-' : m.sentBy),
        MapEntry('Created', formatDateTime(m.createdAt)),
      ],
      bodyLabel: 'Message',
      body: m.messageText.isEmpty ? 'No message content' : m.messageText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sublocalities = sublocalitiesFrom(_data.areas);
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.edit_document,
            title: 'Draft Messages',
            subtitle: 'Review and send the messages written in New Messages',
            gradient: draftMsgGradient,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MsgFilterGrid(
                    children: [
                      MsgSelect(
                        label: 'Message Title',
                        value: _title,
                        items: allMessageTitles,
                        onChanged: (v) => setState(() {
                          _title = v;
                          _page = 1;
                        }),
                      ),
                      MsgSelect(
                        label: 'Sublocality',
                        value: _sublocality,
                        items: ['all', ...sublocalities],
                        onChanged: (v) => setState(() {
                          _sublocality = v;
                          _page = 1;
                        }),
                      ),
                      MsgSelect(
                        label: 'Send To',
                        value: _sendTo,
                        items: ['All', ...draftSendToOptions],
                        onChanged: (v) => setState(() {
                          _sendTo = v;
                          _page = 1;
                        }),
                      ),
                      MsgSelect(
                        label: 'Date',
                        value: _dateFilter,
                        items: ['all', ..._dateOptions],
                        displayLabel: (v) =>
                            v == 'all' ? 'All dates' : displayDateKey(v),
                        onChanged: (v) => setState(() {
                          _dateFilter = v;
                          _page = 1;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _actionsRow(context),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _tableHeader(context),
                  const SizedBox(height: 16),
                  NetworkTable<MsgMessage>(
                    rows: _pageRows,
                    emptyIcon: Icons.edit_document,
                    emptyTitle: 'No draft messages found',
                    emptyHint: 'Write a message in New Messages or adjust the filters.',
                    emptyTint: const Color(0xFFF59E0B),
                    mobileTrailing: (context, m, _) => _rowActions(context, m),
                    columns: [
                      NetColumn(
                        label: 'Select',
                        width: 44,
                        center: true,
                        headerBuilder: (context) => MsgCheckbox(
                          value: _allPageSelected,
                          onChanged: _toggleAll,
                        ),
                        builder: (context, m, _) => MsgCheckbox(
                          value: _selected.contains(m.id),
                          onChanged: (_) => setState(() {
                            if (_selected.contains(m.id)) {
                              _selected.remove(m.id);
                            } else {
                              _selected.add(m.id);
                            }
                          }),
                        ),
                      ),
                      NetColumn(
                        label: 'ID',
                        width: 60,
                        builder: (context, m, i) => Text(
                          '${(_page - 1) * _pageSize + i + 1}',
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
                        builder: (context, m, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (m.messageType.isNotEmpty)
                              Text(
                                m.messageType,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.mutedFg,
                                ),
                              ),
                          ],
                        ),
                      ),
                      NetColumn(
                        label: 'Message',
                        width: 240,
                        builder: (context, m, _) => Text(
                          m.messageText.isEmpty ? '-' : m.messageText,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Phone',
                        width: 140,
                        builder: (context, m, _) => Text(
                          m.preferPhone.isEmpty ? '-' : m.preferPhone,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      NetColumn(
                        label: 'Send By',
                        width: 110,
                        builder: (context, m, _) => Text(
                          m.sentBy.isEmpty ? '-' : m.sentBy,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Date & Time',
                        width: 170,
                        builder: (context, m, _) => Text(
                          formatDateTime(m.createdAt),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Action',
                        width: 92,
                        isActions: true,
                        builder: (context, m, _) => Align(
                          alignment: Alignment.centerLeft,
                          child: _rowActions(context, m),
                        ),
                      ),
                    ],
                  ),
                  NetworkPagination(
                    currentPage: _page,
                    pageSize: _pageSize,
                    totalItems: _filtered.length,
                    noun: 'messages',
                    pageSizes: const [5, 10, 25, 50, 100],
                    onPageChanged: (p) => setState(() => _page = p),
                    onPageSizeChanged: (s) => setState(() {
                      _pageSize = s;
                      _page = 1;
                    }),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rowActions(BuildContext context, MsgMessage m) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MessageActionIcon(
          icon: Icons.visibility_outlined,
          color: const Color(0xFF2563EB),
          tooltip: 'Preview',
          onTap: () => _preview(m),
        ),
        MessageActionIcon(
          icon: Icons.delete_outline,
          color: const Color(0xFFE11D48),
          tooltip: 'Delete',
          onTap: () => _deleteDraft(m),
        ),
      ],
    );
  }

  Widget _actionsRow(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 10,
      children: [
        GradientButton(
          label: 'Send Selected (${_selected.length})',
          icon: Icons.send,
          gradient: emeraldGreenGradient,
          loading: _sending,
          onPressed: _selected.isEmpty ? null : _sendSelected,
        ),
        GradientButton(
          label: 'New Draft',
          icon: Icons.add_circle_outline,
          gradient: blueCyanGradient,
          onPressed: _createDraft,
        ),
        GradientButton(
          label: 'Clear Draft Messages',
          icon: Icons.warning_amber_rounded,
          gradient: roseRedGradient,
          onPressed: _clearDrafts,
        ),
      ],
    );
  }

  Widget _tableHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Draft Messages',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: context.mutedFg),
                children: [
                  TextSpan(text: '${_filtered.length} message(s)'),
                  if (_selected.isNotEmpty)
                    TextSpan(
                      text: '  |  ${_selected.length} selected',
                      style: const TextStyle(
                        color: AppColors.emerald600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
        final search = SizedBox(
          width: 300,
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() {
              _searchText = v;
              _page = 1;
            }),
            style: const TextStyle(fontSize: 14),
            decoration:
                netInputDecoration(
                  context,
                  hint: 'Search by name, ID or mobile...',
                ).copyWith(
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: context.mutedFg,
                  ),
                ),
          ),
        );
        if (constraints.maxWidth >= 560) {
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              search,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [title, const SizedBox(height: 10), search],
        );
      },
    );
  }
}

/// New draft message dialog.
class _NewDraftDialog extends StatefulWidget {
  const _NewDraftDialog();

  @override
  State<_NewDraftDialog> createState() => _NewDraftDialogState();
}

class _NewDraftDialogState extends State<_NewDraftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _message = TextEditingController();
  String _title = 'All';
  String _sendTo = 'Subscriber';

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'mobileNo': _mobile.text.trim(),
      'messageType': _title == 'All' ? '' : _title,
      'messageText': _message.text.trim(),
      'sendTo': _sendTo,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('New Draft Message'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NetField(
                  label: 'Recipient Name',
                  child: TextFormField(
                    controller: _name,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g., Ahmed Khan',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Recipient name is required'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Mobile Number',
                  child: TextFormField(
                    controller: _mobile,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g., 0300-1234567',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: MsgSelect(
                        label: 'Message Title',
                        value: _title,
                        items: allMessageTitles,
                        onChanged: (v) => setState(() => _title = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MsgSelect(
                        label: 'Send To',
                        value: _sendTo,
                        items: draftSendToOptions,
                        onChanged: (v) => setState(() => _sendTo = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Message',
                  child: TextFormField(
                    controller: _message,
                    maxLines: 4,
                    decoration: netInputDecoration(
                      context,
                      hint: 'Type your message...',
                    ),
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
            foregroundColor: const Color(0xFFE11D48),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Save Draft',
          gradient: blueCyanGradient,
          onPressed: _submit,
        ),
      ],
    );
  }
}
