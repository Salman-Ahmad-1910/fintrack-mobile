import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'crm_common.dart';
import 'crm_models.dart';

/// Flutter counterpart of `client/src/app/(app)/crm/customers/page.tsx` —
/// customer profiles, history and status.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<CrmCustomer> _customers = [];
  bool _loading = true;
  String _filter = '';
  final Set<String> _statusFilters = {};
  int _page = 1;
  int _pageSize = 10;
  final TextEditingController _search = TextEditingController();

  static const List<String> _statuses = ['active', 'inactive', 'blacklisted'];

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

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final json = await _api.get('/crm/customers', query: {'companyId': cid});
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

  List<CrmCustomer> get _filtered => _customers
      .where(
        (c) =>
            netContains(_filter, [c.id, c.cnic, c.name]) &&
            (_statusFilters.isEmpty || _statusFilters.contains(c.status)),
      )
      .toList();

  List<CrmCustomer> get _pageRows {
    final start = (_page - 1) * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  void _setFilter(String value) {
    setState(() {
      _filter = value;
      _page = 1;
    });
  }

  Future<void> _save(Map<String, dynamic> values, CrmCustomer? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/crm/customers/${existing.id}?companyId=$cid',
          body: values,
        );
      } else {
        await _api.post(
          '/crm/customers?companyId=$cid',
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
        await showCrmFeedback(
          context,
          type: 'success',
          title: 'Success',
          message: existing != null
              ? 'Customer updated successfully.'
              : 'Customer added successfully.',
        );
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) {
        await showCrmFeedback(
          context,
          type: 'error',
          title: 'Error',
          message: e.message,
        );
      }
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
          await _api.delete('/crm/customers/${customer.id}?companyId=$cid');
          await _load();
          if (mounted) {
            await showCrmFeedback(
              context,
              type: 'success',
              title: 'Success',
              message: 'Customer deleted successfully.',
            );
          }
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) {
            await showCrmFeedback(
              context,
              type: 'error',
              title: 'Error',
              message: e.message,
            );
          }
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
    final active = _customers.where((c) => c.status == 'active').length;
    final inactive = _customers.where((c) => c.status == 'inactive').length;
    final blacklisted = _customers
        .where((c) => c.status == 'blacklisted')
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: CrmScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.person_outline,
            title: 'Customers',
            subtitle: 'Manage your customer profiles, view their history, and track their status.',
            gradient: crmAmberGradient,
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
                    NetworkStatGrid(
                      maxColumns: 4,
                      children: [
                        NetworkStatCard(
                          icon: Icons.person_outline,
                          label: 'Total',
                          value: '${_customers.length}',
                          gradient: crmAmberGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.person_add_alt,
                          label: 'Active',
                          value: '$active',
                          gradient: crmGreenGradient,
                          valueColor: crmStatusActive,
                        ),
                        NetworkStatCard(
                          icon: Icons.person_off_outlined,
                          label: 'Inactive',
                          value: '$inactive',
                          gradient: crmSlateGradient,
                          valueColor: crmStatusInactive,
                        ),
                        NetworkStatCard(
                          icon: Icons.block,
                          label: 'Blacklisted',
                          value: '$blacklisted',
                          gradient: crmRoseGradient,
                          valueColor: crmStatusDeactivated,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _toolbar(context),
                    const SizedBox(height: 16),
                    NetworkTable<CrmCustomer>(
                      rows: _pageRows,
                      emptyIcon: Icons.person_outline,
                      emptyTitle: 'No customers found.',
                      emptyHint: 'Get started by adding a new customer.',
                      emptyTint: AppColors.emerald600,
                      mobileTrailing: (context, c, _) => NetworkRowActions(
                        onEdit: () => _openForm(c),
                        onDelete: () => _delete(c),
                      ),
                      columns: [
                        NetColumn(
                          label: 'ID',
                          width: 60,
                          builder: (context, c, index) => Text(
                            '${index + 1}',
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
                          builder: (context, c, _) => Text(c.name),
                        ),
                        NetColumn(
                          label: 'CNIC',
                          width: 160,
                          builder: (context, c, _) => Text(c.cnic),
                        ),
                        NetColumn(
                          label: 'Phone',
                          width: 140,
                          builder: (context, c, _) => Text(c.phone),
                        ),
                        NetColumn(
                          label: 'City',
                          width: 140,
                          builder: (context, c, _) => Text(c.city),
                        ),
                        NetColumn(
                          label: 'Status',
                          width: 130,
                          builder: (context, c, _) => CrmBadge(
                            label: c.status,
                            color: _statusColor(c.status),
                          ),
                        ),
                        NetColumn(
                          label: 'Outstanding (PKR)',
                          width: 150,
                          center: true,
                          builder: (context, c, _) => SizedBox(
                            width: double.infinity,
                            child: Text(
                              crmNumber(c.outstandingBalance),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        NetColumn(
                          label: '',
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
                      onPageChanged: (p) => setState(() => _page = p),
                      onPageSizeChanged: (s) => setState(() {
                        _pageSize = s;
                        _page = 1;
                      }),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return crmStatusActive;
      case 'blacklisted':
        return crmStatusDeactivated;
      default:
        return crmStatusInactive;
    }
  }

  Widget _toolbar(BuildContext context) {
    final search = TextField(
      controller: _search,
      onChanged: _setFilter,
      style: const TextStyle(fontSize: 14),
      decoration: netInputDecoration(context, hint: 'Filter by name or CNIC...')
          .copyWith(
            prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
          ),
    );
    final statusFilter = MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.surface),
      ),
      builder: (context, controller, child) => OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list, size: 16, color: context.fg),
            const SizedBox(width: 8),
            Text('Status', style: TextStyle(color: context.fg)),
            if (_statusFilters.isNotEmpty) ...[
              const SizedBox(width: 6),
              CrmBadge(
                label: '${_statusFilters.length}',
                color: AppColors.primary,
                solid: true,
              ),
            ],
          ],
        ),
      ),
      menuChildren: [
        for (final status in _statuses)
          CheckboxMenuButton(
            value: _statusFilters.contains(status),
            onChanged: (checked) => setState(() {
              if (checked ?? false) {
                _statusFilters.add(status);
              } else {
                _statusFilters.remove(status);
              }
              _page = 1;
            }),
            child: Text(status, style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
    final add = GradientButton(
      label: 'Add Customer',
      icon: Icons.add_circle_outline,
      gradient: crmGreenGradient,
      onPressed: () => _openForm(null),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 640) {
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              statusFilter,
              const SizedBox(width: 12),
              add,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: 10),
            Row(
              children: [
                statusFilter,
                const Spacer(),
                Flexible(child: add),
              ],
            ),
          ],
        );
      },
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
    _status = c?.status ?? 'active';
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
                colors: crmAmberGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text('${editing ? 'Edit' : 'Add'} Customer'),
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
                if (editing)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.subtle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer ID',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.customer!.id,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                NetField(
                  label: 'Name',
                  child: TextFormField(
                    controller: _name,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g., John Doe',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                _twoColumn(
                  NetField(
                    label: 'CNIC',
                    child: TextFormField(
                      controller: _cnic,
                      decoration: netInputDecoration(
                        context,
                        hint: 'e.g., 42201-1234567-8',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'CNIC is required'
                          : null,
                    ),
                  ),
                  NetField(
                    label: 'Phone',
                    child: TextFormField(
                      controller: _phone,
                      decoration: netInputDecoration(
                        context,
                        hint: 'e.g., 0300-1234567',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Phone is required'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _twoColumn(
                  NetField(
                    label: 'City',
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
                  NetField(
                    label: 'Status',
                    child: _StatusDropdown(
                      value: _status,
                      onChanged: (v) => setState(() => _status = v),
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
            foregroundColor: context.dangerText,
            side: BorderSide(color: context.dangerText.withValues(alpha: 0.3)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Save Customer',
          gradient: crmGreenGradient,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _twoColumn(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 14), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: netInputDecoration(context),
      items: [
        for (final s in _CustomersScreenState._statuses)
          DropdownMenuItem(
            value: s,
            child: Text(s[0].toUpperCase() + s.substring(1)),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
