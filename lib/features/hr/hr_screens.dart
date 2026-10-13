import 'dart:math' as math;

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

// Permission ids (`permission-pages.ts`).
const String kStaffPermission = '15316';
const String kStaffSalaryPermission = '15318';
const String kStaffAttendancePermission = '15322';
const String kAdvanceLoanPermission = '15317';

const List<String> kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

/// Staff record as returned by `GET /hr/staff` (raw map kept so an update
/// re-sends qualifications, experiences, work times and attachments that
/// the mobile form does not edit).
class StaffMember {
  StaffMember(this.raw);
  final Map<String, dynamic> raw;

  String get id => kitStr(raw['id']);
  String get name => kitStr(raw['name']);
  String get email => kitStr(raw['email']);
  String get phone => kitStr(raw['phone']);
  String get designation => kitStr(raw['designation']);
  String get department => kitStr(raw['department']);
  String get status => kitStr(raw['status']).isEmpty ? 'working' : kitStr(raw['status']);
  String get address => kitStr(raw['address']);
  String get appointedDate => kitStr(raw['appointedDate']);
  String get paymentMode => kitStr(raw['paymentMode']);
  double get salary => kitNum(raw['salary']);

  /// Web: `staff.basicPay ?? salary`.
  double get basicPay =>
      raw['basicPay'] == null ? salary : kitNum(raw['basicPay']);
  double get leaveAllow => kitNum(raw['leaveAllow']);
}

Future<List<StaffMember>> loadStaff(OfflineApi api) async {
  final json = await api.get(
    '/hr/staff',
    query: {'companyId': Session.companyId ?? ''},
  );
  return kitMaps(json).map(StaffMember.new).toList();
}

String _pkr(num v) => 'PKR ${kitMoney(v)}';

