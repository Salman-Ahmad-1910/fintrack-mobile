import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../network/network_common.dart';
import 'messages_common.dart';
import 'messages_models.dart';

/// Flutter counterpart of `client/src/app/(app)/messages/sent/page.tsx` —
/// browse sent messages one day at a time.
class SentMessagesScreen extends StatefulWidget {
  const SentMessagesScreen({super.key});

  @override
  State<SentMessagesScreen> createState() => _SentMessagesScreenState();
}

class _SentMessagesScreenState extends State<SentMessagesScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: messageUnauthorizedHandler);

  MsgData _data = const MsgData(messages: [], connections: [], areas: []);
  bool _loading = true;

  DateTime _selectedDate = DateTime.now();
  int _pageSize = 10;
  int _page = 1;
  final TextEditingController _search = TextEditingController();
  String _searchText = '';
  String _sublocality = 'all';
  String _messageTitle = 'All';
  String _sendTo = 'All';

  static final DateFormat _dayLabel = DateFormat('EEEE, dd MMM yyyy');
  static final DateFormat _shortDate = DateFormat('dd MMM yyyy');

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

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  List<MsgMessage> get _dayMessages => _data.messages
      .where((m) => m.status == 'sent' && m.dateKey == _dateKey)
      .toList();

  List<MsgMessage> get _filtered => _dayMessages.where((m) {
    if (_messageTitle != 'All' && m.messageType != _messageTitle) return false;
    if (_sendTo != 'All' && m.sendTo != _sendTo) return false;
    if (_sublocality != 'all' && _data.areaName(m.entityId) != _sublocality) {
      return false;
    }
    return msgMatchesSearch(
      _searchText,
      entityId: m.entityId,
      internetId: m.internetId,
      mobileNo: m.mobileNo,
      name: m.name,
      messageType: m.messageType,
    );
  }).toList();

  List<MsgMessage> get _pageRows {
    final start = (_page - 1) * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  int get _uniqueRecipients => _dayMessages.map((m) => m.name).toSet().length;

  void _shiftDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _page = 1;
    });
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final sublocalities = sublocalitiesFrom(_data.areas);
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.send_outlined,
            title: 'Sent Messages',
            subtitle: 'View sent messages day by day',
            gradient: sentMsgGradient,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _dateNavigator(context),
            const SizedBox(height: 16),
            AppCard(
              child: MsgFilterGrid(
                children: [
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
                    label: 'Message Title',
                    value: _messageTitle,
                    items: allMessageTitles,
                    onChanged: (v) => setState(() {
                      _messageTitle = v;
                      _page = 1;
                    }),
                  ),
                  MsgSelect(
                    label: 'Send To',
                    value: _sendTo,
                    items: ['All', ...sentSendToOptions],
                    onChanged: (v) => setState(() {
                      _sendTo = v;
                      _page = 1;
                    }),
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
                    emptyIcon: Icons.send_outlined,
                    emptyTitle: 'No sent messages on this date',
                    emptyHint: 'Use the arrows to browse other dates.',
                    emptyTint: const Color(0xFF3B82F6),
                    columns: [
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
                        label: 'Internet ID',
                        width: 140,
                        builder: (context, m, _) => Text(
                          m.internetId.isEmpty ? '-' : m.internetId,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      NetColumn(
                        label: 'Name',
                        width: 160,
                        builder: (context, m, _) =>
                            Text(m.name, overflow: TextOverflow.ellipsis),
                      ),
                      NetColumn(
                        label: 'Message',
                        width: 260,
                        builder: (context, m, _) => Text(
                          m.messageText.isNotEmpty
                              ? m.messageText
                              : (m.messageType.isEmpty ? '-' : m.messageType),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Sent To',
                        width: 140,
                        builder: (context, m, _) => Text(
                          m.mobileNo.isNotEmpty
                              ? m.mobileNo
                              : (m.phone.isEmpty ? '-' : m.phone),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      NetColumn(
                        label: 'Send By',
                        width: 120,
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
                        label: 'Time',
                        width: 90,
                        builder: (context, m, _) => Text(
                          formatTime(
                            m.sendedAt.isNotEmpty ? m.sendedAt : m.createdAt,
                          ),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
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

  Widget _dateNavigator(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 12,
            children: [
              _navButton(
                icon: Icons.chevron_left,
                tooltip: 'Previous day',
                onTap: () => _shiftDate(-1),
              ),
              Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _dayLabel.format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    children: [
                      _statPill(
                        Icons.send,
                        const Color(0xFF2563EB),
                        '${_dayMessages.length}',
                        'sent',
                      ),
                      _statPill(
                        Icons.check_circle_outline,
                        AppColors.emerald600,
                        '${_dayMessages.length}',
                        'delivered',
                      ),
                      _statPill(
                        Icons.people_outline,
                        const Color(0xFF7C3AED),
                        '$_uniqueRecipients',
                        'recipients',
                      ),
                    ],
                  ),
                ],
              ),
              _navButton(
                icon: Icons.chevron_right,
                tooltip: 'Next day',
                onTap: _isToday ? null : () => _shiftDate(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              foregroundColor: context.fg,
            ),
            onPressed: () => setState(() {
              _selectedDate = DateTime.now();
              _page = 1;
            }),
            child: const Text('Today'),
          ),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, Color color, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: context.mutedFg)),
      ],
    );
  }

  Widget _navButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          foregroundColor: context.fg,
          side: BorderSide(
            color: onTap == null
                ? context.line.withValues(alpha: 0.5)
                : context.line,
          ),
        ),
        onPressed: onTap,
        child: Icon(icon, size: 24),
      ),
    );
  }

  Widget _tableHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages Sent on ${_shortDate.format(_selectedDate)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              '${_filtered.length} message(s)',
              style: TextStyle(fontSize: 12, color: context.mutedFg),
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
                  hint: 'Search by name, ID or message...',
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
