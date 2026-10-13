import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Resolves and caches the Go backend base URL.
///
/// The mobile app has no backend of its own: every request goes to the very
/// same Gin server the Next.js web app talks to, which is what keeps both
/// clients on one database.
class ApiConfig {
  ApiConfig._();

  /// The online FinTrack server the mobile app talks to by default. A
  /// different address can still be supplied at build time (see [kEnvBase])
  /// or at sign-in for local development.
  ///
  /// IMPORTANT: a production Go build (`build.sh --prod`) serves HTTPS on
  /// 8090. Unless `TLS_CERT_FILE` / `TLS_KEY_FILE` point at a certificate
  /// that is valid for the host below, `main.go` generates a self-signed
  /// certificate for `localhost`/`127.0.0.1` only, which Android correctly
  /// rejects. Certificate checks are never disabled here — install a real
  /// certificate (or a TLS reverse proxy) and point this at its hostname.
  static const String kDefaultBase = 'https://103.99.132.68:8090/api/v1';

  /// TEMPORARY — accept the FinTrack server's self-signed certificate.
  ///
  /// The Go server currently uses the self-signed `localhost` certificate
  /// that `main.go` generates, which Android/Dart reject. Until a valid
  /// certificate is installed, invalid certificates are accepted, but ONLY
  /// from the host and port of [kDefaultBase] (103.99.132.68:8090). Any other
  /// server still gets full certificate validation.
  ///
  /// SECURITY: while this is `true`, traffic to that server is encrypted but
  /// not authenticated, so someone on the same network could impersonate the
  /// server. Set it to `false` as soon as the server has a valid certificate.
  static const bool kAllowSelfSignedServer = true;

  static final Uri _trustedServer = Uri.parse(kDefaultBase);

  /// The one place `dart:io` HTTP clients are created (API requests and the
  /// health probe), so the temporary exception above is applied consistently.
  static HttpClient createHttpClient() {
    final client = HttpClient();
    if (kAllowSelfSignedServer) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) =>
          host == _trustedServer.host && port == _trustedServer.port;
    }
    return client;
  }

  /// Override at build/run time:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.100.179:8090/api/v1
  static const String kEnvBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kDefaultBase,
  );

  static const String kPort = '8090';
  static const String kApiSuffix = '/api/v1';

  /// The app targets the single online server; no localhost/emulator/LAN
  /// addresses are used, so a physical device reaches the server directly.
  static const List<String> kFallbacks = [kDefaultBase];

  /// Mobile networks routinely need more than 2s for a TLS handshake, so the
  /// health probe gets a more forgiving budget.
  static const Duration _defaultTimeout = Duration(seconds: 6);

  static String? _resolved;
  static Future<String>? _inFlight;

  static String get base {
    if (_resolved != null) return _resolved!;
    if (kEnvBase.isNotEmpty) return kEnvBase;
    return kFallbacks.first;
  }

  /// Server origin without the /api/v1 suffix (used for /health probing).
  static String get origin {
    final b = base;
    return b.endsWith(kApiSuffix)
        ? b.substring(0, b.length - kApiSuffix.length)
        : b;
  }

  /// Called whenever a request fails at the transport level so the next
  /// attempt re-detects the server (e.g. the user just started it).
  static void invalidate() {
    _resolved = null;
  }

  /// Health-checks the currently known (or freshly detected) server. Used by
  /// the sync engine to decide whether the app is really online — a mere OS
  /// network connection is not enough if the Go server is unreachable.
  static Future<bool> ping() async {
    final resolved = await resolve();
    return _healthy(resolved);
  }

  /// Probes for a reachable server and caches it. Concurrent callers share
  /// the same in-flight detection.
  static Future<String> resolve({String? override}) {
    if (_inFlight != null) return _inFlight!;

    final Future<String> future;
    if (override != null && override.isNotEmpty) {
      future = _doResolve(override);
    } else if (_resolved != null) {
      future = _revalidate();
    } else {
      future = _doResolve(null);
    }

    _inFlight = future.whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  static Future<String> _revalidate() async {
    if (await _healthy(_resolved!)) return _resolved!;
    return _doResolve(null);
  }

  static Future<String> _doResolve(String? override) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('api_base');
    final candidates = <String>[
      if (override != null && override.isNotEmpty) _normalize(override),
      // Keep a server the user explicitly chose, but ignore any stale
      // localhost/emulator address saved by an older build now that the app
      // targets the online server.
      if (saved != null && saved.isNotEmpty && !_isLocalAddress(saved)) saved,
      if (kEnvBase.isNotEmpty) kEnvBase,
      ...kFallbacks,
    ];

    for (final candidate in candidates) {
      if (await _healthy(candidate)) return _remember(candidate);
    }

    _resolved = override != null && override.isNotEmpty
        ? _normalize(override)
        : (kEnvBase.isNotEmpty ? kEnvBase : kFallbacks.first);
    return _resolved!;
  }

  /// True for the development-only addresses the production app must not use.
  static bool _isLocalAddress(String url) {
    final u = url.toLowerCase();
    return u.contains('localhost') ||
        u.contains('127.0.0.1') ||
        u.contains('10.0.2.2');
  }

  static Future<String> _remember(String url) async {
    _resolved = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base', url);
    return url;
  }

  static void use(String url) {
    _resolved = _normalize(url);
  }

  static String _normalize(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.endsWith(kApiSuffix)) {
      u = '$u$kApiSuffix';
    }
    return u;
  }

  static Future<bool> _healthy(
    String apiBase, {
    Duration timeout = _defaultTimeout,
  }) async {
    var originUrl = apiBase;
    if (originUrl.endsWith(kApiSuffix)) {
      originUrl = originUrl.substring(0, originUrl.length - kApiSuffix.length);
    }
    HttpClient? client;
    try {
      client = createHttpClient()..connectionTimeout = timeout;
      final request = await client
          .getUrl(Uri.parse('$originUrl/health'))
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }
}