// ===========================================================================
// Staff (hr/staff)
// ===========================================================================

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: kitHandleUnauthorized);
  final TextEditingController _search = TextEditingController();
  List<StaffMember> _staff = [];
  List<String> _departments = [];
  bool _loading = true;
  String? _error;
  String _filter = '';
  int _page = 1;
  int _pageSize = 10;

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
    try {
      final staff = await loadStaff(_api);
      var depts = <String>[];
      try {
        depts = kitMaps(
          await _api.get('/hr/departments', query: {'companyId': _cid}),
        ).map((d) => kitStr(d['name'])).where((n) => n.isNotEmpty).toList();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _departments = depts;
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

  List<StaffMember> get _filtered => _staff
      .where(
        (s) => kitMatch(_filter, [
          s.name,
          s.phone,
          s.email,
          s.designation,
          s.department,
        ]),
      )
      .toList();

  Future<void> _delete(StaffMember s) async {
    await showNetworkDeleteDialog(
      context,
      itemName: s.name,
      onConfirm: () async {
        try {
          await _api.delete('/hr/staff/${s.id}');
          if (mounted) showToast(context, 'Staff member deleted successfully.');
          await _load();
        } catch (e) {
          if (mounted) kitReportError(context, e);
        }
      },
    );
  }

  Future<String?> _addDepartment() async {
    final name = TextEditingController();
    String? created;
    await showKitForm(
      context,
      title: 'Add Department',
      submitLabel: 'Add',
      builder: (ctx, _) => KitTextField(label: 'Department Name', controller: name),
      onSubmit: () async {
        final value = name.text.trim();
        if (value.isEmpty) return false;
        try {
          await _api.post(
            '/hr/departments',
            body: {'name': value, 'companyId': _cid},
          );
          created = value;
          if (mounted) showToast(context, 'Department added successfully.');
          return true;
        } catch (e) {
          if (mounted) kitReportError(context, e);
          return false;
        }
      },
    );
    if (created != null && !_departments.contains(created)) {
      setState(() => _departments = [..._departments, created!]);
    }
    return created;
  }

  Future<void> _openForm(StaffMember? existing) async {
    final raw = existing?.raw ?? const <String, dynamic>{};
    TextEditingController ctl(String key) =>
        TextEditingController(text: kitStr(raw[key]));
    final name = ctl('name');
    final email = ctl('email');
    final phone = ctl('phone');
    final fatherName = ctl('fatherName');
    final nic = ctl('nic');
    final address = ctl('address');
    final designation = ctl('designation');
    final basicPay = TextEditingController(
      text: existing == null ? '' : existing.basicPay.toStringAsFixed(0),
    );
    final leaveAllow = TextEditingController(
      text: existing == null ? '' : existing.leaveAllow.toStringAsFixed(0),
    );
    final bankName = ctl('bankName');
    final accountTitle = ctl('accountTitle');
    final accountNo = ctl('accountNo');
    final password = TextEditingController();
    var gender = kitStr(raw['gender']);
    var marital = kitStr(raw['maritalStatus']);
    var department = kitStr(raw['department']).isEmpty
        ? 'technical'
        : kitStr(raw['department']);
    var paymentMode = kitStr(raw['paymentMode']).isEmpty
        ? 'cash'
        : kitStr(raw['paymentMode']);
    var status = existing?.status ?? 'working';
    var appointed = kitStr(raw['appointedDate']);
    var leaveDate = kitStr(raw['leaveDate']);
    var technical = kitStr(raw['technical']).isEmpty
        ? 'no'
        : kitStr(raw['technical']);
    var generatePassword = existing == null;

    Map<String, String> deptItems() => {
      for (final d in {department, ..._departments})
        if (d.isNotEmpty) d: kitTitle(d),
    };

    await showKitForm(
      context,
      title: existing == null ? 'Add Staff Member' : 'Edit Staff Member',
      icon: Icons.badge_outlined,
      submitLabel: existing == null ? 'Add Staff' : 'Update Staff',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('Personal Information'),
          KitTextField(label: 'Name *', controller: name),
          kitGap,
          KitRow(
            children: [
              KitTextField(
                label: 'Email *',
                controller: email,
                keyboardType: TextInputType.emailAddress,
              ),
              KitTextField(
                label: 'Phone *',
                controller: phone,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          kitGap,
          KitRow(
            children: [
              KitSelect(
                label: 'Gender',
                value: gender,
                items: const {'': 'Select', 'male': 'Male', 'female': 'Female'},
                onChanged: (v) => setSheet(() => gender = v),
              ),
              KitSelect(
                label: 'Marital Status',
                value: marital,
                items: const {
                  '': 'Select',
                  'single': 'Single',
                  'married': 'Married',
                },
                onChanged: (v) => setSheet(() => marital = v),
              ),
            ],
          ),
          kitGap,
          KitRow(
            children: [
              KitTextField(label: "Father's Name", controller: fatherName),
              KitTextField(label: 'CNIC', controller: nic),
            ],
          ),
          kitGap,
          KitTextField(label: 'Address', controller: address, maxLines: 2),
          const _SectionTitle('Accounts'),
          KitRow(
            children: [
              KitTextField(
                label: 'Basic Pay *',
                controller: basicPay,
                keyboardType: TextInputType.number,
              ),
              KitTextField(
                label: 'Leave Allowance',
                controller: leaveAllow,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          kitGap,
          KitSelect(
            label: 'Payment Mode',
            value: paymentMode,
            items: const {'cash': 'Cash', 'bank': 'Bank'},
            onChanged: (v) => setSheet(() => paymentMode = v),
          ),
          if (paymentMode == 'bank') ...[
            kitGap,
            KitTextField(label: 'Bank Name *', controller: bankName),
            kitGap,
            KitRow(
              children: [
                KitTextField(label: 'Account Title', controller: accountTitle),
                KitTextField(label: 'Account No', controller: accountNo),
              ],
            ),
          ],
          const _SectionTitle('Other'),
          KitRow(
            children: [
              KitSelect(
                label: 'Department',
                value: department,
                items: deptItems(),
                onChanged: (v) => setSheet(() => department = v),
              ),
              KitTextField(label: 'Designation *', controller: designation),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final added = await _addDepartment();
                if (added != null) setSheet(() => department = added);
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add department'),
            ),
          ),
          KitRow(
            children: [
              NetField(
                label: 'Appointed Date',
                child: TxDateField(
                  label: 'Select date',
                  value: appointed,
                  width: double.infinity,
                  onChanged: (v) => setSheet(() => appointed = v),
                ),
              ),
              KitSelect(
                label: 'Technical',
                value: technical,
                items: const {'no': 'No', 'yes': 'Yes'},
                onChanged: (v) => setSheet(() => technical = v),
              ),
            ],
          ),
          kitGap,
          KitRow(
            children: [
              KitSelect(
                label: 'Status',
                value: status,
                items: const {'working': 'Working', 'left': 'Left'},
                onChanged: (v) => setSheet(() => status = v),
              ),
              if (status == 'left')
                NetField(
                  label: 'Leave Date *',
                  child: TxDateField(
                    label: 'Select date',
                    value: leaveDate,
                    width: double.infinity,
                    onChanged: (v) => setSheet(() => leaveDate = v),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
          kitGap,
          KitSelect(
            label: existing == null ? 'Generate Password' : 'Password',
            value: generatePassword ? 'yes' : 'no',
            items: existing == null
                ? const {'yes': 'Generate automatically', 'no': 'Set manually'}
                : const {'yes': 'Keep current password', 'no': 'Set a new password'},
            onChanged: (v) => setSheet(() => generatePassword = v == 'yes'),
          ),
          if (!generatePassword) ...[
            kitGap,
            KitTextField(
              label: 'Password (min 6 characters)',
              controller: password,
              obscure: true,
            ),
          ],
        ],
      ),
      onSubmit: () async {
        // Same rules as the web `validatePersonal / validateAccounts /
        // validateOther`.
        final emailText = email.text.trim();
        String? err;
        if (name.text.trim().isEmpty) {
          err = 'Name is required';
        } else if (phone.text.trim().isEmpty) {
          err = 'Phone is required';
        } else if (emailText.isEmpty) {
          err = 'Email is required';
        } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(emailText)) {
          err = 'Invalid email address';
        } else if (basicPay.text.trim().isEmpty ||
            (double.tryParse(basicPay.text.trim()) ?? -1) < 0) {
          err = 'Basic pay is required';
        } else if (paymentMode == 'bank' && bankName.text.trim().isEmpty) {
          err = 'Select a bank';
        } else if (designation.text.trim().isEmpty) {
          err = 'Designation is required';
        } else if (status == 'left' && leaveDate.isEmpty) {
          err = 'Leave date is required';
        } else if (!generatePassword && password.text.length < 6) {
          err = 'Password must be at least 6 characters';
        }
        if (err != null) {
          showToast(context, err, error: true);
          return false;
        }

        String pass;
        if (!generatePassword) {
          pass = password.text;
        } else if (existing != null) {
          pass = kitStr(raw['plainPassword']);
        } else {
          pass = 'Staff@${1000 + math.Random.secure().nextInt(9000)}';
        }
        final pay = double.tryParse(basicPay.text.trim()) ?? 0;
        final body = <String, dynamic>{
          // Keep everything the mobile form does not edit (qualifications,
          // experiences, work times, attachments, area).
          ...raw,
          'name': name.text.trim(),
          'email': emailText,
          'phone': phone.text.trim(),
          if (pass.isNotEmpty) 'password': pass,
          if (pass.isNotEmpty) 'plainPassword': pass,
          'secondaryPhone': kitStr(raw['secondaryPhone']),
          'role': 'staff',
          'gender': gender,
          'maritalStatus': marital,
          'fatherName': fatherName.text.trim(),
          'nic': nic.text.trim(),
          'address': address.text.trim(),
          'designation': designation.text.trim(),
          'department': department,
          'salary': pay,
          'basicPay': pay,
          'leaveAllow': double.tryParse(leaveAllow.text.trim()) ?? 0,
          'paymentMode': paymentMode,
          'bankName': paymentMode == 'bank' ? bankName.text.trim() : '',
          'accountTitle': accountTitle.text.trim(),
          'accountNo': accountNo.text.trim(),
          'appointedDate': appointed,
          'technical': technical,
          'status': status,
          'leaveDate': status == 'left' ? leaveDate : '',
          'qualifications': raw['qualifications'] ?? const [],
          'experiences': raw['experiences'] ?? const [],
          'workTimes': raw['workTimes'] ?? const [],
          'areaId': raw['areaId'],
          'companyId': _cid,
        };
        try {
          if (existing == null) {
            await _api.post('/hr/staff', body: body);
          } else {
            await _api.put('/hr/staff/${existing.id}', body: body);
          }
          if (mounted) {
            showToast(
              context,
              existing == null
                  ? 'Staff member added. Login password: $pass'
                  : 'Staff member updated successfully.',
            );
          }
          await _load();
          return true;
        } catch (e) {
          if (mounted) {
            kitReportError(context, e, fallback: 'Failed to save staff member');
          }
          return false;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final working = _staff.where((s) => s.status != 'left').length;
    final totalSalary = _staff.fold<double>(0, (a, s) => a + s.salary);
    final canCreate = invCrud(kStaffPermission, 'create');
    final canUpdate = invCrud(kStaffPermission, 'update');
    final canDelete = invCrud(kStaffPermission, 'delete');
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.badge_outlined,
            title: 'Staff',
            subtitle: 'Manage your staff members and their details.',
            gradient: kitBlue,
          ),
          if (_cid.isEmpty)
            const KitNoCompany(what: 'staff')
          else if (_loading)
            const KitLoading()
          else if (_error != null && _staff.isEmpty)
            KitErrorCard(message: _error!, onRetry: _load)
          else ...[
            NetworkStatGrid(
              children: [
                kitStat('Total Staff', _staff.length, Icons.groups_outlined, kitBlue),
                kitStat('Working', working, Icons.work_outline, kitEmerald),
                kitStat('Total Salary', _pkr(totalSalary), Icons.payments_outlined, kitAmber),
              ],
            ),
            const SizedBox(height: 20),
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
                        hint: 'Search staff...',
                        onChanged: (v) => setState(() {
                          _filter = v;
                          _page = 1;
                        }),
                      ),
                    ],
                    actions: [
                      if (canCreate)
                        GradientButton(
                          label: 'Add Staff',
                          icon: Icons.person_add_alt_1_outlined,
                          gradient: kitEmerald,
                          onPressed: () => _openForm(null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  NetworkTable<StaffMember>(
                    rows: kitPage(filtered, _page, _pageSize),
                    emptyIcon: Icons.badge_outlined,
                    emptyTitle: 'No staff found.',
                    emptyHint: canCreate ? 'Add your first staff member.' : '',
                    emptyTint: AppColors.emerald600,
                    mobileTrailing: (context, s, _) => NetworkRowActions(
                      onEdit: canUpdate ? () => _openForm(s) : null,
                      onDelete: canDelete ? () => _delete(s) : null,
                    ),
                    columns: [
                      NetColumn(
                        label: 'Name',
                        width: 170,
                        builder: (context, s, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (s.designation.isNotEmpty)
                              Text(
                                s.designation,
                                style: TextStyle(fontSize: 12, color: context.mutedFg),
                              ),
                          ],
                        ),
                      ),
                      NetColumn(
                        label: 'Department',
                        width: 120,
                        builder: (context, s, _) => Text(kitTitle(s.department)),
                      ),
                      NetColumn(
                        label: 'Phone',
                        width: 130,
                        builder: (context, s, _) => Text(s.phone),
                      ),
                      NetColumn(
                        label: 'Joining Date',
                        width: 110,
                        builder: (context, s, _) =>
                            Text(s.appointedDate.isEmpty ? '—' : s.appointedDate),
                      ),
                      NetColumn(
                        label: 'Salary (PKR)',
                        width: 120,
                        builder: (context, s, _) => Text(kitMoney(s.salary)),
                      ),
                      NetColumn(
                        label: 'Status',
                        width: 100,
                        builder: (context, s, _) => Align(
                          alignment: Alignment.centerLeft,
                          child: KitPill(
                            label: kitTitle(s.status),
                            background: s.status == 'left'
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDCFCE7),
                            foreground: s.status == 'left'
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF166534),
                          ),
                        ),
                      ),
                      NetColumn(
                        label: '',
                        width: 96,
                        isActions: true,
                        builder: (context, s, _) => Align(
                          alignment: Alignment.centerRight,
                          child: NetworkRowActions(
                            onEdit: canUpdate ? () => _openForm(s) : null,
                            onDelete: canDelete ? () => _delete(s) : null,
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
                      noun: 'staff',
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
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.emerald600,
      ),
    ),
  );
}

// ===========================================================================
// Staff Salary (hr/salary)
// ===========================================================================

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: kitHandleUnauthorized);
  List<StaffMember> _staff = [];
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;
  bool _loadingPayments = false;
  String? _error;
  String _month = kMonths[DateTime.now().month - 1];
  int _year = DateTime.now().year;
  String _department = 'all';
  ({String month, int year, String department})? _applied;

  String get _cid => Session.companyId ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final staff = await loadStaff(_api);
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _loading = false;
        _error = null;
      });
      if (_applied != null) await _loadPayments();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadPayments() async {
    final applied = _applied;
    if (applied == null) return;
    setState(() => _loadingPayments = true);
    try {
      final json = await _api.get(
        '/hr/salary',
        query: {
          'companyId': _cid,
          'month': applied.month,
          'year': '${applied.year}',
        },
      );
      if (!mounted) return;
      setState(() {
        _payments = kitMaps(json);
        _loadingPayments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPayments = false);
      kitReportError(context, e);
    }
  }

  List<StaffMember> get _filteredStaff {
    final applied = _applied;
    if (applied == null) return const [];
    if (applied.department == 'all') return _staff;
    return _staff.where((s) => s.department == applied.department).toList();
  }

  Future<void> _pay(StaffMember s) async {
    final applied = _applied!;
    final other = TextEditingController();
    final deduction = TextEditingController();
    double net() =>
        s.basicPay +
        s.leaveAllow +
        (double.tryParse(other.text) ?? 0) -
        (double.tryParse(deduction.text) ?? 0);
    await showKitForm(
      context,
      title: 'Pay Salary — ${s.name}',
      icon: Icons.payments_outlined,
      submitLabel: 'Pay Salary',
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitRow(
            children: [
              KitReadOnly(label: 'Month', value: '${applied.month} ${applied.year}'),
              KitReadOnly(label: 'Payment Mode', value: kitTitle(s.paymentMode.isEmpty ? 'cash' : s.paymentMode)),
            ],
          ),
          kitGap,
          KitRow(
            children: [
              KitReadOnly(label: 'Basic Pay', value: _pkr(s.basicPay)),
              KitReadOnly(label: 'Leave Allowance', value: _pkr(s.leaveAllow)),
            ],
          ),
          kitGap,
          NetField(
            label: 'Other Allowance',
            child: TextField(
              controller: other,
              keyboardType: TextInputType.number,
              onChanged: (_) => setSheet(() {}),
              decoration: netInputDecoration(ctx, hint: '0'),
            ),
          ),
          kitGap,
          NetField(
            label: 'Deduction',
            child: TextField(
              controller: deduction,
              keyboardType: TextInputType.number,
              onChanged: (_) => setSheet(() {}),
              decoration: netInputDecoration(ctx, hint: '0'),
            ),
          ),
          kitGap,
          KitReadOnly(label: 'Net Pay', value: _pkr(net())),
        ],
      ),
      onSubmit: () async {
        try {
          await _api.post(
            '/hr/salary',
            body: {
              'staffId': s.id,
              'staffName': s.name,
              'month': applied.month,
              'year': applied.year,
              'salary': s.salary,
              'basicPay': s.basicPay,
              'leaveAllow': s.leaveAllow,
              'otherAllowance': double.tryParse(other.text) ?? 0,
              'deduction': double.tryParse(deduction.text) ?? 0,
              'netPay': net(),
              'paymentMode': s.paymentMode.isEmpty ? 'cash' : s.paymentMode,
              'paidAt': kitToday(),
              'companyId': _cid,
            },
          );
          if (mounted) {
            showToast(
              context,
              "${s.name}'s salary for ${applied.month} ${applied.year} has been paid.",
            );
          }
          await _loadPayments();
          return true;
        } catch (e) {
          if (mounted) kitReportError(context, e, fallback: 'Failed to pay salary');
          return false;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = _filteredStaff;
    final paidIds = _payments.map((p) => kitStr(p['staffId'])).toSet();
    final unpaid = staff.where((s) => !paidIds.contains(s.id)).toList();
    double base(StaffMember s) => s.basicPay > 0 ? s.basicPay : s.salary;
    final totalSalary = staff.fold<double>(0, (a, s) => a + base(s));
    final unpaidSalary = unpaid.fold<double>(0, (a, s) => a + base(s));
    final totalDeduction =
        _payments.fold<double>(0, (a, p) => a + kitNum(p['deduction']));
    final otherAllow =
        _payments.fold<double>(0, (a, p) => a + kitNum(p['otherAllowance']));
    final departments = _staff.map((s) => s.department).where((d) => d.isNotEmpty).toSet().toList()..sort();
    final canPay = invCrud(kStaffSalaryPermission, 'create');
    final nowYear = DateTime.now().year;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.payments_outlined,
            title: 'Staff Salary',
            subtitle: 'Pay monthly salaries and track unpaid staff.',
            gradient: kitEmerald,
          ),
          if (_cid.isEmpty)
            const KitNoCompany(what: 'salaries')
          else if (_loading)
            const KitLoading()
          else if (_error != null && _staff.isEmpty)
            KitErrorCard(message: _error!, onRetry: _load)
          else ...[
            NetworkStatGrid(
              children: [
                kitStat('Total Staff', staff.length, Icons.groups_outlined, kitBlue),
                kitStat('Total Salary', _pkr(totalSalary), Icons.attach_money, kitEmerald),
                kitStat('Salary Unpaid', _pkr(unpaidSalary), Icons.error_outline, kitRose),
                kitStat('Total Deduction', _pkr(totalDeduction), Icons.balance, kitAmber),
                kitStat('Other Allowance', _pkr(otherAllow), Icons.card_giftcard, kitViolet),
              ],
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InvFilterBar(
                    filterWidth: 180,
                    filtersPerRow: 3,
                    filters: [
                      TxSelect(
                        value: _month,
                        items: {for (final m in kMonths) m: m},
                        onChanged: (v) => setState(() => _month = v),
                      ),
                      TxSelect(
                        value: '$_year',
                        items: {
                          for (var y = nowYear; y >= 2020; y--) '$y': '$y',
                        },
                        onChanged: (v) => setState(() => _year = int.parse(v)),
                      ),
                      TxSelect(
                        value: _department,
                        items: {
                          'all': 'All Departments',
                          for (final d in departments) d: kitTitle(d),
                        },
                        onChanged: (v) => setState(() => _department = v),
                      ),
                    ],
                    actions: [
                      GradientButton(
                        label: 'Show',
                        icon: Icons.search,
                        gradient: kitEmerald,
                        loading: _loadingPayments,
                        onPressed: () {
                          setState(() => _applied = (
                            month: _month,
                            year: _year,
                            department: _department,
                          ));
                          _loadPayments();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_applied == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Select a month and tap "Show".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.mutedFg),
                      ),
                    )
                  else
                    NetworkTable<StaffMember>(
                      rows: staff,
                      emptyIcon: Icons.groups_outlined,
                      emptyTitle: 'No staff for this selection.',
                      emptyHint: '',
                      emptyTint: AppColors.emerald600,
                      mobileTrailing: (context, s, _) => paidIds.contains(s.id)
                          ? const _PaidPill()
                          : (canPay
                                ? TextButton(onPressed: () => _pay(s), child: const Text('Pay'))
                                : const SizedBox.shrink()),
                      columns: [
                        NetColumn(
                          label: 'Name',
                          width: 170,
                          builder: (context, s, _) => Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        NetColumn(
                          label: 'Department',
                          width: 120,
                          builder: (context, s, _) => Text(kitTitle(s.department)),
                        ),
                        NetColumn(
                          label: 'Basic Pay',
                          width: 120,
                          builder: (context, s, _) => Text(kitMoney(base(s))),
                        ),
                        NetColumn(
                          label: 'Status',
                          width: 100,
                          builder: (context, s, _) => paidIds.contains(s.id)
                              ? const _PaidPill()
                              : const KitPill(
                                  label: 'Unpaid',
                                  background: Color(0xFFFEE2E2),
                                  foreground: Color(0xFF991B1B),
                                ),
                        ),
                        NetColumn(
                          label: '',
                          width: 90,
                          isActions: true,
                          builder: (context, s, _) => paidIds.contains(s.id) || !canPay
                              ? const SizedBox.shrink()
                              : TextButton(onPressed: () => _pay(s), child: const Text('Pay')),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaidPill extends StatelessWidget {
  const _PaidPill();

  @override
  Widget build(BuildContext context) => const KitPill(
    label: 'Paid',
    background: Color(0xFFDCFCE7),
    foreground: Color(0xFF166534),
  );
}

// ===========================================================================
// Staff Attendance — one day (hr/attendance-day)
// ===========================================================================

const Map<String, String> _kAttendanceStatuses = {
  'present': 'Present',
  'absent': 'Absent',
  'late': 'Late',
  'leave': 'Leave',
};

class AttendanceDayScreen extends StatefulWidget {
  const AttendanceDayScreen({super.key});

  @override
  State<AttendanceDayScreen> createState() => _AttendanceDayScreenState();
}

class _AttendanceRow {
  _AttendanceRow({required this.status, this.checkIn = '', this.checkOut = '', this.id});
  String status;
  String checkIn;
  String checkOut;
  String? id;
}

class _AttendanceDayScreenState extends State<AttendanceDayScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: kitHandleUnauthorized);
  List<StaffMember> _staff = [];
  final Map<String, _AttendanceRow> _rows = {};
  String _date = kitToday();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String get _cid => Session.companyId ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final staff = (await loadStaff(_api)).where((s) => s.status != 'left').toList();
      final records = kitMaps(
        await _api.get('/hr/attendance', query: {'companyId': _cid, 'date': _date}),
      );
      if (!mounted) return;
      _rows.clear();
      for (final s in staff) {
        Map<String, dynamic>? rec;
        for (final r in records) {
          if (kitStr(r['staffId']) == s.id && kitStr(r['date']) == _date) rec = r;
        }
        _rows[s.id] = rec == null
            ? _AttendanceRow(status: 'present')
            : _AttendanceRow(
                status: kitStr(rec['status']),
                checkIn: kitStr(rec['checkIn']),
                checkOut: kitStr(rec['checkOut']),
                id: kitStr(rec['id']),
              );
      }
      setState(() {
        _staff = staff;
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      for (final s in _staff) {
        final r = _rows[s.id];
        if (r == null) continue;
        final payload = {
          'staffId': s.id,
          'staffName': s.name,
          'date': _date,
          'status': r.status,
          'checkIn': r.checkIn,
          'checkOut': r.checkOut,
          'companyId': _cid,
        };
        if (r.id != null && r.id!.isNotEmpty) {
          await _api.put('/hr/attendance/${r.id}', body: {...payload, 'id': r.id});
        } else {
          final res = await _api.post('/hr/attendance', body: payload);
          final newId = kitStr(res['id']);
          if (newId.isNotEmpty) r.id = newId;
        }
      }
      if (mounted) showToast(context, 'Attendance for $_date saved successfully.');
      await _load();
    } catch (e) {
      if (mounted) kitReportError(context, e, fallback: 'Failed to save attendance');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(_AttendanceRow row, bool checkIn) async {
    final current = checkIn ? row.checkIn : row.checkOut;
    final parts = current.split(':');
    final initial = parts.length >= 2
        ? TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0)
        : TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final v = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (checkIn) {
        row.checkIn = v;
      } else {
        row.checkOut = v;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{for (final k in _kAttendanceStatuses.keys) k: 0};
    for (final s in _staff) {
      final st = _rows[s.id]?.status;
      if (st != null && counts.containsKey(st)) counts[st] = counts[st]! + 1;
    }
    final canSave = invCrud(kStaffAttendancePermission, 'create');
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.fact_check_outlined,
            title: 'Staff Attendance',
            subtitle: 'Mark daily attendance for your staff.',
            gradient: kitIndigo,
          ),
          if (_cid.isEmpty)
            const KitNoCompany(what: 'attendance')
          else ...[
            NetworkStatGrid(
              maxColumns: 4,
              children: [
                kitStat('Present', counts['present']!, Icons.check_circle_outline, kitEmerald),
                kitStat('Absent', counts['absent']!, Icons.cancel_outlined, kitRose),
                kitStat('Late', counts['late']!, Icons.schedule, kitAmber),
                kitStat('Leave', counts['leave']!, Icons.beach_access_outlined, kitBlue),
              ],
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InvFilterBar(
                    filterWidth: 200,
                    filters: [
                      TxDateField(
                        label: 'Date',
                        value: _date,
                        onChanged: (v) {
                          setState(() => _date = v);
                          _load();
                        },
                      ),
                    ],
                    actions: [
                      if (canSave)
                        GradientButton(
                          label: 'Save Attendance',
                          icon: Icons.save_outlined,
                          gradient: kitEmerald,
                          loading: _saving,
                          onPressed: _staff.isEmpty ? null : _save,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const KitLoading()
                  else if (_error != null && _staff.isEmpty)
                    KitErrorCard(message: _error!, onRetry: _load)
                  else if (_staff.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No working staff found.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.mutedFg),
                      ),
                    )
                  else
                    for (final s in _staff) _attendanceTile(s, canSave),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _attendanceTile(StaffMember s, bool editable) {
    final row = _rows[s.id] ?? _AttendanceRow(status: 'present');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (s.designation.isNotEmpty)
            Text(s.designation, style: TextStyle(fontSize: 12, color: context.mutedFg)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in _kAttendanceStatuses.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: row.status == e.key,
                  onSelected: editable
                      ? (_) => setState(() => row.status = e.key)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: editable ? () => _pickTime(row, true) : null,
                  icon: const Icon(Icons.login, size: 16),
                  label: Text(row.checkIn.isEmpty ? 'Check in' : row.checkIn),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: editable ? () => _pickTime(row, false) : null,
                  icon: const Icon(Icons.logout, size: 16),
                  label: Text(row.checkOut.isEmpty ? 'Check out' : row.checkOut),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Attendance Report — monthly summary (hr/attendance-subscriber)
// ===========================================================================

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceSummary {
  _AttendanceSummary(this.name);
  final String name;
  int present = 0, absent = 0, late = 0, leave = 0, total = 0;
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: kitHandleUnauthorized);
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;
  String _month = kMonths[DateTime.now().month - 1];
  int _year = DateTime.now().year;
  ({String month, int year})? _applied;

  String get _cid => Session.companyId ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final json = await _api.get('/hr/attendance', query: {'companyId': _cid});
      if (!mounted) return;
      setState(() {
        _records = kitMaps(json);
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

  List<Map<String, dynamic>> get _monthRecords {
    final applied = _applied;
    if (applied == null) return const [];
    final m = kMonths.indexOf(applied.month) + 1;
    final list = _records.where((r) {
      final parts = kitStr(r['date']).split('-');
      if (parts.length < 2) return false;
      return int.tryParse(parts[0]) == applied.year && int.tryParse(parts[1]) == m;
    }).toList()
      ..sort((a, b) {
        final byDate = kitStr(a['date']).compareTo(kitStr(b['date']));
        return byDate != 0
            ? byDate
            : kitStr(a['staffName']).compareTo(kitStr(b['staffName']));
      });
    return list;
  }

  List<_AttendanceSummary> _summaries(List<Map<String, dynamic>> recs) {
    final map = <String, _AttendanceSummary>{};
    for (final r in recs) {
      final key = kitStr(r['staffId']);
      final name = kitStr(r['staffName']);
      final e = map.putIfAbsent(key, () => _AttendanceSummary(name.isEmpty ? 'Unknown' : name));
      switch (kitStr(r['status'])) {
        case 'present':
          e.present++;
        case 'absent':
          e.absent++;
        case 'late':
          e.late++;
        case 'leave':
          e.leave++;
      }
      e.total++;
    }
    return map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _print(List<_AttendanceSummary> rows) async {
    final applied = _applied!;
    final body = rows
        .map((s) => '<tr><td>${salesEscapeHtml(s.name)}</td><td>${s.present}</td>'
            '<td>${s.absent}</td><td>${s.late}</td><td>${s.leave}</td><td>${s.total}</td></tr>')
        .join();
    final html = '''<!doctype html><html><head><meta charset="utf-8"><title>Attendance Report</title>
<style>body{font-family:sans-serif;padding:24px}table{width:100%;border-collapse:collapse;font-size:13px}
th{background:#4f46e5;color:#fff;padding:8px;text-align:left}td{border:1px solid #e5e7eb;padding:8px}</style></head><body>
<h2>Monthly Attendance Report — ${salesEscapeHtml(applied.month)} ${applied.year}</h2>
<p>${salesEscapeHtml(Session.companyName ?? '')}</p>
<table><thead><tr><th>Staff</th><th>Present</th><th>Absent</th><th>Late</th><th>Leave</th><th>Total</th></tr></thead>
<tbody>$body</tbody></table></body></html>''';
    await salesOpenHtml(context, 'attendance-report.html', html);
  }

  @override
  Widget build(BuildContext context) {
    final recs = _monthRecords;
    final rows = _summaries(recs);
    int count(String st) => recs.where((r) => kitStr(r['status']) == st).length;
    final nowYear = DateTime.now().year;
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.event_note_outlined,
            title: 'Attendance Report',
            subtitle: 'Monthly attendance summary for your staff.',
            gradient: kitIndigo,
          ),
          if (_cid.isEmpty)
            const KitNoCompany(what: 'attendance')
          else if (_loading)
            const KitLoading()
          else if (_error != null && _records.isEmpty)
            KitErrorCard(message: _error!, onRetry: _load)
          else ...[
            NetworkStatGrid(
              maxColumns: 4,
              children: [
                kitStat('Present', count('present'), Icons.check_circle_outline, kitEmerald),
                kitStat('Absent', count('absent'), Icons.cancel_outlined, kitRose),
                kitStat('Late', count('late'), Icons.schedule, kitAmber),
                kitStat('Leave', count('leave'), Icons.beach_access_outlined, kitBlue),
              ],
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InvFilterBar(
                    filterWidth: 180,
                    filters: [
                      TxSelect(
                        value: _month,
                        items: {for (final m in kMonths) m: m},
                        onChanged: (v) => setState(() => _month = v),
                      ),
                      TxSelect(
                        value: '$_year',
                        items: {for (var y = nowYear; y >= 2020; y--) '$y': '$y'},
                        onChanged: (v) => setState(() => _year = int.parse(v)),
                      ),
                    ],
                    actions: [
                      GradientButton(
                        label: 'Show',
                        icon: Icons.search,
                        gradient: kitIndigo,
                        onPressed: () => setState(() => _applied = (month: _month, year: _year)),
                      ),
                      if (rows.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => _print(rows),
                          icon: const Icon(Icons.print_outlined, size: 18),
                          label: const Text('Print'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_applied == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Select a month and tap "Show".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.mutedFg),
                      ),
                    )
                  else
                    NetworkTable<_AttendanceSummary>(
                      rows: rows,
                      emptyIcon: Icons.event_busy_outlined,
                      emptyTitle: 'No attendance recorded for this month.',
                      emptyHint: '',
                      emptyTint: AppColors.emerald600,
                      columns: [
                        NetColumn(label: 'Staff', width: 180, builder: (c, s, _) => Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        NetColumn(label: 'Present', width: 80, builder: (c, s, _) => Text('${s.present}')),
                        NetColumn(label: 'Absent', width: 80, builder: (c, s, _) => Text('${s.absent}')),
                        NetColumn(label: 'Late', width: 70, builder: (c, s, _) => Text('${s.late}')),
                        NetColumn(label: 'Leave', width: 70, builder: (c, s, _) => Text('${s.leave}')),
                        NetColumn(label: 'Total', width: 70, builder: (c, s, _) => Text('${s.total}')),
                      ],
                    ),
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
// Advances & Loans (hr/advances)
// ===========================================================================

const Map<String, String> _kTxnTypes = {
  'cash': 'Cash',
  'easypaisa': 'Easypaisa',
  'jazzcash': 'JazzCash',
  'bank_transfer': 'Bank Transfer',
  'other_bank': 'Other Bank',
};

class AdvancesScreen extends StatefulWidget {
  const AdvancesScreen({super.key});

  @override
  State<AdvancesScreen> createState() => _AdvancesScreenState();
}

class _AdvancesScreenState extends State<AdvancesScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: kitHandleUnauthorized);
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  List<StaffMember> _staff = [];
  bool _loading = true;
  String? _error;
  String _filter = '';
  String _staffFilter = 'all';
  String _categoryFilter = 'all';
  int _page = 1;
  int _pageSize = 10;

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
    try {
      final results = await Future.wait([
        _api.get('/hr/advances', query: {'companyId': _cid}),
        loadStaff(_api),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = kitMaps(results[0] as Map<String, dynamic>)
          ..sort((a, b) => kitStr(b['date']).compareTo(kitStr(a['date'])));
        _staff = results[1] as List<StaffMember>;
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

  List<Map<String, dynamic>> get _filtered => _rows.where((r) {
    if (_staffFilter != 'all' && kitStr(r['staffId']) != _staffFilter) return false;
    if (_categoryFilter != 'all' && kitStr(r['category']) != _categoryFilter) return false;
    return kitMatch(_filter, [kitStr(r['staffName']), kitStr(r['description']), kitStr(r['comments'])]);
  }).toList();

  Future<void> _delete(Map<String, dynamic> r) async {
    await showNetworkDeleteDialog(
      context,
      itemName: '${kitTitle(kitStr(r['category']))} of ${kitStr(r['staffName'])}',
      onConfirm: () async {
        try {
          await _api.delete('/hr/advances/${kitStr(r['id'])}');
          if (mounted) showToast(context, 'Record deleted successfully.');
          await _load();
        } catch (e) {
          if (mounted) kitReportError(context, e);
        }
      },
    );
  }

  Future<void> _openForm(Map<String, dynamic>? existing) async {
    final raw = existing ?? const <String, dynamic>{};
    String? staffId = kitStr(raw['staffId']).isEmpty ? null : kitStr(raw['staffId']);
    var category = kitStr(raw['category']).isEmpty ? 'advance' : kitStr(raw['category']);
    var direction = kitStr(raw['direction']).isEmpty ? 'issue' : kitStr(raw['direction']);
    var date = kitStr(raw['date']).isEmpty ? kitToday() : kitStr(raw['date']);
    var txn = kitStr(raw['transactionType']).isEmpty ? 'cash' : kitStr(raw['transactionType']);
    var repayment = kitStr(raw['repaymentStatus']).isEmpty ? 'pending' : kitStr(raw['repaymentStatus']);
    final amount = TextEditingController(text: existing == null ? '' : kitNum(raw['amount']).toStringAsFixed(0));
    final returnValue = TextEditingController(text: existing == null ? '0' : kitNum(raw['returnValue']).toStringAsFixed(0));
    final comments = TextEditingController(text: kitStr(raw['comments']));
    final description = TextEditingController(text: kitStr(raw['description']));
    final staffOptions = [
      for (final s in _staff) TxPickOption(id: s.id, name: s.name, secondary: s.designation),
    ];

    await showKitForm(
      context,
      title: existing == null ? 'Add Advance / Loan' : 'Edit Advance / Loan',
      icon: Icons.account_balance_wallet_outlined,
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TxSearchableSelect(
            label: 'Staff Member *',
            placeholder: 'Select staff member',
            searchPlaceholder: 'Search staff...',
            options: staffOptions,
            value: staffId,
            onChanged: (v) => setSheet(() => staffId = v),
          ),
          kitGap,
          KitRow(
            children: [
              KitSelect(
                label: 'Category',
                value: category,
                items: const {'advance': 'Advance', 'loan': 'Loan'},
                onChanged: (v) => setSheet(() => category = v),
              ),
              KitSelect(
                label: 'Direction',
                value: direction,
                items: const {'issue': 'Issue', 'return': 'Return'},
                onChanged: (v) => setSheet(() => direction = v),
              ),
            ],
          ),
          kitGap,
          KitRow(
            children: [
              KitTextField(label: 'Amount *', controller: amount, keyboardType: TextInputType.number),
              NetField(
                label: 'Date *',
                child: TxDateField(
                  label: 'Select date',
                  value: date,
                  width: double.infinity,
                  onChanged: (v) => setSheet(() => date = v),
                ),
              ),
            ],
          ),
          kitGap,
          KitRow(
            children: [
              KitTextField(label: 'Return Value', controller: returnValue, keyboardType: TextInputType.number),
              KitSelect(
                label: 'Transaction Type',
                value: txn,
                items: _kTxnTypes,
                onChanged: (v) => setSheet(() => txn = v),
              ),
            ],
          ),
          kitGap,
          KitSelect(
            label: 'Repayment Status',
            value: repayment,
            items: const {'pending': 'Pending', 'deducted': 'Deducted', 'paid': 'Paid'},
            onChanged: (v) => setSheet(() => repayment = v),
          ),
          kitGap,
          KitTextField(label: 'Description', controller: description, maxLines: 2),
          kitGap,
          KitTextField(label: 'Comments', controller: comments, maxLines: 2),
        ],
      ),
      onSubmit: () async {
        final amt = double.tryParse(amount.text.trim()) ?? 0;
        final ret = double.tryParse(returnValue.text.trim()) ?? 0;
        StaffMember? member;
        for (final s in _staff) {
          if (s.id == staffId) member = s;
        }
        String? err;
        if (member == null) {
          err = 'Staff member is required';
        } else if (amt < 1) {
          err = 'Amount must be greater than 0';
        } else if (ret < 0) {
          err = 'Return value must be 0 or greater';
        } else if (date.isEmpty) {
          err = 'Date is required';
        }
        if (err != null) {
          showToast(context, err, error: true);
          return false;
        }
        final m = member!;
        final body = <String, dynamic>{
          ...raw,
          'staffId': m.id,
          'staffName': m.name,
          'category': category,
          'direction': direction,
          'amount': amt,
          'date': date,
          'returnValue': ret,
          'transactionType': txn,
          'comments': comments.text.trim(),
          'repaymentStatus': repayment,
          'description': description.text.trim(),
          'companyId': _cid,
        };
        try {
          if (existing == null) {
            await _api.post('/hr/advances', body: body);
          } else {
            await _api.put('/hr/advances/${kitStr(existing['id'])}', body: body);
          }
          if (mounted) {
            showToast(context, existing == null ? 'Record added successfully.' : 'Record updated successfully.');
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final issued = filtered.where((r) => kitStr(r['direction']) == 'issue').fold<double>(0, (a, r) => a + kitNum(r['amount']));
    final returned = filtered.where((r) => kitStr(r['direction']) == 'return').fold<double>(0, (a, r) => a + kitNum(r['amount']));
    final canCreate = invCrud(kAdvanceLoanPermission, 'create');
    final canUpdate = invCrud(kAdvanceLoanPermission, 'update');
    final canDelete = invCrud(kAdvanceLoanPermission, 'delete');
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Advances & Loans',
            subtitle: 'Track advances and loans issued to and returned by staff.',
            gradient: kitAmber,
          ),
          if (_cid.isEmpty)
            const KitNoCompany(what: 'advances')
          else if (_loading)
            const KitLoading()
          else if (_error != null && _rows.isEmpty)
            KitErrorCard(message: _error!, onRetry: _load)
          else ...[
            NetworkStatGrid(
              children: [
                kitStat('Total Issued', _pkr(issued), Icons.call_made, kitRose),
                kitStat('Total Returned', _pkr(returned), Icons.call_received, kitEmerald),
                kitStat('Balance', _pkr(issued - returned), Icons.balance, kitAmber),
              ],
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InvFilterBar(
                    filterWidth: 220,
                    filtersPerRow: 3,
                    filters: [
                      txSearchField(
                        context: context,
                        controller: _search,
                        hint: 'Search...',
                        onChanged: (v) => setState(() {
                          _filter = v;
                          _page = 1;
                        }),
                      ),
                      TxSelect(
                        value: _staffFilter,
                        items: {'all': 'All Employees', for (final s in _staff) s.id: s.name},
                        onChanged: (v) => setState(() {
                          _staffFilter = v;
                          _page = 1;
                        }),
                      ),
                      TxSelect(
                        value: _categoryFilter,
                        items: const {'all': 'All Types', 'advance': 'Advance', 'loan': 'Loan'},
                        onChanged: (v) => setState(() {
                          _categoryFilter = v;
                          _page = 1;
                        }),
                      ),
                    ],
                    actions: [
                      if (canCreate)
                        GradientButton(
                          label: 'Add Record',
                          icon: Icons.add_circle_outline,
                          gradient: kitEmerald,
                          onPressed: () => _openForm(null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  NetworkTable<Map<String, dynamic>>(
                    rows: kitPage(filtered, _page, _pageSize),
                    emptyIcon: Icons.account_balance_wallet_outlined,
                    emptyTitle: 'No advances or loans found.',
                    emptyHint: '',
                    emptyTint: AppColors.emerald600,
                    mobileTrailing: (context, r, _) => NetworkRowActions(
                      onEdit: canUpdate ? () => _openForm(r) : null,
                      onDelete: canDelete ? () => _delete(r) : null,
                    ),
                    columns: [
                      NetColumn(label: 'Staff', width: 160, builder: (c, r, _) => Text(kitStr(r['staffName']), style: const TextStyle(fontWeight: FontWeight.w600))),
                      NetColumn(label: 'Type', width: 90, builder: (c, r, _) => Text(kitTitle(kitStr(r['category'])))),
                      NetColumn(
                        label: 'Direction',
                        width: 90,
                        builder: (c, r, _) {
                          final issue = kitStr(r['direction']) == 'issue';
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: KitPill(
                              label: issue ? 'Issue' : 'Return',
                              background: issue ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                              foreground: issue ? const Color(0xFF991B1B) : const Color(0xFF166534),
                            ),
                          );
                        },
                      ),
                      NetColumn(label: 'Amount', width: 110, builder: (c, r, _) => Text(kitMoney(kitNum(r['amount'])))),
                      NetColumn(label: 'Date', width: 100, builder: (c, r, _) => Text(kitStr(r['date']))),
                      NetColumn(label: 'Payment', width: 110, builder: (c, r, _) => Text(_kTxnTypes[kitStr(r['transactionType'])] ?? kitStr(r['transactionType']))),
                      NetColumn(label: 'Repayment', width: 100, builder: (c, r, _) => Text(kitTitle(kitStr(r['repaymentStatus'])))),
                      NetColumn(
                        label: '',
                        width: 96,
                        isActions: true,
                        builder: (c, r, _) => Align(
                          alignment: Alignment.centerRight,
                          child: NetworkRowActions(
                            onEdit: canUpdate ? () => _openForm(r) : null,
                            onDelete: canDelete ? () => _delete(r) : null,
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
                      noun: 'records',
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
        ],
      ),
    );
  }
}
