import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../network/network_common.dart';
import 'messages_common.dart';
import 'messages_models.dart';

/// Flutter counterpart of `client/src/app/(app)/messages/whatsapp-draft/page.tsx`.
class WhatsappDraftScreen extends StatefulWidget {
  const WhatsappDraftScreen({super.key});

  @override
  State<WhatsappDraftScreen> createState() => _WhatsappDraftScreenState();
}

class _WhatsappDraftScreenState extends State<WhatsappDraftScreen> {
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
      _data.messages.where((m) => m.status == 'whatsapp_draft').toList();

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

  Future<void> _openWhatsApp(String phone, String text) async {
    final num = waNumber(phone);
    if (num.isEmpty) return;
    final uri = Uri.parse(
      'https://wa.me/$num?text=${Uri.encodeComponent(text)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Launcher unavailable (e.g. tests) — the message is still marked sent.
    }
  }

  Future<void> _sendSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final ok = await showMessageConfirmDialog(
      context,
      message:
          'Send ${ids.length} WhatsApp message(s)? WhatsApp will open for each '
          'recipient.',
      confirmLabel: 'Send',
      confirmColor: const Color(0xFF16A34A),
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
        final phone = msg.mobileNo.isNotEmpty ? msg.mobileNo : msg.phone;
        await _openWhatsApp(phone, msg.messageText);
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
      showToast(context, '${ids.length} WhatsApp message(s) sent.');
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _sending = false);
      showToast(context, e.message, error: true);
    }
  }

  Future<void> _deleteDraft(MsgMessage m) async {
    final ok = await showMessageConfirmDialog(
      context,
      message: 'Delete this WhatsApp draft?',
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

  Future<void> _clearAll() async {
    if (_drafts.isEmpty) return;
    final ok = await showMessageConfirmDialog(
      context,
      message: 'Are you sure you want to clear all WhatsApp drafts?',
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
      showToast(context, 'All WhatsApp drafts cleared.');
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  void _preview(MsgMessage m) {
    showMessagePreviewDialog(
      context,
      title: 'WhatsApp Message Preview',
      fields: [
        MapEntry('Name', m.name),
        MapEntry('Phone', m.preferPhone.isEmpty ? '-' : m.preferPhone),
        MapEntry('Message Type', m.messageType.isEmpty ? '-' : m.messageType),
        MapEntry('Send To', m.sendTo.isEmpty ? '-' : m.sendTo),
        MapEntry('Send By', m.sentBy.isEmpty ? '-' : m.sentBy),
        MapEntry('Created', formatDateTime(m.createdAt)),
      ],
      bodyLabel: 'WhatsApp Message',
      body: m.messageText.isEmpty ? 'No message content' : m.messageText,
      bodyTint: context.isDark
          ? const Color(0xFF052E16)
          : const Color(0xFFF0FDF4),
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
            icon: Icons.chat_bubble_outline,
            title: 'WhatsApp Draft Messages',
            subtitle:
                'Review and send WhatsApp messages written in New Messages',
            gradient: whatsappGradient,
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
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      GradientButton(
                        label: 'Send (${_selected.length})',
                        icon: Icons.send,
                        gradient: whatsappGradient,
                        loading: _sending,
                        onPressed: _selected.isEmpty ? null : _sendSelected,
                      ),
                      GradientButton(
                        label: 'Clear All Drafts',
                        icon: Icons.warning_amber_rounded,
                        gradient: roseRedGradient,
                        onPressed: _clearAll,
                      ),
                    ],
                  ),
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
                    emptyIcon: Icons.chat_bubble_outline,
                    emptyTitle: 'No WhatsApp drafts found',
                    emptyHint:
                        'Write a WhatsApp message in New Messages or adjust the '
                        'filters.',
                    emptyTint: const Color(0xFF22C55E),
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

  Widget _tableHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WhatsApp Drafts',
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
