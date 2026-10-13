import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_utils.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import '../sales/sales_common.dart';
import 'transaction_common.dart';
import 'transaction_models.dart';

const List<Color> _kViolet = [Color(0xFF6D28D9), Color(0xFF9333EA)];
const List<Color> _kBlue = [Color(0xFF2563EB), Color(0xFF0891B2)];
const List<Color> _kGreen = [Color(0xFF059669), Color(0xFF16A34A)];

const _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

List<int> _yearOptions() {
  final now = DateTime.now().year;
  return [for (var y = now - 5; y <= now + 1; y++) y];
}

String _monthYear(DateTime dt) => DateFormat('MMM yyyy').format(dt);
String _shortDate(DateTime dt) => DateFormat('M/d/yyyy').format(dt);

/// Flutter counterpart of
/// `client/src/app/(app)/transaction/allocated-collections/page.tsx`.
class AllocatedCollectionsScreen extends StatefulWidget {
  const AllocatedCollectionsScreen({super.key});

  @override
  State<AllocatedCollectionsScreen> createState() =>
      _AllocatedCollectionsScreenState();
}

class _AllocatedCollectionsScreenState extends State<AllocatedCollectionsScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<TxSubscriber> _subscribers = [];
  List<TxPayment> _payments = [];
  bool _loading = true;
  bool _loadingPayments = false;
  String? _selectedSubscriberId;

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

  TxSubscriber? get _selected => _subscribers
      .where((s) => s.id == _selectedSubscriberId)
      .firstOrNull;

  List<TxPayment> get _allocatedPayments => _payments
      .where((p) => p.subscriberId?.toString() == _selectedSubscriberId)
      .toList();

  @override
  void initState() {
    super.initState();
    _loadSubscribers();
  }

  Future<void> _loadSubscribers() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final json = await _api.get(
        '/billing/subscribers',
        query: {'companyId': cid},
      );
      if (!mounted) return;
      setState(() {
        _subscribers = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(TxSubscriber.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadPayments() async {
    final cid = _cid;
    final id = _selectedSubscriberId;
    if (cid == null || cid.isEmpty || id == null) return;
    setState(() => _loadingPayments = true);
    try {
      final json = await _api.get(
        '/billing/payments',
        query: {'companyId': cid},
      );
      if (!mounted) return;
      setState(() {
        _payments = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(TxPayment.fromJson)
            .toList();
        _loadingPayments = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loadingPayments = false);
    }
  }

  void _selectSubscriber(String? id) {
    setState(() {
      _selectedSubscriberId = id;
      _payments = [];
      _loadingPayments = false;
    });
    if (id != null) _loadPayments();
  }

  double get _totalAmount =>
      _payments.fold<double>(0, (sum, p) => sum + p.amount);

  Future<void> _createPayment(Map<String, dynamic> payload) async {
    try {
      await _api.post('/billing/payments', body: payload);
      if (!mounted) return;
      showToast(context, 'Payment recorded successfully.');
      await _loadPayments();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (mounted) showToast(context, e.message, error: true);
    }
  }

  Future<void> _openNewAmount() async {
    final subscriber = _selected;
    if (subscriber == null) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _NewPaymentDialog(subscriber: subscriber),
    );
    if (payload == null) return;
    await _createPayment(payload);
  }

  Future<void> _openPromiseDate() async {
    final subscriber = _selected;
    if (subscriber == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _PromiseDateDialog(),
    );
    if (result == null) return;
    await _createPayment({
      'subscriberId': subscriber.id,
      'subscriberName': subscriber.name,
      'amount': 0,
      'paymentDate': result['promiseDate'],
      'method': 'cash',
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadSubscribers,
      child: NetworkScrollBody(
        children: [
          const NetworkPageHeader(
            icon: Icons.edit_note_outlined,
            title: 'Allocated Collections',
            subtitle: 'View and manage allocated collections.',
            gradient: _kViolet,
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
                          icon: Icons.people_outline,
                          label: 'Subscribers',
                          value: '${_subscribers.length}',
                          gradient: _kViolet,
                        ),
                        NetworkStatCard(
                          icon: Icons.receipt_long_outlined,
                          label: 'Payments',
                          value: '${_payments.length}',
                          gradient: _kBlue,
                        ),
                        NetworkStatCard(
                          icon: Icons.attach_money_outlined,
                          label: 'Total Collected',
                          value: 'PKR ${salesNumber(_totalAmount)}',
                          gradient: _kGreen,
                          valueColor: context.isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF059669),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SalesFilterRows(
                      rows: [
                        [
                          TxSearchableSelect(
                            width: 360,
                            label: 'Select Subscriber',
                            placeholder: 'Search and select a subscriber...',
                            searchPlaceholder:
                                'Type to search by name, internet ID, or phone...',
                            options: [
                              for (final s in _subscribers)
                                TxPickOption(
                                  id: s.id,
                                  name:
                                      '${s.subscriberIdentity.isEmpty ? s.shortId : s.subscriberIdentity} | ${s.name}',
                                  secondary: s.phone,
                                ),
                            ],
                            value: _selectedSubscriberId,
                            onChanged: _selectSubscriber,
                          ),
                        ],
                        if (_selected != null)
                          [
                            GradientButton(
                              label: 'Promise Date',
                              icon: Icons.event_outlined,
                              gradient: _kBlue,
                              onPressed: _openPromiseDate,
                            ),
                            GradientButton(
                              label: 'New Amount',
                              icon: Icons.add_circle_outline,
                              gradient: _kGreen,
                              onPressed: _openNewAmount,
                            ),
                          ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selected == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_search_outlined,
                              size: 32,
                              color: context.mutedFg,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No Subscriber Selected',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: context.fg,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Search and select a subscriber to view their allocated collections.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.mutedFg,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _SubscriberPanel(
                        subscriber: _selected!,
                        payments: _allocatedPayments,
                        loadingPayments: _loadingPayments,
                        onPromiseDate: _openPromiseDate,
                        onNewAmount: _openNewAmount,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubscriberPanel extends StatelessWidget {
  const _SubscriberPanel({
    required this.subscriber,
    required this.payments,
    required this.loadingPayments,
    required this.onPromiseDate,
    required this.onNewAmount,
  });

  final TxSubscriber subscriber;
  final List<TxPayment> payments;
  final bool loadingPayments;
  final VoidCallback onPromiseDate;
  final VoidCallback onNewAmount;

  @override
  Widget build(BuildContext context) {
    final s = subscriber;
    final active = s.status == 'active';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Divider(),
        _MetaGrid(items: [
          ('Customer ID', Text(s.shortId)),
          ('Name', Text(s.name, overflow: TextOverflow.ellipsis)),
          ('Internet ID', Text(s.subscriberIdentity.isEmpty ? '---' : s.subscriberIdentity)),
          ('Address', Text(s.installationAddress.isEmpty ? '---' : s.installationAddress)),
        ]),
        _Divider(),
        _MetaGrid(items: [
          ('Monthly / Yearly', Text(s.billingCycle.isEmpty ? 'Monthly' : s.billingCycle)),
          ('Payment Type', Text('Cash')),
          ('Collection Type', Text(s.packageName.isEmpty ? 'Cable' : s.packageName)),
          ('Net Amount', Text('Rs. ${salesNumber(s.balance)}')),
          (
            'Status',
            TxBadge(
              label: s.status,
              color: active ? context.surface : context.mutedFg,
              background: active ? AppColors.primary : context.subtle,
            ),
          ),
        ]),
        _Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Balance',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: context.inputFill,
                        border: Border.all(color: context.line),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        salesNumber(s.balance),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GradientButton(
                label: 'Promise Date',
                icon: Icons.event_outlined,
                gradient: _kBlue,
                onPressed: onPromiseDate,
              ),
              const SizedBox(width: 8),
              GradientButton(
                label: 'New Amount',
                icon: Icons.add_circle_outline,
                gradient: _kGreen,
                onPressed: onNewAmount,
              ),
            ],
          ),
        ),
        _Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Allocated Collection History',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (loadingPayments)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (payments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No collection history found.',
                      style: TextStyle(color: context.mutedFg),
                    ),
                  ),
                )
              else
                NetworkTable<TxPayment>(
                  rows: payments,
                  emptyIcon: Icons.receipt_long_outlined,
                  emptyTitle: 'No collection history found.',
                  emptyHint: '',
                  emptyTint: AppColors.emerald600,
                  columns: [
                    NetColumn(
                      label: 'Bill Number',
                      width: 90,
                      builder: (context, p, index) => Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: context.mutedFg,
                        ),
                      ),
                    ),
                    NetColumn(
                      label: 'Customer ID',
                      width: 110,
                      builder: (context, p, _) => Text(
                        s.shortId,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    NetColumn(
                      label: 'Month / Year',
                      width: 110,
                      builder: (context, p, _) =>
                          Text(p.paymentDate == null ? '---' : _monthYear(p.paymentDate!)),
                    ),
                    NetColumn(
                      label: 'Payment Type',
                      width: 110,
                      builder: (context, p, _) => const Text('Monthly'),
                    ),
                    NetColumn(
                      label: 'Collection Type',
                      width: 130,
                      builder: (context, p, _) => Text(
                        s.packageName.isEmpty ? 'Cable' : s.packageName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    NetColumn(
                      label: 'Receive Amount',
                      width: 130,
                      builder: (context, p, _) => Text('Rs. ${salesNumber(p.amount)}'),
                    ),
                    NetColumn(
                      label: 'Receiving Date',
                      width: 110,
                      builder: (context, p, _) =>
                          Text(p.paymentDate == null ? '---' : _shortDate(p.paymentDate!)),
                    ),
                    NetColumn(
                      label: 'Status',
                      width: 80,
                      center: true,
                      builder: (context, p, _) => TxBadge(
                        label: 'Paid',
                        color: const Color(0xFF16A34A),
                        background: const Color(0xFF16A34A).withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaGrid extends StatelessWidget {
  const _MetaGrid({required this.items});

  final List<(String, Widget)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (label, child) in items)
              SizedBox(
                width: width,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.mutedFg,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1);
}

class _NewPaymentDialog extends StatefulWidget {
  const _NewPaymentDialog({required this.subscriber});

  final TxSubscriber subscriber;

  @override
  State<_NewPaymentDialog> createState() => _NewPaymentDialogState();
}

class _NewPaymentDialogState extends State<_NewPaymentDialog> {
  String _collectionType = 'cable';
  String _paymentType = 'monthly';
  final TextEditingController _netAmount = TextEditingController();
  String _month = DateTime.now().month.toString();
  String _year = DateTime.now().year.toString();
  static const bool _saving = false;

  bool get _hasNet => (double.tryParse(_netAmount.text.trim()) ?? 0) > 0;

  @override
  void dispose() {
    _netAmount.dispose();
    super.dispose();
  }

  void _onPackageFee(String v) {
    if ((double.tryParse(v) ?? 0) > 0) {
      _netAmount.text = v.trim();
    }
    setState(() {});
  }

  void _submit() {
    if (!_hasNet || _saving) return;
    final amount = double.tryParse(_netAmount.text.trim()) ?? 0;
    Navigator.of(context).pop({
      'subscriberId': widget.subscriber.id,
      'subscriberName': widget.subscriber.name,
      'amount': amount,
      'paymentDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'method': 'cash',
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subscriber;
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('New Payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _readonlyRow('Customer ID', s.shortId, 'Name', s.name),
            const SizedBox(height: 14),
            NetField(
              label: 'Internet ID',
              child: _readonly(s.subscriberIdentity.isEmpty ? '---' : s.subscriberIdentity),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: NetField(
                    label: 'Collection Type',
                    child: TxSelect(
                      value: _collectionType,
                      items: const {
                        'cable': 'Cable',
                        'internet': 'Internet',
                        'both': 'Both',
                      },
                      onChanged: (v) => setState(() => _collectionType = v),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NetField(
                    label: 'Payment Type',
                    child: TxSelect(
                      value: _paymentType,
                      items: const {
                        'monthly': 'Monthly',
                        'yearly': 'Yearly',
                      },
                      onChanged: (v) => setState(() => _paymentType = v),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: NetField(
                    label: 'Package Fee',
                    child: TextField(
                      keyboardType: TextInputType.number,
                      onChanged: _onPackageFee,
                      style: const TextStyle(fontSize: 14),
                      decoration: netInputDecoration(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NetField(
                    label: 'Net Amount',
                    child: TextField(
                      keyboardType: TextInputType.number,
                      controller: _netAmount,
                      onChanged: (v) => setState(() {}),
                      style: const TextStyle(fontSize: 14),
                      decoration: netInputDecoration(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: NetField(
                    label: 'Month',
                    child: TxSelect(
                      value: _month,
                      items: {
                        for (var i = 0; i < _kMonths.length; i++)
                          '${i + 1}': _kMonths[i],
                      },
                      onChanged: (v) => setState(() => _month = v),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NetField(
                    label: 'Year',
                    child: TxSelect(
                      value: _year,
                      items: {
                        for (final y in _yearOptions()) '$y': '$y',
                      },
                      onChanged: (v) => setState(() => _year = v),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: 'Submit',
              gradient: _kGreen,
              loading: _saving,
              onPressed: _hasNet && !_saving ? _submit : null,
            ),
          ],
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
      ],
    );
  }

  Widget _readonlyRow(String l1, String v1, String l2, String v2) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: NetField(label: l1, child: _readonly(v1))),
        const SizedBox(width: 12),
        Expanded(child: NetField(label: l2, child: _readonly(v2))),
      ],
    );
  }

  Widget _readonly(String value) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: context.inputFill,
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

class _PromiseDateDialog extends StatefulWidget {
  const _PromiseDateDialog();

  @override
  State<_PromiseDateDialog> createState() => _PromiseDateDialogState();
}

class _PromiseDateDialogState extends State<_PromiseDateDialog> {
  late String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.surface,
      title: const Text('Set Promise Date'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NetField(
              label: 'Promise Date',
              child: TxDateField(
                label: 'Select date...',
                value: _date,
                onChanged: (v) => setState(() => _date = v),
                width: double.infinity,
              ),
            ),
            const SizedBox(height: 14),
            NetField(
              label: 'Remarks',
              child: TextField(
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14),
                decoration: netInputDecoration(
                  context,
                  hint: 'Optional notes...',
                ),
              ),
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: 'Save',
              gradient: _kBlue,
              onPressed: () => Navigator.of(context).pop({'promiseDate': _date}),
            ),
          ],
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
      ],
    );
  }
}