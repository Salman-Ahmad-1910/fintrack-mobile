/// Data models for the Transaction feature, mapped 1:1 to the web client
/// (`client/src/app/(app)/transaction/**`) and the Go backend JSON payloads.
///
/// The backend accepts/returns camelCase (with a snake_case fallback tolerated
/// here), so [fromJson] reads either form. IDs mirror the web types: billing
/// subscribers/connections and dealers use hex string ids, while catalog rows
/// (transaction types, areas) use numeric ids.
library;

dynamic _g(Map<String, dynamic> j, String key) {
  if (j.containsKey(key)) return j[key];
  final snake = key.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m[0]!.toLowerCase()}',
  );
  if (j.containsKey(snake)) return j[snake];
  return null;
}

String _s(dynamic v) => v?.toString() ?? '';

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int? _i(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// A subscriber / connection as returned by `/admin/connections`. Matches the
/// web `Connection` type (string hex `id`).
class TxConnection {
  TxConnection({
    required this.id,
    this.internetId = '',
    this.name = '',
    this.address = '',
    this.cell = '',
    this.mobile = '',
    this.connectionType = '',
    this.packageCable = '',
    this.packageInternet = '',
    this.amount = 0,
    this.sameAmount = 0,
    this.remainingAmount = 0,
    this.lastPaymentDate,
    this.rechargeDate,
    this.createdAt,
    this.areaName = '',
    this.areaId,
    this.sublocalityId = '',
    this.recoveryOfficerId,
    this.recoveryOfficerName = '',
    this.transactionId = '',
    this.connectionStatus = '',
    this.status = 'active',
  });

  final String id;
  final String internetId;
  final String name;
  final String address;
  final String cell;
  final String mobile;
  final String connectionType;
  final String packageCable;
  final String packageInternet;
  final double amount;
  final double sameAmount;
  final double remainingAmount;
  final DateTime? lastPaymentDate;
  final DateTime? rechargeDate;
  final DateTime? createdAt;
  final String areaName;
  final int? areaId;
  final String sublocalityId;
  final int? recoveryOfficerId;
  final String recoveryOfficerName;
  final String transactionId;
  final String connectionStatus;
  final String status;

  double get dueAmount => remainingAmount;

  String get primaryPhone => cell.isNotEmpty ? cell : mobile;
  String get shortId => id.length > 8 ? id.substring(0, 8) : id;
  String get displayInternetId =>
      internetId.isEmpty ? shortId : internetId;
  String get displayPackage =>
      packageInternet.isNotEmpty ? packageInternet : packageCable;

  factory TxConnection.fromJson(Map<String, dynamic> j) {
    final area = _g(j, 'area') ?? _g(j, 'sublocality') ?? _g(j, 'subLocality');
    final officer = _g(j, 'recoveryOfficer');
    return TxConnection(
      id: _s(_g(j, 'id')),
      internetId: _s(_g(j, 'internetId') ?? _g(j, 'internet_id')),
      name: _s(_g(j, 'name')),
      address: _s(_g(j, 'address')),
      cell: _s(_g(j, 'cell')),
      mobile: _s(_g(j, 'mobile')),
      connectionType: _s(_g(j, 'connectionType')),
      packageCable: _s(_g(j, 'packageCable') ?? _g(j, 'package_cable')),
      packageInternet: _s(_g(j, 'packageInternet') ?? _g(j, 'package_internet')),
      amount: _d(_g(j, 'amount')),
      sameAmount: _d(_g(j, 'sameAmount') ?? _g(j, 'same_amount')),
      remainingAmount: _d(_g(j, 'remainingAmount') ?? _g(j, 'remaining_amount')),
      lastPaymentDate: _date(_g(j, 'lastPaymentDate')),
      rechargeDate: _date(_g(j, 'rechargeDate')),
      createdAt: _date(_g(j, 'createdAt')),
      areaName: area is Map
          ? _s(_g(area.cast<String, dynamic>(), 'name'))
          : _s(area),
      areaId: _i(_g(j, 'areaId')),
      sublocalityId: _s(
        _g(j, 'sublocalityId') ?? _g(j, 'sublocality_id'),
      ),
      recoveryOfficerId: _i(_g(j, 'recoveryOfficerId')),
      recoveryOfficerName: officer is Map
          ? _s(_g(officer.cast<String, dynamic>(), 'name'))
          : _s(_g(j, 'recoveryOfficerName')),
      transactionId: _s(_g(j, 'transactionId')),
      connectionStatus: _s(_g(j, 'connectionStatus')),
      status: _s(_g(j, 'status')).isEmpty ? 'active' : _s(_g(j, 'status')),
    );
  }
}

/// A billing subscriber as returned by `/billing/subscribers` (used by the
/// Allocated collection page). Matches the web `Subscriber` type — `id` is a hex
/// string and billing fields use the `subscriber_*` naming.
class TxSubscriber {
  TxSubscriber({
    required this.id,
    this.name = '',
    this.subscriberIdentity = '',
    this.phone = '',
    this.installationAddress = '',
    this.billingCycle = '',
    this.packageName = '',
    this.balance = 0,
    this.status = 'active',
    this.companyId,
  });

  final String id;
  final String name;
  final String subscriberIdentity;
  final String phone;
  final String installationAddress;
  final String billingCycle;
  final String packageName;
  final double balance;
  final String status;
  final String? companyId;

  String get shortId => id.length > 8 ? id.substring(0, 8) : id;

  factory TxSubscriber.fromJson(Map<String, dynamic> j) {
    final company = _s(_g(j, 'companyId'));
    return TxSubscriber(
      id: _s(_g(j, 'id')),
      name: _s(_g(j, 'name')),
      subscriberIdentity: _s(
        _g(j, 'subscriberIdentity') ?? _g(j, 'subscriber_identity') ?? _g(j, 'internetId'),
      ),
      phone: _s(_g(j, 'phone')),
      installationAddress: _s(_g(j, 'installationAddress') ?? _g(j, 'address')),
      billingCycle: _s(_g(j, 'billingCycle') ?? _g(j, 'billing_cycle')),
      packageName: _s(_g(j, 'packageName') ?? _g(j, 'package_name')),
      balance: _d(_g(j, 'balance')),
      status: _s(_g(j, 'status')).isEmpty ? 'active' : _s(_g(j, 'status')),
      companyId: company.isEmpty ? _s(_g(j, 'company_id')) : company,
    );
  }
}

/// A payment row (`/billing/payments`).
class TxPayment {
  TxPayment({
    required this.id,
    this.billNo = '',
    this.subscriberId,
    this.subscriberName = '',
    this.internetId = '',
    this.amount = 0,
    this.paymentDate,
    this.method = '',
    this.transactionId = '',
    this.transactionType = '',
    this.collectorId,
    this.collectedByName = '',
    this.address = '',
    this.createdAt,
    this.companyId,
  });

  final String id;
  final String billNo;
  final String? subscriberId;
  final String subscriberName;
  final String internetId;
  final double amount;
  final DateTime? paymentDate;
  final String method;
  final String transactionId;
  final String transactionType;
  final int? collectorId;
  final String collectedByName;
  final String address;
  final DateTime? createdAt;
  final String? companyId;

  factory TxPayment.fromJson(Map<String, dynamic> j) {
    final sub = _g(j, 'subscriber');
    return TxPayment(
      id: _s(_g(j, 'id')),
      billNo: _s(_g(j, 'billNo') ?? _g(j, 'bill_no')),
      subscriberId: _s(_g(j, 'subscriberId')),
      subscriberName: sub is Map
          ? _s(_g(sub.cast<String, dynamic>(), 'name'))
          : _s(_g(j, 'subscriberName')),
      internetId: sub is Map
          ? _s(_g(sub.cast<String, dynamic>(), 'internetId'))
          : _s(_g(j, 'internetId')),
      amount: _d(_g(j, 'amount')),
      paymentDate: _date(_g(j, 'paymentDate')),
      method: _s(_g(j, 'method')),
      transactionId: _s(_g(j, 'transactionId')),
      transactionType: _s(_g(j, 'transactionType')),
      collectorId: _i(_g(j, 'collectorId')),
      collectedByName: _s(_g(j, 'collectedByName')),
      address: sub is Map
          ? _s(_g(sub.cast<String, dynamic>(), 'installationAddress'))
          : _s(_g(j, 'address')),
      createdAt: _date(_g(j, 'createdAt')),
      companyId: _s(_g(j, 'companyId')).isEmpty ? null : _s(_g(j, 'companyId')),
    );
  }
}

/// A recovery promise (`/billing/promises`).
class TxPromise {
  TxPromise({
    required this.id,
    this.companyId,
    this.subscriberId,
    this.subscriberName = '',
    this.internetId = '',
    this.phone = '',
    this.address = '',
    this.sublocality = '',
    this.connectionType = '',
    this.amount = 0,
    this.promiseDate,
    this.description = '',
    this.status = 'pending',
    this.collectorId,
    this.collectorName = '',
    this.createdAt,
  });

  final String id;
  final String? companyId;
  final String? subscriberId;
  final String subscriberName;
  final String internetId;
  final String phone;
  final String address;
  final String sublocality;
  final String connectionType;
  final double amount;
  final DateTime? promiseDate;
  final String description;
  final String status;
  final int? collectorId;
  final String collectorName;
  final DateTime? createdAt;

  factory TxPromise.fromJson(Map<String, dynamic> j) {
    final sub = _g(j, 'subscriber');
    final collector = _g(j, 'collector');
    return TxPromise(
      id: _s(_g(j, 'id')),
      companyId: _s(_g(j, 'companyId')).isEmpty ? null : _s(_g(j, 'companyId')),
      subscriberId: _s(_g(j, 'subscriberId')).isEmpty
          ? null
          : _s(_g(j, 'subscriberId')),
      subscriberName: sub is Map
          ? _s(_g(sub.cast<String, dynamic>(), 'name'))
          : _s(_g(j, 'subscriberName')),
      internetId: sub is Map
          ? _s(_g(sub.cast<String, dynamic>(), 'internetId'))
          : _s(_g(j, 'internetId')),
      phone: _s(_g(j, 'phone')),
      address: _s(_g(j, 'address')),
      sublocality: _s(_g(j, 'sublocality') ?? _g(j, 'areaName')),
      connectionType: _s(_g(j, 'connectionType')),
      amount: _d(_g(j, 'amount')),
      promiseDate: _date(_g(j, 'promiseDate')),
      description: _s(_g(j, 'description')),
      status: _s(_g(j, 'status')).isEmpty ? 'pending' : _s(_g(j, 'status')),
      collectorId: _i(_g(j, 'collectorId')),
      collectorName: collector is Map
          ? _s(_g(collector.cast<String, dynamic>(), 'name'))
          : _s(_g(j, 'collectorName')),
      createdAt: _date(_g(j, 'createdAt')),
    );
  }
}

/// A POS promise (`/pos/promises`).
class TxPosPromise {
  TxPosPromise({
    required this.id,
    this.saleNumber = '',
    this.subscriberName = '',
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.pendingAmount = 0,
    this.collectedAmount = 0,
    this.remainingAmount = 0,
    this.promiseDate,
    this.description = '',
    this.status = 'pending',
    this.collectorName = '',
  });

  final String id;
  final String saleNumber;
  final String subscriberName;
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final double collectedAmount;
  final double remainingAmount;
  final DateTime? promiseDate;
  final String description;
  final String status;
  final String collectorName;

  /// Money still owed on this promise — mirrors the backend
  /// `remainingAmount` / `posPromiseRemaining` (`pendingAmount - collected`).
  double get posRemaining => remainingAmount;

  factory TxPosPromise.fromJson(Map<String, dynamic> j) => TxPosPromise(
    id: _s(_g(j, 'id')),
    saleNumber: _s(_g(j, 'saleNumber')),
    subscriberName: _s(_g(j, 'subscriberName')),
    totalAmount: _d(_g(j, 'totalAmount')),
    paidAmount: _d(_g(j, 'paidAmount')),
    pendingAmount: _d(_g(j, 'pendingAmount')),
    collectedAmount: _d(_g(j, 'collectedAmount')),
    remainingAmount: _d(_g(j, 'remainingAmount') ?? _g(j, 'pendingAmount')),
    promiseDate: _date(_g(j, 'promiseDate')),
    description: _s(_g(j, 'description')),
    status: _s(_g(j, 'status')).isEmpty ? 'pending' : _s(_g(j, 'status')),
    collectorName: _s(_g(j, 'collectorName')),
  );
}

/// A network area (`/network/areas`).
class TxArea {
  TxArea({
    required this.id,
    this.city = '',
    this.zone = '',
    this.locality = '',
    this.subLocality = '',
    this.name = '',
    this.companyId,
    this.recoveryOfficerId,
    this.recoveryOfficerName = '',
  });

  final String id;
  final String city;
  final String zone;
  final String locality;
  final String subLocality;
  final String name;
  final String? companyId;
  final String? recoveryOfficerId;
  final String recoveryOfficerName;

  String get label => [subLocality, locality, zone, city]
      .where((e) => e.trim().isNotEmpty)
      .join(' / ');

  factory TxArea.fromJson(Map<String, dynamic> j) {
    final officer = _g(j, 'recoveryOfficer');
    return TxArea(
      id: _s(_g(j, 'id')),
      city: _s(_g(j, 'city')),
      zone: _s(_g(j, 'zone')),
      locality: _s(_g(j, 'locality')),
      subLocality: _s(_g(j, 'subLocality')),
      name: _s(_g(j, 'name')),
      companyId: _s(_g(j, 'companyId')).isEmpty ? null : _s(_g(j, 'companyId')),
      recoveryOfficerId: _s(_g(j, 'recoveryOfficerId')).isEmpty
          ? null
          : _s(_g(j, 'recoveryOfficerId')),
      recoveryOfficerName: officer is Map
          ? _s(_g(officer.cast<String, dynamic>(), 'name'))
          : _s(_g(j, 'recoveryOfficerName')),
    );
  }
}

/// A recovery officer (`/admin/recovery-officers`).
class TxRecoveryOfficer {
  TxRecoveryOfficer({
    required this.id,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.areaId,
    this.status = 'active',
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String? areaId;
  final String status;

  factory TxRecoveryOfficer.fromJson(Map<String, dynamic> j) {
    final id = _s(_g(j, 'id'));
    return TxRecoveryOfficer(
      id: id,
      name: _s(_g(j, 'name')),
      email: _s(_g(j, 'email')),
      phone: _s(_g(j, 'phone')),
      areaId: _s(_g(j, 'areaId')).isEmpty ? null : _s(_g(j, 'areaId')),
      status: _s(_g(j, 'status')).isEmpty ? 'active' : _s(_g(j, 'status')),
    );
  }
}

/// A transaction type (`/billing/transaction-types`).
class TxTransactionType {
  TxTransactionType({
    required this.id,
    this.transaction = '',
    this.openingBalance = 0,
    this.title = '',
    this.paymentChannel = '',
    this.companyId,
  });

  final int id;
  final String transaction;
  final double openingBalance;
  final String title;
  final String paymentChannel;
  final String? companyId;

  factory TxTransactionType.fromJson(Map<String, dynamic> j) =>
      TxTransactionType(
        id: _i(_g(j, 'id')) ?? 0,
        transaction: _s(_g(j, 'transaction')),
        openingBalance: _d(_g(j, 'openingBalance')),
        title: _s(_g(j, 'title')),
        paymentChannel: _s(_g(j, 'paymentChannel')),
        companyId: _s(_g(j, 'companyId')).isEmpty
            ? null
            : _s(_g(j, 'companyId')),
      );
}

/// A dealer (`/dealers`). Matches the web `Dealer` type.
class TxDealer {
  TxDealer({
    required this.id,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.cnic = '',
    this.address = '',
    this.commissionRate = 0,
    this.walletBalance = 0,
    this.remainingAmount = 0,
    this.areaId,
    this.lastPaymentDate,
    this.createdAt,
    this.status = 'active',
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String cnic;
  final String address;
  final double commissionRate;
  final double walletBalance;
  final double remainingAmount;
  final String? areaId;
  final DateTime? lastPaymentDate;
  final DateTime? createdAt;
  final String status;

  String get shortId => id.length > 8 ? id.substring(0, 8) : id;

  factory TxDealer.fromJson(Map<String, dynamic> j) {
    final user = _g(j, 'user');
    return TxDealer(
      id: _s(_g(j, 'id')),
      name: _s(_g(j, 'name')).isEmpty && user is Map
          ? _s(_g(user.cast<String, dynamic>(), 'name'))
          : _s(_g(j, 'name')),
      email: _s(_g(j, 'email')),
      phone: _s(_g(j, 'phone')),
      cnic: _s(_g(j, 'cnic')),
      address: _s(_g(j, 'address')),
      commissionRate: _d(_g(j, 'commissionRate')),
      walletBalance: _d(_g(j, 'walletBalance')),
      remainingAmount: _d(_g(j, 'remainingAmount')),
      areaId: _s(_g(j, 'areaId')).isEmpty ? null : _s(_g(j, 'areaId')),
      lastPaymentDate: _date(_g(j, 'lastPaymentDate')),
      createdAt: _date(_g(j, 'createdAt')),
      status: _s(_g(j, 'status')).isEmpty ? 'active' : _s(_g(j, 'status')),
    );
  }
}

/// A dealer collection (`/dealers/collections`).
class TxDealerCollection {
  TxDealerCollection({
    required this.id,
    this.dealerId,
    this.dealerName = '',
    this.dealerAddress = '',
    this.amount = 0,
    this.collectionDate,
    this.settlementStatus = 'pending',
    this.transactionType = '',
    this.comment = '',
    this.receivedById,
    this.receivedByName = '',
    this.companyId,
    this.createdAt,
  });

  final String id;
  final String? dealerId;
  final String dealerName;
  final String dealerAddress;
  final double amount;
  final DateTime? collectionDate;
  final String settlementStatus;
  final String transactionType;
  final String comment;
  final int? receivedById;
  final String receivedByName;
  final String? companyId;
  final DateTime? createdAt;

  factory TxDealerCollection.fromJson(Map<String, dynamic> j) {
    final dealer = _g(j, 'dealer');
    final receivedBy = _g(j, 'receivedBy');
    return TxDealerCollection(
      id: _s(_g(j, 'id')),
      dealerId: _s(_g(j, 'dealerId')).isEmpty ? null : _s(_g(j, 'dealerId')),
      dealerName: dealer is Map
          ? _s(_g(dealer.cast<String, dynamic>(), 'name'))
          : _s(_g(j, 'dealerName')),
      dealerAddress: dealer is Map
          ? _s(_g(dealer.cast<String, dynamic>(), 'address'))
          : _s(_g(j, 'dealerAddress')),
      amount: _d(_g(j, 'amount')),
      collectionDate: _date(_g(j, 'collectionDate') ?? _g(j, 'date')),
      settlementStatus: _s(_g(j, 'settlementStatus')).isEmpty
          ? 'pending'
          : _s(_g(j, 'settlementStatus')),
      transactionType: _s(_g(j, 'transactionType')),
      comment: _s(_g(j, 'comment') ?? _g(j, 'notes')),
      receivedById: _i(_g(j, 'receivedById')),
      receivedByName: receivedBy is Map
          ? _s(_g(receivedBy.cast<String, dynamic>(), 'name'))
          : _s(_g(j, 'receivedByName')),
      companyId: _s(_g(j, 'companyId')).isEmpty ? null : _s(_g(j, 'companyId')),
      createdAt: _date(_g(j, 'createdAt')),
    );
  }
}

/// Result of the `bill-creator` bill generation preview (`/billing/bills`).
class TxBillRow {
  TxBillRow({
    this.id,
    this.billNo = '',
    this.subscriberId,
    this.subscriberName = '',
    this.internetId = '',
    this.area = '',
    this.amount = 0,
    this.billDate,
  });

  final int? id;
  final String billNo;
  final String? subscriberId;
  final String subscriberName;
  final String internetId;
  final String area;
  final double amount;
  final DateTime? billDate;

  factory TxBillRow.fromJson(Map<String, dynamic> j) {
    final sub = _g(j, 'subscriber');
    return TxBillRow(
      id: _i(_g(j, 'id')),
      billNo: _s(_g(j, 'billNo')),
      subscriberId: _s(_g(j, 'subscriberId')).isEmpty
          ? null
          : _s(_g(j, 'subscriberId')),
      subscriberName: sub is Map
          ? _s(_g(sub.cast<String, dynamic>(), 'name'))
          : _s(_g(j, 'subscriberName')),
      internetId: sub is Map
          ? _s(_g(sub.cast<String, dynamic>(), 'internetId'))
          : _s(_g(j, 'internetId')),
      area: _s(_g(j, 'area')),
      amount: _d(_g(j, 'amount')),
      billDate: _date(_g(j, 'billDate') ?? _g(j, 'createdAt')),
    );
  }
}

/// Simple numeric `(id, label)` option used by dropdowns.
class TxOption {
  const TxOption(this.id, this.name);
  final int id;
  final String name;
}