import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'session.dart';

/// Thrown for any non-2xx response or transport failure.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  /// 403 — the server knows the user but the action is not permitted
  /// (RBAC / page-permission guards, or a company the user cannot access).
  bool get isForbidden => statusCode == 403;

  /// True when no HTTP response was received at all (offline, DNS, TLS,
  /// timeout). Callers use this to decide whether to fall back to cache.
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => message;
}

/// Thin wrapper around the Go backend's `/api/v1` REST API.
///
/// Mirrors the web client's axios instance (`client/src/lib/api.ts`):
///  - same base URL
///  - `Authorization: Bearer <token>`
///  - `x-company-id` header for multi-tenancy
///  - `{success, message, data, error}` response envelope
class ApiClient {
  ApiClient({this.onUnauthorized});

  /// Called whenever the server answers 401 so the UI can bounce to login.
  final void Function()? onUnauthorized;

  static const Duration timeout = Duration(seconds: 30);

  /// One shared client so TCP connections to the Go server are reused.
  /// Built from [ApiConfig.createHttpClient] so the temporary self-signed
  /// certificate exception (see `ApiConfig.kAllowSelfSignedServer`) applies.
  static http.Client _client = IOClient(ApiConfig.createHttpClient());

  /// Test seam: swap in a fake HTTP layer (e.g. `package:http/testing`'s
  /// `MockClient`) without touching the transport code path.
  @visibleForTesting
  static void useClientForTesting(http.Client client) {
    _client = client;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (Session.token != null && Session.token!.isNotEmpty)
      'Authorization': 'Bearer ${Session.token}',
    if (Session.companyId != null && Session.companyId!.isNotEmpty)
      'x-company-id': Session.companyId!,
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiConfig.base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalizedPath').replace(
      queryParameters: (query == null || query.isEmpty)
          ? null
          : {...Uri.parse('$base$normalizedPath').queryParameters, ...query},
    );
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    return _send('GET', path, query: query);
  }

  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> put(String path, {Object? body}) async {
    return _send('PUT', path, body: body);
  }

  Future<Map<String, dynamic>> patch(String path, {Object? body}) async {
    return _send('PATCH', path, body: body);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    return _send('DELETE', path);
  }

  /// POSTs a file to an upload endpoint (`multipart/form-data`), the same
  /// shape the web client sends for `/upload/company-image` and
  /// `/upload/company-stamp` (`formData.append('image', file)`).
  Future<Map<String, dynamic>> postFile(
    String path, {
    required String filePath,
    required String filename,
    String field = 'image',
  }) async {
    final uri = _uri(path);
    // The multipart boundary header must not be replaced by the JSON one.
    final headers = Map<String, String>.of(_headers)..remove('Content-Type');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..files.add(
        await http.MultipartFile.fromPath(
          field,
          filePath,
          filename: filename,
        ),
      );

    http.Response res;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      res = await http.Response.fromStream(streamed);
    } catch (e) {
      ApiConfig.invalidate();
      throw ApiException(transportErrorMessage(e));
    }
    return _decode(res);
  }

  /// Human readable explanation of a transport-level failure. Certificate
  /// problems are called out explicitly because the production Go binary
  /// falls back to a self-signed `localhost` certificate (see `main.go`).
  @visibleForTesting
  static String transportErrorMessage(Object error) {
    final server = ApiConfig.base;
    final text = error.toString().toLowerCase();
    // package:http wraps socket errors in `ClientException`, so the
    // certificate case is also recognised from the message text.
    final tlsFailure = error is TlsException ||
        text.contains('certificate') ||
        text.contains('handshake');
    if (tlsFailure) {
      return 'Secure connection to $server failed: the server\'s HTTPS '
          'certificate is not trusted by this device (self-signed, expired or '
          'issued for a different host). Install a valid certificate on the '
          'server or ask your administrator for the correct address.';
    }
    if (error is TimeoutException) {
      return 'The FinTrack server at $server did not respond in time. '
          'Check your internet connection and try again.';
    }
    if (error is SocketException || error is http.ClientException) {
      return 'Cannot reach the FinTrack server at $server. Check your '
          'internet connection, or tap the server address on the sign-in '
          'screen if your administrator gave you a different one.';
    }
    return 'Cannot reach the FinTrack server at $server. Please try again.';
  }

  /// The raw list carried by an envelope whose `data` was an array
  /// (the client wraps non-map payloads in `{'raw': ...}` — see [_send]).
  static List<dynamic> listData(Map<String, dynamic> envelope) {
    final raw = envelope['raw'];
    return raw is List ? raw : <dynamic>[];
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = _uri(path, query);
    final encodedBody = body == null ? null : jsonEncode(body);

    http.Response res;
    try {
      final request = http.Request(method, uri)
        ..headers.addAll(_headers)
        ..body = encodedBody ?? '';
      final streamed = await _client.send(request).timeout(timeout);
      res = await http.Response.fromStream(streamed);
    } on ApiException {
      rethrow;
    } catch (e) {
      // Transport level failure: forget the cached server so the next
      // attempt re-detects it (server may have just been started).
      ApiConfig.invalidate();
      throw ApiException(transportErrorMessage(e));
    }

    return _decode(res);
  }

  Future<Map<String, dynamic>> _decode(http.Response res) async {
    Map<String, dynamic> envelope;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      envelope = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'data': decoded};
    } catch (_) {
      envelope = <String, dynamic>{};
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (res.statusCode == 401) {
        final message = (envelope['message'] as String?) ?? 'Session expired';
        final lower = message.toLowerCase();
        if (lower.contains('expired') ||
            lower.contains('invalid') ||
            lower.contains('unauthorized') ||
            lower.contains('missing')) {
          await Session.clear();
          onUnauthorized?.call();
        }
      }
      throw ApiException(
        (envelope['message'] as String?) ??
            'Request failed (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }

    final data = envelope['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{'raw': data};
  }
}
