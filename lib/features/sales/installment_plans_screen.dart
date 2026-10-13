import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'sales_common.dart';
import 'sales_models.dart';

/// Flutter counterpart of
/// `client/src/app/(app)/sales/installment-plans/page.tsx` — create and manage
/// installment plans (name, number of installments, percentage increase).
class InstallmentPlansScreen extends StatefulWidget {
  const InstallmentPlansScreen({super.key});

  @override
  State<InstallmentPlansScreen> createState() => _InstallmentPlansScreenState();
}

class _InstallmentPlansScreenState extends State<InstallmentPlansScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<SalesPlan> _plans = [];
  bool _loading = true;
  String _filter = '';
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

  List<SalesPlan> get _filtered =>
      _plans.where((p) => salesPrefixMatch(_filter, [p.name])).toList();

  List<SalesPlan> get _paged {
    final start = (_page - 1) * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final json = await _api.get(
        'sales/installment-plans',
        query: {'companyId': cid},
      );
      if (!mounted) return;
      setState(() {
        _plans = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(SalesPlan.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save(Map<String, dynamic> values, SalesPlan? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          'sales/installment-plans/${existing.id}?companyId=$cid',
          body: values,
        );
      } else {
        await _api.post(
          'sales/installment-plans?companyId=$cid',
          body: {...values, 'companyId': cid},
        );
      }
      await _load();
      if (mounted) {
        showToast(
          context,
          existing != null
              ? 'Plan updated successfully.'
              : 'Plan added successfully.',
        );
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(SalesPlan plan) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    await showNetworkDeleteDialog(
      context,
      itemName: plan.name,
      onConfirm: () async {
        try {
          await _api.delete(
            'sales/installment-plans/${plan.id}?companyId=$cid',
          );
          await _load();
          if (mounted) showToast(context, 'Plan deleted successfully.');
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openForm(SalesPlan? plan) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PlanFormDialog(plan: plan),
    );
    if (result != null) await _save(result, plan);
  }

  @override
  Widget build(BuildContext context) {
    final cid = _cid;
    final activePlans = _plans.where((p) => p.isActive).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.event_available_outlined,
            title: 'Installment Plans',
            subtitle: 'Create and manage installment plans.',
            gradient: salesRoseGradient,
          ),
          if (cid == null || cid.isEmpty)
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: const Text(
                  'Please select a company to manage installment plans.',
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
              maxColumns: 2,
              children: [
                NetworkStatCard(
                  icon: Icons.pie_chart_outline,
                  label: 'Total Plans',
                  value: '${_plans.length}',
                  gradient: salesRoseGradient,
                ),
                NetworkStatCard(
                  icon: Icons.schedule,
                  label: 'Active Plans',
                  value: '$activePlans',
                  gradient: salesEmeraldGradient,
                  valueColor: salesGoodSaleColor,
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
                        hint: 'Filter by plan name...',
                      ).copyWith(
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: context.mutedFg,
                        ),
                      ),
                );
                final add = GradientButton(
                  label: 'Add Plan',
                  icon: Icons.add_circle_outline,
                  gradient: salesEmeraldGradient,
                  onPressed: () => _openForm(null),
                );
                return SalesFilterRows(
                  rows: [
                    [SizedBox(width: 300, child: search)],
                    [add],
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
                NetworkTable<SalesPlan>(
                  rows: _paged,
                  emptyIcon: Icons.event_available_outlined,
                  emptyTitle: 'No installment plans found.',
                  emptyHint: 'Click "Add Plan" to create one.',
                  emptyTint: salesRoseGradient.first,
                  mobileTrailing: (context, p, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit plan',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _openForm(p),
                      ),
                      IconButton(
                        tooltip: 'Delete plan',
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: context.dangerText,
                        ),
                        onPressed: () => _delete(p),
                      ),
                    ],
                  ),
                  columns: [
                    NetColumn(
                      label: 'Plan Name',
                      width: 240,
                      builder: (context, p, _) => Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    NetColumn(
                      label: 'Installments',
                      width: 160,
                      center: true,
                      builder: (context, p, _) => Text('${p.installments}'),
                    ),
                    NetColumn(
                      label: 'Percentage Increase',
                      width: 200,
                      center: true,
                      builder: (context, p, _) =>
                          Text('${p.percentageIncrease}%'),
                    ),
                    NetColumn(
                      label: 'Actions',
                      width: 96,
                      isActions: true,
                      builder: (context, p, _) => Align(
                        alignment: Alignment.centerRight,
                        child: NetworkRowActions(
                          onEdit: () => _openForm(p),
                          onDelete: () => _delete(p),
                        ),
                      ),
                    ),
                  ],
                ),
                NetworkPagination(
                  currentPage: _page,
                  pageSize: _pageSize,
                  totalItems: _filtered.length,
                  noun: 'plans',
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
}

class _PlanFormDialog extends StatefulWidget {
  const _PlanFormDialog({this.plan});

  final SalesPlan? plan;

  @override
  State<_PlanFormDialog> createState() => _PlanFormDialogState();
}

class _PlanFormDialogState extends State<_PlanFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _installments;
  late final TextEditingController _percentage;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _name = TextEditingController(text: p?.name ?? '');
    _installments = TextEditingController(text: '${p?.installments ?? 1}');
    _percentage = TextEditingController(text: '${p?.percentageIncrease ?? 0}');
  }

  @override
  void dispose() {
    _name.dispose();
    _installments.dispose();
    _percentage.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'installments': int.tryParse(_installments.text.trim()) ?? 0,
      'percentageIncrease': double.tryParse(_percentage.text.trim()) ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.plan != null;
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
              Icons.hourglass_bottom,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text('${editing ? 'Edit' : 'Create'} Installment Plan'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NetField(
                  label: 'Plan Name',
                  child: TextFormField(
                    controller: _name,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g., 6-Month Easy Plan',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Plan name is required'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Number of Installments',
                  child: TextFormField(
                    controller: _installments,
                    keyboardType: TextInputType.number,
                    decoration: netInputDecoration(context),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1) return 'Enter 1 or more';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Percentage Increase (%)',
                  child: TextFormField(
                    controller: _percentage,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: netInputDecoration(context),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null || n < 0) return 'Enter 0 or more';
                      return null;
                    },
                  ),
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
          label: 'Save Plan',
          gradient: salesEmeraldGradient,
          onPressed: _submit,
        ),
      ],
    );
  }
}
