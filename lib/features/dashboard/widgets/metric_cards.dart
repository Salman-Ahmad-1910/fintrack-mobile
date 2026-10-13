import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/models.dart';
import '../../../theme/app_theme.dart';

final NumberFormat _nf = NumberFormat('#,##0');

/// Gradient-tinted metric card replicating the shadcn `<Card>` blocks used on
/// the web dashboard (11px title, gradient icon chip, 2xl value, caption).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.caption,
    required this.colors,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String value;
  final String caption;
  final List<Color> colors;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      gradientTint: true,
      gradientColors: colors,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 132),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 13, color: Colors.white),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: TextStyle(
                fontSize: 11,
                color: context.mutedFg,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subscriber overview row (horizontal scroll, 180–280px cards on web).
class SubscriberStatsRow extends StatelessWidget {
  const SubscriberStatsRow({
    super.key,
    required this.stats,
    required this.packageType,
    required this.companyName,
    required this.onTap,
  });

  final SubscriberStats stats;
  final String packageType;
  final String companyName;
  final void Function(String route) onTap;

  String get _typeLabel => packageType == 'both'
      ? 'all'
      : packageType == 'tv_cable'
      ? 'TV cable'
      : 'internet';

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      MetricCard(
        title: 'Total Subscribers',
        value: '${stats.total}',
        caption: '$_typeLabel subscribers',
        colors: const [Color(0xFF0EA5E9), Color(0xFF3B82F6)],
        icon: Icons.people,
        onTap: () => onTap('/collection/active-subscribers'),
      ),
      MetricCard(
        title: 'Active Subscribers',
        value: '${stats.active}',
        caption: packageType == 'both'
            ? 'in $companyName'
            : '${_typeLabel.startsWith('TV') ? 'TV cable ' : 'internet '}in $companyName',
        colors: const [Color(0xFF3B82F6), Color(0xFF06B6D4)],
        icon: Icons.people,
        onTap: () => onTap('/collection/active-subscribers'),
      ),
      MetricCard(
        title: 'Inactive Subscribers',
        value: '${stats.inactive}',
        caption: 'suspended / inactive',
        colors: const [Color(0xFFF97316), Color(0xFFF59E0B)],
        icon: Icons.cancel_outlined,
        onTap: () => onTap('/collection/overdue-subscribers'),
      ),
      MetricCard(
        title: 'Pending Subscribers',
        value: '${stats.pending}',
        caption: 'still owe amount',
        colors: const [Color(0xFFF59E0B), Color(0xFFF97316)],
        icon: Icons.schedule,
        onTap: () => onTap('/collection/pending-subscribers'),
      ),
    ];

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => SizedBox(width: 220, child: cards[i]),
      ),
    );
  }
}

/// Financial metrics grid — 2 columns on phones, mirroring the web's
/// 1/2/3 column responsive grid.
class FinancialMetricsGrid extends StatelessWidget {
  const FinancialMetricsGrid({
    super.key,
    required this.data,
    required this.monthName,
    required this.year,
    required this.onTap,
  });

  final DashboardData data;
  final String monthName;
  final String year;
  final void Function(String route) onTap;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      MetricCard(
        title: 'Receivable',
        value: 'PKR ${_grouped(data.receivableAmount)}',
        caption: 'pending + received this month',
        colors: const [Color(0xFF10B981), Color(0xFF22C55E)],
        icon: Icons.payments_outlined,
        onTap: () => onTap('/collection/pending-subscribers'),
      ),
      MetricCard(
        title: 'Balance',
        value: 'PKR ${_grouped(data.pendingAmount)}',
        caption: 'pending amount this month',
        colors: const [Color(0xFFF59E0B), Color(0xFFF97316)],
        icon: Icons.schedule,
        onTap: () => onTap('/collection/pending-subscribers'),
      ),
      MetricCard(
        title: 'Received (All Time)',
        value: 'PKR ${_grouped(data.receivedAllTime)}',
        caption: 'total payments received',
        colors: const [Color(0xFF3B82F6), Color(0xFF6366F1)],
        icon: Icons.account_balance_wallet_outlined,
        onTap: () => onTap('/billing/payments'),
      ),
      MetricCard(
        title: 'Total Balance',
        value: 'PKR ${_grouped(data.pendingAmount)}',
        caption: 'remaining amount all time',
        colors: const [Color(0xFF06B6D4), Color(0xFF0EA5E9)],
        icon: Icons.schedule,
        onTap: () => onTap('/collection/pending-subscribers'),
      ),
      MetricCard(
        title: 'Received This Month',
        value: 'PKR ${_grouped(data.receivedThisMonth)}',
        caption: 'collected in $monthName $year',
        colors: const [Color(0xFF14B8A6), Color(0xFF10B981)],
        icon: Icons.trending_up,
        onTap: () => onTap('/billing/payments'),
      ),
      MetricCard(
        title: 'Bad Debt',
        value: 'PKR ${_grouped(data.badDebtAmount)}',
        caption: 'unpaid by lost / defaulted subscribers',
        colors: const [Color(0xFFEF4444), Color(0xFFF43F5E)],
        icon: Icons.warning_amber_outlined,
        onTap: () => onTap('/collection/overdue-subscribers'),
      ),
      MetricCard(
        title: 'Paid Amount',
        value: 'PKR ${_grouped(data.paidAmount)}',
        caption: 'received from fully paid subscribers',
        colors: const [Color(0xFF22C55E), Color(0xFF10B981)],
        icon: Icons.attach_money,
        onTap: () => onTap('/collection/paid-subscribers'),
      ),
      MetricCard(
        title: 'Paid Subscribers',
        value: '${data.subscribersStats.paid}',
        caption: 'subscribers who cleared their dues',
        colors: const [Color(0xFF84CC16), Color(0xFF22C55E)],
        icon: Icons.check_circle_outline,
        onTap: () => onTap('/collection/paid-subscribers'),
      ),
      MetricCard(
        title: 'Advance Amount',
        value: 'PKR ${_grouped(data.advanceAmount)}',
        caption: 'overpaid / advance credit',
        colors: const [Color(0xFFEAB308), Color(0xFFF59E0B)],
        icon: Icons.account_balance,
        onTap: () => onTap('/collection/advance-subscribers'),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: cards,
    );
  }
}

String _grouped(num v) => _nf.format(v);
