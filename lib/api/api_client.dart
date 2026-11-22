import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/token_store.dart';

/// Centralised HTTP client wrapping Dio.
/// - Hardcoded default server: https://mail.epocanvas.com
/// - Auto-injects the [Authorization] token from [TokenStore], only for the
///   server origin that issued it.
/// - HTTPS only: cleartext server URLs are rejected.
/// - Guarantees `/api` prefix on all endpoints with zero URI resolution loss.
/// - Unwraps the backend's `{ code, data, message }` envelope.
/// - Optional outbound proxy via the `EPO_HTTP_PROXY` env var
///   (e.g. `127.0.0.1:7897`) — for self-hosted / restricted networks.
class ApiClient {
  ApiClient._() {
    _applyOptionalProxy();
  }
  static final ApiClient instance = ApiClient._();

  static const String defaultBaseUrl = 'https://mail.epocanvas.com';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    followRedirects: false,
    // The backend reports errors in the JSON envelope; read it on any status.
    validateStatus: (_) => true,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  bool _interceptorAdded = false;

  /// Called when the server rejects the stored session token (code 401).
  void Function()? onUnauthorized;

  /// Canonical form of a user-supplied server URL. Throws [ApiException]
  /// unless it is an absolute `https://` URL.
  static String normalizeBaseUrl(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return defaultBaseUrl;
    if (!raw.contains('://')) raw = 'https://$raw';
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) {
      throw ApiException('Invalid server URL', -1);
    }
    if (uri.scheme != 'https') {
      throw ApiException('Server URL must start with https://', -1);
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw ApiException('Invalid server URL', -1);
    }
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return '${uri.origin}$path';
  }

  /// Dart's HttpClient ignores OS proxy env vars, so wire an explicit proxy
  /// when EPO_HTTP_PROXY is present (host:port or http://host:port).
  void _applyOptionalProxy() {
    if (kIsWeb) return;
    final raw = Platform.environment['EPO_HTTP_PROXY']?.trim() ?? '';
    if (raw.isEmpty) return;
    final proxy = raw.replaceFirst(RegExp(r'^https?://'), '');
    try {
      final adapter = _dio.httpClientAdapter as IOHttpClientAdapter;
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.findProxy = (uri) => 'PROXY $proxy';
        return client;
      };
    } catch (_) {
      // Adapter type differs on some platforms — proxy stays optional.
    }
  }

  /// Test seam: lets contract tests stub the HTTP transport while still
  /// exercising the real URL builder, token injection and envelope unwrapper.
  @visibleForTesting
  Dio get dioForTest => _dio;

  void _ensureInterceptors() {
    if (_interceptorAdded) return;
    _interceptorAdded = true;

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final session = await TokenStore.read();
        if (session != null &&
            session.origin.isNotEmpty &&
            session.origin == TokenStore.originOf(options.path)) {
          options.headers['Authorization'] = session.token;
        }

        if (kDebugMode) {
          debugPrint('[API REQUEST] ${options.method} ${options.path}');
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          debugPrint(
              '[API ERROR] ${error.message} on ${error.requestOptions.path}');
        }
        handler.next(error);
      },
    ));
  }

  /// Builds a guaranteed valid absolute API URL:
  /// e.g. "https://mail.epocanvas.com/api/setting/websiteConfig"
  Future<String> _buildFullUrl(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = (prefs.getString('base_url') ?? '').trim();
    if (stored.isEmpty) await prefs.setString('base_url', defaultBaseUrl);
    final raw = normalizeBaseUrl(stored);

    // Ensure /api prefix
    final base = raw.endsWith('/api') ? raw : '$raw/api';

    // Strip leading slash on path
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$base/$cleanPath';
  }

  // ─── Typed request helpers ───────────────────────────────────────────────

  /// Absolute URL for attachment downloads. Keys are served OUTSIDE `/api`
  /// at `/attachments/<key>` (see mail-worker index.js static routes).
  Future<String> attachmentUrl(String key) async {
    final base = await _rawBase();
    final clean = key.startsWith('/') ? key.substring(1) : key;
    final uri = Uri.parse('$base/attachments/$clean');
    // Keys come from the server; never let one point outside /attachments.
    final root = Uri.parse('$base/attachments/');
    if (clean.isEmpty ||
        uri.origin != root.origin ||
        !uri.path.startsWith(root.path)) {
      throw ApiException('Invalid attachment', -1);
    }
    return uri.toString();
  }

  Future<String> _rawBase() async {
    final prefs = await SharedPreferences.getInstance();
    return normalizeBaseUrl(prefs.getString('base_url') ?? '');
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic data) parse,
  }) async {
    _ensureInterceptors();
    final url = await _buildFullUrl(path);
    final res = await _dio.get(url, queryParameters: query);
    return _unwrap(res, parse);
  }

  Future<T> post<T>(
    String path, {
    dynamic body,
    required T Function(dynamic data) parse,
  }) async {
    _ensureInterceptors();
    final url = await _buildFullUrl(path);
    final res = await _dio.post(url, data: body);
    return _unwrap(res, parse);
  }

  Future<T> put<T>(
    String path, {
    dynamic body,
    required T Function(dynamic data) parse,
  }) async {
    _ensureInterceptors();
    final url = await _buildFullUrl(path);
    final res = await _dio.put(url, data: body);
    return _unwrap(res, parse);
  }

  Future<T> delete<T>(
    String path, {
    Map<String, dynamic>? query,
    dynamic body,
    required T Function(dynamic data) parse,
  }) async {
    _ensureInterceptors();
    final url = await _buildFullUrl(path);
    final res = await _dio.delete(url, queryParameters: query, data: body);
    return _unwrap(res, parse);
  }

  // ─── Envelope unwrapper ──────────────────────────────────────────────────

  T _unwrap<T>(Response res, T Function(dynamic) parse) {
    final body = res.data;
    if (body is! Map<String, dynamic>) {
      throw ApiException('Invalid response format', -1);
    }
    final code = (body['code'] as num?)?.toInt() ?? -1;
    if (code == 200) {
      return parse(body['data']);
    }
    final message = body['message']?.toString();
    if (code == 401) {
      if (res.requestOptions.headers.containsKey('Authorization')) {
        onUnauthorized?.call();
      }
      throw ApiException(message ?? 'Unauthorized', 401);
    }
    if (code == 403) throw ApiException(message ?? 'Forbidden', 403);
    throw ApiException(message ?? 'Server error', code);
  }
}

/// Structured error from the API.
class ApiException implements Exception {
  final String message;
  final int code;
  ApiException(this.message, this.code);

  bool get isAuthError => code == 401;
  bool get isForbidden => code == 403;

  @override
  String toString() => 'ApiException($code): $message';
}
