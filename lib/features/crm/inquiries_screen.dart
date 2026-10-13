import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import '../network/network_models.dart';
import 'crm_common.dart';
import 'crm_models.dart';

const List<Color> _blueCyanGradient = [Color(0xFF3B82F6), Color(0xFF0891B2)];
const List<Color> _rosePinkGradient = [Color(0xFFF43F5E), Color(0xFFDB2777)];

/// Flutter counterpart of
/// `client/src/app/(app)/subscribers/inquiries/page.tsx` — leads and potential
/// new subscribers.
class InquiriesScreen extends StatefulWidget {
  const InquiriesScreen({super.key});

  @override
  State<InquiriesScreen> createState() => _InquiriesScreenState();
}

class _InquiriesScreenState extends State<InquiriesScreen> {
  final ApiClient _api = ApiClient(onUnauthorized: _handleUnauthorized);

  List<CrmInquiry> _inquiries = [];
  List<NetArea> _areas = [];
  List<NetBox> _boxes = [];
  List<CrmPackage> _packages = [];
  bool _loading = true;

  String _search = '';
  String _filterSublocality = 'all';
  String _filterType = 'all';
  String _filterMonth = 'all';

  int _page = 1;
  int _pageSize = 10;
  final TextEditingController _searchController = TextEditingController();

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
    _searchController.dispose();
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
        _api.get('/subscribers/inquiries', query: {'companyId': cid}),
        _api.get('/network/areas', query: {'companyId': cid}),
        _api.get('/network/boxes', query: {'companyId': cid}),
        _api.get('/billing/packages', query: {'companyId': cid}),
      ]);
      if (!mounted) return;
      setState(() {
        _inquiries = ApiClient.listData(results[0])
            .whereType<Map<String, dynamic>>()
            .map(CrmInquiry.fromJson)
            .toList();
        _areas = ApiClient.listData(results[1])
            .whereType<Map<String, dynamic>>()
            .map(NetArea.fromJson)
            .toList();
        _boxes = ApiClient.listData(results[2])
            .whereType<Map<String, dynamic>>()
            .map(NetBox.fromJson)
            .toList();
        _packages = ApiClient.listData(results[3])
            .whereType<Map<String, dynamic>>()
            .map(CrmPackage.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<String> get _sublocalities {
    final seen = <String>{};
    for (final a in _areas) {
      if (a.subLocality.isNotEmpty) seen.add(a.subLocality);
    }
    return seen.toList();
  }

  List<CrmInquiry> get _filtered {
    var result = _inquiries;
    if (_filterSublocality != 'all') {
      result = result
          .where((i) => i.subLocality == _filterSublocality)
          .toList();
    }
    if (_filterType != 'all') {
      result = result.where((i) => i.connectionType == _filterType).toList();
    }
    if (_filterMonth != 'all') {
      final month = int.tryParse(_filterMonth);
      result = result.where((i) {
        final d = i.installationDate.isNotEmpty
            ? i.installationDate
            : i.createdAt;
        if (d.isEmpty) return false;
        final parsed = DateTime.tryParse(d);
        return parsed != null && parsed.month - 1 == month;
      }).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      result = result.where((i) {
        final matchText = [
          i.name,
          i.address,
        ].any((v) => v.toLowerCase().contains(q));
        final matchId = [
          i.cell,
          i.mobile,
          i.internetId,
        ].any((v) => v.toLowerCase().contains(q));
        return matchText || matchId;
      }).toList();
    }
    return result;
  }

  List<CrmInquiry> get _pageRows {
    final start = (_page - 1) * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  void _resetPage() => _page = 1;

  Future<void> _save(Map<String, dynamic> values, CrmInquiry? existing) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    try {
      if (existing != null) {
        await _api.put(
          '/subscribers/inquiries/${existing.id}?companyId=$cid',
          body: values,
        );
      } else {
        await _api.post(
          '/subscribers/inquiries?companyId=$cid',
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
              ? 'Inquiry updated successfully.'
              : 'Inquiry added successfully.',
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

  Future<void> _delete(CrmInquiry inquiry) async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) return;
    await showNetworkDeleteDialog(
      context,
      itemName: inquiry.name,
      onConfirm: () async {
        try {
          await _api.delete(
            '/subscribers/inquiries/${inquiry.id}?companyId=$cid',
          );
          await _load();
          if (mounted) {
            await showCrmFeedback(
              context,
              type: 'success',
              title: 'Success',
              message: 'Inquiry deleted successfully.',
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

  Future<void> _openForm(CrmInquiry? inquiry) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _InquiryFormDialog(
        inquiry: inquiry,
        sublocalities: _sublocalities,
        boxes: _boxes,
        packages: _packages,
      ),
    );
    if (result != null) await _save(result, inquiry);
  }

  @override
  Widget build(BuildContext context) {
    final newCount = _inquiries.where((i) => i.status == 'new').length;
    final followUp = _inquiries.where((i) => i.status == 'follow-up').length;
    final converted = _inquiries.where((i) => i.status == 'converted').length;
    final closed = _inquiries.where((i) => i.status == 'closed').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: CrmScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.person_add_alt_1_outlined,
            title: 'New Inquiries',
            subtitle: 'Manage leads and potential new subscribers.',
            gradient: crmEmeraldVioletGradient,
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
                      maxColumns: 5,
                      children: [
                        NetworkStatCard(
                          icon: Icons.person_add_alt_1_outlined,
                          label: 'Total',
                          value: '${_inquiries.length}',
                          gradient: crmEmeraldVioletGradient,
                        ),
                        NetworkStatCard(
                          icon: Icons.auto_awesome,
                          label: 'New',
                          value: '$newCount',
                          gradient: _blueCyanGradient,
                          valueColor: const Color(0xFF2563EB),
                        ),
                        NetworkStatCard(
                          icon: Icons.refresh,
                          label: 'Follow-up',
                          value: '$followUp',
                          gradient: crmAmberGradient,
                          valueColor: crmStatusSuspended,
                        ),
                        NetworkStatCard(
                          icon: Icons.check_circle_outline,
                          label: 'Converted',
                          value: '$converted',
                          gradient: crmGreenGradient,
                          valueColor: crmStatusActive,
                        ),
                        NetworkStatCard(
                          icon: Icons.cancel_outlined,
                          label: 'Closed',
                          value: '$closed',
                          gradient: _rosePinkGradient,
                          valueColor: crmStatusDeactivated,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _filterRow(context),
                    const SizedBox(height: 16),
                    _searchRow(context),
                    const SizedBox(height: 16),
                    NetworkTable<CrmInquiry>(
                      rows: _pageRows,
                      emptyIcon: Icons.person_add_alt_1_outlined,
                      emptyTitle: 'No inquiries found.',
                      emptyHint: 'Get started by adding a new inquiry.',
                      emptyTint: AppColors.emerald600,
                      mobileTrailing: (context, i, _) => NetworkRowActions(
                        onEdit: () => _openForm(i),
                        onDelete: () => _delete(i),
                      ),
                      columns: [
                        NetColumn(
                          label: '#',
                          width: 80,
                          builder: (context, i, _) => Text(
                            i.shortId,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: context.mutedFg,
                            ),
                          ),
                        ),
                        NetColumn(
                          label: 'Internet ID',
                          width: 120,
                          builder: (context, i, _) =>
                              Text(i.internetId.isEmpty ? '-' : i.internetId),
                        ),
                        NetColumn(
                          label: 'Name',
                          width: 160,
                          builder: (context, i, _) => Text(i.name),
                        ),
                        NetColumn(
                          label: 'Address',
                          width: 200,
                          builder: (context, i, _) => Text(
                            i.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        NetColumn(
                          label: 'Contact',
                          width: 150,
                          builder: (context, i, _) => Text(
                            '${i.cell.isEmpty ? '-' : i.cell}'
                            '${i.mobile.isNotEmpty ? ' / ${i.mobile}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        NetColumn(
                          label: 'Type',
                          width: 110,
                          builder: (context, i, _) => i.connectionType.isEmpty
                              ? const Text('-')
                              : CrmBadge(
                                  label: inquiryTypeLabel(i.connectionType),
                                  color: AppColors.mutedForeground,
                                ),
                        ),
                        NetColumn(
                          label: 'Install Date',
                          width: 120,
                          builder: (context, i, _) => Text(
                            i.installationDate.isEmpty
                                ? '-'
                                : i.installationDate,
                          ),
                        ),
                        NetColumn(
                          label: 'Cable/Internet',
                          width: 170,
                          builder: (context, i, _) => Text(
                            '${i.packageCable.isEmpty ? '-' : i.packageCable}'
                            '${i.boxNumber.isNotEmpty ? ' / Box: ${i.boxNumber}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        NetColumn(
                          label: 'Status',
                          width: 120,
                          builder: (context, i, _) => CrmBadge(
                            label: i.status,
                            color: _statusColor(i.status),
                          ),
                        ),
                        NetColumn(
                          label: '',
                          width: 96,
                          isActions: true,
                          builder: (context, i, _) => Align(
                            alignment: Alignment.centerRight,
                            child: NetworkRowActions(
                              onEdit: () => _openForm(i),
                              onDelete: () => _delete(i),
                            ),
                          ),
                        ),
                      ],
                    ),
                    NetworkPagination(
                      currentPage: _page,
                      pageSize: _pageSize,
                      totalItems: _filtered.length,
                      noun: 'inquiries',
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
      case 'new':
        return AppColors.mutedForeground;
      case 'follow-up':
        return AppColors.mutedForeground;
      case 'converted':
        return AppColors.primary;
      case 'closed':
        return AppColors.destructive;
      default:
        return AppColors.mutedForeground;
    }
  }

  Widget _filterRow(BuildContext context) {
    final add = GradientButton(
      label: 'Add Inquiry',
      icon: Icons.add_circle_outline,
      gradient: crmGreenGradient,
      onPressed: () => _openForm(null),
    );
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        _labeledSelect(
          context,
          'Sublocality',
          width: 180,
          value: _filterSublocality,
          items: {
            'all': 'All Sublocalities',
            for (final s in _sublocalities) s: s,
          },
          onChanged: (v) => setState(() {
            _filterSublocality = v;
            _resetPage();
          }),
        ),
        _labeledSelect(
          context,
          'Select Type',
          width: 150,
          value: _filterType,
          items: const {
            'all': 'All Types',
            'both': 'Both',
            'internet': 'Internet',
            'tv_cable': 'TV Cable',
          },
          onChanged: (v) => setState(() {
            _filterType = v;
            _resetPage();
          }),
        ),
        _labeledSelect(
          context,
          'Month',
          width: 150,
          value: _filterMonth,
          items: const {
            'all': 'All Months',
            '0': 'January',
            '1': 'February',
            '2': 'March',
            '3': 'April',
            '4': 'May',
            '5': 'June',
            '6': 'July',
            '7': 'August',
            '8': 'September',
            '9': 'October',
            '10': 'November',
            '11': 'December',
          },
          onChanged: (v) => setState(() {
            _filterMonth = v;
            _resetPage();
          }),
        ),
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () {},
            icon: const Icon(Icons.send_outlined, size: 16),
            label: const Text('Pending Referrals'),
          ),
        ),
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () {},
            icon: const Icon(Icons.groups_outlined, size: 16),
            label: const Text('Send Promotions'),
          ),
        ),
        add,
      ],
    );
  }

  Widget _searchRow(BuildContext context) {
    final search = TextField(
      controller: _searchController,
      onChanged: (v) => setState(() {
        _search = v;
        _resetPage();
      }),
      style: const TextStyle(fontSize: 14),
      decoration: netInputDecoration(context, hint: 'Search inquiries...')
          .copyWith(
            prefixIcon: Icon(Icons.search, size: 18, color: context.mutedFg),
          ),
    );
    return search;
  }

  Widget _labeledSelect(
    BuildContext context,
    String label, {
    required double width,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: netInputDecoration(context),
            items: [
              for (final entry in items.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _InquiryFormDialog extends StatefulWidget {
  const _InquiryFormDialog({
    this.inquiry,
    required this.sublocalities,
    required this.boxes,
    required this.packages,
  });

  final CrmInquiry? inquiry;
  final List<String> sublocalities;
  final List<NetBox> boxes;
  final List<CrmPackage> packages;

  @override
  State<_InquiryFormDialog> createState() => _InquiryFormDialogState();
}

class _InquiryFormDialogState extends State<_InquiryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _internetId;
  late final TextEditingController _cell;
  late final TextEditingController _mobile;
  late final TextEditingController _address;
  late final TextEditingController _installationAmount;
  late final TextEditingController _otherAmount;
  late final TextEditingController _discount;
  late final TextEditingController _amount;
  late final TextEditingController _comments;
  late String _installationDate;
  late String _rechargeDate;
  String? _subLocality;
  String? _connectionType;
  String? _boxNumber;
  String? _packageCable;
  late String _status;

  @override
  void initState() {
    super.initState();
    final i = widget.inquiry;
    _name = TextEditingController(text: i?.name ?? '');
    _internetId = TextEditingController(text: i?.internetId ?? '');
    _cell = TextEditingController(text: i?.cell ?? '');
    _mobile = TextEditingController(text: i?.mobile ?? '');
    _address = TextEditingController(text: i?.address ?? '');
    _installationAmount = TextEditingController(
      text: _numText(i?.installationAmount),
    );
    _otherAmount = TextEditingController(text: _numText(i?.otherAmount));
    _discount = TextEditingController(text: _numText(i?.discount));
    _amount = TextEditingController(text: _numText(i?.amount));
    _comments = TextEditingController(text: i?.comments ?? '');
    _installationDate = i?.installationDate ?? '';
    _rechargeDate = i?.rechargeDate ?? '';
    _subLocality = (i?.subLocality.isNotEmpty ?? false) ? i!.subLocality : null;
    _connectionType = (i?.connectionType.isNotEmpty ?? false)
        ? i!.connectionType
        : null;
    _boxNumber = (i?.boxNumber.isNotEmpty ?? false) ? i!.boxNumber : null;
    _packageCable = (i?.packageCable.isNotEmpty ?? false)
        ? i!.packageCable
        : null;
    _status = i?.status ?? 'new';
    _discount.addListener(_recomputeAmount);
  }

  static String _numText(num? value) {
    if (value == null || value == 0) return '';
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  double? get _packagePrice {
    final name = _packageCable;
    if (name == null) return null;
    for (final p in widget.packages) {
      if (p.name == name) return p.effectivePrice;
    }
    return null;
  }

  void _recomputeAmount() {
    final price = _packagePrice;
    if (price == null || price <= 0) return;
    final discount = double.tryParse(_discount.text.trim()) ?? 0;
    final amount = (price - discount) < 0 ? 0.0 : (price - discount);
    _amount.text = _numText(amount);
    setState(() {});
  }

  @override
  void dispose() {
    _discount.removeListener(_recomputeAmount);
    _name.dispose();
    _internetId.dispose();
    _cell.dispose();
    _mobile.dispose();
    _address.dispose();
    _installationAmount.dispose();
    _otherAmount.dispose();
    _discount.dispose();
    _amount.dispose();
    _comments.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final price = _packagePrice;
    final discount = double.tryParse(_discount.text.trim()) ?? 0;
    if (price != null && price > 0 && discount >= price) {
      _showDiscountError();
      return;
    }
    Navigator.of(context).pop({
      'name': _name.text.trim(),
      'internetId': _internetId.text.trim(),
      'cell': _cell.text.trim(),
      'mobile': _mobile.text.trim(),
      'address': _address.text.trim(),
      'installationAmount':
          double.tryParse(_installationAmount.text.trim()) ?? 0,
      'otherAmount': double.tryParse(_otherAmount.text.trim()) ?? 0,
      'installationDate': _installationDate,
      'rechargeDate': _rechargeDate,
      'subLocality': _subLocality ?? '',
      'connectionType': _connectionType ?? '',
      'boxNumber': _boxNumber ?? '',
      'packageCable': _packageCable ?? '',
      'discount': discount,
      'amount': double.tryParse(_amount.text.trim()) ?? 0,
      'comments': _comments.text.trim(),
      'status': _status,
      'notes': widget.inquiry?.notes ?? '',
    });
  }

  void _showDiscountError() {
    showCrmFeedback(
      context,
      type: 'error',
      title: 'Invalid Discount',
      message: 'Discount must be less than the package selling price.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.inquiry != null;
    return AlertDialog(
      backgroundColor: context.surface,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: crmEmeraldVioletGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.person_add_alt_1_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text('${editing ? 'Edit' : 'Add'} Inquiry'),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NetField(
                  label: 'Name',
                  child: TextFormField(
                    controller: _name,
                    decoration: netInputDecoration(
                      context,
                      hint: 'e.g., Jane Doe',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Internet ID',
                  child: TextFormField(
                    controller: _internetId,
                    decoration: netInputDecoration(
                      context,
                      hint: 'Internet ID',
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
                        hint: 'e.g., 0301-1234567',
                      ),
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
                      hint: 'Full address of potential customer',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Address is required'
                        : null,
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
                _two(
                  NetField(
                    label: 'Sublocality',
                    child: DropdownButtonFormField<String>(
                      initialValue: _subLocality,
                      isExpanded: true,
                      decoration: netInputDecoration(context),
                      hint: const Text('Select sublocality'),
                      items: [
                        for (final s in widget.sublocalities)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => setState(() => _subLocality = v),
                    ),
                  ),
                  NetField(
                    label: 'Connection Type',
                    child: DropdownButtonFormField<String>(
                      initialValue: _connectionType,
                      isExpanded: true,
                      decoration: netInputDecoration(context),
                      hint: const Text('Select type'),
                      items: const [
                        DropdownMenuItem(value: 'both', child: Text('Both')),
                        DropdownMenuItem(
                          value: 'internet',
                          child: Text('Internet'),
                        ),
                        DropdownMenuItem(
                          value: 'tv_cable',
                          child: Text('TV Cable'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _connectionType = v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _two(
                  NetField(
                    label: 'Box Number',
                    child: DropdownButtonFormField<String>(
                      initialValue: _boxNumber,
                      isExpanded: true,
                      decoration: netInputDecoration(context),
                      hint: const Text('Select box'),
                      items: [
                        for (final b in widget.boxes)
                          DropdownMenuItem(value: b.name, child: Text(b.name)),
                      ],
                      onChanged: (v) => setState(() => _boxNumber = v),
                    ),
                  ),
                  NetField(
                    label: 'Package Cable',
                    child: DropdownButtonFormField<String>(
                      initialValue: _packageCable,
                      isExpanded: true,
                      decoration: netInputDecoration(context),
                      hint: const Text('Select package'),
                      items: [
                        for (final p in widget.packages)
                          DropdownMenuItem(
                            value: p.name,
                            child: Text(
                              '${p.name} - PKR ${crmNumber(p.price)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _packageCable = v;
                        _recomputeAmount();
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _two(
                  NetField(
                    label: 'Discount',
                    child: TextFormField(
                      controller: _discount,
                      keyboardType: TextInputType.number,
                      decoration: netInputDecoration(context),
                    ),
                  ),
                  NetField(
                    label: 'Amount',
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      decoration: netInputDecoration(context),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Comment',
                  child: TextFormField(
                    controller: _comments,
                    maxLines: 3,
                    decoration: netInputDecoration(
                      context,
                      hint: 'Enter comments...',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                NetField(
                  label: 'Status',
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: netInputDecoration(context),
                    items: const [
                      DropdownMenuItem(value: 'new', child: Text('New')),
                      DropdownMenuItem(
                        value: 'follow-up',
                        child: Text('Follow-up'),
                      ),
                      DropdownMenuItem(
                        value: 'converted',
                        child: Text('Converted'),
                      ),
                      DropdownMenuItem(value: 'closed', child: Text('Closed')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
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
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            foregroundColor: context.dangerText,
            side: BorderSide(color: context.dangerText.withValues(alpha: 0.3)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GradientButton(
          label: editing ? 'Update' : 'Add',
          gradient: crmGreenGradient,
          onPressed: _submit,
        ),
      ],
    );
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
}
