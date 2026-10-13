import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'crm_common.dart';
import 'crm_models.dart';

/// Flutter counterpart of
/// `client/src/app/(app)/subscribers/corporate/page.tsx` — bulk connections and
/// corporate accounts.
class CorporateScreen extends StatefulWidget {
  const CorporateScreen({super.key});

  @override
  State<CorporateScreen> createState() => _CorporateScreenState();
}

class _CorporateScreenState extends State<CorporateScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<CrmCorporate> _clients = [];
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
      final json = await _api.get(
        '/subscribers/corporate',
        query: {'companyId': cid},
      );
      if (!mounted) return;
      setState(() {
        _clients = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(CrmCorporate.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<CrmCorporate> get _filtered => _clients
      .where(
        (c) => netContains(_filter, [c.id, c.companyName, c.contactPerson]),
      )
      .toList();

  List<CrmCorporate> get _pageRows {
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
    CrmCorporate? existing,
  ) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/subscribers/corporate/${existing.id}?companyId=$cid',
          body: values,
        );
      } else {
        await _api.post(
          '/subscribers/corporate?companyId=$cid',
          body: {...values, 'companyId': cid},
        );
      }
      await _load();
      if (mounted) {
        await showCrmFeedback(
          context,
          type: 'success',
          title: 'Success',
          message: existing != null
              ? 'Corporate client updated successfully.'
              : 'Corporate client added successfully.',
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

  Future<void> _delete(CrmCorporate client) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    await showNetworkDeleteDialog(
      context,
      itemName: client.companyName,
      onConfirm: () async {
        try {
          await _api.delete(
            '/subscribers/corporate/${client.id}?companyId=$cid',
          );
          await _load();
          if (mounted) {
            await showCrmFeedback(
              context,
              type: 'success',
              title: 'Success',
              message: 'Corporate client deleted successfully.',
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

  Future<void> _openForm(CrmCorporate? client) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CorporateFormDialog(client: client),
    );
    if (result != null) await _save(result, client);
  }

  @override
  Widget build(BuildContext context) {
    final totalConnections = _clients.fold<int>(
      0,
      (sum, c) => sum + c.totalConnections,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: CrmScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.business_outlined,
            title: 'Corporate Clients',
            subtitle: 'Manage bulk connections and corporate accounts.',
            gradient: crmIndigoGradient,
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
                          icon: Icons.business_outlined,
                          label: 'Total Clients',
                          value: '${_clients.length}',
                          gradient: crmIndigoGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.public,
                          label: 'Total Connections',
                          value: '$totalConnections',
                          gradient: crmGreenGradient,
                          valueColor: crmStatusActive,
                        ),
                        NetworkStatCard(
                          icon: Icons.groups_outlined,
                          label: 'Active Contracts',
                          value: '${_clients.length}',
                          gradient: crmAmberGradient,
                          valueColor: crmStatusSuspended,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _toolbar(context),
                    const SizedBox(height: 16),
                    NetworkTable<CrmCorporate>(
                      rows: _pageRows,
                      emptyIcon: Icons.business_outlined,
                      emptyTitle: 'No corporate clients found.',
                      emptyHint: 'Get started by adding a new client.',
                      emptyTint: AppColors.emerald600,
                      mobileTrailing: (context, c, _) => NetworkRowActions(
                        onEdit: () => _openForm(c),
                        onDelete: () => _delete(c),
                      ),
                      columns: [
                        NetColumn(
                          label: 'ID',
                          width: 90,
                          builder: (context, c, _) => Text(
                            c.id,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: context.mutedFg,
                            ),
                          ),
                        ),
                        NetColumn(
                          label: 'Company Name',
                          width: 200,
                          builder: (context, c, _) => Text(c.companyName),
                        ),
                        NetColumn(
                          label: 'Contact Person',
                          width: 170,
                          builder: (context, c, _) => Text(c.contactPerson),
                        ),
                        NetColumn(
                          label: 'Phone',
                          width: 140,
                          builder: (context, c, _) => Text(c.contactPhone),
                        ),
                        NetColumn(
                          label: 'Connections',
                          width: 120,
                          center: true,
                          builder: (context, c, _) => Text(
                            '${c.totalConnections}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        NetColumn(
                          label: 'Contract End',
                          width: 140,
                          builder: (context, c, _) => Text(c.contractEndDate),
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
                      noun: 'corporate clients',
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
            hint: 'Filter by company or contact name...',
          ).copyWith(
            prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
          ),
    );
    final add = GradientButton(
      label: 'Add Corporate Client',
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

class _CorporateFormDialog extends StatefulWidget {
  const _CorporateFormDialog({this.client});

  final CrmCorporate? client;

  @override
  State<_CorporateFormDialog> createState() => _CorporateFormDialogState();
}

class _CorporateFormDialogState extends State<_CorporateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _companyName;
  late final TextEditingController _contactPerson;
  late final TextEditingController _contactPhone;
  late final TextEditingController _pricing;
  late final TextEditingController _totalConnections;
  late String _startDate;
  late String _endDate;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _companyName = TextEditingController(text: c?.companyName ?? '');
    _contactPerson = TextEditingController(text: c?.contactPerson ?? '');
    _contactPhone = TextEditingController(text: c?.contactPhone ?? '');
    _pricing = TextEditingController(text: c?.negotiatedPricing ?? '');
    _totalConnections = TextEditingController(
      text: '${c?.totalConnections ?? 1}',
    );
    _startDate = (c?.contractStartDate.isNotEmpty ?? false)
        ? c!.contractStartDate
        : crmDateValue(DateTime.now());
    _endDate = c?.contractEndDate ?? '';
  }

  @override
  void dispose() {
    _companyName.dispose();
    _contactPerson.dispose();
    _contactPhone.dispose();
    _pricing.dispose();
    _totalConnections.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'companyName': _companyName.text.trim(),
      'contactPerson': _contactPerson.text.trim(),
      'contactPhone': _contactPhone.text.trim(),
      'negotiatedPricing': _pricing.text.trim(),
      'contractStartDate': _startDate,
      'contractEndDate': _endDate,
      'totalConnections': int.tryParse(_totalConnections.text.trim()) ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.client != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: crmIndigoGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.business_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text('${editing ? 'Edit' : 'Add'} Corporate Client'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NetField(
                  label: 'Company Name',
                  child: TextFormField(
                    controller: _companyName,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g., Acme Corp',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Company name is required'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                _twoColumn(
                  NetField(
                    label: 'Contact Person',
                    child: TextFormField(
                      controller: _contactPerson,
                      decoration: netInputDecoration(
                        context,
                        hint: 'e.g., John Doe',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Contact person is required'
                          : null,
                    ),
                  ),
                  NetField(
                    label: 'Contact Phone',
                    child: TextFormField(
                      controller: _contactPhone,
                      keyboardType: TextInputType.phone,
                      decoration: netInputDecoration(
                        context,
                        hint: 'e.g., 0300-1234567',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Contact phone is required'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _twoColumn(
                  NetField(
                    label: 'Contract Start Date',
                    child: CrmDateField(
                      value: _startDate,
                      onChanged: (v) => setState(() => _startDate = v),
                    ),
                  ),
                  NetField(
                    label: 'Contract End Date',
                    child: CrmDateField(
                      value: _endDate,
                      onChanged: (v) => setState(() => _endDate = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Total Connections',
                  child: TextFormField(
                    controller: _totalConnections,
                    keyboardType: TextInputType.number,
                    decoration: netInputDecoration(context),
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Pricing Details (Optional)',
                  child: TextFormField(
                    controller: _pricing,
                    maxLines: 3,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g., Flat 10% discount on all services',
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
          label: 'Save Client',
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
