import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/navigation.dart';
import '../../core/offline_api.dart';
import '../../core/session.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../network/network_common.dart';
import '../sales/sales_common.dart';
import 'transaction_common.dart';
import 'transaction_models.dart';

const List<Color> _kEmerald = [Color(0xFF059669), Color(0xFF16A34A)];
const List<Color> _kAmber = [Color(0xFFD97706), Color(0xFFF59E0B)];

const Map<String, String> _periodLabels = {
  'daily': 'Daily',
  'weekly': 'Weekly',
  'monthly': 'Monthly',
  'yearly': 'Yearly',
};

/// Flutter counterpart of
/// `client/src/app/(app)/transaction/collection-details/page.tsx`.
///
/// Web routes to this page from the dashboard collection chart using
/// `?period=daily|weekly|monthly|yearly` and an optional `month=YYYY-MM`.
class CollectionDetailsScreen extends StatefulWidget {
  const CollectionDetailsScreen({
    super.key,
    required this.period,
    this.month,
  });

  final String period;
  final String? month;

  @override
  State<CollectionDetailsScreen> createState() =>
      _CollectionDetailsScreenState();
}

class _CollectionDetailsScreenState extends State<CollectionDetailsScreen> {
  final OfflineApi _api = OfflineApi(onUnauthorized: _handleUnauthorized);

  List<TxPayment> _payments = [];
  bool _loading = true;

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

  Future<void> _load() async {
    final cid = _cid;
    if (cid == null || cid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final json = await _api.get('/billing/payments', query: {'companyId': cid});
      if (!mounted) return;
      setState(() {
        _payments = ApiClient.listData(json)
            .whereType<Map<String, dynamic>>()
            .map(TxPayment.fromJson)
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) return;
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool _included(DateTime d) {
    final now = DateTime.now();
    final period = widget.period;
    switch (period) {
      case 'daily':
        final start = DateTime(now.year, now.month, now.day);
        return !d.isBefore(start);
      case 'weekly':
        final weekAgo = DateTime(now.year, now.month, now.day - 7);
        return !d.isBefore(weekAgo);
      case 'monthly':
        final target = widget.month ??
            '${now.year.toString().padLeft(4, '0')}-${(now.month).toString().padLeft(2, '0')}';
        final itemMonth =
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
        return itemMonth == target;
      case 'yearly':
        return d.year == now.year;
      default:
        return true;
    }
  }

  List<TxPayment> get _filtered => _payments.where((p) {
        final d = p.paymentDate ?? p.createdAt;
        if (d == null) return false;
        return _included(d);
      }).toList();

  double get _totalAmount =>
      _filtered.fold(0.0, (sum, p) => sum + p.amount);

  String get _periodLabel => _periodLabels[widget.period] ?? widget.period;

  String get _subtitle {
    switch (widget.period) {
      case 'daily':
        return "Today's collection entries";
      case 'weekly':
        return 'Last 7 days collection entries';
      case 'monthly':
        final m = widget.month;
        if (m != null && m.isNotEmpty) {
          final parts = m.split('-');
          if (parts.length == 2) {
            final d = DateTime(int.parse(parts[0]), int.parse(parts[1]));
            return 'Collection for ${DateFormat('MMMM yyyy').format(d)}';
          }
        }
        return "This month's collection entries";
      case 'yearly':
        return "This year's collection entries";
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = NetworkScrollBody(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _kEmerald,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Color(0x22059669), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_periodLabel Collection Details',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle,
                    style: TextStyle(fontSize: 13, color: context.mutedFg),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 12),
        Row(
          children: [
            Expanded(
              child: NetworkStatCard(
                icon: Icons.receipt_long_outlined,
                label: 'Total Entries',
                value: '${_filtered.length}',
                gradient: _kEmerald,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NetworkStatCard(
                icon: Icons.payments_outlined,
                label: 'Total Amount',
                value: 'PKR ${salesNumber(_totalAmount)}',
                gradient: _kAmber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _table(context),
      ],
    );
    return RefreshIndicator(onRefresh: _load, child: body);
  }

  Widget _table(BuildContext context) {
    final rows = _filtered;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            : rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 40,
                          color: context.mutedFg.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No collection entries found',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: context.mutedFg,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No records available for the selected period.',
                          style: TextStyle(fontSize: 12, color: context.mutedFg),
                        ),
                      ],
                    ),
                  )
                : NetworkTable<TxPayment>(
                    rows: rows,
                    emptyIcon: Icons.receipt_long_outlined,
                    emptyTitle: 'No collection entries found',
                    emptyHint: 'No records available for the selected period.',
                    emptyTint: AppColors.emerald600,
                    columns: [
                      NetColumn(
                        label: '#',
                        width: 40,
                        builder: (context, p, index) => Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                      NetColumn(
                        label: 'Subscriber',
                        width: 180,
                        builder: (context, p, _) {
                          final name = p.subscriberName.isEmpty
                              ? 'Unknown'
                              : p.subscriberName;
                          return Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          );
                        },
                      ),
                      NetColumn(
                        label: 'Amount',
                        width: 130,
                        builder: (context, p, _) => Text(
                          'PKR ${salesNumber(p.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      NetColumn(
                        label: 'Date',
                        width: 110,
                        builder: (context, p, _) {
                          final d = p.paymentDate ?? p.createdAt;
                          return Text(
                            d == null
                                ? '-'
                                : DateFormat('MMM d, yyyy').format(d),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.mutedFg,
                            ),
                          );
                        },
                      ),
                      NetColumn(
                        label: 'Payment Method',
                        width: 130,
                        builder: (context, p, _) => TxBadge(
                          label: p.method.isEmpty ? 'cash' : p.method,
                          color: context.fg,
                          background: context.subtle,
                        ),
                      ),
                      NetColumn(
                        label: 'Address',
                        width: 170,
                        builder: (context, p, _) => Text(
                          p.address.isEmpty ? '---' : p.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.mutedFg,
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}