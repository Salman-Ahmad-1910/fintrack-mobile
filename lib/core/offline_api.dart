import 'api_client.dart';
import 'local/local_store.dart';
import 'local/outbox.dart';
import 'local/sync_engine.dart';
import 'session.dart';

/// Offline-first wrapper around [ApiClient]. Drop-in compatible with the
/// existing screens: reads are served from the Hive cache when offline (and
/// mirrored into it when online), while writes made offline are queued in the
/// outbox and replayed by [SyncEngine] once connectivity returns.
///
/// Because it extends [ApiClient], it can be passed anywhere an `ApiClient` is
/// expected (e.g. `fetchSalesCompany`).
class OfflineApi extends ApiClient {
  OfflineApi({super.onUnauthorized});

  static int _seq = 0;

  /// Canonical cache key for a read request.
  static String cacheKey(String path, Map<String, String>? query) {
    if (query == null || query.isEmpty) return path;
    final keys = query.keys.toList()..sort();
    return '$path?${[for (final k in keys) '$k=${query[k]}'].join('&')}';
  }

  /// Set when a write is served from the outbox instead of the server.
  static const String queuedFlag = 'queued';

  bool get isOnline => SyncEngine.online.value;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final key = cacheKey(path, query);

    if (!SyncEngine.online.value) {
      final cached = LocalStore.read(key);
      if (cached != null) return cached;
      throw ApiException(
        'You are offline and this data has not been downloaded yet.',
      );
    }

    try {
      final json = await super.get(path, query: query);
      await LocalStore.write(key, json);
      SyncEngine.markOnline(true);
      return json;
    } on ApiException catch (e) {
      if (e.isUnauthorized) rethrow;
      if (e.statusCode == null) SyncEngine.markOnline(false);
      final cached = LocalStore.read(key);
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _write('POST', path, body);

  @override
  Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _write('PUT', path, body);

  @override
  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _write('PATCH', path, body);

  @override
  Future<Map<String, dynamic>> delete(String path) =>
      _write('DELETE', path, null);

  Future<Map<String, dynamic>> _write(
    String method,
    String path,
    Object? body,
  ) async {
    if (SyncEngine.online.value) {
      try {
        final Map<String, dynamic> result;
        switch (method) {
          case 'POST':
            result = await super.post(path, body: body);
          case 'PUT':
            result = await super.put(path, body: body);
          case 'PATCH':
            result = await super.patch(path, body: body);
          default:
            result = await super.delete(path);
        }
        SyncEngine.markOnline(true);
        return result;
      } on ApiException catch (e) {
        if (e.isUnauthorized) rethrow;
        // Transport failure (no status) → fall through to the outbox.
        if (e.statusCode != null) rethrow;
        SyncEngine.markOnline(false);
      }
    }

    await _enqueue(method, path, body);
    await _applyOptimistic(method, path, body);
    return <String, dynamic>{queuedFlag: true};
  }

  Future<void> _enqueue(String method, String path, Object? body) async {
    final id = 'ob-${DateTime.now().microsecondsSinceEpoch}-${_seq++}';
    await Outbox.add(
      OutboxEntry(
        id: id,
        method: method,
        path: path,
        body: body is Map ? body.cast<String, dynamic>() : null,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await SyncEngine.refreshPending();
  }

  // -------------------------------------------------------------------------
  // Optimistic cache edits so offline writes are visible immediately.
  // -------------------------------------------------------------------------

  Future<void> _applyOptimistic(
    String method,
    String path,
    Object? body,
  ) async {
    final cid = Session.companyId;
    if (cid == null || cid.isEmpty) return;
    final b = body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};

    Future<void> mutate(
      String basePath,
      void Function(List<Map<String, dynamic>> list) edit,
    ) async {
      final key = cacheKey(basePath, {'companyId': cid});
      final cached = LocalStore.read(key);
      if (cached == null) return;
      final list = ApiClient.listData(cached)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      edit(list);
      await LocalStore.write(key, {'raw': list});
    }

    if (path.startsWith('/billing/payments')) {
      await mutate('/billing/payments', (list) {
        if (method == 'POST') {
          list.add({...b, 'id': _localId('pay')});
        } else if (method == 'PUT') {
          _replaceById(list, _pathId(path), b);
        } else if (method == 'DELETE') {
          _removeById(list, _pathId(path));
        }
      });
    } else if (path.startsWith('/billing/promises')) {
      await mutate('/billing/promises', (list) {
        if (method == 'POST') {
          list.add({
            'status': 'pending',
            ...b,
            'id': _localId('prom'),
          });
        } else if (method == 'PUT') {
          _replaceById(list, _pathId(path), b);
        } else if (method == 'DELETE') {
          _removeById(list, _pathId(path));
        }
      });
    } else if (path.startsWith('/dealers/collections')) {
      await mutate('/dealers/collections', (list) {
        if (method == 'POST') {
          list.add({...b, 'id': _localId('col')});
        } else if (method == 'PUT') {
          _replaceById(list, _pathId(path), b);
        } else if (method == 'DELETE') {
          _removeById(list, _pathId(path));
        }
      });
    }
  }

  static String _localId(String prefix) =>
      'local-$prefix-${DateTime.now().microsecondsSinceEpoch}';

  static String _pathId(String path) {
    final clean = path.split('?').first;
    final parts = clean.split('/');
    return parts.isEmpty ? '' : parts.last;
  }

  static void _removeById(List<Map<String, dynamic>> list, String id) {
    list.removeWhere((e) => e['id']?.toString() == id);
  }

  static void _replaceById(
    List<Map<String, dynamic>> list,
    String id,
    Map<String, dynamic> patch,
  ) {
    final i = list.indexWhere((e) => e['id']?.toString() == id);
    if (i >= 0) list[i] = {...list[i], ...patch};
  }
}
