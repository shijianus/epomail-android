import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralised HTTP client wrapping Dio.
/// - Hardcoded default server: https://mail.epocanvas.com
/// - Auto-injects [Authorization] token from SharedPreferences.
/// - Guarantees `/api` prefix on all endpoints with zero URI resolution loss.
/// - Unwraps the backend's `{ code, data, message }` envelope.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String defaultBaseUrl = 'https://mail.epocanvas.com';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  bool _interceptorAdded = false;

  void _ensureInterceptors() {
    if (_interceptorAdded) return;
    _interceptorAdded = true;

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? '';

        if (token.isNotEmpty) {
          options.headers['Authorization'] = token;
        }

        if (kDebugMode) {
          debugPrint('[API REQUEST] ${options.method} ${options.path}');
        }
        handler.next(options);
      },
      onError: (error, handler) {
        debugPrint('[API ERROR] ${error.message} on ${error.requestOptions.path}');
        handler.next(error);
      },
    ));
  }

  /// Builds a guaranteed valid absolute API URL:
  /// e.g. "https://mail.epocanvas.com/api/setting/websiteConfig"
  Future<String> _buildFullUrl(String path) async {
    final prefs = await SharedPreferences.getInstance();
    var raw = (prefs.getString('base_url') ?? '').trim();
    if (raw.isEmpty) {
      raw = defaultBaseUrl;
      await prefs.setString('base_url', raw);
    }

    // Strip trailing slashes
    while (raw.endsWith('/')) {
      raw = raw.substring(0, raw.length - 1);
    }

    // Ensure /api prefix
    final base = raw.endsWith('/api') ? raw : '$raw/api';

    // Strip leading slash on path
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$base/$cleanPath';
  }

  // ─── Typed request helpers ───────────────────────────────────────────────

  Future<T> get<T>(String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic data) parse,
  }) async {
    _ensureInterceptors();
    final url = await _buildFullUrl(path);
    final res = await _dio.get(url, queryParameters: query);
    return _unwrap(res, parse);
  }

  Future<T> post<T>(String path, {
    dynamic body,
    required T Function(dynamic data) parse,
  }) async {
    _ensureInterceptors();
    final url = await _buildFullUrl(path);
    final res = await _dio.post(url, data: body);
    return _unwrap(res, parse);
  }

  Future<T> put<T>(String path, {
    dynamic body,
    required T Function(dynamic data) parse,
  }) async {
    _ensureInterceptors();
    final url = await _buildFullUrl(path);
    final res = await _dio.put(url, data: body);
    return _unwrap(res, parse);
  }

  Future<T> delete<T>(String path, {
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
    if (code == 401) throw ApiException(body['message'] ?? 'Unauthorized', 401);
    if (code == 403) throw ApiException(body['message'] ?? 'Forbidden', 403);
    throw ApiException(body['message'] ?? 'Server error', code);
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
