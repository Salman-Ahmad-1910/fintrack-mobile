import 'package:flutter/material.dart';

import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../shared/crud_kit.dart';
import '../transaction/transaction_common.dart';

/// Shared pieces of the Complaints section — Flutter counterpart of
/// `support/complaints/_components/complaint-status.tsx` plus the lookups the
/// complaint pages load (`hr/staff`, `admin/recovery-officers`, ...).

// Permission ids (`permission-pages.ts`).
const String kComplaintSubjectPermission = '15323';
const String kComplaintTypePermission = '15325';
const String kComplaintsUserPermission = '13342';
const String kComplaintsAllocatedPermission = '13343';

class ComplaintStatusDef {
  const ComplaintStatusDef(this.value, this.label, this.bg, this.fg);
  final String value;
  final String label;
  final Color bg;
  final Color fg;
}

/// `COMPLAINT_STATUSES` / `STATUS_COLORS`.
const List<ComplaintStatusDef> kComplaintStatuses = [
  ComplaintStatusDef('open', 'Open', Color(0xFFDCFCE7), Color(0xFF166534)),
  ComplaintStatusDef('done', 'Done', Color(0xFFDBEAFE), Color(0xFF1E40AF)),
  ComplaintStatusDef('on-hold', 'On Hold', Color(0xFFFEF9C3), Color(0xFF854D0E)),
  ComplaintStatusDef('reject', 'Reject', Color(0xFFFEE2E2), Color(0xFF991B1B)),
  ComplaintStatusDef('closed', 'Closed', Color(0xFFE5E7EB), Color(0xFF1F2937)),
];

Map<String, String> get kComplaintStatusItems => {
  for (final s in kComplaintStatuses) s.value: s.label,
};

class ComplaintStatusPill extends StatelessWidget {
  const ComplaintStatusPill({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    ComplaintStatusDef? def;
    for (final s in kComplaintStatuses) {
      if (s.value == status) def = s;
    }
    return KitPill(
      label: def?.label ?? kitTitle(status),
      background: def?.bg ?? const Color(0xFFF3F4F6),
      foreground: def?.fg ?? const Color(0xFF1F2937),
    );
  }
}

class ComplaintCategoryPill extends StatelessWidget {
  const ComplaintCategoryPill({super.key, required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (category) {
      'network' => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      'billing' => (const Color(0xFFFFEDD5), const Color(0xFF9A3412)),
      _ => (const Color(0xFFF3E8FF), const Color(0xFF6B21A8)),
    };
    return KitPill(label: kitTitle(category), background: bg, foreground: fg);
  }
}

/// One complaint row. [raw] keeps every server field so updates can send the
/// complete record — the generic Go `PUT` uses GORM `Save()`, which would
/// blank any column missing from the body (the web spreads `...complaint`).
class Complaint {
  Complaint(this.raw);

  final Map<String, dynamic> raw;

  String get id => kitStr(raw['id']);
  String get subscriberId => kitStr(raw['subscriberId']);
  String get subscriberName => kitStr(raw['subscriberName']);
  String get phone => kitStr(raw['phone']);
  String get address => kitStr(raw['address']);
  String get type => kitStr(raw['type']);
  String get subject => kitStr(raw['subject']);
  String get department => kitStr(raw['department']);
  String get priority => kitStr(raw['priority']);
  String get deadline => kitStr(raw['deadline']);
  String get category => kitStr(raw['category']);
  String get description => kitStr(raw['description']);
  String get status => kitStr(raw['status']);
  String get assignedToId => kitStr(raw['assignedToId']);
  String get createdAt => kitStr(raw['createdAt']);

  /// Full body for `PUT /support/complaints/:id` with [changes] applied.
  Map<String, dynamic> withChanges(Map<String, dynamic> changes) => {
    ...raw,
    ...changes,
  };
}

/// Staff + recovery officers merged into one assignee list (web
/// `assigneeOptions`).
class ComplaintLookups {
  ComplaintLookups({required this.assignees});

  final List<TxPickOption> assignees;

