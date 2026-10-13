import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../crm/crm_common.dart';
import '../crm/crm_models.dart';
import '../network/network_common.dart';
import 'sales_common.dart';

const List<Color> _violetGradient = [Color(0xFF8B5CF6), Color(0xFF9333EA)];
const List<Color> _shiftedRoseGradient = [Color(0xFFF43F5E), Color(0xFFE11D48)];

/// Flutter counterpart of `client/src/app/(app)/sales/customers/page.tsx` —
/// customers who are not subscribers or dealers.
class SalesCustomersScreen extends StatefulWidget {
  const SalesCustomersScreen({super.key});

  @override
  State<SalesCustomersScreen> createState() => _SalesCustomersScreenState();
}

class _SalesCustomersScreenState extends State<SalesCustomersScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<CrmCustomer> _customers = [];
  bool _loading = true;
  String _filter = '';
  final Set<String> _statusFilters = {};
  final TextEditingController _search = TextEditingController();
  int _page = 1;
  int _pageSize = 10;

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

  List<CrmCustomer> get _filtered => _customers
      .where(
        (c) => salesSmartMatch(_filter, [
          [c.cnic, c.phone],
          [c.name],
        ]),
      )
      .where((c) => _statusFilters.isEmpty || _statusFilters.contains(c.status))
      .toList();

  List<CrmCustomer> get _paged {
    final start = (_page - 1) * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  double get _totalOutstanding =>
      _customers.fold(0, (sum, c) => sum + c.outstandingBalance);

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final json = await _api.get('crm/customers', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _customers = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(CrmCustomer.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save(Map<String, dynamic> values, CrmCustomer? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          'crm/customers/${existing.id}?companyId=$cid',
          body: values,
        );
      } else {
        await _api.post(
          'crm/customers?companyId=$cid',
          body: {
            ...values,
            'companyId': cid,
            'totalInvoices': 0,
            'outstandingBalance': 0,
          },
        );
      }
      await _load();
      if (mounted) {
        showToast(
          context,
          existing != null
              ? 'Customer updated successfully.'
              : 'Customer added successfully.',
        );
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(CrmCustomer customer) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    await showNetworkDeleteDialog(
      context,
      itemName: customer.name,
      onConfirm: () async {
        try {
          await _api.delete('crm/customers/${customer.id}?companyId=$cid');
          await _load();
          if (mounted) showToast(context, 'Customer deleted successfully.');
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openForm(CrmCustomer? customer) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CustomerFormDialog(customer: customer),
    );
    if (result != null) await _save(result, customer);
  }

  @override
  Widget build(BuildContext context) {
    final cid = _cid;
    final active = _customers.where((c) => c.status == 'active').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.person_outline,
            title: 'Customers',
            subtitle: 'Manage customers who are not subscribers or dealers.',
            gradient: salesVioletGradient,
          ),
          if (cid == null || cid.isEmpty)
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: const Text(
                  'Please select a company to manage customers.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            NetworkStatGrid(
              maxColumns: 3,
              children: [
                NetworkStatCard(
                  icon: Icons.people_outline,
                  label: 'Total Customers',
                  value: '${_customers.length}',
                  gradient: salesVioletGradient,
                ),
                NetworkStatCard(
                  icon: Icons.verified_user_outlined,
                  label: 'Active',
                  value: '$active',
                  gradient: salesEmeraldGradient,
                  valueColor: salesGoodSaleColor,
                ),
                NetworkStatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Outstanding (PKR)',
                  value: salesNumber(_totalOutstanding),
                  gradient: salesAmberGradient,
                  valueColor: salesHoldColor,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _tableCard(context),
          ],
        ],
      ),
    );
  }

  Widget _tableCard(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Builder(
              builder: (context) {
                final search = TextField(
                  controller: _search,
                  onChanged: (v) => setState(() {
                    _filter = v;
                    _page = 1;
                  }),
                  style: const TextStyle(fontSize: 14),
                  decoration:
                      netInputDecoration(
                        context,
                        hint: 'Search by name, CNIC, or phone...',
                      ).copyWith(
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: context.mutedFg,
                        ),
                      ),
                );
                final statusFilter = _StatusFilterButton(
                  selected: _statusFilters,
                  onChanged: (status, checked) => setState(() {
                    if (checked) {
                      _statusFilters.add(status);
                    } else {
                      _statusFilters.remove(status);
                    }
                    _page = 1;
                  }),
                );
                final add = GradientButton(
                  label: 'Add Customer',
                  icon: Icons.add_circle_outline,
                  gradient: salesEmeraldGradient,
                  onPressed: () => _openForm(null),
                );
                return SalesFilterRows(
                  rows: [
                    [SizedBox(width: 280, child: search)],
                    [statusFilter, add],
                  ],
                );
              },
            ),
          ),
          Divider(color: context.line, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                NetworkTable<CrmCustomer>(
                  rows: _paged,
                  emptyIcon: Icons.person_outline,
                  emptyTitle: 'No customers found.',
                  emptyHint: 'Click "Add Customer" to create one.',
                  emptyTint: salesVioletGradient.first,
                  mobileTrailing: (context, c, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit customer',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _openForm(c),
                      ),
                      IconButton(
                        tooltip: 'Delete customer',
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: context.dangerText,
                        ),
                        onPressed: () => _delete(c),
                      ),
                    ],
                  ),
                  columns: [
                    NetColumn(
                      label: 'Name',
                      width: 200,
                      builder: (context, c, _) => Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _violetGradient.first.withValues(
                                alpha: 0.14,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              size: 14,
                              color: _violetGradient.first,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    NetColumn(
                      label: 'CNIC',
                      width: 150,
                      builder: (context, c, _) =>
                          Text(c.cnic, style: const TextStyle(fontSize: 13)),
                    ),
                    NetColumn(
                      label: 'Phone',
                      width: 140,
                      builder: (context, c, _) => Text(c.phone),
                    ),
                    NetColumn(
                      label: 'City',
                      width: 120,
                      builder: (context, c, _) => Text(c.city),
                    ),
                    NetColumn(
                      label: 'Status',
                      width: 120,
                      builder: (context, c, _) => _statusBadge(c.status),
                    ),
                    NetColumn(
                      label: 'Outstanding',
                      width: 140,
                      center: true,
                      builder: (context, c, _) => SizedBox(
                        width: double.infinity,
                        child: Text(
                          'PKR ${salesNumber(c.outstandingBalance)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    NetColumn(
                      label: 'Actions',
                      width: 96,
                      isActions: true,
                      builder: (context, c, _) => Align(
                        alignment: Alignment.centerRight,
                        child: NetworkRowActions(
                          onEdit: () => _openForm(c),
                          onDelete: () => _delete(c),
                        ),
                      ),
                    ),
                  ],
                ),
                NetworkPagination(
                  currentPage: _page,
                  pageSize: _pageSize,
                  totalItems: _filtered.length,
                  noun: 'customers',
                  pageSizes: const [5, 10, 20, 50],
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
      ),
    );
  }

  Widget _statusBadge(String status) {
    final s = status.toLowerCase();
    final color = s == 'active'
        ? salesGoodSaleColor
        : s == 'blacklisted'
        ? context.dangerText
        : _shiftedRoseGradient.last;
    final label = status.isEmpty
        ? 'unknown'
        : status[0].toUpperCase() + status.substring(1);
    return CrmBadge(label: label, color: color, solid: s == 'active');
  }
}

