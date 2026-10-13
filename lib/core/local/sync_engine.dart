import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../api_client.dart';
import '../api_config.dart';
import 'outbox.dart';

/// Connectivity-aware sync engine. Keeps the Hive outbox drained into the
/// server whenever it is reachable and notifies the UI when a flush completes.
///
/// Online-ness is driven by *actual server reachability*, not just the OS
/// network flag: a successful request marks us online, a transport failure
/// marks us offline, and a slow background probe lets the banner clear again
/// once the server comes back (e.g. after `adb reverse` is re-established).
class SyncEngine {
  SyncEngine._();

  /// Whether the server is currently reachable.
  static final ValueNotifier<bool> online = ValueNotifier<bool>(true);

  /// Number of mutations still waiting to be pushed to the server.
  static final ValueNotifier<int> pending = ValueNotifier<int>(0);

  /// Incremented after a flush empties the outbox, so screens can refresh.
  static final ValueNotifier<int> syncedTick = ValueNotifier<int>(0);

  static bool _started = false;
  static bool _flushing = false;

  static const Duration _probeInterval = Duration(seconds: 15);

  /// A transient empty result at startup means "unknown", not "offline", so we
  /// only treat an explicit `none` as no network.
  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.isEmpty || results.any((r) => r != ConnectivityResult.none);

  /// Initialises connectivity state and starts listening. Safe to call once.
  static Future<void> start() async {
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addObserver(_Lifecycle());

    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isNotEmpty && !_hasNetwork(results)) online.value = false;
    } catch (_) {
      online.value = true;
    }

    Connectivity().onConnectivityChanged.listen((results) {
      if (_hasNetwork(results)) {
        unawaited(flush());
      } else {
        online.value = false;
      }
    });

    Timer.periodic(_probeInterval, (_) => flush());

    await refreshPending();
    unawaited(flush());
  }

  /// Called by [OfflineApi] after each request so the banner reflects reality.
  static void markOnline(bool value) {
    if (online.value != value) online.value = value;
  }

  static Future<void> refreshPending() async {
    pending.value = Outbox.count();
  }

  /// Drains the outbox. Stops on transport/5xx errors (retried later) and
  /// discards entries the server rejects with a 4xx (invalid mutation) so a
  /// poison entry cannot block the queue forever.
  static Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final entries = Outbox.readAll();
      if (entries.isEmpty) {
        // Nothing queued: just probe so the offline banner can clear once the
        // server is reachable again.
        if (!online.value && await ApiConfig.ping()) markOnline(true);
        await refreshPending();
        return;
      }

      final api = ApiClient();
      for (final entry in entries) {
        try {
          switch (entry.method) {
            case 'POST':
              await api.post(entry.path, body: entry.body);
            case 'PUT':
              await api.put(entry.path, body: entry.body);
            case 'PATCH':
              await api.patch(entry.path, body: entry.body);
            case 'DELETE':
              await api.delete(entry.path);
          }
          markOnline(true);
          await Outbox.remove(entry.id);
        } on ApiException catch (e) {
          if (e.isUnauthorized) return; // session issue — resume after re-login
          final code = e.statusCode;
          if (code == null) {
            markOnline(false); // transport failure — retry later
            break;
          }
          if (code >= 400 && code < 500) {
            await Outbox.remove(entry.id); // invalid — drop
          } else {
            break; // 5xx — retry later
          }
        }
      }

      await refreshPending();
      if (Outbox.readAll().isEmpty) {
        syncedTick.value = syncedTick.value + 1;
      }
    } finally {
      _flushing = false;
    }
  }
}

/// Re-drains the outbox whenever the app returns to the foreground.
class _Lifecycle extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(SyncEngine.flush());
    }
  }
}