  /// Staff ids + recovery officer ids — used to decide whether the signed-in
  /// user is a "member" on the Allocated Complaints page.
  Set<String> get memberIds => assignees.map((a) => a.id).toSet();

  String nameOf(String id) {
    if (id.isEmpty) return '---';
    for (final a in assignees) {
      if (a.id == id) return a.name;
    }
    return 'Unknown';
  }

  static Future<ComplaintLookups> load(OfflineApi api) async {
    final cid = Session.companyId ?? '';
    final q = {'companyId': cid};
    final results = await Future.wait([
      api.get('/hr/staff', query: q).catchError((_) => <String, dynamic>{}),
      api
          .get('/admin/recovery-officers', query: q)
          .catchError((_) => <String, dynamic>{}),
    ]);
    final options = <TxPickOption>[
      for (final s in kitMaps(results[0]))
        TxPickOption(
          id: kitStr(s['id']),
          name: kitStr(s['name']),
          secondary: '${kitStr(s['designation'])} (Staff)',
        ),
      for (final r in kitMaps(results[1]))
        TxPickOption(
          id: kitStr(r['id']),
          name: kitStr(r['name']),
          secondary: 'Recovery Officer',
        ),
    ];
    return ComplaintLookups(assignees: options);
  }
}

/// Subscriber picker entry: connections first, then any `/subscribers`
/// record that has no connection row (web `subscriberRoster`).
class ComplaintSubscriber {
  const ComplaintSubscriber({
    required this.id,
    required this.internetId,
    required this.name,
    required this.address,
    required this.phone,
    required this.sublocalityId,
    required this.status,
  });

  final String id;
  final String internetId;
  final String name;
  final String address;
  final String phone;
  final String sublocalityId;
  final String status;

  static Future<List<ComplaintSubscriber>> load(OfflineApi api) async {
    final q = {'companyId': Session.companyId ?? ''};
    final results = await Future.wait([
      api.get('/admin/connections', query: q),
      api.get('/subscribers', query: q).catchError((_) => <String, dynamic>{}),
    ]);
    final byId = <String, ComplaintSubscriber>{};
    for (final c in kitMaps(results[0])) {
      final id = kitStr(c['id']);
      final cell = kitStr(c['cell']);
      byId[id] = ComplaintSubscriber(
        id: id,
        internetId: kitStr(c['internetId']),
        name: kitStr(c['name']),
        address: kitStr(c['address']),
        phone: cell.isNotEmpty ? cell : kitStr(c['mobile']),
        sublocalityId: kitStr(c['sublocalityId']),
        status: kitStr(c['status']),
      );
    }
    for (final s in kitMaps(results[1])) {
      final id = kitStr(s['id']);
      if (byId.containsKey(id)) continue;
      final identity = kitStr(s['subscriber_identity']);
      byId[id] = ComplaintSubscriber(
        id: id,
        internetId: identity.isNotEmpty ? identity : id,
        name: kitStr(s['name']),
        address: kitStr(s['installationAddress']),
        phone: kitStr(s['phone']),
        sublocalityId: kitStr(s['areaId']),
        status: kitStr(s['status']),
      );
    }
    return byId.values.toList();
  }
}

// ---------------------------------------------------------------------------
// Dialogs shared by Subscriber Complaint and Allocated Complaints
// ---------------------------------------------------------------------------

Future<bool> _putComplaint(
  BuildContext context,
  OfflineApi api,
  Complaint complaint,
  Map<String, dynamic> changes,
  String success,
) async {
  try {
    await api.put(
      '/support/complaints/${complaint.id}',
      body: complaint.withChanges(changes),
    );
    if (context.mounted) showToast(context, success);
    return true;
  } catch (e) {
    if (context.mounted) kitReportError(context, e, fallback: 'Update failed');
    return false;
  }
}

/// `ComplaintStatusDialog`.
Future<bool> showComplaintStatusDialog(
  BuildContext context,
  OfflineApi api,
  Complaint complaint,
) async {
  var status = complaint.status.isEmpty ? 'open' : complaint.status;
  var saved = false;
  await showKitForm(
    context,
    title: 'Update Complaint Status',
    icon: Icons.radio_button_checked,
    submitLabel: 'Update Status',
    builder: (ctx, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitReadOnly(label: 'Subscriber', value: complaint.subscriberName),
        kitGap,
        KitSelect(
          label: 'Status',
          value: status,
          items: kComplaintStatusItems,
          onChanged: (v) => setState(() => status = v),
        ),
      ],
    ),
    onSubmit: () async {
      final label = kComplaintStatusItems[status] ?? status;
      saved = await _putComplaint(
        context,
        api,
        complaint,
        {
          'status': status,
          'assignedToId': complaint.assignedToId.isEmpty
              ? null
              : complaint.assignedToId,
        },
        'Complaint status updated to $label.',
      );
      return saved;
    },
  );
  return saved;
}

/// "Allocate" dialog (assign an assignee).
Future<bool> showComplaintAllocateDialog(
  BuildContext context,
  OfflineApi api,
  Complaint complaint,
  ComplaintLookups lookups,
) async {
  String? assignee = complaint.assignedToId.isEmpty
      ? null
      : complaint.assignedToId;
  var saved = false;
  await showKitForm(
    context,
    title: 'Allocate Complaint',
    icon: Icons.person_add_alt_1_outlined,
    submitLabel: 'Allocate',
    gradient: kitViolet,
    builder: (ctx, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitReadOnly(
          label: 'Complaint',
          value: '${complaint.subscriberName} - ${complaint.description}',
        ),
        kitGap,
        TxSearchableSelect(
          label: 'Assign To',
          placeholder: 'Search staff or recovery officer...',
          searchPlaceholder: 'Search...',
          options: lookups.assignees,
          value: assignee,
          onChanged: (v) => setState(() => assignee = v),
        ),
      ],
    ),
    onSubmit: () async {
      if (assignee == null || assignee!.isEmpty) {
        showToast(context, 'Select an assignee to allocate.', error: true);
        return false;
      }
      saved = await _putComplaint(
        context,
        api,
        complaint,
        {'assignedToId': assignee},
        'Complaint allocated successfully.',
      );
      return saved;
    },
  );
  return saved;
}