class _StatusFilterButton extends StatelessWidget {
  const _StatusFilterButton({required this.selected, required this.onChanged});

  final Set<String> selected;
  final void Function(String status, bool checked) onChanged;

  static const _statuses = ['active', 'inactive', 'blacklisted'];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (_) {},
      itemBuilder: (context) => [
        for (final status in _statuses)
          CheckedPopupMenuItem<String>(
            value: status,
            checked: selected.contains(status),
            onTap: () => onChanged(status, !selected.contains(status)),
            child: Text(
              status[0].toUpperCase() + status.substring(1),
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: context.line),
          borderRadius: BorderRadius.circular(10),
          color: context.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list, size: 16, color: context.mutedFg),
            const SizedBox(width: 8),
            const Text('Status', style: TextStyle(fontSize: 13)),
            if (selected.isNotEmpty) ...[
              const SizedBox(width: 6),
              CrmBadge(
                label: '${selected.length}',
                color: context.fg,
                solid: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomerFormDialog extends StatefulWidget {
  const _CustomerFormDialog({this.customer});

  final CrmCustomer? customer;

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _cnic;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  late String _status;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _name = TextEditingController(text: c?.name ?? '');
    _cnic = TextEditingController(text: c?.cnic ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _city = TextEditingController(text: c?.city ?? '');
    _status = (c != null && c.status.isNotEmpty) ? c.status : 'active';
  }

  @override
  void dispose() {
    _name.dispose();
    _cnic.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'cnic': _cnic.text.trim(),
      'phone': _phone.text.trim(),
      'city': _city.text.trim(),
      'status': _status,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.customer != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: salesVioletGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.person_add_alt_1,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text('${editing ? 'Edit' : 'Add New'} Customer'),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NetField(
                  label: 'Customer Name *',
                  child: TextFormField(
                    controller: _name,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g., Ahmed Khan',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: NetField(
                        label: 'CNIC *',
                        child: TextFormField(
                          controller: _cnic,
                          decoration: netInputDecoration(
                            context,
                            hint: '42201-1234567-8',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'CNIC is required'
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: NetField(
                        label: 'Phone *',
                        child: TextFormField(
                          controller: _phone,
                          decoration: netInputDecoration(
                            context,
                            hint: '0300-1234567',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Phone is required'
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: NetField(
                        label: 'City *',
                        child: TextFormField(
                          controller: _city,
                          decoration: netInputDecoration(
                            context,
                            hint: 'e.g., Karachi',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'City is required'
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: NetField(
                        label: 'Status',
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          isExpanded: true,
                          decoration: netInputDecoration(context),
                          items: const [
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('Inactive'),
                            ),
                            DropdownMenuItem(
                              value: 'blacklisted',
                              child: Text('Blacklisted'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _status = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Save Customer',
          gradient: salesEmeraldGradient,
          onPressed: _submit,
        ),
      ],
    );
  }
}
