import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

/// Session token persistence backed by the Android Keystore.
///
/// The token is bound to the server origin it was issued by, so it is never
/// attached to requests for a different server.
class TokenStore {
  TokenStore._();

  static const _tokenKey = 'auth_token';
  static const _originKey = 'auth_origin';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Used only when the platform keystore is unavailable: the session then
  // lasts until the process dies instead of falling back to plaintext storage.
  static String? _memToken;
  static String? _memOrigin;

  static Future<({String token, String origin})?> read() async {
    await _migrateLegacy();
    try {
      final token = await _storage.read(key: _tokenKey) ?? '';
      final origin = await _storage.read(key: _originKey) ?? '';
      if (token.isNotEmpty) return (token: token, origin: origin);
    } catch (e) {
      if (kDebugMode) debugPrint('[TokenStore] read failed: $e');
    }
    final mem = _memToken;
    if (mem != null && mem.isNotEmpty) {
      return (token: mem, origin: _memOrigin ?? '');
    }
    return null;
  }

  static Future<void> write(String token, String origin) async {
    if (token.isEmpty) return clear();
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _originKey, value: origin);
      _memToken = null;
      _memOrigin = null;
    } catch (e) {
      if (kDebugMode) debugPrint('[TokenStore] write failed: $e');
      _memToken = token;
      _memOrigin = origin;
    }
  }

  static Future<void> clear() async {
    _memToken = null;
    _memOrigin = null;
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _originKey);
    } catch (e) {
      if (kDebugMode) debugPrint('[TokenStore] clear failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Versions <= 1.1.0 kept the token in plaintext SharedPreferences.
  static Future<void> _migrateLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_tokenKey);
    if (legacy == null) return;
    await prefs.remove(_tokenKey);
    if (legacy.isEmpty) return;
    var origin = originOf(prefs.getString('base_url') ?? '');
    if (origin.isEmpty) origin = originOf(ApiClient.defaultBaseUrl);
    await write(legacy, origin);
  }

  /// `scheme://host[:port]` of a URL, or '' when it is not absolute.
  static String originOf(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return '';
    return uri.origin;
  }
}
