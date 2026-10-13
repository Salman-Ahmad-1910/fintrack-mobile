import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../network/network_common.dart';
import '../network/network_models.dart';
import 'crm_common.dart';
import 'crm_models.dart';

/// Web `calcDiscountedAmount(base, discount)`.
int calcDiscountedAmount(num base, String discount) {
  switch (discount) {
    case 'quarter':
      return (base * 0.75).round();
    case 'half':
      return (base * 0.50).round();
    case 'full_free':
      return 0;
    case 'no_discount':
    case 'custom':
    default:
      return base.round();
  }
}

const List<MapEntry<String, String>> _discountOptions = [
  MapEntry('no_discount', 'No discount'),
  MapEntry('quarter', 'Quarter'),
  MapEntry('half', 'Half'),
  MapEntry('full_free', 'Full Free'),
  MapEntry('custom', 'Custom'),
];

const List<MapEntry<String, String>> _connectionTypeOptions = [
  MapEntry('both', 'Both'),
  MapEntry('internet', 'Internet'),
  MapEntry('tv_cable', 'TV Cable'),
];

const List<MapEntry<String, String>> _statusOptions = [
  MapEntry('active', 'Active'),
  MapEntry('inactive', 'Inactive'),
  MapEntry('deactivated', 'Deactivated'),
  MapEntry('suspended', 'Suspended'),
];

/// Flutter counterpart of the web `ConnectionForm`
/// (`crm/subscriber-detail/_components/connection-form.tsx`). Shows as a
/// dialog; returns the connection payload map on save.
class ConnectionFormDialog extends StatefulWidget {
  const ConnectionFormDialog({
    super.key,
    required this.areas,
    required this.boxes,
    required this.packages,
    required this.companies,
    required this.splitters,
    this.connection,
  });

  final List<NetArea> areas;
  final List<NetBox> boxes;
  final List<CrmPackage> packages;
  final List<CrmCompany> companies;
  final List<NetSplitter> splitters;
  final Conn? connection;

  @override
  State<ConnectionFormDialog> createState() => _ConnectionFormDialogState();
}

