import 'package:intl/intl.dart';

num _num(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

double _d(Object? v) => _num(v).toDouble();

String _s(Object? v) => v?.toString() ?? '';

String _firstNonEmpty(Iterable<String> values) {
  for (final value in values) {
    if (value.isNotEmpty) return value;
  }
  return '';
}

/// A single SMS / notification record (`models/misc.go` `Message`).
class MsgMessage {
  const MsgMessage({
    required this.id,
    required this.status,
    required this.name,
    this.entityId = '',
    this.internetId = '',
    this.mobileNo = '',
    this.phone = '',
    this.address = '',
    this.messageType = '',
    this.messageText = '',
    this.sentBy = '',
    this.sendedAt = '',
    this.sendTo = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.companyId = '',
  });

  final String id;
  final String status;
  final String name;
  final String entityId;
  final String internetId;
  final String mobileNo;
  final String phone;
  final String address;
  final String messageType;
  final String messageText;
  final String sentBy;
  final String sendedAt;
  final String sendTo;
  final String createdAt;
  final String updatedAt;
  final String companyId;

  factory MsgMessage.fromJson(Map<String, dynamic> json) => MsgMessage(
    id: _s(json['id']),
    status: _s(json['status']),
    name: _s(json['name']),
    entityId: _s(json['entityId']),
    internetId: _s(json['internetId']),
    mobileNo: _s(json['mobileNo']),
    phone: _s(json['phone']),
    address: _s(json['address']),
    messageType: _s(json['messageType']),
    messageText: _s(json['messageText']),
    sentBy: _s(json['sentBy']),
    sendedAt: _s(json['sendedAt']),
    sendTo: _s(json['sendTo']),
    createdAt: _s(json['createdAt']),
    updatedAt: _s(json['updatedAt']),
    companyId: _s(json['companyId']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'name': name,
    'entityId': entityId,
    'internetId': internetId,
    'mobileNo': mobileNo,
    'phone': phone,
    'address': address,
    'messageType': messageType,
    'messageText': messageText,
    'sentBy': sentBy,
    'sendedAt': sendedAt,
    'sendTo': sendTo,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'companyId': companyId,
  };

  String get preferPhone => _firstNonEmpty([mobileNo, phone]);

  String get dateKey => toDateKey(sendedAt.isNotEmpty ? sendedAt : createdAt);

  bool get isExpiry =>
      messageType == expiryTitle || messageText.startsWith('$expiryTitle:');
}

/// Reusable message template (`models/misc.go` `MessageTemplate`).
class MsgTemplate {
  const MsgTemplate({
    required this.id,
    required this.title,
    required this.message,
    this.parameters = '',
    this.companyId = '',
  });

  final String id;
  final String title;
  final String message;
  final String parameters;
  final String companyId;

  factory MsgTemplate.fromJson(Map<String, dynamic> json) => MsgTemplate(
    id: _s(json['id']),
    title: _s(json['title']),
    message: _s(json['message']),
    parameters: _s(json['parameters']),
    companyId: _s(json['companyId']),
  );

  List<String> get paramList => parameters
      .split(',')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'parameters': parameters,
    'companyId': companyId,
  };
}

/// Subset of the web `Connection` used by the messages pages.
class MsgConnection {
  const MsgConnection({
    required this.id,
    required this.name,
    this.internetId = '',
    this.cell = '',
    this.mobile = '',
    this.address = '',
    this.status = '',
    this.connectionType = '',
    this.boxNumber = '',
    this.packageCable = '',
    this.packageInternet = '',
    this.sublocalityId = '',
    this.companyId = '',
    this.amount = 0,
    this.remainingAmount = 0,
  });

  final String id;
  final String name;
  final String internetId;
  final String cell;
  final String mobile;
  final String address;
  final String status;
  final String connectionType;
  final String boxNumber;
  final String packageCable;
  final String packageInternet;
  final String sublocalityId;
  final String companyId;
  final double amount;
  final double remainingAmount;

  factory MsgConnection.fromJson(Map<String, dynamic> json) => MsgConnection(
    id: _s(json['id']),
    name: _s(json['name']),
    internetId: _s(json['internetId']),
    cell: _s(json['cell']),
    mobile: _s(json['mobile']),
    address: _s(json['address']),
    status: _s(json['status']),
    connectionType: _s(json['connectionType']),
    boxNumber: _s(json['boxNumber']),
    packageCable: _s(json['packageCable']),
    packageInternet: _s(json['packageInternet']),
    sublocalityId: _s(json['sublocalityId']),
    companyId: _s(json['companyId']),
    amount: _d(json['amount']),
    remainingAmount: _d(json['remainingAmount']),
  );

  String get phone => _firstNonEmpty([mobile, cell]);
}

/// Subset of the web `Area` used to resolve connection sub-localities.
class MsgArea {
  const MsgArea({required this.id, this.locality = '', this.subLocality = ''});

  final String id;
  final String locality;
  final String subLocality;

  factory MsgArea.fromJson(Map<String, dynamic> json) => MsgArea(
    id: _s(json['id']),
    locality: _s(json['locality']),
    subLocality: _s(json['subLocality']),
  );

  String get label => subLocality.isNotEmpty ? subLocality : locality;
}

// ---------------------------------------------------------------- constants --

const String expiryTitle = 'Defaulter';
const String selectMessage = 'Select the Message';

/// Web `messageTitles` for the Other / Expiry filter dropdowns.
const List<String> otherMessageTitles = [
  selectMessage,
  'User Cradentials',
  'Internet Card',
  'Promotion',
  'New User',
  'Internet Recharge',
];

/// Web `messageTitles` for the Expiry filter dropdown (adds Defaulter).
const List<String> expiredMessageTitles = [
  selectMessage,
  'User Cradentials',
  expiryTitle,
  'Internet Card',
  'Promotion',
  'New User',
  'Internet Recharge',
];

/// Web `messageTitles` for the Draft / Sent / WhatsApp dropdowns.
const List<String> allMessageTitles = [
  'All',
  'User Cradentials',
  expiryTitle,
  'Internet Card',
  'Promotion',
  'New User',
  'Internet Recharge',
];

const List<String> draftSendToOptions = [
  'Subscriber',
  'Dealer',
  'Inquiry',
  'Staff',
  'Admin',
  'Other',
];

const List<String> sentSendToOptions = [
  'Subscriber',
  'Dealer',
  'Staff',
  'Admin',
];

const List<String> newMessageDefaultParams = [
  'name',
  'cableAmount',
  'internetAmount',
  'received',
  'balance',
  'date',
  'bill',
];

/// Web `SEND_CATEGORIES` used by the New Messages send dialog.
class SendCategory {
  const SendCategory({
    required this.value,
    required this.label,
    required this.sendTo,
  });

  final String value;
  final String label;
  final String sendTo;
}

const List<SendCategory> sendCategories = [
  SendCategory(
    value: 'subscribers',
    label: 'Subscribers',
    sendTo: 'Subscriber',
  ),
  SendCategory(value: 'dealers', label: 'Dealers', sendTo: 'Dealer'),
  SendCategory(
    value: 'recovery',
    label: 'Recovery Officers',
    sendTo: 'Recovery Officer',
  ),
  SendCategory(value: 'staff', label: 'Staff', sendTo: 'Staff'),
];

// ------------------------------------------------------------------ helpers --

final NumberFormat _thousands = NumberFormat.decimalPattern();
final DateFormat _dayMonthYear = DateFormat('dd MMM yyyy');
final DateFormat _dateKey = DateFormat('yyyy-MM-dd');

/// Web `formatVal`: format numbers with thousands separators and ISO date
/// strings as `dd MMM yyyy`.
String formatMsgValue(Object? v) {
  if (v == null) return '';
  if (v is num) {
    if (v is double && v.isNaN) return '';
    return _thousands.format(v);
  }
  if (v is String) {
    final trimmed = v.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(trimmed)) {
      final d = DateTime.tryParse(trimmed);
      if (d != null) return _dayMonthYear.format(d);
    }
    return v;
  }
  return v.toString();
}

