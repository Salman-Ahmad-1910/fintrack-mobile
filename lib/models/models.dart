/// Models mirroring the Go API payloads used by the dashboard.
library;

num _num(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

double _d(Object? v) => _num(v).toDouble();

int _i(Object? v) => _num(v).toInt();

String _s(Object? v) => v?.toString() ?? '';

class Company {
  const Company({
    required this.id,
    required this.name,
    this.logo = '',
    this.role = '',
  });

  final String id;
  final String name;
  final String logo;
  final String role;

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: _s(json['id']),
    name: _s(json['name']),
    logo: _s(json['logo']),
    role: _s(json['role']),
  );
}

class ChartPoint {
  const ChartPoint({required this.label, required this.value});

  final String label;
  final double value;

  factory ChartPoint.fromJson(Map<String, dynamic> json) =>
      ChartPoint(label: _s(json['label']), value: _d(json['value']));
}

class SubscriberStats {
  const SubscriberStats({
    this.total = 0,
    this.active = 0,
    this.suspended = 0,
    this.inactive = 0,
    this.pending = 0,
    this.advance = 0,
    this.paid = 0,
  });

  final int total;
  final int active;
  final int suspended;
  final int inactive;
  final int pending;
  final int advance;
  final int paid;

  factory SubscriberStats.fromJson(Map<String, dynamic> json) =>
      SubscriberStats(
        total: _i(json['total']),
        active: _i(json['active']),
        suspended: _i(json['suspended']),
        inactive: _i(json['inactive']),
        pending: _i(json['pending']),
        advance: _i(json['advance']),
        paid: _i(json['paid']),
      );
}

class PaymentItem {
  const PaymentItem({
    required this.id,
    required this.subscriberName,
    required this.amount,
    required this.paymentDate,
    required this.method,
  });

  final String id;
  final String subscriberName;
  final double amount;
  final String paymentDate;
  final String method;

  factory PaymentItem.fromJson(Map<String, dynamic> json) => PaymentItem(
    id: _s(json['id']),
    subscriberName: _s(json['subscriberName']),
    amount: _d(json['amount']),
    paymentDate: _s(json['paymentDate']),
    method: _s(json['method']),
  );
}

class ComplaintItem {
  const ComplaintItem({
    required this.id,
    required this.subscriberName,
    required this.category,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String subscriberName;
  final String category;
  final String status;
  final String createdAt;

  bool get isOpen => status != 'resolved' && status != 'closed';

  factory ComplaintItem.fromJson(Map<String, dynamic> json) => ComplaintItem(
    id: _s(json['id']),
    subscriberName: _s(json['subscriberName']),
    category: _s(json['category']),
    status: _s(json['status']),
    createdAt: _s(json['createdAt']),
  );
}

class DashboardData {
  const DashboardData({
    required this.subscribersStats,
    required this.totalCollectionToday,
    required this.totalCollectionMonth,
    required this.totalCollection,
    required this.pendingAmount,
    required this.paidAmount,
    required this.receivableAmount,
    required this.receivedAllTime,
    required this.receivedThisMonth,
    required this.advanceAmount,
    required this.badDebtAmount,
    required this.overdueCount,
    required this.overdueAmount,
    required this.complaintsCount,
    required this.payments,
    required this.complaints,
    required this.dailyCollection,
    required this.subscriberGrowth,
    required this.selectedMonth,
    required this.selectedYear,
  });

  final SubscriberStats subscribersStats;
  final double totalCollectionToday;
  final double totalCollectionMonth;
  final double totalCollection;
  final double pendingAmount;
  final double paidAmount;
  final double receivableAmount;
  final double receivedAllTime;
  final double receivedThisMonth;
  final double advanceAmount;
  final double badDebtAmount;
  final int overdueCount;
  final double overdueAmount;
  final int complaintsCount;
  final List<PaymentItem> payments;
  final List<ComplaintItem> complaints;
  final List<ChartPoint> dailyCollection;
  final List<ChartPoint> subscriberGrowth;
  final String selectedMonth;
  final String selectedYear;

  List<ComplaintItem> get openComplaints =>
      complaints.where((c) => c.isOpen).toList();

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    List<ChartPoint> points(Object? raw) => raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(ChartPoint.fromJson)
              .toList()
        : <ChartPoint>[];

    return DashboardData(
      subscribersStats: SubscriberStats.fromJson(
        (json['subscribersStats'] as Map<String, dynamic>?) ?? const {},
      ),
      totalCollectionToday: _d(json['totalCollectionToday']),
      totalCollectionMonth: _d(json['totalCollectionMonth']),
      totalCollection: _d(json['totalCollection']),
      pendingAmount: _d(json['pendingAmount']),
      paidAmount: _d(json['paidAmount']),
      receivableAmount: _d(json['receivableAmount']),
      receivedAllTime: _d(json['receivedAllTime']),
      receivedThisMonth: _d(json['receivedThisMonth']),
      advanceAmount: _d(json['advanceAmount']),
      badDebtAmount: _d(json['badDebtAmount']),
      overdueCount: _i(json['overdueCount']),
      overdueAmount: _d(json['overdueAmount']),
      complaintsCount: _i(json['complaintsCount']),
      payments: ((json['payments'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PaymentItem.fromJson)
          .toList(),
      complaints: ((json['complaints'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ComplaintItem.fromJson)
          .toList(),
      dailyCollection: points(json['dailyCollection']),
      subscriberGrowth: points(json['subscriberGrowth']),
      selectedMonth: _s(json['selectedMonth']),
      selectedYear: _s(json['selectedYear']),
    );
  }
}

class ChartSeries {
  const ChartSeries({
    required this.period,
    required this.points,
    this.periodTotal = 0,
  });

  final String period;
  final List<ChartPoint> points;
  final double periodTotal;

  factory ChartSeries.fromJson(Map<String, dynamic> json) => ChartSeries(
    period: _s(json['period']),
    points: ((json['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChartPoint.fromJson)
        .toList(),
    periodTotal: _d(json['periodTotal']),
  );
}

/// `/auth/me` payload (subset the dashboard needs).
class MeProfile {
  const MeProfile({
    required this.role,
    required this.permissions,
    required this.permissionsConfigured,
    this.name = '',
    this.email = '',
    this.id = '',
  });

  final String role;
  final List<String> permissions;
  final bool permissionsConfigured;
  final String name;
  final String email;

  /// The signed-in user's id (`GET /auth/me` → `id`). The Allocated
  /// Complaints page uses it to show staff only their own complaints.
  final String id;

  factory MeProfile.fromJson(Map<String, dynamic> json) => MeProfile(
    role: _s(json['role']),
    permissions: ((json['permissions'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(),
    permissionsConfigured: json['permissionsConfigured'] == true,
    name: _s(json['name']),
    email: _s(json['email']),
    id: _s(json['id']),
  );
}
