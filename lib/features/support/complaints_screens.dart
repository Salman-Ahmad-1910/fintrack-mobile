import 'package:flutter/material.dart';

import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../inventory/inventory_common.dart';
import '../network/network_common.dart';
import '../sales/sales_common.dart';
import '../shared/crud_kit.dart';
import '../transaction/transaction_common.dart';
import 'support_common.dart';

// ===========================================================================
// Complaint Type / Subject Type (support/complaints/complaint-type|subject-type)
// ===========================================================================

/// `support/complaints/complaint-type/page.tsx` — `{name}` records at
/// `/support/complaint-types`, gated by page 15325.
class ComplaintTypesScreen extends StatelessWidget {
  const ComplaintTypesScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LookupScreen(
    endpoint: '/support/complaint-types',
    permission: kComplaintTypePermission,
    title: 'Complaint Type',
    subtitle: 'Manage the types of complaints subscribers can raise',
    noun: 'complaint types',
    primaryKey: 'name',
    primaryLabel: 'Complaint Type',
  );
}

/// `support/complaints/subject-type/page.tsx` — `{subject, type}` records at
/// `/support/complaint-subjects` (type = a Complaint Type name), page 15323.
class SubjectTypesScreen extends StatelessWidget {
  const SubjectTypesScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LookupScreen(
    endpoint: '/support/complaint-subjects',
    permission: kComplaintSubjectPermission,
    title: 'Subject Type',
    subtitle: 'Manage complaint subjects for each complaint type',
    noun: 'subjects',
    primaryKey: 'subject',
    primaryLabel: 'Subject',
    typeEndpoint: '/support/complaint-types',
  );
}

class _LookupScreen extends StatefulWidget {
  const _LookupScreen({
    required this.endpoint,
    required this.permission,
    required this.title,
    required this.subtitle,
    required this.noun,
    required this.primaryKey,
    required this.primaryLabel,
    this.typeEndpoint,
  });

  final String endpoint;
  final String permission;
  final String title;
  final String subtitle;
  final String noun;
  final String primaryKey;
  final String primaryLabel;

  /// When set, each record also carries a `type` chosen from this list.
  final String? typeEndpoint;

