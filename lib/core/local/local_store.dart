import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Local Hive storage used as the offline-first cache and sync outbox.
///
/// Two boxes back the offline layer:
///  * [_cache]  — read-through cache of API responses, keyed by request
///                (method+path+query for reads).
///  * [_outbox] — mutations made while offline, replayed against the server
///                once connectivity returns.
///
/// Values are stored as JSON strings so arbitrary nested server payloads can be
/// round-tripped without generated TypeAdapters.
class LocalStore {
  LocalStore._();

  static const String _cacheBox = 'fintrack_cache';
  static const String _outboxBox = 'fintrack_outbox';

  static Box<String>? _cache;
  static Box<String>? _outbox;
  static bool _ready = false;

  static bool get isReady => _ready;

  /// Opens the Hive boxes. Safe to call multiple times.
  static Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    _cache = await Hive.openBox<String>(_cacheBox);
    _outbox = await Hive.openBox<String>(_outboxBox);
    _ready = true;
  }

  // --- cache ---------------------------------------------------------------

  static bool has(String key) => _cache?.containsKey(key) ?? false;

  static Map<String, dynamic>? read(String key) {
    final raw = _cache?.get(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, Map<String, dynamic> value) async {
    await _cache?.put(key, jsonEncode(value));
  }

  static Future<void> deleteKey(String key) async {
    await _cache?.delete(key);
  }

  static Future<void> clearCache() async {
    await _cache?.clear();
  }

  // --- outbox --------------------------------------------------------------

  static List<Map<String, dynamic>> readOutbox() {
    final raw = _outbox?.get(OutboxKeys.entries);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> writeOutbox(List<Map<String, dynamic>> entries) async {
    await _outbox?.put(OutboxKeys.entries, jsonEncode(entries));
  }

  static Future<void> clearOutbox() async {
    await _outbox?.clear();
  }
}

class OutboxKeys {
  OutboxKeys._();
  static const String entries = 'entries';
}
