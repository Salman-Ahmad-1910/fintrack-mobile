import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'crm_common.dart';
import 'crm_models.dart';

const List<Color> _purpleGradient = [Color(0xFFA855F7), Color(0xFF7C3AED)];

/// Flutter counterpart of `client/src/app/(app)/crm/packages/page.tsx` —
/// internet and cable packages with pricing.
class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<CrmPackage> _packages = [];
  List<CrmCompany> _companies = [];
  int _subscriberCount = 0;
  bool _loading = true;
  String _filter = '';
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
        _api.get('/billing/packages', query: {'companyId': cid}),
        _api.get('/subscribers', query: {'companyId': cid}),
        _api.get('/companies'),
      ]);
      if (!mounted) return;
      setState(() {
        _packages = ApiClient.listData(results[0])
            .whereType<Map<String, dynamic>>()
            .map(CrmPackage.fromJson)
            .toList();
        _subscriberCount = ApiClient.listData(results[1]).length;
        _companies = ApiClient.listData(results[2])
            .whereType<Map<String, dynamic>>()
            .map(CrmCompany.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<CrmPackage> get _filtered => _packages
      .where(
        (p) =>
            netContains(_filter, [p.id, p.name, p.companyName, p.packageType]),
      )
      .toList();

  List<CrmPackage> _byType(String type) =>
      _filtered.where((p) => p.packageType == type).toList();

  Future<void> _save(Map<String, dynamic> values, CrmPackage? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/billing/packages/${existing.id}?companyId=$cid',
          body: values,
        );
      } else {
        await _api.post(
          '/billing/packages?companyId=$cid',
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
              ? 'Package updated successfully.'
              : 'Package added successfully.',
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

  int _inUseCount(CrmPackage pkg) => _subscriberCount;

  Future<void> _delete(CrmPackage pkg) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    final inUse = _inUseCount(pkg);
    await showNetworkDeleteDialog(
      context,
      itemName: pkg.name,
      onConfirm: () async {
        try {
          await _api.delete('/billing/packages/${pkg.id}?companyId=$cid');
          await _load();
          if (mounted) {
            await showCrmFeedback(
              context,
              type: 'success',
              title: 'Success',
              message: 'Package deleted successfully.',
            );
          }
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          final msg =
              (e.message.contains('foreign key') ||
                  e.message.contains('violates'))
              ? 'Cannot delete package: It is being used by one or more subscribers. '
                    'Please reassign or delete those subscribers first.'
              : e.message;
          if (mounted) {
            await showCrmFeedback(
              context,
              type: 'error',
              title: 'Error',
              message: msg,
            );
          }
        }
      },
    );
    // Force a rebuild in case the in-use count changed.
    if (mounted && inUse > 0) setState(() {});
  }

  Future<void> _openForm(CrmPackage? pkg) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PackageFormDialog(pkg: pkg, companies: _companies),
    );
    if (result != null) await _save(result, pkg);
  }

  @override
  Widget build(BuildContext context) {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      return CrmScrollBody(
        children: const [
          NetworkPageHeader(
            icon: Icons.receipt_long_outlined,
            title: 'Internet Packages',
            subtitle: 'Define and manage your subscriber packages and pricing.',
            gradient: crmRoseGradient,
          ),
          AppCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Please select a company to manage packages.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    final internetCount = _packages
        .where((p) => p.packageType == 'Internet')
        .length;
    final tvCableCount = _packages
        .where((p) => p.packageType == 'TV Cable')
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: CrmScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.receipt_long_outlined,
            title: 'Internet Packages',
            subtitle: 'Define and manage your subscriber packages and pricing.',
            gradient: crmRoseGradient,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            NetworkStatGrid(
              maxColumns: 4,
              children: [
                NetworkStatCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Total Packages',
                  value: '${_packages.length}',
                  gradient: crmRoseGradient,
                ),
                NetworkStatCard(
                  icon: Icons.wifi,
                  label: 'Internet Packages',
                  value: '$internetCount',
                  gradient: crmBlueGradient,
                ),
                NetworkStatCard(
                  icon: Icons.sell_outlined,
                  label: 'TV Cable Packages',
                  value: '$tvCableCount',
                  gradient: _purpleGradient,
                ),
                NetworkStatCard(
                  icon: Icons.storage_outlined,
                  label: 'Subscribers on Packages',
                  value: '$_subscriberCount',
                  gradient: crmGreenGradient,
                  valueColor: crmStatusActive,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _toolbar(context),
            const SizedBox(height: 20),
            _typeSection(
              context,
              title: 'TV Cable Packages',
              description:
                  'Packages for cable TV subscribers '
                  '($tvCableCount packages)',
              icon: Icons.sell_outlined,
              iconColor: const Color(0xFF9333EA),
              rows: _byType('TV Cable'),
              emptyTitle: 'No TV Cable packages found.',
            ),
            const SizedBox(height: 20),
            _typeSection(
              context,
              title: 'Internet Packages',
              description:
                  'Packages for internet subscribers '
                  '($internetCount packages)',
              icon: Icons.wifi,
              iconColor: crmBlueGradient.last,
              rows: _byType('Internet'),
              emptyTitle: 'No Internet packages found.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _typeSection(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required List<CrmPackage> rows,
    required String emptyTitle,
  }) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.fg,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(fontSize: 13, color: context.mutedFg),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: context.line, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: NetworkTable<CrmPackage>(
              rows: rows,
              emptyIcon: Icons.inventory_2_outlined,
              emptyTitle: emptyTitle,
              emptyHint: 'Click "Add Package" to create one.',
              emptyTint: iconColor,
              mobileTrailing: (context, p, _) => NetworkRowActions(
                onEdit: () => _openForm(p),
                onDelete: () => _delete(p),
              ),
              columns: [
                NetColumn(
                  label: 'Package ID',
                  width: 120,
                  builder: (context, p, _) => Text(
                    p.packageNumber.isEmpty ? '-' : p.packageNumber,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
                NetColumn(
                  label: 'Package Name',
                  width: 180,
                  builder: (context, p, _) => Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                NetColumn(
                  label: 'Company Name',
                  width: 170,
                  builder: (context, p, _) =>
                      Text(p.companyName.isEmpty ? '-' : p.companyName),
                ),
                NetColumn(
                  label: 'Sale Price (PKR)',
                  width: 140,
                  center: true,
                  builder: (context, p, _) => SizedBox(
                    width: double.infinity,
                    child: Text(
                      crmNumber(p.salePrice),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                NetColumn(
                  label: 'Purchase Price (PKR)',
                  width: 160,
                  center: true,
                  builder: (context, p, _) => SizedBox(
                    width: double.infinity,
                    child: Text(
                      crmNumber(p.purchasePrice),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                NetColumn(
                  label: '',
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
          ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final search = TextField(
      controller: _search,
      onChanged: (v) => setState(() => _filter = v),
      style: const TextStyle(fontSize: 14),
      decoration:
          netInputDecoration(
            context,
            hint: 'Filter by name or company...',
          ).copyWith(
            prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
          ),
    );
    final add = GradientButton(
      label: 'Add Package',
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

class _PackageFormDialog extends StatefulWidget {
  const _PackageFormDialog({this.pkg, required this.companies});

  final CrmPackage? pkg;
  final List<CrmCompany> companies;

  @override
  State<_PackageFormDialog> createState() => _PackageFormDialogState();
}

class _PackageFormDialogState extends State<_PackageFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _salePrice;
  late final TextEditingController _purchasePrice;
  String? _companyName;
  late String _packageType;

  @override
  void initState() {
    super.initState();
    final p = widget.pkg;
    _name = TextEditingController(text: p?.name ?? '');
    _salePrice = TextEditingController(
      text: p != null && p.salePrice != 0 ? '${p.salePrice}' : '',
    );
    _purchasePrice = TextEditingController(
      text: p != null && p.purchasePrice != 0 ? '${p.purchasePrice}' : '',
    );
    _companyName = (p?.companyName.isNotEmpty ?? false) ? p!.companyName : null;
    _packageType = p?.packageType ?? 'Internet';
  }

  @override
  void dispose() {
    _name.dispose();
    _salePrice.dispose();
    _purchasePrice.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'speed': '',
      'price': double.tryParse(_salePrice.text.trim()) ?? 0,
      'dataLimit': 'Unlimited',
      'companyName': _companyName ?? '',
      'salePrice': double.tryParse(_salePrice.text.trim()) ?? 0,
      'purchasePrice': double.tryParse(_purchasePrice.text.trim()) ?? 0,
      'packageType': _packageType,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.pkg != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: crmRoseGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text('${editing ? 'Edit' : 'Add'} Package'),
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
                  label: 'Package Name',
                  child: TextFormField(
                    controller: _name,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g., Bronze',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Company Name',
                  child: DropdownButtonFormField<String>(
                    initialValue: _companyName,
                    isExpanded: true,
                    decoration: netInputDecoration(context),
                    hint: const Text('Select company'),
                    items: [
                      for (final c in widget.companies)
                        DropdownMenuItem(value: c.name, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _companyName = v),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: NetField(
                        label: 'Sale Price (PKR)',
                        child: TextFormField(
                          controller: _salePrice,
                          keyboardType: TextInputType.number,
                          decoration: netInputDecoration(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: NetField(
                        label: 'Purchase Price (PKR)',
                        child: TextFormField(
                          controller: _purchasePrice,
                          keyboardType: TextInputType.number,
                          decoration: netInputDecoration(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Package Type',
                  child: DropdownButtonFormField<String>(
                    initialValue: _packageType,
                    decoration: netInputDecoration(context),
                    items: const [
                      DropdownMenuItem(
                        value: 'Internet',
                        child: Text('Internet'),
                      ),
                      DropdownMenuItem(
                        value: 'TV Cable',
                        child: Text('TV Cable'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _packageType = v);
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
          label: 'Save Package',
          gradient: crmGreenGradient,
          onPressed: _submit,
        ),
      ],
    );
  }
}
