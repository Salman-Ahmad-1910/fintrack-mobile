/// Models for the Subscribers Management / CRM section. Shapes mirror
/// `client/src/lib/types.ts`; parsing is defensive because the Go backend
/// sometimes serialises numbers as strings.
library;

num _num(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

double _d(Object? v) => _num(v).toDouble();

int _i(Object? v) => _num(v).toInt();

bool _b(Object? v) {
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  if (v is num) return v != 0;
  return false;
}

String _s(Object? v) => v?.toString() ?? '';

String _firstNonEmpty(Iterable<String> values) {
  for (final value in values) {
    if (value.isNotEmpty) return value;
  }
  return '';
}

/// `models/crm.go` `Customer`.
class CrmCustomer {
  const CrmCustomer({
    required this.id,
    required this.name,
    this.cnic = '',
    this.phone = '',
    this.city = '',
    this.status = 'active',
    this.totalInvoices = 0,
    this.outstandingBalance = 0,
    this.companyId = '',
  });

  final String id;
  final String name;
  final String cnic;
  final String phone;
  final String city;
  final String status;
  final int totalInvoices;
  final double outstandingBalance;
  final String companyId;

  factory CrmCustomer.fromJson(Map<String, dynamic> json) => CrmCustomer(
    id: _s(json['id']),
    name: _s(json['name']),
    cnic: _s(json['cnic']),
    phone: _s(json['phone']),
    city: _s(json['city']),
    status: _s(json['status']).isEmpty ? 'active' : _s(json['status']),
    totalInvoices: _i(json['totalInvoices']),
    outstandingBalance: _d(json['outstandingBalance']),
    companyId: _s(json['companyId']),
  );
}

/// `models/crm.go` `Guarantor`.
class CrmGuarantor {
  const CrmGuarantor({
    required this.id,
    required this.name,
    this.cnic = '',
    this.phone = '',
    this.customerId = '',
    this.customerName = '',
    this.companyId = '',
  });

  final String id;
  final String name;
  final String cnic;
  final String phone;
  final String customerId;
  final String customerName;
  final String companyId;

  factory CrmGuarantor.fromJson(Map<String, dynamic> json) => CrmGuarantor(
    id: _s(json['id']),
    name: _s(json['name']),
    cnic: _s(json['cnic']),
    phone: _s(json['phone']),
    customerId: _s(json['customerId']),
    customerName: _s(json['customerName']),
    companyId: _s(json['companyId']),
  );
}

/// Web `CorporateCustomer` (`subscribers/corporate`).
class CrmCorporate {
  const CrmCorporate({
    required this.id,
    required this.companyName,
    this.contactPerson = '',
    this.contactPhone = '',
    this.negotiatedPricing = '',
    this.contractStartDate = '',
    this.contractEndDate = '',
    this.totalConnections = 0,
    this.companyId = '',
  });

  final String id;
  final String companyName;
  final String contactPerson;
  final String contactPhone;
  final String negotiatedPricing;
  final String contractStartDate;
  final String contractEndDate;
  final int totalConnections;
  final String companyId;

  factory CrmCorporate.fromJson(Map<String, dynamic> json) => CrmCorporate(
    id: _s(json['id']),
    companyName: _s(json['companyName']),
    contactPerson: _s(json['contactPerson']),
    contactPhone: _s(json['contactPhone']),
    negotiatedPricing: _s(json['negotiatedPricing']),
    contractStartDate: _s(json['contractStartDate']),
    contractEndDate: _s(json['contractEndDate']),
    totalConnections: _i(json['totalConnections']),
    companyId: _s(json['companyId']),
  );
}

/// `models/subscriber.go` `Package` (served at `/billing/packages`).
class CrmPackage {
  const CrmPackage({
    required this.id,
    required this.name,
    this.packageNumber = '',
    this.speed = '',
    this.price = 0,
    this.dataLimit = '',
    this.companyName = '',
    this.salePrice = 0,
    this.purchasePrice = 0,
    this.packageType = 'Internet',
    this.companyId = '',
  });

  final String id;
  final String name;
  final String packageNumber;
  final String speed;
  final double price;
  final String dataLimit;
  final String companyName;
  final double salePrice;
  final double purchasePrice;
  final String packageType;
  final String companyId;

  /// Web `packagePrice`: sale price when set, otherwise the list price.
  double get effectivePrice => salePrice > 0 ? salePrice : price;

  factory CrmPackage.fromJson(Map<String, dynamic> json) => CrmPackage(
    id: _s(json['id']),
    name: _s(json['name']),
    packageNumber: _s(json['packageNumber']),
    speed: _s(json['speed']),
    price: _d(json['price']),
    dataLimit: _s(json['dataLimit']),
    companyName: _s(json['companyName']),
    salePrice: _d(json['salePrice']),
    purchasePrice: _d(json['purchasePrice']),
    packageType: _s(json['packageType']).isEmpty
        ? 'Internet'
        : _s(json['packageType']),
    companyId: _s(json['companyId']),
  );
}

/// Web `Inquiry` (`subscribers/inquiries`).
class CrmInquiry {
  const CrmInquiry({
    required this.id,
    required this.name,
    this.internetId = '',
    this.cell = '',
    this.mobile = '',
    this.address = '',
    this.installationAmount = 0,
    this.otherAmount = 0,
    this.installationDate = '',
    this.rechargeDate = '',
    this.subLocality = '',
    this.connectionType = '',
    this.boxNumber = '',
    this.packageCable = '',
    this.discount = 0,
    this.amount = 0,
    this.comments = '',
    this.status = 'new',
    this.notes = '',
    this.assignedToId = '',
    this.createdAt = '',
    this.companyId = '',
  });

  final String id;
  final String name;
  final String internetId;
  final String cell;
  final String mobile;
  final String address;
  final double installationAmount;
  final double otherAmount;
  final String installationDate;
  final String rechargeDate;
  final String subLocality;
  final String connectionType;
  final String boxNumber;
  final String packageCable;
  final double discount;
  final double amount;
  final String comments;
  final String status;
  final String notes;
  final String assignedToId;
  final String createdAt;
  final String companyId;

  String get shortId => id.length > 6 ? id.substring(0, 6) : id;

  factory CrmInquiry.fromJson(Map<String, dynamic> json) => CrmInquiry(
    id: _s(json['id']),
    name: _s(json['name']),
    internetId: _s(json['internetId']),
    cell: _s(json['cell']),
    mobile: _s(json['mobile']),
    address: _s(json['address']),
    installationAmount: _d(json['installationAmount']),
    otherAmount: _d(json['otherAmount']),
    installationDate: _s(json['installationDate']),
    rechargeDate: _s(json['rechargeDate']),
    subLocality: _s(json['subLocality']),
    connectionType: _s(json['connectionType']),
    boxNumber: _s(json['boxNumber']),
    packageCable: _s(json['packageCable']),
    discount: _d(json['discount']),
    amount: _d(json['amount']),
    comments: _s(json['comments']),
    status: _s(json['status']).isEmpty ? 'new' : _s(json['status']),
    notes: _s(json['notes']),
    assignedToId: _s(json['assignedToId']),
    createdAt: _s(json['createdAt']),
    companyId: _s(json['companyId']),
  );
}

/// Full web `Connection` (`models/connection.go`) used by the subscriber
/// detail screen. The messages section only needed a small subset.
class Conn {
  const Conn({
    required this.id,
    required this.name,
    this.internetId = '',
    this.address = '',
    this.cell = '',
    this.mobile = '',
    this.installationAmount = 0,
    this.otherAmount = 0,
    this.installationDate = '',
    this.rechargeDate = '',
    this.connectionProvider = '',
    this.connectionType = 'both',
    this.boxNumber = '',
    this.packageCable = '',
    this.discount = '',
    this.amount = 0,
    this.packageInternet = '',
    this.createBalance = false,
    this.balanceDays = 0,
    this.sameDiscount = '',
    this.sameAmount = 0,
    this.status = 'active',
    this.sublocalityId = '',
    this.splitterId = '',
    this.splitterPort = 0,
    this.cnic = '',
    this.transactionId = '',
    this.leavingDate = '',
    this.deactivationReason = '',
    this.comments = '',
    this.companyId = '',
  });

  final String id;
  final String name;
  final String internetId;
  final String address;
  final String cell;
  final String mobile;
  final double installationAmount;
  final double otherAmount;
  final String installationDate;
  final String rechargeDate;
  final String connectionProvider;
  final String connectionType;
  final String boxNumber;
  final String packageCable;
  final String discount;
  final double amount;
  final String packageInternet;
  final bool createBalance;
  final int balanceDays;
  final String sameDiscount;
  final double sameAmount;
  final String status;
  final String sublocalityId;
  final String splitterId;
  final int splitterPort;
  final String cnic;
  final String transactionId;
  final String leavingDate;
  final String deactivationReason;
  final String comments;
  final String companyId;

  String get contact => _firstNonEmpty([cell, mobile]);

  factory Conn.fromJson(Map<String, dynamic> json) => Conn(
    id: _s(json['id']),
    name: _s(json['name']),
    internetId: _s(json['internetId']),
    address: _s(json['address']),
    cell: _s(json['cell']),
    mobile: _s(json['mobile']),
    installationAmount: _d(json['installationAmount']),
    otherAmount: _d(json['otherAmount']),
    installationDate: _s(json['installationDate']),
    rechargeDate: _s(json['rechargeDate']),
    connectionProvider: _s(json['connectionProvider']),
    connectionType: _s(json['connectionType']).isEmpty
        ? 'both'
        : _s(json['connectionType']),
    boxNumber: _s(json['boxNumber']),
    packageCable: _s(json['packageCable']),
    discount: _s(json['discount']),
    amount: _d(json['amount']),
    packageInternet: _s(json['packageInternet']),
    createBalance: _b(json['createBalance']),
    balanceDays: _i(json['balanceDays']),
    sameDiscount: _s(json['sameDiscount']),
    sameAmount: _d(json['sameAmount']),
    status: _s(json['status']).isEmpty ? 'active' : _s(json['status']),
    sublocalityId: _s(json['sublocalityId']),
    splitterId: _s(json['splitterId']),
    splitterPort: _i(json['splitterPort']),
    cnic: _s(json['cnic']),
    transactionId: _s(json['transactionId']),
    leavingDate: _s(json['leavingDate']),
    deactivationReason: _s(json['deactivationReason']),
    comments: _s(json['comments']),
    companyId: _s(json['companyId']),
  );
}

/// Simple `{id, name}` company option (web `Company`).
class CrmCompany {
  const CrmCompany({required this.id, required this.name});

  final String id;
  final String name;

  factory CrmCompany.fromJson(Map<String, dynamic> json) =>
      CrmCompany(id: _s(json['id']), name: _s(json['name']));
}
