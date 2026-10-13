import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../inventory/inventory_common.dart';
import '../network/network_common.dart';
import '../sales/sales_common.dart';
import '../shared/crud_kit.dart';
import '../transaction/transaction_common.dart';
import 'admin_utils.dart';

// ===========================================================================
// System Log (admin/logs/page.tsx) — server-side filtered + paged audit trail
// ===========================================================================

class SystemLogScreen extends StatefulWidget {
  const SystemLogScreen({super.key});

  @override
  State<SystemLogScreen> createState() => _SystemLogScreenState();
}

class _SystemLogScreenState extends State<SystemLogScreen> {
  // Logs are always read live (no offline cache): they change constantly.
  final ApiClient _api = ApiClient(onUnauthorized: kitHandleUnauthorized);
  final TextEditingController _search = TextEditingController();

  List<Map<String, dynamic>> _logs = [];
  Map<String, dynamic> _summary = const {};
  List<Map<String, dynamic>> _users = [];
  List<String> _actions = [];
  List<String> _modules = [];
  bool _loading = true;
  String? _error;
  String? _restoring;

  late String _from = _fmt(DateTime.now().subtract(const Duration(days: 7)));
  String _to = kitToday();
  String _user = 'all';
  String _action = 'all';
  String _module = 'all';
  String _status = 'all';
  String _query = '';
  int _page = 1;
  int _pageSize = 20;

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _cid => Session.companyId ?? '';

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
    if (_cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final params = <String, String>{
        'companyId': _cid,
        'fromDate': _from,
        'toDate': _to,
        if (_user != 'all') 'userId': _user,
        if (_action != 'all') 'action': _action,
        if (_module != 'all') 'module': _module,
        if (_status != 'all') 'status': _status,
        if (_query.isNotEmpty) 'search': _query,
        'limit': '$_pageSize',
        'offset': '${(_page - 1) * _pageSize}',
      };
      final json = await _api.get('/admin/logs', query: params);
      if (!mounted) return;
      final logs = json['data'];
      setState(() {
        _logs = logs is List
            ? logs.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
            : [];
        final summary = json['summary'];
        _summary = summary is Map ? summary.cast<String, dynamic>() : const {};
        final users = json['users'];
        _users = users is List
            ? users.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
            : [];
        final actions = json['actions'];
        _actions = actions is List ? actions.map((e) => '$e').toList() : [];
        final modules = json['modules'];
        _modules = modules is List ? modules.map((e) => '$e').toList() : [];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  bool _canRestore(Map<String, dynamic> log) {
    if (kitStr(log['action']) != 'delete') return false;
    final details = log['details'];
    return details is Map && kitStr(details['entityId']).isNotEmpty;
  }

  Future<void> _restore(Map<String, dynamic> log) async {
    final id = kitStr(log['id']);
    setState(() => _restoring = id);
    try {
      await _api.post('/admin/logs/$id/restore?companyId=$_cid', body: const {});
      if (mounted) showToast(context, 'Record restored successfully');
      await _load();
    } catch (e) {
      if (mounted) kitReportError(context, e);
    } finally {
      if (mounted) setState(() => _restoring = null);
    }
  }

  Future<void> _export() async {
    final rows = <List<String>>[
      ['Timestamp', 'User', 'Role', 'Action', 'Module', 'Page', 'Serial Numbers', 'Description', 'Status'],
      for (final l in _logs)
        [
          kitDateTime(kitStr(l['timestamp'])),
          kitStr(l['userName']),
          kitStr(l['userRole']),
          kitStr(l['action']),
          kitStr(l['module']),
          kitStr(l['page']),
          kitStr(l['serialNumbers']),
          kitStr(l['description']),
          kitStr(l['status']),
        ],
    ];
    final ok = await salesWriteCsv(context, 'system-logs-${kitToday()}.csv', rows);
    if (ok && mounted) showToast(context, 'Logs exported successfully');
  }

  void _apply() {
    setState(() => _page = 1);
    _load();
  }

  Color _statusColor(String s) => switch (s) {
    'success' => AppColors.emerald600,
    'error' => const Color(0xFFDC2626),
    'warning' => const Color(0xFFD97706),
    _ => const Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final total = kitInt(_summary['totalLogs']);
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.history,
            title: 'System Log',
            subtitle: 'Every create, update and delete across the system.',
            gradient: kitSlate,
          ),
          if (_cid.isEmpty)
            const KitNoCompany(what: 'logs')
          else ...[
            NetworkStatGrid(
              maxColumns: 4,
              children: [
                kitStat('Total Logs', total, Icons.list_alt, kitBlue),
                kitStat('Success', kitInt(_summary['successCount']), Icons.check_circle_outline, kitEmerald),
                kitStat('Errors', kitInt(_summary['errorCount']), Icons.error_outline, kitRose),
                kitStat('Warnings', kitInt(_summary['warningCount']), Icons.warning_amber_outlined, kitAmber),
              ],
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InvFilterBar(
                    filterWidth: 200,
                    filtersPerRow: 2,
                    filters: [
                      TxDateField(label: 'From', value: _from, width: 200, onChanged: (v) => setState(() => _from = v)),
                      TxDateField(label: 'To', value: _to, width: 200, onChanged: (v) => setState(() => _to = v)),
                      TxSelect(
                        value: _user,
                        items: {
                          'all': 'All Users',
                          for (final u in _users)
                            if (kitStr(u['id']).isNotEmpty) kitStr(u['id']): kitStr(u['name']),
                        },
                        onChanged: (v) => setState(() => _user = v),
                      ),
                      TxSelect(
                        value: _action,
                        items: {'all': 'All Actions', for (final a in _actions) a: kitTitle(a)},
                        onChanged: (v) => setState(() => _action = v),
                      ),
                      TxSelect(
                        value: _module,
                        items: {'all': 'All Modules', for (final m in _modules) m: kitTitle(m)},
                        onChanged: (v) => setState(() => _module = v),
                      ),
                      TxSelect(
                        value: _status,
                        items: const {
                          'all': 'All Status',
                          'success': 'Success',
                          'error': 'Error',
                          'warning': 'Warning',
                        },
                        onChanged: (v) => setState(() => _status = v),
                      ),
                      txSearchField(
                        context: context,
                        controller: _search,
                        hint: 'Search user, action, serial...',
                        onChanged: (v) => _query = v.trim(),
                      ),
                    ],
                    actions: [
                      GradientButton(
                        label: 'Apply',
                        icon: Icons.filter_alt_outlined,
                        gradient: kitBlue,
                        loading: _loading,
                        onPressed: _apply,
                      ),
                      if (_logs.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: _export,
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Export CSV'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const KitLoading()
                  else if (_error != null)
                    KitErrorCard(message: _error!, onRetry: _load)
                  else ...[
                    NetworkTable<Map<String, dynamic>>(
                      rows: _logs,
                      emptyIcon: Icons.history,
                      emptyTitle: 'No logs for the selected filters.',
                      emptyHint: '',
                      emptyTint: AppColors.emerald600,
                      mobileTrailing: (context, l, _) => _canRestore(l)
                          ? TextButton(
                              onPressed: _restoring == null ? () => _restore(l) : null,
                              child: Text(_restoring == kitStr(l['id']) ? 'Restoring…' : 'Restore'),
                            )
                          : const SizedBox.shrink(),
                      columns: [
                        NetColumn(label: 'Time', width: 150, builder: (c, l, _) => Text(kitDateTime(kitStr(l['timestamp'])), style: const TextStyle(fontSize: 12.5))),
                        NetColumn(
                          label: 'User',
                          width: 140,
                          builder: (c, l, _) => Text(
                            kitStr(l['userName']).isEmpty ? 'System' : kitStr(l['userName']),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        NetColumn(label: 'Action', width: 90, builder: (c, l, _) => Text(kitTitle(kitStr(l['action'])))),
                        NetColumn(label: 'Module', width: 110, builder: (c, l, _) => Text(kitTitle(kitStr(l['module'])))),
                        NetColumn(label: 'Description', width: 260, builder: (c, l, _) => Text(kitStr(l['description']), maxLines: 3, overflow: TextOverflow.ellipsis)),
                        NetColumn(
                          label: 'Status',
                          width: 90,
                          builder: (c, l, _) => Text(
                            kitTitle(kitStr(l['status'])),
                            style: TextStyle(color: _statusColor(kitStr(l['status'])), fontWeight: FontWeight.w600),
                          ),
                        ),
                        NetColumn(
                          label: '',
                          width: 100,
                          isActions: true,
                          builder: (c, l, _) => _canRestore(l)
                              ? TextButton(
                                  onPressed: _restoring == null ? () => _restore(l) : null,
                                  child: const Text('Restore'),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    if (total > 0) ...[
                      const SizedBox(height: 12),
                      NetworkPagination(
                        currentPage: _page,
                        pageSize: _pageSize,
                        totalItems: total,
                        noun: 'logs',
                        pageSizes: const [10, 20, 50, 100],
                        onPageChanged: (p) {
                          setState(() => _page = p);
                          _load();
                        },
                        onPageSizeChanged: (s) {
                          setState(() {
                            _pageSize = s;
                            _page = 1;
                          });
                          _load();
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Downloads — Drivers / Application (shared-file-manager.tsx)
// ===========================================================================

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key, required this.kind});

  /// `drivers` or `applications` (the list endpoints `/drivers`,
  /// `/applications`; uploads go to `/upload/driver` or `/upload/application`).
  final String kind;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: kitHandleUnauthorized);
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  bool get _drivers => widget.kind == 'drivers';
  String get _cid => Session.companyId ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DownloadsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) _load();
  }

  Future<void> _load() async {
    if (_cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final json = await _api.get('/${widget.kind}', query: {'companyId': _cid});
      final files = json['files'];
      if (!mounted) return;
      setState(() {
        _files = files is List
            ? files.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
            : [];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _download(Map<String, dynamic> f) async {
    final path = kitStr(f['downloadUrl']);
    if (path.isEmpty) return;
    final url = Uri.parse('${ApiConfig.origin}$path');
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showToast(context, 'Could not open the download link', error: true);
  }

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['exe', 'msi', 'zip'],
    );
    final file = picked?.files.single;
    if (file == null || file.path == null) return;
    setState(() => _uploading = true);
    try {
      await _api.postFile(
        _drivers ? '/upload/driver' : '/upload/application',
        filePath: file.path!,
        filename: file.name,
        field: 'file',
      );
      if (mounted) showToast(context, 'File uploaded successfully');
      await _load();
    } catch (e) {
      if (mounted) kitReportError(context, e, fallback: 'Upload failed');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> f) async {
    await showNetworkDeleteDialog(
      context,
      itemName: kitStr(f['originalName']),
      onConfirm: () async {
        try {
          await _api.delete('/files/${kitStr(f['id'])}');
          if (mounted) showToast(context, 'File deleted');
          await _load();
        } catch (e) {
          if (mounted) kitReportError(context, e);
        }
      },
    );
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final title = _drivers ? 'Drivers' : 'Application';
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          NetworkPageHeader(
            icon: _drivers ? Icons.memory_outlined : Icons.apps_outlined,
            title: title,
            subtitle: 'Shared .exe, .msi and .zip downloads for your team.',
            gradient: kitBlue,
          ),
          if (_cid.isEmpty)
            KitNoCompany(what: title.toLowerCase())
          else
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GradientButton(
                      label: _uploading ? 'Uploading...' : 'Upload File',
                      icon: Icons.upload_file_outlined,
                      gradient: kitEmerald,
                      loading: _uploading,
                      onPressed: _upload,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const KitLoading()
                  else if (_error != null && _files.isEmpty)
                    KitErrorCard(message: _error!, onRetry: _load)
                  else
                    NetworkTable<Map<String, dynamic>>(
                      rows: _files,
                      emptyIcon: Icons.folder_open_outlined,
                      emptyTitle: 'No files uploaded yet.',
                      emptyHint: '',
                      emptyTint: AppColors.emerald600,
                      mobileTrailing: (c, f, _) => _actions(f),
                      columns: [
                        NetColumn(label: 'File', width: 260, builder: (c, f, _) => Text(kitStr(f['originalName']), style: const TextStyle(fontWeight: FontWeight.w600))),
                        NetColumn(label: 'Size', width: 90, builder: (c, f, _) => Text(_size(kitInt(f['size'])))),
                        NetColumn(label: 'Uploaded', width: 110, builder: (c, f, _) => Text(kitDate(kitStr(f['createdAt'])))),
                        NetColumn(label: '', width: 110, isActions: true, builder: (c, f, _) => _actions(f)),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions(Map<String, dynamic> f) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Download',
        onPressed: () => _download(f),
        icon: const Icon(Icons.download_outlined, color: AppColors.emerald600),
      ),
      IconButton(
        tooltip: 'Delete',
        onPressed: () => _delete(f),
        icon: Icon(Icons.delete_outline, color: context.dangerText),
      ),
    ],
  );
}