/// Web `getEntityPhone`.
String getEntityPhone(Map<String, dynamic> entity) => _firstNonEmpty([
  _s(entity['mobileNo']),
  _s(entity['mobile']),
  _s(entity['cell']),
  _s(entity['phone']),
  _s(entity['contactPhone']),
  _s(entity['secondaryPhone']),
]);

/// Web `buildValues`.
Map<String, String> buildMessageValues(
  Map<String, dynamic> entity,
  String category,
) {
  final map = <String, String>{};
  entity.forEach((k, v) {
    final val = formatMsgValue(v);
    map[k] = val;
    map[k.toLowerCase()] = val;
  });
  map['name'] = map['name'] ?? '';
  final phone = getEntityPhone(entity);
  map['phone'] = phone;
  map['mobile'] = phone;
  map['mobileNo'] = phone;
  map['cnic'] = _firstNonEmpty([map['cnic'] ?? '', map['nic'] ?? '']);
  map['address'] = _firstNonEmpty([
    map['address'] ?? '',
    map['installationAddress'] ?? '',
  ]);

  String value(String key) => _s(entity[key]);

  switch (category) {
    case 'subscribers':
      map['cableAmount'] = formatMsgValue(entity['amount']);
      map['internetAmount'] = formatMsgValue(entity['packageInternet']);
      map['received'] = formatMsgValue(entity['amount']);
      map['balance'] = formatMsgValue(
        entity['remainingAmount'] ?? entity['amount'],
      );
      map['bill'] = formatMsgValue(entity['amount']);
      map['date'] ??= formatMsgValue(
        _firstNonEmpty([
          value('rechargeDate'),
          value('lastPaymentDate'),
          value('createdAt'),
        ]),
      );
    case 'dealers':
      map['amount'] = formatMsgValue(entity['walletBalance']);
      map['received'] = formatMsgValue(entity['walletBalance']);
      map['balance'] = formatMsgValue(
        entity['remainingAmount'] ?? entity['walletBalance'],
      );
      map['bill'] = formatMsgValue(entity['walletBalance']);
      map['date'] ??= formatMsgValue(
        _firstNonEmpty([value('lastPaymentDate'), value('createdAt')]),
      );
    case 'recovery':
      map['amount'] = formatMsgValue(entity['collected']);
      map['received'] = formatMsgValue(entity['collected']);
      map['balance'] = formatMsgValue(entity['target']);
      map['bill'] = formatMsgValue(entity['target']);
      map['date'] ??= formatMsgValue(value('createdAt'));
    case 'staff':
      map['date'] ??= formatMsgValue(
        _firstNonEmpty([value('appointedDate'), value('createdAt')]),
      );
  }
  return map;
}