  @override
  State<_LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends State<_LookupScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: kitHandleUnauthorized);
  final TextEditingController _search = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  List<String> _types = [];
  bool _loading = true;
  String? _error;
  String _filter = '';
  int _page = 1;
  int _pageSize = 10;

  String get _cid => Session.companyId ?? '';
  bool get _canCreate => invCrud(widget.permission, 'create');
  bool get _canUpdate => invCrud(widget.permission, 'update');
  bool get _canDelete => invCrud(widget.permission, 'delete');

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
    try {
      final q = {'companyId': _cid};
      final rows = kitMaps(await _api.get(widget.endpoint, query: q));
      var types = <String>[];
      if (widget.typeEndpoint != null) {
        types = kitMaps(await _api.get(widget.typeEndpoint!, query: q))
            .map((t) => kitStr(t['name']))
            .where((n) => n.isNotEmpty)
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _types = types;
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

  List<Map<String, dynamic>> get _filtered => _rows
      .where(
        (r) => kitMatch(_filter, [
          kitStr(r[widget.primaryKey]),
          kitStr(r['type']),
        ]),
      )
      .toList();

  Future<void> _openForm(Map<String, dynamic>? existing) async {
    final primary = TextEditingController(
      text: kitStr(existing?[widget.primaryKey]),
    );
    var type = kitStr(existing?['type']);
    if (type.isEmpty && _types.isNotEmpty) type = _types.first;
    final hasType = widget.typeEndpoint != null;
    await showKitForm(
      context,
      title: existing == null
          ? 'Add ${widget.title}'
          : 'Edit ${widget.title}',
      submitLabel: existing == null ? 'Add' : 'Update',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasType) ...[
            if (_types.isEmpty)
              const KitReadOnly(
                label: 'Select Type',
                value: 'No types available — add a Complaint Type first',
              )
            else
              KitSelect(
                label: 'Select Type',
                value: type,
                items: {for (final t in _types) t: t},
                onChanged: (v) => setSheet(() => type = v),
              ),
            kitGap,
          ],
          KitTextField(label: widget.primaryLabel, controller: primary),
        ],
      ),
      onSubmit: () async {
        final value = primary.text.trim();
        if (value.isEmpty) {
          showToast(context, '${widget.primaryLabel} is required', error: true);
          return false;
        }
        if (hasType && type.isEmpty) {
          showToast(context, 'Select a type', error: true);
          return false;
        }
        final body = <String, dynamic>{
          ...?existing,
          widget.primaryKey: value,
          if (hasType) 'type': type,
          'companyId': _cid,
        };
        try {
          if (existing == null) {
            await _api.post(widget.endpoint, body: body);
          } else {
            await _api.put(
              '${widget.endpoint}/${kitStr(existing['id'])}',
              body: body,
            );
          }
          if (mounted) {
            showToast(
              context,
              '${widget.title} ${existing == null ? 'created' : 'updated'}.',
            );
          }
          await _load();
          return true;
        } catch (e) {
          if (mounted) kitReportError(context, e);
          return false;
        }
      },
    );
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    await showNetworkDeleteDialog(
      context,
      itemName: kitStr(row[widget.primaryKey]),
      onConfirm: () async {
        try {
          await _api.delete('${widget.endpoint}/${kitStr(row['id'])}');
          if (mounted) showToast(context, '${widget.title} deleted.');
          await _load();
        } catch (e) {
          if (mounted) kitReportError(context, e);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final page = kitPage(filtered, _page, _pageSize);
    final hasType = widget.typeEndpoint != null;
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          NetworkPageHeader(
            icon: hasType ? Icons.subject_outlined : Icons.category_outlined,
            title: widget.title,
            subtitle: widget.subtitle,
            gradient: kitEmerald,
          ),
          NetworkStatGrid(
            children: [
              kitStat(
                'Total ${hasType ? 'Subjects' : 'Types'}',
                _rows.length,
                Icons.layers_outlined,
                kitBlue,
              ),
              if (hasType)
                for (final t in _types.take(4))
                  kitStat(
                    t,
                    _rows.where((r) => kitStr(r['type']) == t).length,
                    Icons.label_outline,
                    kitEmerald,
                  ),
            ],
          ),
          const SizedBox(height: 20),
          if (_cid.isEmpty)
            KitNoCompany(what: widget.noun)
          else if (_loading)
            const KitLoading()
          else if (_error != null && _rows.isEmpty)
            KitErrorCard(message: _error!, onRetry: _load)
          else
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InvFilterBar(
                    filterWidth: 320,
                    filters: [
                      txSearchField(
                        context: context,
                        controller: _search,
                        hint: 'Search ${widget.noun}...',
                        onChanged: (v) => setState(() {
                          _filter = v;
                          _page = 1;
                        }),
                      ),
                    ],
                    actions: [
                      if (_canCreate)
                        GradientButton(
                          label: 'Add ${widget.title}',
                          icon: Icons.add_circle_outline,
                          gradient: kitEmerald,
                          onPressed: () => _openForm(null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  NetworkTable<Map<String, dynamic>>(
                    rows: page,
                    emptyIcon: Icons.inbox_outlined,
                    emptyTitle: 'No ${widget.noun} found.',
                    emptyHint: _canCreate
                        ? 'Get started by adding one.'
                        : 'Nothing to show yet.',
                    emptyTint: AppColors.emerald600,
                    mobileTrailing: (context, row, _) => NetworkRowActions(
                      onEdit: _canUpdate ? () => _openForm(row) : null,
                      onDelete: _canDelete ? () => _delete(row) : null,
                    ),
                    columns: [
                      NetColumn(
                        label: 'ID',
                        width: 60,
                        builder: (context, row, i) =>
                            Text('${(_page - 1) * _pageSize + i + 1}'),
                      ),
                      NetColumn(
                        label: widget.primaryLabel,
                        width: 280,
                        builder: (context, row, _) => Text(
                          kitStr(row[widget.primaryKey]),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (hasType)
                        NetColumn(
                          label: 'Type',
                          width: 160,
                          builder: (context, row, _) =>
                              Text(kitStr(row['type'])),
                        ),
                      NetColumn(
                        label: '',
                        width: 96,
                        isActions: true,
                        builder: (context, row, _) => Align(
                          alignment: Alignment.centerRight,
                          child: NetworkRowActions(
                            onEdit: _canUpdate ? () => _openForm(row) : null,
                            onDelete: _canDelete ? () => _delete(row) : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (filtered.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    NetworkPagination(
                      currentPage: _page,
                      pageSize: _pageSize,
                      totalItems: filtered.length,
                      noun: widget.noun,
                      onPageChanged: (p) => setState(() => _page = p),
                      onPageSizeChanged: (s) => setState(() {
                        _pageSize = s;
                        _page = 1;
                      }),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Complaint list shared by the three complaint pages
// ===========================================================================

enum _ComplaintMode { subscriber, allocated, report }

/// `support/complaints/user/page.tsx` — create, edit, status, allocate,
/// delete complaints (page 13342).
class SubscriberComplaintsScreen extends StatelessWidget {
  const SubscriberComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const _ComplaintsPage(mode: _ComplaintMode.subscriber);
}

/// `support/complaints/allocated/page.tsx` — complaints that have an
/// operator; staff / recovery officers only see their own (page 13343).
class AllocatedComplaintsScreen extends StatelessWidget {
  const AllocatedComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const _ComplaintsPage(mode: _ComplaintMode.allocated);
}

/// `support/complaints/report/page.tsx` — filter by category / status, then
/// view, print or export the report.
class ComplaintReportScreen extends StatelessWidget {
  const ComplaintReportScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const _ComplaintsPage(mode: _ComplaintMode.report);
}

class _ComplaintsPage extends StatefulWidget {
  const _ComplaintsPage({required this.mode});

  final _ComplaintMode mode;

  @override
  State<_ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends State<_ComplaintsPage> {
  final OfflineApi _api = OfflineApi(onUnauthorized: kitHandleUnauthorized);
  final TextEditingController _search = TextEditingController();

  List<Complaint> _complaints = [];
  ComplaintLookups _lookups = ComplaintLookups(assignees: const []);
  bool _loading = true;
  String? _error;
  String _filter = '';
  String _category = 'All';
  String _status = 'All';
  bool _showReport = false;
  int _page = 1;
  int _pageSize = 10;

  String get _cid => Session.companyId ?? '';
  _ComplaintMode get _mode => widget.mode;

  String get _permission => _mode == _ComplaintMode.allocated
      ? kComplaintsAllocatedPermission
      : kComplaintsUserPermission;
  bool get _canCreate =>
      _mode == _ComplaintMode.subscriber && invCrud(_permission, 'create');
  bool get _canUpdate =>
      _mode != _ComplaintMode.report && invCrud(_permission, 'update');
  bool get _canDelete =>
      _mode != _ComplaintMode.report && invCrud(_permission, 'delete');

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
    try {
      final results = await Future.wait([
        _api.get('/support/complaints', query: {'companyId': _cid}),
        ComplaintLookups.load(_api),
      ]);
      if (!mounted) return;
      final list = kitMaps(results[0] as Map<String, dynamic>)
          .map(Complaint.new)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _complaints = list;
        _lookups = results[1] as ComplaintLookups;
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

  /// Allocated page: members (staff / recovery officers) see only their own
  /// allocations, everyone else sees every allocated complaint.
  List<Complaint> get _scoped {
    switch (_mode) {
      case _ComplaintMode.subscriber:
      case _ComplaintMode.report:
        return _complaints;
      case _ComplaintMode.allocated:
        final all = _complaints.where((c) => c.assignedToId.isNotEmpty);
        final me = Session.userId ?? '';
        if (me.isNotEmpty && _lookups.memberIds.contains(me)) {
          return all.where((c) => c.assignedToId == me).toList();
        }
        return all.toList();
    }
  }

  List<Complaint> get _filtered {
    if (_mode == _ComplaintMode.report && !_showReport) return const [];
    return _scoped.where((c) {
      if (_mode != _ComplaintMode.subscriber) {
        if (_category != 'All' && c.category != _category) return false;
        if (_status != 'All' && c.status != _status) return false;
      }
      if (_mode != _ComplaintMode.report &&
          !kitMatch(_filter, [c.id, c.subscriberName, c.description])) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _delete(Complaint c) async {
    await showNetworkDeleteDialog(
      context,
      itemName: 'complaint for ${c.subscriberName}',
      onConfirm: () async {
        try {
          await _api.delete('/support/complaints/${c.id}');
          if (mounted) showToast(context, 'Complaint deleted.');
          await _load();
        } catch (e) {
          if (mounted) kitReportError(context, e, fallback: 'Delete failed');
        }
      },
    );
  }

  Future<void> _after(Future<bool> action) async {
    if (await action) await _load();
  }

  // ---- New complaint ------------------------------------------------------

  Future<void> _openCreate() async {
    List<ComplaintSubscriber> roster;
    List<Map<String, dynamic>> subjects;
    List<Map<String, dynamic>> areas;
    try {
      final q = {'companyId': _cid};
      final results = await Future.wait([
        ComplaintSubscriber.load(_api),
        _api.get('/support/complaint-subjects', query: q),
        _api.get('/network/areas', query: q),
      ]);
      roster = results[0] as List<ComplaintSubscriber>;
      subjects = kitMaps(results[1] as Map<String, dynamic>);
      areas = kitMaps(results[2] as Map<String, dynamic>);
    } catch (e) {
      if (mounted) kitReportError(context, e);
      return;
    }
    if (!mounted) return;

    const departments = [
      'Technical',
      'CRO Support',
      'Technician',
      'Subscriber Support Desk',
      'Subscriber Care Support',
      'Finance',
    ];
    final description = TextEditingController();
    ComplaintSubscriber? selected;
    var sublocality = '';
    var type = '';
    var subject = '';
    var department = '';
    var priority = '';
    var deadline = '';
    String? assignee;

    final subscriberOptions = [
      for (final s in roster)
        TxPickOption(
          id: s.id,
          name: '${s.internetId} — ${s.name}',
          secondary: s.phone,
        ),
    ];
    final areaItems = <String, String>{
      '': 'Select sublocality',
      for (final a in areas)
        kitStr(a['id']): [
          kitStr(a['city']),
          kitStr(a['zone']),
          kitStr(a['locality']),
        ].where((p) => p.isNotEmpty).join(' - ') +
            (kitStr(a['subLocality']).isEmpty
                ? ''
                : ' / ${kitStr(a['subLocality'])}'),
    };

    await showKitForm(
      context,
      title: 'New Complaint',
      icon: Icons.confirmation_number_outlined,
      submitLabel: 'Save Complaint',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TxSearchableSelect(
            label: 'Internet ID / Subscriber',
            placeholder: 'Search by subscriber ID, name or phone...',
            searchPlaceholder: 'Search subscribers...',
            options: subscriberOptions,
            value: selected?.id,
            onChanged: (id) => setSheet(() {
              for (final s in roster) {
                if (s.id == id) selected = s;
              }
              sublocality = selected?.sublocalityId ?? '';
              if (!areaItems.containsKey(sublocality)) sublocality = '';
            }),
          ),
          kitGap,
          KitRow(
            children: [
              KitReadOnly(label: 'Name', value: selected?.name ?? ''),
              KitReadOnly(label: 'Phone', value: selected?.phone ?? ''),
            ],
          ),
          kitGap,
          KitReadOnly(label: 'Address', value: selected?.address ?? ''),
          kitGap,
          KitSelect(
            label: 'Sublocality',
            value: sublocality,
            items: areaItems,
            onChanged: (v) => setSheet(() => sublocality = v),
          ),
          kitGap,
          KitRow(
            children: [
              KitSelect(
                label: 'Type',
                value: type,
                items: const {
                  '': 'Select type',
                  'internet': 'Internet',
                  'cable': 'Cable',
                  'both': 'Both',
                },
                onChanged: (v) => setSheet(() => type = v),
              ),
              KitSelect(
                label: 'Subject',
                value: subject,
                items: {
                  '': subjects.isEmpty
                      ? 'No subjects available'
                      : 'Select subject',
                  for (final s in subjects)
                    kitStr(s['subject']): kitStr(s['subject']),
                },
                onChanged: (v) => setSheet(() => subject = v),
              ),
            ],
          ),
          kitGap,
          KitRow(
            children: [
              KitSelect(
                label: 'Department',
                value: department,
                items: {
                  '': 'Select department',
                  for (final d in departments)
                    d.toLowerCase().replaceAll(RegExp(r'\s+'), '-'): d,
                },
                onChanged: (v) => setSheet(() => department = v),
              ),
              KitSelect(
                label: 'Priority',
                value: priority,
                items: const {
                  '': 'Select priority',
                  'low': 'Low',
                  'medium': 'Medium',
                  'high': 'High',
                },
                onChanged: (v) => setSheet(() => priority = v),
              ),
            ],
          ),
          kitGap,
          NetField(
            label: 'Deadline Date',
            child: TxDateField(
              label: 'Select date',
              value: deadline,
              width: double.infinity,
              onChanged: (v) => setSheet(() => deadline = v),
            ),
          ),
          kitGap,
          TxSearchableSelect(
            label: 'Assign To',
            placeholder: 'Search staff or recovery officer...',
            searchPlaceholder: 'Search...',
            options: _lookups.assignees,
            value: assignee,
            onChanged: (v) => setSheet(() => assignee = v),
          ),
          kitGap,
          KitTextField(
            label: 'Complaint',
            controller: description,
            hint: 'Describe the issue...',
            maxLines: 4,
          ),
        ],
      ),
      onSubmit: () async {
        final sub = selected;
        if (sub == null) {
          showToast(context, 'Select a subscriber.', error: true);
          return false;
        }
        if (description.text.trim().isEmpty) {
          showToast(context, 'Describe the complaint.', error: true);
          return false;
        }
        // Mirrors `handleAddComplaint`: blank optional fields are omitted.
        final body = <String, dynamic>{
          'subscriberId': sub.id,
          'subscriberName': sub.name,
          'phone': sub.phone,
          'address': sub.address,
          if (type.isNotEmpty) 'type': type,
          if (subject.isNotEmpty) 'subject': subject,
          if (department.isNotEmpty) 'department': department,
          if (priority.isNotEmpty) 'priority': priority,
          if (deadline.isNotEmpty) 'deadline': deadline,
          'category': 'service',
          'description': description.text.trim(),
          'status': 'open',
          if (assignee != null && assignee!.isNotEmpty)
            'assignedToId': assignee,
        };
        try {
          final res = await _api.post('/support/complaints', body: body);
          if (mounted) {
            showToast(
              context,
              res[OfflineApi.queuedFlag] == true
                  ? 'Saved offline — the complaint will sync when online.'
                  : 'Complaint created successfully.',
            );
          }
          await _load();
          return true;
        } catch (e) {
          if (mounted) {
            kitReportError(context, e, fallback: 'Failed to create complaint');
          }
          return false;
        }
      },
    );
  }

  // ---- Report export / print ---------------------------------------------

  List<List<String>> _reportRows(List<Complaint> rows) => [
    ['#', 'Subscriber', 'Description', 'Category', 'Status', 'Operator', 'Opened At'],
    for (var i = 0; i < rows.length; i++)
      [
        '${i + 1}',
        rows[i].subscriberName,
        rows[i].description,
        rows[i].category,
        kComplaintStatusItems[rows[i].status] ?? rows[i].status,
        _lookups.nameOf(rows[i].assignedToId),
        kitDate(rows[i].createdAt),
      ],
  ];

  Future<void> _exportCsv(List<Complaint> rows) async {
    final ok = await salesWriteCsv(
      context,
      'complaint-report-${kitToday()}.csv',
      _reportRows(rows),
    );
    if (ok && mounted) showToast(context, 'Report exported');
  }

  Future<void> _print(List<Complaint> rows) async {
    final table = _reportRows(rows);
    final head = table.first
        .map((h) => '<th>${salesEscapeHtml(h)}</th>')
        .join();
    final body = table
        .skip(1)
        .map(
          (r) => '<tr>${r.map((c) => '<td>${salesEscapeHtml(c)}</td>').join()}</tr>',
        )
        .join();
    final html =
        '''<!doctype html><html><head><meta charset="utf-8"><title>Complaint Report</title>
<style>body{font-family:sans-serif;padding:24px;color:#111827}h1{font-size:22px}
table{width:100%;border-collapse:collapse;font-size:12px}th{background:#059669;color:#fff;text-align:left;padding:8px}
td{border:1px solid #e5e7eb;padding:8px}</style></head><body>
<h1>Complaint Report</h1><p>${salesEscapeHtml(Session.companyName ?? '')} — ${kitToday()}
 · Category: ${salesEscapeHtml(_category)} · Status: ${salesEscapeHtml(_status)} · Total: ${rows.length}</p>
<table><thead><tr>$head</tr></thead><tbody>$body</tbody></table></body></html>''';
    await salesOpenHtml(context, 'complaint-report.html', html);
  }

  // ---- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scoped = _scoped;
    final filtered = _filtered;
    final page = kitPage(filtered, _page, _pageSize);
    int count(bool Function(Complaint) test) => scoped.where(test).length;

    final (title, subtitle, icon) = switch (_mode) {
      _ComplaintMode.subscriber => (
        'Subscriber Complaint',
        'Manage and track subscriber complaints',
        Icons.confirmation_number_outlined,
      ),
      _ComplaintMode.allocated => (
        'Allocated Complaints',
        'Complaints assigned to operators',
        Icons.assignment_ind_outlined,
      ),
      _ComplaintMode.report => (
        'Complaint Report',
        'Generate and print complaint history',
        Icons.description_outlined,
      ),
    };

    final stats = _mode == _ComplaintMode.report
        ? [
            kitStat('Total Complaints', scoped.length, Icons.bar_chart, kitBlue),
            kitStat('Open', count((c) => c.status == 'open'),
                Icons.error_outline, kitAmber),
            kitStat('In Progress', count((c) => c.status == 'in-progress'),
                Icons.schedule, kitViolet),
            kitStat(
              'Resolved',
              count((c) => const ['resolved', 'done', 'closed'].contains(c.status)),
              Icons.check_circle_outline,
              kitEmerald,
            ),
          ]
        : [
            kitStat('Total Complaints', scoped.length, Icons.list_alt, kitBlue),
            kitStat('Open', count((c) => c.status == 'open'),
                Icons.radio_button_checked, kitEmerald),
            kitStat('Done', count((c) => c.status == 'done'),
                Icons.check_circle_outline, kitBlue),
            kitStat('On Hold', count((c) => c.status == 'on-hold'),
                Icons.schedule, kitAmber),
            kitStat('Rejected', count((c) => c.status == 'reject'),
                Icons.error_outline, kitRose),
            kitStat('Closed', count((c) => c.status == 'closed'),
                Icons.task_alt, kitSlate),
          ];

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          NetworkPageHeader(
            icon: icon,
            title: title,
            subtitle: subtitle,
            gradient: kitEmerald,
          ),
          if (_cid.isEmpty)
            const KitNoCompany(what: 'complaints')
          else if (_loading)
            const KitLoading()
          else if (_error != null && _complaints.isEmpty)
            KitErrorCard(message: _error!, onRetry: _load)
          else ...[
            NetworkStatGrid(maxColumns: 3, children: stats),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _toolbar(filtered),
                  const SizedBox(height: 16),
                  if (_mode == _ComplaintMode.report && !_showReport)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Choose the filters and tap "View Report".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.mutedFg),
                      ),
                    )
                  else ...[
                    _table(page),
                    if (filtered.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      NetworkPagination(
                        currentPage: _page,
                        pageSize: _pageSize,
                        totalItems: filtered.length,
                        noun: 'complaints',
                        onPageChanged: (p) => setState(() => _page = p),
                        onPageSizeChanged: (s) => setState(() {
                          _pageSize = s;
                          _page = 1;
                        }),
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

  Widget _toolbar(List<Complaint> filtered) {
    final filters = <Widget>[
      if (_mode != _ComplaintMode.report)
        txSearchField(
          context: context,
          controller: _search,
          hint: 'Search by subscriber or description...',
          onChanged: (v) => setState(() {
            _filter = v;
            _page = 1;
          }),
        ),
      if (_mode != _ComplaintMode.subscriber) ...[
        TxSelect(
          value: _category,
          items: const {
            'All': 'All Categories',
            'network': 'Network',
            'billing': 'Billing',
            'service': 'Service',
          },
          onChanged: (v) => setState(() {
            _category = v;
            _page = 1;
          }),
        ),
        TxSelect(
          value: _status,
          items: _mode == _ComplaintMode.report
              ? const {
                  'All': 'All Status',
                  'open': 'Open',
                  'in-progress': 'In Progress',
                  'resolved': 'Resolved',
                  'done': 'Done',
                  'closed': 'Closed',
                }
              : {'All': 'All Status', ...kComplaintStatusItems},
          onChanged: (v) => setState(() {
            _status = v;
            _page = 1;
          }),
        ),
      ],
    ];
    final actions = <Widget>[
      if (_canCreate)
        GradientButton(
          label: 'New Complaint',
          icon: Icons.add_circle_outline,
          gradient: kitEmerald,
          onPressed: _openCreate,
        ),
      if (_mode == _ComplaintMode.report) ...[
        GradientButton(
          label: 'View Report',
          icon: Icons.visibility_outlined,
          gradient: kitEmerald,
          onPressed: () => setState(() {
            _showReport = true;
            _page = 1;
          }),
        ),
        if (_showReport && filtered.isNotEmpty) ...[
          OutlinedButton.icon(
            onPressed: () => _print(filtered),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Print'),
          ),
          OutlinedButton.icon(
            onPressed: () => _exportCsv(filtered),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Export CSV'),
          ),
        ],
      ],
    ];
    return InvFilterBar(filterWidth: 240, filters: filters, actions: actions);
  }

  Widget _rowMenu(Complaint c) {
    if (_mode == _ComplaintMode.report) return const SizedBox.shrink();
    return KitRowMenu(
      actions: [
        if (_mode == _ComplaintMode.subscriber) ...[
          KitAction(
            'Status',
            Icons.radio_button_checked,
            () => _after(showComplaintStatusDialog(context, _api, c)),
          ),
          KitAction(
            'Allocate',
            Icons.person_add_alt_1_outlined,
            () => _after(showComplaintAllocateDialog(context, _api, c, _lookups)),
          ),
        ],
        KitAction(
          'Edit',
          Icons.edit_outlined,
          _canUpdate
              ? () => _after(showComplaintEditDialog(context, _api, c, _lookups))
              : null,
        ),
        KitAction(
          'Delete',
          Icons.delete_outline,
          _canDelete ? () => _delete(c) : null,
          danger: true,
        ),
      ],
    );
  }

  Widget _table(List<Complaint> rows) {
    final showOperator = _mode != _ComplaintMode.subscriber;
    return NetworkTable<Complaint>(
      rows: rows,
      emptyIcon: Icons.confirmation_number_outlined,
      emptyTitle: _mode == _ComplaintMode.report
          ? 'No complaint history found.'
          : 'No complaints found.',
      emptyHint: '',
      emptyTint: AppColors.emerald600,
      mobileTrailing: (context, c, _) => _rowMenu(c),
      columns: [
        NetColumn(
          label: 'Ticket ID',
          width: 70,
          builder: (context, c, i) => Text(
            '${(_page - 1) * _pageSize + i + 1}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: context.mutedFg,
            ),
          ),
        ),
        NetColumn(
          label: 'Subscriber',
          width: 170,
          builder: (context, c, _) => Text(
            c.subscriberName,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        NetColumn(
          label: 'Description',
          width: 240,
          builder: (context, c, _) => Text(
            c.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        NetColumn(
          label: 'Category',
          width: 110,
          builder: (context, c, _) => Align(
            alignment: Alignment.centerLeft,
            child: ComplaintCategoryPill(category: c.category),
          ),
        ),
        NetColumn(
          label: 'Status',
          width: 110,
          builder: (context, c, _) => Align(
            alignment: Alignment.centerLeft,
            child: ComplaintStatusPill(status: c.status),
          ),
        ),
        if (showOperator)
          NetColumn(
            label: 'Operator',
            width: 150,
            builder: (context, c, _) => Text(_lookups.nameOf(c.assignedToId)),
          ),
        NetColumn(
          label: 'Opened At',
          width: 110,
          builder: (context, c, _) => Text(
            kitDate(c.createdAt),
            style: TextStyle(fontSize: 13, color: context.mutedFg),
          ),
        ),
        if (_mode != _ComplaintMode.report)
          NetColumn(
            label: 'Action',
            width: 70,
            isActions: true,
            builder: (context, c, _) => _rowMenu(c),
          ),
      ],
    );
  }
}
