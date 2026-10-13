/// Models for the Network Operations modules (Areas, POPs, OLTs, Splitters,
/// Boxes). Shapes mirror `client/src/lib/types.ts`; parsing is defensive
/// because the Go backend sometimes serialises numbers as strings.
library;

num _num(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

int _i(Object? v) => _num(v).toInt();

String _s(Object? v) => v?.toString() ?? '';

class NetArea {
  const NetArea({
    required this.id,
    required this.city,
    required this.zone,
    required this.locality,
    this.subLocality = '',
    this.companyId = '',
  });

  final String id;
  final String city;
  final String zone;
  final String locality;
  final String subLocality;
  final String companyId;

  factory NetArea.fromJson(Map<String, dynamic> json) => NetArea(
    id: _s(json['id']),
    city: _s(json['city']),
    zone: _s(json['zone']),
    locality: _s(json['locality']),
    subLocality: _s(json['subLocality']),
    companyId: _s(json['companyId']),
  );
}

class NetPop {
  const NetPop({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    this.lastOutage = '',
    this.companyId = '',
  });

  final String id;
  final String name;
  final String location;
  final String status;
  final String lastOutage;
  final String companyId;

  bool get isOnline => status == 'online';

  factory NetPop.fromJson(Map<String, dynamic> json) => NetPop(
    id: _s(json['id']),
    name: _s(json['name']),
    location: _s(json['location']),
    status: _s(json['status']),
    lastOutage: _s(json['lastOutage']),
    companyId: _s(json['companyId']),
  );
}

class NetOlt {
  const NetOlt({
    required this.id,
    required this.name,
    required this.location,
    required this.ipAddress,
    required this.ports,
    this.popId = '',
    this.companyId = '',
  });

  final String id;
  final String name;
  final String location;
  final String ipAddress;
  final int ports;
  final String popId;
  final String companyId;

  factory NetOlt.fromJson(Map<String, dynamic> json) => NetOlt(
    id: _s(json['id']),
    name: _s(json['name']),
    location: _s(json['location']),
    ipAddress: _s(json['ipAddress']),
    ports: _i(json['ports']),
    popId: _s(json['popId']),
    companyId: _s(json['companyId']),
  );
}

class NetSplitter {
  const NetSplitter({
    required this.id,
    required this.name,
    required this.location,
    required this.oltId,
    required this.totalPorts,
    required this.availablePorts,
    this.companyId = '',
  });

  final String id;
  final String name;
  final String location;
  final String oltId;
  final int totalPorts;
  final int availablePorts;
  final String companyId;

  int get usedPorts => totalPorts - availablePorts;

  double get utilization =>
      totalPorts == 0 ? 0 : (usedPorts / totalPorts) * 100;

  factory NetSplitter.fromJson(Map<String, dynamic> json) => NetSplitter(
    id: _s(json['id']),
    name: _s(json['name']),
    location: _s(json['location']),
    oltId: _s(json['oltId']),
    totalPorts: _i(json['totalPorts']),
    availablePorts: _i(json['availablePorts']),
    companyId: _s(json['companyId']),
  );
}

class NetBox {
  const NetBox({required this.id, required this.name, this.companyId = ''});

  final String id;
  final String name;
  final String companyId;

  factory NetBox.fromJson(Map<String, dynamic> json) => NetBox(
    id: _s(json['id']),
    name: _s(json['name']),
    companyId: _s(json['companyId']),
  );
}