/// Edit dialog (description, status, assignee).
Future<bool> showComplaintEditDialog(
  BuildContext context,
  OfflineApi api,
  Complaint complaint,
  ComplaintLookups lookups,
) async {
  final description = TextEditingController(text: complaint.description);
  var status = complaint.status.isEmpty ? 'open' : complaint.status;
  String? assignee = complaint.assignedToId.isEmpty
      ? null
      : complaint.assignedToId;
  var saved = false;
  await showKitForm(
    context,
    title: 'Edit Complaint',
    builder: (ctx, setState) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitReadOnly(label: 'Subscriber', value: complaint.subscriberName),
        kitGap,
        KitSelect(
          label: 'Status',
          value: status,
          items: kComplaintStatusItems,
          onChanged: (v) => setState(() => status = v),
        ),
        kitGap,
        KitTextField(
          label: 'Description',
          controller: description,
          maxLines: 3,
        ),
        kitGap,
        TxSearchableSelect(
          label: 'Assign To',
          placeholder: 'Search staff or recovery officer...',
          searchPlaceholder: 'Search...',
          options: lookups.assignees,
          value: assignee,
          onChanged: (v) => setState(() => assignee = v),
        ),
        if (assignee != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => assignee = null),
              child: const Text('Clear assignment'),
            ),
          ),
        ],
      ],
    ),
    onSubmit: () async {
      saved = await _putComplaint(
        context,
        api,
        complaint,
        {
          'description': description.text,
          'status': status,
          'assignedToId': (assignee == null || assignee!.isEmpty)
              ? null
              : assignee,
        },
        'Complaint updated.',
      );
      return saved;
    },
  );
  return saved;
}

/// Hint text shown when a page loads without a selected company.
Widget complaintEmptyHint(BuildContext context) => Text(
  'Please select a company to view complaints.',
  style: TextStyle(color: context.mutedFg),
);
