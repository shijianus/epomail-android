import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralised HTTP client wrapping Dio.
/// - Auto-injects [Authorization] token from SharedPreferences.
/// - Auto-prefixes [/api] to the stored base URL.
/// - Unwraps the backend's `{ code, data, message }` envelope.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  bool _interceptorAdded = false;

  void _ensureInterceptors() {
    if (_interceptorAdded) return;
    _interceptorAdded = true;

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final rawUrl = prefs.getString('base_url') ?? '';
        final token = prefs.getString('auth_token') ?? '';

        // Build base URL: strip trailing slash, append /api
        final cleaned = rawUrl.replaceAll(RegExp(r'/+$'), '');
        options.baseUrl = '$cleaned/api';

        if (token.isNotEmpty) {
          options.headers['Authorization'] = token;
        }

        if (kDebugMode) {
          debugPrint('[API] ${options.method} ${options.baseUrl}${options.path}');
        }
        handler.next(options);
      },
      onError: (error, handler) {
        debugPrint('[API ERROR] ${error.message}');
        handler.next(error);
      },
    ));
  }

  // ─── Typed request helpers ───────────────────────────────────────────────

  Future<T> get<T>(String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic data) parse,
  }) async {
    _ensureInterceptors();
    final res = await _dio.get(path, queryParameters: query);
    return _unwrap(res, parse);
  }

  Future<T> post<T>(String path, {
    dynamic body,
    required T Function(dynamic data) parse,
  }) async {
    _ensureInterceptors();
    final res = await _dio.post(path, data: body);
    return _unwrap(res, parse);
  }

  Future<T> put<T>(String path, {
    dynamic body,
    required T Function(dynamic data) parse,
  }) async {
    _ensureInterceptors();
    final res = await _dio.put(path, data: body);
    return _unwrap(res, parse);
  }

  Future<T> delete<T>(String path, {
    Map<String, dynamic>? query,
    dynamic body,
    required T Function(dynamic data) parse,
  }) async {
    _ensureInterceptors();
    final res = await _dio.delete(path, queryParameters: query, data: body);
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