/// Web `fillTemplate`.
String fillMessageTemplate(
  String message,
  Map<String, dynamic> entity,
  String category,
) {
  final values = buildMessageValues(entity, category);
  return message.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (match) {
    final p = match.group(1) ?? '';
    return values[p] ?? values[p.toLowerCase()] ?? '';
  });
}

/// `yyyy-MM-dd` key used by the sent / draft date filters.
String toDateKey(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  return d == null ? '' : _dateKey.format(d);
}

/// `dd MMM yyyy` for a `yyyy-MM-dd` key.
String displayDateKey(String key) {
  final d = DateTime.tryParse('${key}T00:00:00');
  return d == null ? key : _dayMonthYear.format(d);
}

/// Web `waNumber`: strip non-digits and turn a leading `0` into the `92`
/// country code.
String waNumber(String? phone) {
  if (phone == null || phone.isEmpty) return '';
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) digits = '92${digits.substring(1)}';
  return digits;
}

/// Default body used when a message has no text (web `messageBody`).
String messageBody(MsgMessage m) => m.messageText.isNotEmpty
    ? m.messageText
    : 'Dear ${m.name}, your monthly subscription fee is due. Please pay your '
          'dues to continue uninterrupted services. Thank you.';

/// Web `format(date, 'dd MMM yyyy, hh:mm a')`.
String formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final d = DateTime.tryParse(iso);
  if (d == null) return '-';
  return DateFormat('dd MMM yyyy, hh:mm a').format(d.toLocal());
}

/// Web `format(date, 'hh:mm a')`.
String formatTime(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final d = DateTime.tryParse(iso);
  if (d == null) return '-';
  return DateFormat('hh:mm a').format(d.toLocal());
}
