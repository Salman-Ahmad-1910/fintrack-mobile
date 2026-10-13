/// Models for the Recovery Officers modules (Officers + Area Assignment).
/// Shapes mirror `client/src/lib/types.ts` (`RecoveryOfficer`, `Area`); parsing
/// is defensive because the Go backend sometimes serialises numbers as strings.
library;

num _num(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? 0;
  return 0;
}

String _s(Object? v) => v?.toString() ?? '';

List<String> _strList(Object? v) {
  if (v is List) return v.map(_s).where((e) => e.isNotEmpty).toList();
  return const [];
}

/// A recovery officer (`/admin/recovery-officers`).
class RecoveryOfficer {
  const RecoveryOfficer({
    required this.id,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.secondaryPhone = '',
    this.areaId,
    this.status = 'active',
    this.companyId = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.target = 0,
    this.collected = 0,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String secondaryPhone;
  final String? areaId;
  final String status;
  final String companyId;
  final String createdAt;
  final String updatedAt;
  final num target;
  final num collected;

  bool get isActive => status != 'inactive';

  factory RecoveryOfficer.fromJson(Map<String, dynamic> j) {
    final areaId = _s(j['areaId']);
    return RecoveryOfficer(
      id: _s(j['id']),
      name: _s(j['name']),
      email: _s(j['email']),
      phone: _s(j['phone']),
      secondaryPhone: _s(j['secondaryPhone']),
      areaId: areaId.isEmpty ? null : areaId,
      status: _s(j['status']).isEmpty ? 'active' : _s(j['status']),
      companyId: _s(j['companyId']),
      createdAt: _s(j['createdAt']),
      updatedAt: _s(j['updatedAt']),
      target: _num(j['target']),
      collected: _num(j['collected']),
    );
  }
}

/// An area (`/network/areas`) with recovery-officer assignment info.
class RecoveryArea {
  const RecoveryArea({
    required this.id,
    this.city = '',
    this.zone = '',
    this.locality = '',
    this.subLocality = '',
    this.recoveryOfficerId,
    this.recoveryOfficerIds = const [],
    this.companyId = '',
  });

  final String id;
  final String city;
  final String zone;
  final String locality;
  final String subLocality;
  final String? recoveryOfficerId;
  final List<String> recoveryOfficerIds;
  final String companyId;

  factory RecoveryArea.fromJson(Map<String, dynamic> j) {
    final primary = _s(j['recoveryOfficerId']);
    final ids = _strList(j['recoveryOfficerIds']).toList();
    if (ids.isEmpty && primary.isNotEmpty) ids.add(primary);
    return RecoveryArea(
      id: _s(j['id']),
      city: _s(j['city']),
      zone: _s(j['zone']),
      locality: _s(j['locality']),
      subLocality: _s(j['subLocality']),
      recoveryOfficerId: primary.isEmpty ? null : primary,
      recoveryOfficerIds: ids,
      companyId: _s(j['companyId']),
    );
  }
}
