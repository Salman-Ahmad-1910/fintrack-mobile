import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../models/models.dart';
import '../../../theme/app_theme.dart';

/// Card shell with icon-chip header + "View All" link, matching the web
/// dashboard's Recent Payments / Open Complaints cards.
class DashboardTableCard extends StatelessWidget {
  const DashboardTableCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.headers,
    required this.children,
    this.emptyIcon,
    this.emptyText,
    this.onViewAll,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final List<Widget> headers;
  final List<Widget> children;
  final IconData? emptyIcon;
  final String? emptyText;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InkWell(
                onTap: onViewAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'View All',
                      style: TextStyle(fontSize: 13, color: AppColors.primary),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.north_east,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: context.mutedFg),
          ),
          const SizedBox(height: 14),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      emptyIcon ?? Icons.hourglass_empty,
                      size: 32,
                      color: context.mutedFg.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      emptyText ?? '',
                      style: TextStyle(fontSize: 13, color: context.mutedFg),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                _headerRow(),
                const Divider(height: 1),
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1) const Divider(height: 1),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: headers),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.child, this.flex = 1, this.alignRight = false});

  final Widget child;
  final int flex;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
  }
}

class PaymentRow extends StatelessWidget {
  const PaymentRow({super.key, required this.payment});

  final PaymentItem payment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _Cell(
            flex: 3,
            child: Text(
              payment.subscriberName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          _Cell(
            flex: 2,
            alignRight: true,
            child: Text(
              groupedDecimals(payment.amount),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF059669),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Cell(
            flex: 2,
            child: Text(
              payment.paymentDate,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.mutedFg),
            ),
          ),
          const SizedBox(width: 8),
          _Cell(flex: 2, child: _MethodBadge(method: payment.method)),
        ],
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    final normalized = method.toLowerCase();
    IconData icon;
    Color color;
    switch (normalized) {
      case 'cash':
        icon = Icons.attach_money;
        color = const Color(0xFF10B981);
      case 'card':
        icon = Icons.credit_card;
        color = const Color(0xFF3B82F6);
      case 'bank':
        icon = Icons.account_balance;
        color = const Color(0xFFA855F7);
      default:
        icon = Icons.attach_money;
        color = context.mutedFg;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(method, style: TextStyle(fontSize: 11, color: context.fg)),
        ],
      ),
    );
  }
}

class ComplaintRow extends StatelessWidget {
  const ComplaintRow({super.key, required this.complaint});

  final ComplaintItem complaint;

  @override
  Widget build(BuildContext context) {
    final isOpen = complaint.status.toLowerCase() == 'open';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _Cell(
            flex: 3,
            child: Text(
              complaint.subscriberName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          _Cell(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: context.subtle,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                complaint.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Cell(
            flex: 2,
            child: Text(
              complaintDate(complaint.createdAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.mutedFg),
            ),
          ),
          const SizedBox(width: 8),
          _Cell(
            flex: 2,
            child: _StatusBadge(status: complaint.status, isOpen: isOpen),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.isOpen});

  final String status;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.destructive : context.subtle,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpen ? Icons.cancel_outlined : Icons.check_circle_outline,
            size: 12,
            color: isOpen ? Colors.white : context.fg,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              color: isOpen ? Colors.white : context.fg,
            ),
          ),
        ],
      ),
    );
  }
}
