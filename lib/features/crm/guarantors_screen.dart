import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'crm_common.dart';
import 'crm_models.dart';

/// Flutter counterpart of `client/src/app/(app)/crm/guarantors/page.tsx` —
/// customer guarantors and their information.
class GuarantorsScreen extends StatefulWidget {
  const GuarantorsScreen({super.key});

  @override
  State<GuarantorsScreen> createState() => _GuarantorsScreenState();
}

class _GuarantorsScreenState extends State<GuarantorsScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<CrmGuarantor> _guarantors = [];
  List<CrmCustomer> _customers = [];
  bool _loading = true;
  String _filter = '';
  int _page = 1;
  int _pageSize = 10;
  final TextEditingController _search = TextEditingController();

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
      final results = await Future.wait([
        _api.get('/crm/guarantors', query: {'companyId': cid}),
        _api.get('/crm/customers', query: {'companyId': cid}),
      ]);
      if (!mounted) return;
      setState(() {
        _guarantors = ApiClient.listData(results[0])
            .whereType<Map<String, dynamic>>()
            .map(CrmGuarantor.fromJson)
            .toList();
        _customers = ApiClient.listData(results[1])
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

  List<CrmGuarantor> get _filtered => _guarantors
      .where(
        (g) => netContains(_filter, [g.id, g.cnic, g.name, g.customerName]),
      )
      .toList();

  List<CrmGuarantor> get _pageRows {
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

  Future<void> _save(
    Map<String, dynamic> values,
    CrmGuarantor? existing,
  ) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    final customerId = values['customerId'] as String;
    CrmCustomer? customer;
    for (final c in _customers) {
      if (c.id == customerId) {
        customer = c;
        break;
      }
    }
    if (customer == null) {
      await showCrmFeedback(
        context,
        type: 'error',
        title: 'Error',
        message: 'Selected customer not found.',
      );
      return;
    }
    try {
      if (existing != null) {
        await _api.put(
          '/crm/guarantors/${existing.id}?companyId=$cid',
          body: values,
        );
      } else {
        await _api.post(
          '/crm/guarantors?companyId=$cid',
          body: {...values, 'companyId': cid, 'customerName': customer.name},
        );
      }
      await _load();
      if (mounted) {
        await showCrmFeedback(
          context,
          type: 'success',
          title: 'Success',
          message: existing != null
              ? 'Guarantor updated successfully.'
              : 'Guarantor added successfully.',
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

  Future<void> _delete(CrmGuarantor guarantor) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    await showNetworkDeleteDialog(
      context,
      itemName: guarantor.name,
      onConfirm: () async {
        try {
          await _api.delete('/crm/guarantors/${guarantor.id}?companyId=$cid');
          await _load();
          if (mounted) {
            await showCrmFeedback(
              context,
              type: 'success',
              title: 'Success',
              message: 'Guarantor deleted successfully.',
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

  Future<void> _openForm(CrmGuarantor? guarantor) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _GuarantorFormDialog(guarantor: guarantor, customers: _customers),
    );
    if (result != null) await _save(result, guarantor);
  }

  @override
  Widget build(BuildContext context) {
    final uniqueCustomers = _guarantors
        .map((g) => g.customerName)
        .toSet()
        .length;
    final avg = uniqueCustomers > 0 ? _guarantors.length / uniqueCustomers : 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: CrmScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.verified_user_outlined,
            title: 'Guarantors',
            subtitle: 'Manage customer guarantors and their information.',
            gradient: crmTealGradient,
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
                      children: [
                        NetworkStatCard(
                          icon: Icons.verified_user_outlined,
                          label: 'Total Guarantors',
                          value: '${_guarantors.length}',
                          gradient: crmTealGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.shield_outlined,
                          label: 'Unique Customers',
                          value: '$uniqueCustomers',
                          gradient: crmGreenGradient,
                          valueColor: crmStatusActive,
                        ),
                        NetworkStatCard(
                          icon: Icons.groups_outlined,
                          label: 'Avg per Customer',
                          value: crmFixed1(avg),
                          gradient: crmAmberGradient,
                          valueColor: crmStatusSuspended,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _toolbar(context),
                    const SizedBox(height: 16),
                    NetworkTable<CrmGuarantor>(
                      rows: _pageRows,
                      emptyIcon: Icons.verified_user_outlined,
                      emptyTitle: 'No guarantors found.',
                      emptyHint: 'Get started by adding a new guarantor.',
                      emptyTint: AppColors.emerald600,
                      mobileTrailing: (context, g, _) => NetworkRowActions(
                        onEdit: () => _openForm(g),
                        onDelete: () => _delete(g),
                      ),
                      columns: [
                        NetColumn(
                          label: 'ID',
                          width: 60,
                          builder: (context, g, index) => Text(
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
                          builder: (context, g, _) => Text(g.name),
                        ),
                        NetColumn(
                          label: 'CNIC',
                          width: 160,
                          builder: (context, g, _) => Text(g.cnic),
                        ),
                        NetColumn(
                          label: 'Phone',
                          width: 140,
                          builder: (context, g, _) => Text(g.phone),
                        ),
                        NetColumn(
                          label: 'Customer',
                          width: 180,
                          builder: (context, g, _) => Text(g.customerName),
                        ),
                        NetColumn(
                          label: '',
                          width: 96,
                          isActions: true,
                          builder: (context, g, _) => Align(
                            alignment: Alignment.centerRight,
                            child: NetworkRowActions(
                              onEdit: () => _openForm(g),
                              onDelete: () => _delete(g),
                            ),
                          ),
                        ),
                      ],
                    ),
                    NetworkPagination(
                      currentPage: _page,
                      pageSize: _pageSize,
                      totalItems: _filtered.length,
                      noun: 'guarantors',
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

  Widget _toolbar(BuildContext context) {
    final search = TextField(
      controller: _search,
      onChanged: _setFilter,
      style: const TextStyle(fontSize: 14),
      decoration:
          netInputDecoration(
            context,
            hint: 'Filter by name, CNIC, or customer...',
          ).copyWith(
            prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
          ),
    );
    final add = GradientButton(
      label: 'Add Guarantor',
      icon: Icons.add_circle_outline,
      gradient: crmGreenGradient,
      onPressed: () => _openForm(null),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            children: [
              Expanded(child: search),
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
            Align(alignment: Alignment.centerRight, child: add),
          ],
        );
      },
    );
  }
}

class _GuarantorFormDialog extends StatefulWidget {
  const _GuarantorFormDialog({this.guarantor, required this.customers});

  final CrmGuarantor? guarantor;
  final List<CrmCustomer> customers;

  @override
  State<_GuarantorFormDialog> createState() => _GuarantorFormDialogState();
}

class _GuarantorFormDialogState extends State<_GuarantorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _cnic;
  late final TextEditingController _phone;
  String? _customerId;

  @override
  void initState() {
    super.initState();
    final g = widget.guarantor;
    _name = TextEditingController(text: g?.name ?? '');
    _cnic = TextEditingController(text: g?.cnic ?? '');
    _phone = TextEditingController(text: g?.phone ?? '');
    _customerId = (g?.customerId.isNotEmpty ?? false) ? g!.customerId : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _cnic.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Customer is required')));
      return;
    }
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'cnic': _cnic.text.trim(),
      'phone': _phone.text.trim(),
      'customerId': _customerId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.guarantor != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: crmTealGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text('${editing ? 'Edit' : 'Add'} Guarantor'),
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
                  label: 'Guarantor Name',
                  child: TextFormField(
                    controller: _name,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g., John Smith',
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
                        label: 'CNIC',
                        child: TextFormField(
                          controller: _cnic,
                          decoration: netInputDecoration(
                            context,
                            hint: 'e.g., 42201-8765432-1',
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
                        label: 'Phone',
                        child: TextFormField(
                          controller: _phone,
                          decoration: netInputDecoration(
                            context,
                            hint: 'e.g., 0321-1234567',
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
                NetField(
                  label: 'Customer to Guarantee',
                  child: DropdownButtonFormField<String>(
                    initialValue: _customerId,
                    isExpanded: true,
                    decoration: netInputDecoration(context),
                    hint: const Text('Select a customer'),
                    items: [
                      for (final c in widget.customers)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _customerId = v),
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
          label: 'Save Guarantor',
          gradient: crmGreenGradient,
          onPressed: _submit,
        ),
      ],
    );
  }
}