class _ConnectionFormDialogState extends State<ConnectionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _internetId;
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _cell;
  late final TextEditingController _mobile;
  late final TextEditingController _installationAmount;
  late final TextEditingController _otherAmount;
  late final TextEditingController _amount;
  late final TextEditingController _sameAmount;
  late final TextEditingController _balanceDays;
  late final TextEditingController _transactionId;

  String? _sublocalityId;
  String? _connectionProvider;
  late String _connectionType;
  late String _status;
  String? _boxNumber;
  String? _splitterId;
  late final TextEditingController _splitterPort;
  String? _cablePkgId;
  String? _internetPkgId;
  late String _discount;
  late String _sameDiscount;
  late bool _createBalance;
  late String _installationDate;
  late String _rechargeDate;

  @override
  void initState() {
    super.initState();
    final c = widget.connection;
    _internetId = TextEditingController(text: c?.internetId ?? '');
    _name = TextEditingController(text: c?.name ?? '');
    _address = TextEditingController(text: c?.address ?? '');
    _cell = TextEditingController(text: c?.cell ?? '');
    _mobile = TextEditingController(text: c?.mobile ?? '');
    _installationAmount = TextEditingController(
      text: _num(c?.installationAmount),
    );
    _otherAmount = TextEditingController(text: _num(c?.otherAmount));
    _amount = TextEditingController(text: _num(c?.amount));
    _sameAmount = TextEditingController(text: _num(c?.sameAmount));
    _balanceDays = TextEditingController(text: _num(c?.balanceDays));
    _transactionId = TextEditingController(text: c?.transactionId ?? '');
    _sublocalityId = (c?.sublocalityId.isNotEmpty ?? false)
        ? c!.sublocalityId
        : null;
    _connectionProvider = (c?.connectionProvider.isNotEmpty ?? false)
        ? c!.connectionProvider
        : null;
    _connectionType = c?.connectionType ?? 'both';
    _status = c?.status ?? 'active';
    _boxNumber = (c?.boxNumber.isNotEmpty ?? false) ? c!.boxNumber : null;
    _splitterId = (c?.splitterId.isNotEmpty ?? false) ? c!.splitterId : null;
    _splitterPort = TextEditingController(text: _num(c?.splitterPort));
    _discount = c?.discount ?? '';
    _sameDiscount = c?.sameDiscount ?? '';
    _createBalance = c?.createBalance ?? false;
    _installationDate = c?.installationDate ?? '';
    _rechargeDate = c?.rechargeDate ?? '';
    _cablePkgId = _resolvePkgId(c?.packageCable);
    _internetPkgId = _resolvePkgId(c?.packageInternet);
  }

  static String _num(num? value) {
    if (value == null || value == 0) return '';
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  String? _resolvePkgId(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final p in widget.packages) {
      if (p.name == name) return p.id;
    }
    return null;
  }

  CrmPackage? _pkgById(String? id) {
    if (id == null) return null;
    for (final p in widget.packages) {
      if (p.id == id) return p;
    }
    return null;
  }

  CrmPackage? get _selectedCablePkg => _pkgById(_cablePkgId);
  CrmPackage? get _selectedInternetPkg => _pkgById(_internetPkgId);

  double get _cableBase => _selectedCablePkg?.effectivePrice ?? 0;
  double get _internetBase => _selectedInternetPkg?.effectivePrice ?? 0;

  bool get _showCable =>
      _connectionType == 'both' || _connectionType == 'tv_cable';
  bool get _showInternet =>
      _connectionType == 'both' || _connectionType == 'internet';

  List<CrmPackage> get _cablePackages =>
      widget.packages.where((p) => p.packageType == 'TV Cable').toList();
  List<CrmPackage> get _internetPackages =>
      widget.packages.where((p) => p.packageType == 'Internet').toList();

  void _recomputeCable() {
    if (_discount == 'custom') return;
    if (_showCable && _cableBase > 0) {
      _amount.text = '${calcDiscountedAmount(_cableBase, _discount)}';
    }
  }

  void _recomputeInternet() {
    if (_sameDiscount == 'custom') return;
    if (_showInternet && _internetBase > 0) {
      _sameAmount.text =
          '${calcDiscountedAmount(_internetBase, _sameDiscount)}';
    }
  }

  @override
  void dispose() {
    _internetId.dispose();
    _name.dispose();
    _address.dispose();
    _cell.dispose();
    _mobile.dispose();
    _installationAmount.dispose();
    _otherAmount.dispose();
    _amount.dispose();
    _sameAmount.dispose();
    _balanceDays.dispose();
    _transactionId.dispose();
    _splitterPort.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'internetId': _internetId.text.trim(),
      'sublocalityId': _sublocalityId ?? '',
      'name': _name.text.trim(),
      'address': _address.text.trim(),
      'cell': _cell.text.trim(),
      'mobile': _mobile.text.trim(),
      'installationAmount':
          double.tryParse(_installationAmount.text.trim()) ?? 0,
      'otherAmount': double.tryParse(_otherAmount.text.trim()) ?? 0,
      'installationDate': _installationDate,
      'rechargeDate': _rechargeDate,
      'connectionProvider': _connectionProvider ?? '',
      'connectionType': _connectionType,
      'boxNumber': _boxNumber ?? '',
      'packageCable': _selectedCablePkg?.name ?? '',
      'discount': _discount,
      'amount': double.tryParse(_amount.text.trim()) ?? 0,
      'packageInternet': _selectedInternetPkg?.name ?? '',
      'createBalance': _createBalance,
      'balanceDays': int.tryParse(_balanceDays.text.trim()) ?? 0,
      'sameDiscount': _sameDiscount,
      'sameAmount': double.tryParse(_sameAmount.text.trim()) ?? 0,
      'status': _status,
      'splitterId': _splitterId ?? '',
      'splitterPort': int.tryParse(_splitterPort.text.trim()) ?? 0,
      'transactionId': _transactionId.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.connection != null;
    final cableBase = _cableBase;
    final internetBase = _internetBase;

    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: crmBlueGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.people_outline,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text('${editing ? 'Edit' : 'Add'} Subscriber'),
        ],
      ),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NetField(
                  label: 'Internet ID',
                  child: TextFormField(
                    controller: _internetId,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g., INT-001',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Sublocality',
                  child: DropdownButtonFormField<String>(
                    initialValue: _sublocalityId,
                    isExpanded: true,
                    decoration: netInputDecoration(context),
                    hint: const Text('Select sublocality'),
                    items: [
                      for (final a in widget.areas)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            a.subLocality.isNotEmpty
                                ? a.subLocality
                                : (a.locality.isNotEmpty
                                      ? a.locality
                                      : a.id.substring(
                                          0,
                                          a.id.length >= 8 ? 8 : a.id.length,
                                        )),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _sublocalityId = v),
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Name',
                  child: TextFormField(
                    controller: _name,
                    decoration: netInputDecoration(context, hint: 'Full name'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Address',
                  child: TextFormField(
                    controller: _address,
                    decoration: netInputDecoration(
                      context,
                      hint: 'Installation address',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _two(
                  NetField(
                    label: 'Cell',
                    child: TextFormField(
                      controller: _cell,
                      decoration: netInputDecoration(
                        context,
                        hint: 'e.g., 0300-1234567',
                      ),
                    ),
                  ),
                  NetField(
                    label: 'Mobile',
                    child: TextFormField(
                      controller: _mobile,
                      decoration: netInputDecoration(
                        context,
                        hint: 'e.g., 0312-7654321',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _two(
                  NetField(
                    label: 'Installation Amount',
                    child: TextFormField(
                      controller: _installationAmount,
                      keyboardType: TextInputType.number,
                      decoration: netInputDecoration(context),
                    ),
                  ),
                  NetField(
                    label: 'Other Amount',
                    child: TextFormField(
                      controller: _otherAmount,
                      keyboardType: TextInputType.number,
                      decoration: netInputDecoration(context),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _two(
                  NetField(
                    label: 'Installation Date',
                    child: CrmDateField(
                      value: _installationDate,
                      onChanged: (v) => setState(() => _installationDate = v),
                    ),
                  ),
                  NetField(
                    label: 'Recharge Date',
                    child: CrmDateField(
                      value: _rechargeDate,
                      onChanged: (v) => setState(() => _rechargeDate = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _three(
                  NetField(
                    label: 'Connection Provider',
                    child: DropdownButtonFormField<String>(
                      initialValue: _connectionProvider,
                      isExpanded: true,
                      decoration: netInputDecoration(context),
                      hint: const Text('Select provider'),
                      items: [
                        for (final c in widget.companies)
                          DropdownMenuItem(value: c.name, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _connectionProvider = v),
                    ),
                  ),
                  NetField(
                    label: 'Connection Type',
                    child: DropdownButtonFormField<String>(
                      initialValue: _connectionType,
                      decoration: netInputDecoration(context),
                      items: [
                        for (final o in _connectionTypeOptions)
                          DropdownMenuItem(value: o.key, child: Text(o.value)),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _connectionType = v);
                          _recomputeCable();
                          _recomputeInternet();
                        }
                      },
                    ),
                  ),
                  NetField(
                    label: 'Status',
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: netInputDecoration(context),
                      items: [
                        for (final o in _statusOptions)
                          DropdownMenuItem(value: o.key, child: Text(o.value)),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _status = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Box Number',
                  child: DropdownButtonFormField<String>(
                    initialValue: _boxNumber,
                    isExpanded: true,
                    decoration: netInputDecoration(context),
                    hint: const Text('Select box number'),
                    items: [
                      for (final b in widget.boxes)
                        DropdownMenuItem(value: b.name, child: Text(b.name)),
                    ],
                    onChanged: (v) => setState(() => _boxNumber = v),
                  ),
                ),
                const SizedBox(height: 14),
                _two(
                  NetField(
                    label: 'Splitter',
                    child: DropdownButtonFormField<String>(
                      initialValue: _splitterId,
                      isExpanded: true,
                      decoration: netInputDecoration(context),
                      hint: const Text('Select splitter'),
                      items: [
                        for (final s in widget.splitters)
                          if (s.availablePorts > 0 ||
                              s.id == widget.connection?.splitterId)
                            DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                '${s.name} (${s.availablePorts}/${s.totalPorts} ports free)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                      ],
                      onChanged: (v) => setState(() {
                        _splitterId = v;
                        _splitterPort.text = '';
                      }),
                    ),
                  ),
                  (_splitterId ?? '').isNotEmpty
                      ? NetField(
                          label: 'Splitter Port (1-$_maxPorts)',
                          child: TextFormField(
                            controller: _splitterPort,
                            keyboardType: TextInputType.number,
                            decoration: netInputDecoration(context),
                            onChanged: (v) {
                              final val = int.tryParse(v) ?? 0;
                              if (val < 0 || val > _maxPorts) {
                                _splitterPort.text = v.isEmpty
                                    ? ''
                                    : v.substring(0, v.length - 1);
                                _splitterPort.selection =
                                    TextSelection.collapsed(
                                      offset: _splitterPort.text.length,
                                    );
                              }
                            },
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                _cableSection(cableBase),
                const SizedBox(height: 16),
                _internetSection(internetBase),
                if (_selectedCablePkg != null &&
                    _selectedInternetPkg != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? AppColors.darkMuted.withValues(alpha: 0.4)
                          : AppColors.muted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedCablePkg!.name} (PKR ${_amount.text.isEmpty ? 0 : _amount.text}) '
                          '+ ${_selectedInternetPkg!.name} (PKR ${_sameAmount.text.isEmpty ? 0 : _sameAmount.text}) '
                          '+ Installation (PKR ${_installationAmount.text.isEmpty ? 0 : _installationAmount.text}) '
                          '+ Other (PKR ${_otherAmount.text.isEmpty ? 0 : _otherAmount.text}) '
                          '= PKR $_total',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.line),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _createBalance,
                        onChanged: (v) =>
                            setState(() => _createBalance = v ?? false),
                      ),
                      const Text('Create Balance'),
                    ],
                  ),
                ),
                if (_createBalance) ...[
                  const SizedBox(height: 14),
                  NetField(
                    label: 'Balance Days',
                    child: TextFormField(
                      controller: _balanceDays,
                      keyboardType: TextInputType.number,
                      decoration: netInputDecoration(context),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                NetField(
                  label: 'Transaction ID',
                  child: TextFormField(
                    controller: _transactionId,
                    decoration: netInputDecoration(context),
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
          label: editing ? 'Update Subscriber' : 'Add Subscriber',
          gradient: crmGreenGradient,
          onPressed: _submit,
        ),
      ],
    );
  }

  int get _maxPorts {
    for (final s in widget.splitters) {
      if (s.id == _splitterId) return s.totalPorts;
    }
    return 0;
  }

  num get _total {
    double parse(TextEditingController c) =>
        double.tryParse(c.text.trim()) ?? 0;
    return parse(_amount) +
        parse(_sameAmount) +
        parse(_installationAmount) +
        parse(_otherAmount);
  }

  Widget _cableSection(double cableBase) {
    final disabled = !_showCable;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: IgnorePointer(
        ignoring: disabled,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF97316),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CABLE INFORMATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: context.mutedFg,
                    ),
                  ),
                  if (disabled)
                    Expanded(
                      child: Text(
                        '(Disabled - Internet only)',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, color: context.mutedFg),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _three(
                NetField(
                  label: 'Package Cable',
                  child: DropdownButtonFormField<String>(
                    initialValue: _cablePkgId,
                    isExpanded: true,
                    decoration: netInputDecoration(context),
                    hint: const Text('Select cable package'),
                    items: [
                      for (final p in _cablePackages)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            p.effectivePrice > 0
                                ? '${p.name} \u2014 PKR ${crmNumber(p.effectivePrice)}'
                                : p.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _cablePkgId = v;
                      _recomputeCable();
                    }),
                  ),
                ),
                NetField(
                  label: 'Discount',
                  child: DropdownButtonFormField<String>(
                    initialValue: _discount.isEmpty ? null : _discount,
                    decoration: netInputDecoration(context),
                    hint: const Text('Select discount'),
                    items: [
                      for (final o in _discountOptions)
                        DropdownMenuItem(value: o.key, child: Text(o.value)),
                    ],
                    onChanged: (v) => setState(() {
                      _discount = v ?? '';
                      _recomputeCable();
                    }),
                  ),
                ),
                NetField(
                  label: _cableAmountLabel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _amount,
                        keyboardType: TextInputType.number,
                        enabled: !disabled && _discount == 'custom',
                        decoration: netInputDecoration(context),
                      ),
                      if (_discount.isNotEmpty &&
                          _discount != 'custom' &&
                          _discount != 'no_discount')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Base: ${crmNumber(cableBase)} \u2192 '
                            '${crmNumber(calcDiscountedAmount(cableBase, _discount))}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.mutedFg,
                            ),
                          ),
                        ),
                      if (_selectedCablePkg != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${_selectedCablePkg!.name} fee = PKR '
                            '${crmNumber(_selectedCablePkg!.effectivePrice)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.mutedFg,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _internetSection(double internetBase) {
    final disabled = !_showInternet;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: IgnorePointer(
        ignoring: disabled,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'INTERNET INFORMATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: context.mutedFg,
                    ),
                  ),
                  if (disabled)
                    Expanded(
                      child: Text(
                        '(Disabled - Cable only)',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, color: context.mutedFg),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _three(
                NetField(
                  label: 'Package Internet',
                  child: DropdownButtonFormField<String>(
                    initialValue: _internetPkgId,
                    isExpanded: true,
                    decoration: netInputDecoration(context),
                    hint: const Text('Select internet package'),
                    items: [
                      for (final p in _internetPackages)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            p.effectivePrice > 0
                                ? '${p.name} \u2014 PKR ${crmNumber(p.effectivePrice)}'
                                : p.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _internetPkgId = v;
                      _recomputeInternet();
                    }),
                  ),
                ),
                NetField(
                  label: 'Internet Discount',
                  child: DropdownButtonFormField<String>(
                    initialValue: _sameDiscount.isEmpty ? null : _sameDiscount,
                    decoration: netInputDecoration(context),
                    hint: const Text('Select discount'),
                    items: [
                      for (final o in _discountOptions)
                        DropdownMenuItem(value: o.key, child: Text(o.value)),
                    ],
                    onChanged: (v) => setState(() {
                      _sameDiscount = v ?? '';
                      _recomputeInternet();
                    }),
                  ),
                ),
                NetField(
                  label: _internetAmountLabel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _sameAmount,
                        keyboardType: TextInputType.number,
                        enabled: !disabled && _sameDiscount == 'custom',
                        decoration: netInputDecoration(context),
                      ),
                      if (_sameDiscount.isNotEmpty &&
                          _sameDiscount != 'custom' &&
                          _sameDiscount != 'no_discount')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Base: ${crmNumber(internetBase)} \u2192 '
                            '${crmNumber(calcDiscountedAmount(internetBase, _sameDiscount))}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.mutedFg,
                            ),
                          ),
                        ),
                      if (_selectedInternetPkg != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${_selectedInternetPkg!.name} fee = PKR '
                            '${crmNumber(_selectedInternetPkg!.effectivePrice)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.mutedFg,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _cableAmountLabel {
    switch (_discount) {
      case 'custom':
        return 'Amount';
      case 'quarter':
        return 'Quarterly Amount (25% off)';
      case 'half':
        return 'Half Amount (50% off)';
      case 'full_free':
        return 'Full Free (100% off)';
      default:
        return 'Amount';
    }
  }

  String get _internetAmountLabel {
    switch (_sameDiscount) {
      case 'custom':
        return 'Internet Amount';
      case 'quarter':
        return 'Quarterly Internet Amount (25% off)';
      case 'half':
        return 'Half Internet Amount (50% off)';
      case 'full_free':
        return 'Full Free (100% off)';
      default:
        return 'Internet Amount';
    }
  }

  Widget _two(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
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

  Widget _three(Widget a, Widget b, Widget c) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              a,
              const SizedBox(height: 14),
              b,
              const SizedBox(height: 14),
              c,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 14),
            Expanded(child: b),
            const SizedBox(width: 14),
            Expanded(child: c),
          ],
        );
      },
    );
  }
}
