import 'package:flutter/material.dart';

import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../inventory/inventory_common.dart';
import '../network/network_common.dart';
import '../shared/crud_kit.dart';
import '../transaction/transaction_common.dart';

const String kMyDealerPermission = '13318';

const Map<String, String> _kDealerStatuses = {
  'active': 'Active',
  'inactive': 'Inactive',
  'suspended': 'Suspended',
  'deactivated': 'Deactivated',
};

/// `franchise/my-dealers` — list, add, edit, change status and delete
/// dealers (`/dealers`, Go `CreateDealer` / `UpdateDealer` / `DeleteDealer`).
class MyDealersScreen extends StatefulWidget {
  const MyDealersScreen({super.key});

  @override
  State<MyDealersScreen> createState() => _MyDealersScreenState();
}

class _MyDealersScreenState extends State<MyDealersScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: kitHandleUnauthorized);
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _dealers = [];
  List<Map<String, dynamic>> _areas = [];
  bool _loading = true;
  String? _error;
  String _filter = '';
  int _page = 1;
  int _pageSize = 10;

  String get _cid => Session.companyId ?? '';
  bool get _canCreate => invCrud(kMyDealerPermission, 'create');
  bool get _canUpdate => invCrud(kMyDealerPermission, 'update');
  bool get _canDelete => invCrud(kMyDealerPermission, 'delete');
  bool get _canStatus => invPage(kMyDealerPermission, 'change-status');

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
      final q = {'companyId': _cid};
      final dealers = kitMaps(await _api.get('/dealers', query: q));
      var areas = <Map<String, dynamic>>[];
      try {
        areas = kitMaps(await _api.get('/network/areas', query: q));
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _dealers = dealers;
        _areas = areas;
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

  List<Map<String, dynamic>> get _filtered => _dealers
      .where((d) => kitMatch(_filter, [
            kitStr(d['name']),
            kitStr(d['phone']),
            kitStr(d['email']),
            kitStr(d['cnic']),
            kitStr(d['areaName']),
          ]))
      .toList();

  Future<void> _openForm(Map<String, dynamic>? existing) async {
    final raw = existing ?? const <String, dynamic>{};
    TextEditingController ctl(String k) => TextEditingController(text: kitStr(raw[k]));
    final name = ctl('name');
    final cell = ctl('cell');
    final phone = ctl('phone');
    final email = ctl('email');
    final password = TextEditingController();
    final cnic = ctl('cnic');
    final address = ctl('address');
    final commission = TextEditingController(
      text: existing == null ? '' : kitNum(raw['commissionRate']).toString(),
    );
    final wallet = TextEditingController(
      text: existing == null ? '' : kitNum(raw['walletBalance']).toString(),
    );
    var status = kitStr(raw['status']).isEmpty ? 'active' : kitStr(raw['status']);
    var joining = kitStr(raw['joiningDate']);
    String? areaId = kitStr(raw['areaId']).isEmpty ? null : kitStr(raw['areaId']);
    final areaOptions = [
      for (final a in _areas)
        TxPickOption(
          id: kitStr(a['id']),
          name: [kitStr(a['city']), kitStr(a['zone']), kitStr(a['locality'])]
              .where((p) => p.isNotEmpty)
              .join(' - '),
          secondary: kitStr(a['subLocality']),
        ),
    ];

    await showKitForm(
      context,
      title: existing == null ? 'Add Dealer' : 'Edit Dealer',
      icon: Icons.handshake_outlined,
      gradient: kitBlue,
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitTextField(label: 'Name *', controller: name),
          kitGap,
          KitRow(children: [
            KitTextField(label: 'Phone No *', controller: phone, keyboardType: TextInputType.phone),
            KitTextField(label: 'Cell No', controller: cell, keyboardType: TextInputType.phone),
          ]),
          kitGap,
          KitTextField(label: 'Email *', controller: email, keyboardType: TextInputType.emailAddress),
          kitGap,
          KitTextField(
            label: existing == null ? 'Password *' : 'Password (leave blank to keep)',
            controller: password,
            obscure: true,
          ),
          kitGap,
          KitRow(children: [
            KitTextField(label: 'CNIC *', controller: cnic),
            KitSelect(
              label: 'Status',
              value: status,
              items: _kDealerStatuses,
              onChanged: (v) => setSheet(() => status = v),
            ),
          ]),
          kitGap,
          TxSearchableSelect(
            label: 'Locality',
            placeholder: 'Select locality',
            searchPlaceholder: 'Search areas...',
            options: areaOptions,
            value: areaId,
            onChanged: (v) => setSheet(() => areaId = v),
          ),
          kitGap,
          NetField(
            label: 'Joining Date',
            child: TxDateField(
              label: 'Select date',
              value: joining,
              width: double.infinity,
              onChanged: (v) => setSheet(() => joining = v),
            ),
          ),
          kitGap,
          KitTextField(label: 'Address', controller: address, maxLines: 2),
          kitGap,
          KitRow(children: [
            KitTextField(label: 'Commission Rate (%)', controller: commission, keyboardType: TextInputType.number),
            KitTextField(label: 'Wallet Balance (PKR)', controller: wallet, keyboardType: TextInputType.number),
          ]),
        ],
      ),
      onSubmit: () async {
        final emailText = email.text.trim().toLowerCase();
        String? err;
        if (name.text.trim().isEmpty || phone.text.trim().isEmpty || cnic.text.trim().isEmpty) {
          err = 'Name, phone and CNIC are required.';
        } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(emailText)) {
          err = 'A valid email is required.';
        } else if (existing == null && password.text.length < 6) {
          err = 'Password is required and must be at least 6 characters.';
        } else if (password.text.isNotEmpty && password.text.length < 6) {
          err = 'Password must be at least 6 characters.';
        }
        if (err != null) {
          showToast(context, err, error: true);
          return false;
        }
        String areaName = '';
        for (final o in areaOptions) {
          if (o.id == areaId) areaName = o.name;
        }
        final body = <String, dynamic>{
          'name': name.text.trim(),
          'cell': cell.text.trim(),
          'phone': phone.text.trim(),
          'email': emailText,
          'status': status,
          'companyId': _cid,
          'cnic': cnic.text.trim(),
          'address': address.text.trim(),
          'joiningDate': joining,
          'areaId': areaId,
          'areaName': areaName,
          'commissionRate': double.tryParse(commission.text.trim()) ?? 0,
          'walletBalance': double.tryParse(wallet.text.trim()) ?? 0,
          if (password.text.isNotEmpty) 'password': password.text,
        };
        try {
          if (existing == null) {
            await _api.post('/dealers?companyId=$_cid', body: body);
          } else {
            await _api.put('/dealers/${kitStr(existing['id'])}?companyId=$_cid', body: body);
          }
          if (mounted) {
            showToast(context, existing == null ? 'Dealer added successfully.' : 'Dealer updated successfully.');
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

  Future<void> _changeStatus(Map<String, dynamic> d) async {
    var status = kitStr(d['status']).isEmpty ? 'active' : kitStr(d['status']);
    await showKitForm(
      context,
      title: 'Change Dealer Status',
      icon: Icons.toggle_on_outlined,
      submitLabel: 'Update',
      gradient: kitBlue,
      builder: (ctx, setSheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KitReadOnly(label: 'Dealer', value: kitStr(d['name'])),
          kitGap,
          KitSelect(
            label: 'Status',
            value: status,
            items: _kDealerStatuses,
            onChanged: (v) => setSheet(() => status = v),
          ),
        ],
      ),
      onSubmit: () async {
        try {
          await _api.put('/dealers/${kitStr(d['id'])}?companyId=$_cid', body: {
              'status': status,
              // Go `UpdateDealer` assigns `Address` unconditionally, so a
              // status-only body (as the web sends) would wipe the address.
              'address': kitStr(d['address']),
            });
          if (mounted) showToast(context, 'Dealer status updated to "$status".');
          await _load();
          return true;
        } catch (e) {
          if (mounted) kitReportError(context, e);
          return false;
        }
      },
    );
  }

  Future<void> _delete(Map<String, dynamic> d) async {
    await showNetworkDeleteDialog(
      context,
      itemName: kitStr(d['name']),
      onConfirm: () async {
        try {
          await _api.delete('/dealers/${kitStr(d['id'])}?companyId=$_cid');
          if (mounted) showToast(context, 'Dealer deleted successfully.');
          await _load();
        } catch (e) {
          if (mounted) kitReportError(context, e);
        }
      },
    );
  }

  Widget _menu(Map<String, dynamic> d) => KitRowMenu(actions: [
        KitAction('Edit', Icons.edit_outlined, _canUpdate ? () => _openForm(d) : null),
        KitAction('Change Status', Icons.toggle_on_outlined, _canStatus ? () => _changeStatus(d) : null),
        KitAction('Delete', Icons.delete_outline, _canDelete ? () => _delete(d) : null, danger: true),
      ]);

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final wallet = _dealers.fold<double>(0, (a, d) => a + kitNum(d['walletBalance']));
    final avgCommission = _dealers.isEmpty
        ? 0.0
        : _dealers.fold<double>(0, (a, d) => a + kitNum(d['commissionRate'])) / _dealers.length;
    return RefreshIndicator(
      onRefresh: _load,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.handshake_outlined,
            title: 'My Dealers',
            subtitle: 'Manage all dealers operating under your network.',
            gradient: kitBlue,
          ),
          if (_cid.isEmpty)
            const KitNoCompany(what: 'dealers')
          else if (_loading)
            const KitLoading()
          else if (_error != null && _dealers.isEmpty)
            KitErrorCard(message: _error!, onRetry: _load)
          else ...[
            NetworkStatGrid(children: [
              kitStat('Total Dealers', _dealers.length, Icons.handshake_outlined, kitBlue),
              kitStat('Total Wallet Balance', 'PKR ${kitMoney(wallet)}', Icons.account_balance_wallet_outlined, kitEmerald),
              kitStat('Avg Commission', '${avgCommission.toStringAsFixed(1)}%', Icons.percent, kitViolet),
            ]),
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
                        hint: 'Search dealers...',
                        onChanged: (v) => setState(() {
                          _filter = v;
                          _page = 1;
                        }),
                      ),
                    ],
                    actions: [
                      if (_canCreate)
                        GradientButton(
                          label: 'Add Dealer',
                          icon: Icons.add_circle_outline,
                          gradient: kitEmerald,
                          onPressed: () => _openForm(null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  NetworkTable<Map<String, dynamic>>(
                    rows: kitPage(filtered, _page, _pageSize),
                    emptyIcon: Icons.handshake_outlined,
                    emptyTitle: 'No dealers found.',
                    emptyHint: '',
                    emptyTint: AppColors.emerald600,
                    mobileTrailing: (c, d, _) => _menu(d),
                    columns: [
                      NetColumn(label: 'Name', width: 160, builder: (c, d, _) => Text(kitStr(d['name']), style: const TextStyle(fontWeight: FontWeight.w600))),
                      NetColumn(label: 'Phone', width: 120, builder: (c, d, _) => Text(kitStr(d['phone']))),
                      NetColumn(label: 'Email', width: 190, builder: (c, d, _) => Text(kitStr(d['email']))),
                      NetColumn(label: 'Area', width: 150, builder: (c, d, _) => Text(kitStr(d['areaName']).isEmpty ? '—' : kitStr(d['areaName']))),
                      NetColumn(label: 'Commission', width: 100, builder: (c, d, _) => Text('${kitNum(d['commissionRate'])}%')),
                      NetColumn(label: 'Wallet', width: 120, builder: (c, d, _) => Text(kitMoney(kitNum(d['walletBalance'])))),
                      NetColumn(label: 'Status', width: 100, builder: (c, d, _) => Text(_kDealerStatuses[kitStr(d['status'])] ?? kitTitle(kitStr(d['status'])))),
                      NetColumn(label: '', width: 70, isActions: true, builder: (c, d, _) => _menu(d)),
                    ],
                  ),
                  if (filtered.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    NetworkPagination(
                      currentPage: _page,
                      pageSize: _pageSize,
                      totalItems: filtered.length,
                      noun: 'dealers',
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
