import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import 'inventory_common.dart';
import 'inventory_models.dart';

/// Flutter counterpart of `client/src/app/(app)/inventory/vendors/page.tsx` —
/// manage suppliers and vendors for inventory purchases.
class VendorsScreen extends StatefulWidget {
  const VendorsScreen({super.key});

  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<Vendor> _vendors = [];
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
      final json = await _api.get(
        '/inventory/vendors',
        query: {'companyId': cid},
      );
      if (!mounted) return;
      setState(() {
        _vendors = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(Vendor.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Vendor> get _filtered {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return _vendors;
    return _vendors.where((v) {
      for (final value in [v.phone, v.name, v.contactPerson, v.email]) {
        if (value.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  Future<void> _save(Map<String, dynamic> values, Vendor? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put('/inventory/vendors/${existing.id}', body: values);
        if (mounted) showToast(context, 'Vendor updated successfully');
      } else {
        await _api.post('/inventory/vendors', body: values);
        if (mounted) showToast(context, 'Vendor created successfully');
      }
      await _load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _delete(Vendor vendor) async {
    await showNetworkDeleteDialog(
      context,
      itemName: vendor.name,
      onConfirm: () async {
        try {
          await _api.delete('/inventory/vendors/${vendor.id}');
          if (mounted) showToast(context, 'Vendor deleted successfully');
          await _load();
        } on ApiException catch (e) {
          if (e.isUnauthorized) return;
          if (mounted) showToast(context, e.message, error: true);
        }
      },
    );
  }

  Future<void> _openForm(Vendor? vendor) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _VendorFormDialog(vendor: vendor),
    );
    if (result != null) await _save(result, vendor);
  }

  @override
  Widget build(BuildContext context) {
    final withContact = _vendors
        .where((v) => v.contactPerson.isNotEmpty || v.phone.isNotEmpty)
        .length;
    final withPhone = _vendors.where((v) => v.phone.isNotEmpty).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.local_shipping_outlined,
            title: 'Vendors',
            subtitle:
                'Manage your suppliers and vendors for inventory purchases.',
            gradient: invVendorGradient,
          ),
          NetworkStatGrid(
            children: [
              NetworkStatCard(
                icon: Icons.local_shipping_outlined,
                label: 'Total Vendors',
                value: '${_vendors.length}',
                gradient: invVendorGradient,
              ),
              NetworkStatCard(
                icon: Icons.business_outlined,
                label: 'With Contact',
                value: '$withContact',
                gradient: invEmeraldStatGradient,
                valueColor: AppColors.emerald600,
              ),
              NetworkStatCard(
                icon: Icons.phone_outlined,
                label: 'With Phone',
                value: '$withPhone',
                gradient: invAmberStatGradient,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _toolbar(context),
                  const SizedBox(height: 16),
                  NetworkTable<Vendor>(
                    rows: _filtered,
                    emptyIcon: Icons.local_shipping_outlined,
                    emptyTitle: 'No vendors found.',
                    emptyHint: 'Get started by adding a new vendor.',
                    emptyTint: AppColors.emerald600,
                    mobileTrailing: (context, vendor, _) => NetworkRowActions(
                      onEdit: () => _openForm(vendor),
                      onDelete: () => _delete(vendor),
                    ),
                    columns: [
                      NetColumn(
                        label: 'ID',
                        width: 50,
                        builder: (context, vendor, index) => Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Vendor Name',
                        width: 180,
                        builder: (context, vendor, _) => Text(
                          vendor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      NetColumn(
                        label: 'Contact Person',
                        width: 160,
                        builder: (context, vendor, _) => vendor.contactPerson.isEmpty
                            ? Text(
                                '-',
                                style: TextStyle(color: context.mutedFg),
                              )
                            : Text(
                                vendor.contactPerson,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      NetColumn(
                        label: 'Phone',
                        width: 160,
                        builder: (context, vendor, _) =>
                            _iconCell(context, Icons.phone, vendor.phone),
                      ),
                      NetColumn(
                        label: 'Email',
                        width: 200,
                        builder: (context, vendor, _) =>
                            _iconCell(context, Icons.mail_outline, vendor.email),
                      ),
                      NetColumn(
                        label: 'Address',
                        width: 220,
                        builder: (context, vendor, _) =>
                            _iconCell(context, Icons.location_on_outlined, vendor.address),
                      ),
                      NetColumn(
                        label: '',
                        width: 96,
                        isActions: true,
                        builder: (context, vendor, _) => Align(
                          alignment: Alignment.centerRight,
                          child: NetworkRowActions(
                            onEdit: () => _openForm(vendor),
                            onDelete: () => _delete(vendor),
                            editTooltip: 'Edit Vendor',
                            deleteTooltip: 'Delete Vendor',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconCell(BuildContext context, IconData icon, String value) {
    if (value.isEmpty) {
      return Text('-', style: TextStyle(color: context.mutedFg));
    }
    return Row(
      children: [
        Icon(icon, size: 13, color: context.mutedFg),
        const SizedBox(width: 4),
        Flexible(
          child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context) {
    final search = TextField(
      controller: _search,
      onChanged: (v) => setState(() => _filter = v),
      style: const TextStyle(fontSize: 14),
      decoration: netInputDecoration(
        context,
        hint: 'Search vendors...',
      ).copyWith(
        prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
      ),
    );
    final add = GradientButton(
      label: 'Add Vendor',
      icon: Icons.add_circle_outline,
      gradient: invEmeraldButtonGradient,
      onPressed: () => _openForm(null),
    );
    return InvFilterBar(
      filterWidth: 360,
      filters: [search],
      actions: [add],
    );
  }
}

class _VendorFormDialog extends StatefulWidget {
  const _VendorFormDialog({this.vendor});

  final Vendor? vendor;

  @override
  State<_VendorFormDialog> createState() => _VendorFormDialogState();
}

class _VendorFormDialogState extends State<_VendorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.vendor?.name ?? '');
  late final TextEditingController _contact =
      TextEditingController(text: widget.vendor?.contactPerson ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.vendor?.phone ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.vendor?.email ?? '');
  late final TextEditingController _address =
      TextEditingController(text: widget.vendor?.address ?? '');

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'contactPerson': _contact.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'address': _address.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.vendor != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: invVendorGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              editing ? 'Edit Vendor' : 'Add New Vendor',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pair(
                  NetField(
                    label: 'Vendor Name *',
                    child: TextFormField(
                      controller: _name,
                      decoration: netInputDecoration(
                        context,
                        hint: 'e.g., Tech Supplies Inc.',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Vendor name is required'
                          : null,
                    ),
                  ),
                  NetField(
                    label: 'Contact Person',
                    child: TextFormField(
                      controller: _contact,
                      decoration: netInputDecoration(
                        context,
                        hint: 'e.g., John Smith',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _pair(
                  NetField(
                    label: 'Phone',
                    child: TextFormField(
                      controller: _phone,
                      decoration: netInputDecoration(
                        context,
                        hint: 'e.g., +1-555-0123',
                      ),
                    ),
                  ),
                  NetField(
                    label: 'Email',
                    child: TextFormField(
                      controller: _email,
                      decoration: netInputDecoration(
                        context,
                        hint: 'e.g., contact@techsupplies.com',
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return null;
                        final ok = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(value);
                        return ok ? null : 'Enter a valid email';
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Address',
                  child: TextFormField(
                    controller: _address,
                    maxLines: 3,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g., 123 Business St, Suite 100, City, State',
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
            foregroundColor: context.mutedFg,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: 'Save Vendor',
          gradient: invEmeraldButtonGradient,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _pair(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 420) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: 14),
              Expanded(child: b),
            ],
          );
        }
        return Column(
          children: [a, const SizedBox(height: 14), b],
        );
      },
    );
  }
}
