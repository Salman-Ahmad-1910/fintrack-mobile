import 'local_store.dart';

/// A mutation captured while offline, replayed against the server when the
/// device reconnects. Mirrors the original `ApiClient` call so it can be
/// re-issued verbatim.
class OutboxEntry {
  OutboxEntry({
    required this.id,
    required this.method,
    required this.path,
    this.body,
    required this.createdAt,
    this.attempts = 0,
  });

  final String id;
  final String method; // POST / PUT / PATCH / DELETE
  final String path; // includes any query string
  final Map<String, dynamic>? body;
  final int createdAt;
  final int attempts;

  OutboxEntry copyWith({int? attempts}) => OutboxEntry(
    id: id,
    method: method,
    path: path,
    body: body,
    createdAt: createdAt,
    attempts: attempts ?? this.attempts,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'method': method,
    'path': path,
    'body': body,
    'createdAt': createdAt,
    'attempts': attempts,
  };

  factory OutboxEntry.fromJson(Map<String, dynamic> j) => OutboxEntry(
    id: j['id']?.toString() ?? '',
    method: j['method']?.toString() ?? 'POST',
    path: j['path']?.toString() ?? '',
    body: j['body'] is Map
        ? (j['body'] as Map).cast<String, dynamic>()
        : null,
    createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
    attempts: (j['attempts'] as num?)?.toInt() ?? 0,
  );
}

/// Persistent FIFO queue of offline mutations.
class Outbox {
  Outbox._();

  static List<OutboxEntry> readAll() =>
      LocalStore.readOutbox().map(OutboxEntry.fromJson).toList();

  static int count() => readAll().length;

  static Future<void> add(OutboxEntry entry) async {
    final list = LocalStore.readOutbox()..add(entry.toJson());
    await LocalStore.writeOutbox(list);
  }

  static Future<void> remove(String id) async {
    final list = LocalStore.readOutbox();
    list.removeWhere((e) => e['id']?.toString() == id);
    await LocalStore.writeOutbox(list);
  }

  static Future<void> replace(OutboxEntry entry) async {
    final list = LocalStore.readOutbox();
    final idx = list.indexWhere((e) => e['id']?.toString() == entry.id);
    if (idx >= 0) {
      list[idx] = entry.toJson();
    } else {
      list.add(entry.toJson());
    }
    await LocalStore.writeOutbox(list);
  }
}
