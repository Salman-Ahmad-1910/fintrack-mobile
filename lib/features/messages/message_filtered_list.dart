import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../network/network_common.dart';
import 'messages_common.dart';
import 'messages_models.dart';

/// Shared implementation for the Other Messages and Expiry Messages pages
/// (`messages/other` and `messages/expired`), which differ only in the message
/// filter they apply and their visual accents.
class MessageFilteredListScreen extends StatefulWidget {
  const MessageFilteredListScreen({super.key, required this.isExpiry});

  final bool isExpiry;

  @override
  State<MessageFilteredListScreen> createState() =>
      _MessageFilteredListScreenState();
}

class _MessageFilteredListScreenState extends State<MessageFilteredListScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: messageUnauthorizedHandler);

  MsgData _data = const MsgData(messages: [], connections: [], areas: []);
  List<Map<String, dynamic>> _companies = [];
  bool _loading = true;

  // Applied filters.
  String _title = 'Select the Message';
  String _sublocality = 'all';
  String _status = 'all';
  String _type = 'all';
  String _box = 'all';
  String _pkg = 'all';
  String _company = 'all';

  // Draft filters.
  String _dTitle = 'Select the Message';
  String _dSublocality = 'all';
  String _dStatus = 'all';
  String _dType = 'all';
  String _dBox = 'all';
  String _dPkg = 'all';
  String _dCompany = 'all';

  int _pageSize = 10;
  int _page = 1;

  bool get _isExpiry => widget.isExpiry;
  List<Color> get _gradient =>
      _isExpiry ? expiredMsgGradient : otherMsgGradient;
  Color get _emptyTint =>
      _isExpiry ? const Color(0xFFF43F5E) : const Color(0xFF8B5CF6);
  IconData get _icon =>
      _isExpiry ? Icons.access_time : Icons.mark_email_unread_outlined;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cid = Session.companyId;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        fetchMsgData(_api, cid),
        fetchCompanies(_api),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as MsgData;
        _companies = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<MsgMessage> get _baseMessages {
    return _data.messages.where((m) {
      if (m.status != 'sent') return false;
      final expiry =
          m.messageType == expiryTitle ||
          m.messageText.startsWith('$expiryTitle:');
      return _isExpiry ? expiry : !expiry;
    }).toList();
  }

  List<MsgMessage> get _filtered {
    return _baseMessages.where((m) {
      if (_title != selectMessage) {
        final matchType = m.messageType == _title;
        final matchText = m.messageText.startsWith('$_title:');
        if (!matchType && !matchText) return false;
      }
      final conn = m.entityId.isEmpty ? null : _data.connectionMap[m.entityId];
      if (_sublocality != 'all' && _data.areaName(m.entityId) != _sublocality) {
        return false;
      }
      if (_status != 'all' && (conn?.status ?? '') != _status) return false;
      if (_type != 'all' && (conn?.connectionType ?? '') != _type) return false;
      if (_box != 'all' && (conn?.boxNumber ?? '') != _box) return false;
      if (_pkg != 'all' &&
          conn?.packageInternet != _pkg &&
          conn?.packageCable != _pkg) {
        return false;
      }
      if (_company != 'all' && (conn?.companyId ?? m.companyId) != _company) {
        return false;
      }
      return true;
    }).toList();
  }

  List<MsgMessage> get _pageRows {
    final start = (_page - 1) * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  String _waPhone(MsgMessage m) {
    final conn = m.entityId.isEmpty ? null : _data.connectionMap[m.entityId];
    if (m.mobileNo.isNotEmpty) return m.mobileNo;
    if (m.phone.isNotEmpty) return m.phone;
    if (conn != null) {
      if (conn.cell.isNotEmpty) return conn.cell;
      if (conn.mobile.isNotEmpty) return conn.mobile;
    }
    return '';
  }

  void _applyFilters() {
    setState(() {
      _title = _dTitle;
      _sublocality = _dSublocality;
      _status = _dStatus;
      _type = _dType;
      _box = _dBox;
      _pkg = _dPkg;
      _company = _dCompany;
      _page = 1;
    });
  }

  void _resetFilters() {
    setState(() {
      _dTitle = selectMessage;
      _dSublocality = 'all';
      _dStatus = 'all';
      _dType = 'all';
      _dBox = 'all';
      _dPkg = 'all';
      _dCompany = 'all';
      _title = selectMessage;
      _sublocality = 'all';
      _status = 'all';
      _type = 'all';
      _box = 'all';
      _pkg = 'all';
      _company = 'all';
      _page = 1;
    });
  }

  Future<void> _handleWhatsApp(MsgMessage m) async {
    final num = waNumber(_waPhone(m));
    if (num.isEmpty) return;
    final uri = Uri.parse(
      'https://wa.me/$num?text=${Uri.encodeComponent(messageBody(m))}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Launcher unavailable (e.g. tests).
    }
  }

  Future<void> _handleDelete(MsgMessage m) async {
    final ok = await showMessageConfirmDialog(
      context,
      message:
          'Delete the ${_isExpiry ? 'expiry ' : ''}message sent to "${m.name}"? '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: context.dangerText,
    );
    if (!ok) return;
    try {
      await _api.delete('/messages/${m.id}?companyId=${Session.companyId}');
      if (mounted) showToast(context, 'Message deleted.');
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  void _preview(MsgMessage m) {
    showMessagePreviewDialog(
      context,
      title: _isExpiry ? 'Expiry Message Preview' : 'Message Preview',
      fields: [
        MapEntry('Name', m.name),
        MapEntry('Internet ID', m.internetId.isEmpty ? '-' : m.internetId),
        MapEntry('WhatsApp', _waPhone(m).isEmpty ? '-' : _waPhone(m)),
        MapEntry('Status', m.status),
        MapEntry('Message Type', m.messageType.isEmpty ? '-' : m.messageType),
        MapEntry(
          'Sent At',
          m.sendedAt.isNotEmpty
              ? m.sendedAt
              : (m.createdAt.isEmpty ? '-' : m.createdAt),
        ),
      ],
      bodyLabel: 'Message body',
      body: messageBody(m),
    );
  }

  @override
  Widget build(BuildContext context) {
    final areas = _data.areas;
    final connections = _data.connections;
    final sublocalities = sublocalitiesFrom(areas);
    final statuses = distinctValues(connections.map((c) => c.status));
    final types = distinctValues(connections.map((c) => c.connectionType));
    final boxes = distinctValues(connections.map((c) => c.boxNumber));
    final packages = distinctValues([
      ...connections.map((c) => c.packageInternet),
      ...connections.map((c) => c.packageCable),
    ]);
    final companyNames = {
      for (final c in _companies)
        c['id']?.toString() ?? '': c['name']?.toString() ?? '',
    };
    final titles = _isExpiry ? expiredMessageTitles : otherMessageTitles;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          NetworkPageHeader(
            icon: _icon,
            title: _isExpiry ? 'Expiry Messages' : 'Other Messages',
            subtitle: _isExpiry
                ? 'View fee reminder messages sent to subscribers'
                : 'View messages sent to subscribers',
            gradient: _gradient,
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
                        value: _dTitle,
                        items: titles,
                        onChanged: (v) => setState(() => _dTitle = v),
                      ),
                      MsgSelect(
                        label: 'Sublocality',
                        value: _dSublocality,
                        items: ['all', ...sublocalities],
                        onChanged: (v) => setState(() => _dSublocality = v),
                      ),
                      MsgSelect(
                        label: 'Status',
                        value: _dStatus,
                        items: ['all', ...statuses],
                        onChanged: (v) => setState(() => _dStatus = v),
                      ),
                      MsgSelect(
                        label: 'Type',
                        value: _dType,
                        items: ['all', ...types],
                        onChanged: (v) => setState(() => _dType = v),
                      ),
                      MsgSelect(
                        label: 'Box Number',
                        value: _dBox,
                        items: ['all', ...boxes],
                        onChanged: (v) => setState(() => _dBox = v),
                      ),
                      MsgSelect(
                        label: 'Package',
                        value: _dPkg,
                        items: ['all', ...packages],
                        onChanged: (v) => setState(() => _dPkg = v),
                      ),
                      MsgSelect(
                        label: 'Company',
                        value: _dCompany,
                        items: [
                          'all',
                          for (final c in _companies) c['id']?.toString() ?? '',
                        ],
                        displayLabel: (v) =>
                            v == 'all' ? 'All' : (companyNames[v] ?? v),
                        onChanged: (v) => setState(() => _dCompany = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          foregroundColor: context.fg,
                        ),
                        onPressed: _resetFilters,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, size: 16),
                            SizedBox(width: 6),
                            Text('Reset'),
                          ],
                        ),
                      ),
                      GradientButton(
                        label: 'Show',
                        gradient: _gradient,
                        onPressed: _applyFilters,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isExpiry ? 'Expiry Reminders' : 'Sent Messages',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_filtered.length} message(s)',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.mutedFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_title != selectMessage)
                        Text(
                          'Message: ',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.mutedFg,
                          ),
                        ),
                      if (_title != selectMessage)
                        Text(
                          _title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  NetworkTable<MsgMessage>(
                    rows: _pageRows,
                    emptyIcon: _icon,
                    emptyTitle: _isExpiry
                        ? 'No expiry messages found'
                        : 'No messages found',
                    emptyHint: 'Adjust the filters and press Show.',
                    emptyTint: _emptyTint,
                    mobileTrailing: (context, m, _) => _rowActions(m),
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
                        label: 'Subscriber ID',
                        width: 110,
                        builder: (context, m, _) => Text(
                          m.entityId.isEmpty
                              ? '-'
                              : (m.entityId.length > 8
                                    ? m.entityId.substring(0, 8)
                                    : m.entityId),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Internet ID',
                        width: 130,
                        builder: (context, m, _) => Text(
                          m.internetId.isEmpty ? '-' : m.internetId,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      NetColumn(
                        label: 'Subscriber Name',
                        width: 160,
                        builder: (context, m, _) => Text(
                          m.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: m.entityId.isEmpty
                                ? context.fg
                                : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Address',
                        width: 200,
                        builder: (context, m, _) {
                          final conn = m.entityId.isEmpty
                              ? null
                              : _data.connectionMap[m.entityId];
                          final address = m.address.isNotEmpty
                              ? m.address
                              : (conn?.address.isNotEmpty ?? false
                                    ? conn!.address
                                    : '-');
                          return Text(
                            address,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.mutedFg,
                            ),
                          );
                        },
                      ),
                      NetColumn(
                        label: 'WhatsApp Number',
                        width: 170,
                        builder: (context, m, _) {
                          final phone = _waPhone(m);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  phone.isEmpty ? '-' : phone,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (phone.isNotEmpty)
                                MessageActionIcon(
                                  icon: Icons.chat_bubble_outline,
                                  color: AppColors.emerald600,
                                  tooltip: 'Send via WhatsApp',
                                  size: 16,
                                  onTap: () => _handleWhatsApp(m),
                                ),
                            ],
                          );
                        },
                      ),
                      NetColumn(
                        label: 'Actions',
                        width: 92,
                        isActions: true,
                        builder: (context, m, _) => Align(
                          alignment: Alignment.centerLeft,
                          child: _rowActions(m),
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

  Widget _rowActions(MsgMessage m) {
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
          color: const Color(0xFFDC2626),
          tooltip: 'Delete',
          onTap: () => _handleDelete(m),
        ),
      ],
    );
  }
}
