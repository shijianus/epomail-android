import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/auth_api.dart';
import '../api/api_client.dart';
import '../models/user_model.dart';
import '../security/token_store.dart';

enum AuthState { loading, unauthenticated, mfaRequired, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.loading;
  UserModel? _user;
  String _baseUrl = ApiClient.defaultBaseUrl;
  String? _tempToken;
  Map<String, dynamic>? _serverConfig;

  AuthState get state => _state;
  UserModel? get user => _user;
  String get baseUrl => _baseUrl;
  String? get tempToken => _tempToken;
  Map<String, dynamic>? get serverConfig => _serverConfig;
  bool get isAuthenticated => _state == AuthState.authenticated;

  final _api = AuthApi();

  /// Invoked when the server rejects the session while the user is signed in.
  VoidCallback? onSessionExpired;

  AuthProvider() {
    ApiClient.instance.onUnauthorized = _handleUnauthorized;
  }

  void _handleUnauthorized() {
    if (_state != AuthState.authenticated) return;
    _state = AuthState.unauthenticated;
    _user = null;
    _tempToken = null;
    TokenStore.clear();
    notifyListeners();
    onSessionExpired?.call();
  }

  // ─── Initialisation ──────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('base_url');
    if (savedUrl == null || savedUrl.trim().isEmpty) {
      _baseUrl = ApiClient.defaultBaseUrl;
      await prefs.setString('base_url', _baseUrl);
    } else {
      try {
        _baseUrl = ApiClient.normalizeBaseUrl(savedUrl);
      } on ApiException {
        // A stored cleartext / malformed URL is no longer accepted.
        _baseUrl = ApiClient.defaultBaseUrl;
        await TokenStore.clear();
      }
      if (_baseUrl != savedUrl) await prefs.setString('base_url', _baseUrl);
    }

    try {
      _serverConfig = await _api.websiteConfig();
    } catch (_) {
      // Server config fetch is non-blocking
    }

    final session = await TokenStore.read();
    if (session == null) {
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final info = await _api.loginUserInfo();
      _user = UserModel.fromJson(info);
      _state = AuthState.authenticated;
    } on ApiException catch (e) {
      if (e.isAuthError) await TokenStore.clear();
      _state = AuthState.unauthenticated;
    } catch (_) {
      // Offline / server unreachable: keep the session for the next launch.
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  // ─── Server setup ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> connectServer(String url) async {
    final cleaned = ApiClient.normalizeBaseUrl(url);
    final previous = _baseUrl;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', cleaned);
    final Map<String, dynamic> config;
    try {
      config = await _api.websiteConfig();
    } catch (_) {
      await prefs.setString('base_url', previous);
      rethrow;
    }

    // A session belongs to the server that issued it.
    if (TokenStore.originOf(cleaned) != TokenStore.originOf(previous)) {
      await TokenStore.clear();
      _user = null;
      _tempToken = null;
      _state = AuthState.unauthenticated;
    }
    _baseUrl = cleaned;
    _serverConfig = config;
    notifyListeners();
    return config;
  }

  // ─── Login ───────────────────────────────────────────────────────────────

  /// Returns true = fully logged in; false = MFA step required.
  Future<bool> login(String email, String password) async {
    final result = await _api.login(email, password);
    if (result['mfaRequired'] == true) {
      _tempToken = result['tempToken']?.toString();
      _state = AuthState.mfaRequired;
      notifyListeners();
      return false;
    }
    await _saveToken(result['token']?.toString() ?? '');
    await _loadUser();
    _tempToken = null;
    return true;
  }

  Future<void> loginTotp(String code) async {
    if (_tempToken == null) throw ApiException('No session', -1);
    final token = await _api.verifyTotp(_tempToken!, code);
    await _saveToken(token);
    await _loadUser();
    _tempToken = null;
  }

  // ─── Register ────────────────────────────────────────────────────────────

  /// POST /register — server auto-logs-in by returning a JWT.
  Future<void> register(String email, String password, {String? regKey}) async {
    final token = await _api.register(email, password, regKey: regKey);
    if (token.isNotEmpty) {
      await _saveToken(token);
      await _loadUser();
    }
  }

  // ─── Logout ──────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final wasAuthenticated = _state == AuthState.authenticated;
    // Flip first so a 401 on the logout call is not reported as an expiry.
    _state = AuthState.unauthenticated;
    if (wasAuthenticated) {
      try {
        await _api.logout();
      } catch (_) {}
    }
    await TokenStore.clear();
    _user = null;
    _tempToken = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  // ─── User operations ─────────────────────────────────────────────────────

  Future<void> refreshUser() async {
    final info = await _api.loginUserInfo();
    _user = UserModel.fromJson(info);
    notifyListeners();
  }

  Future<void> changePassword(String newPassword) =>
      _api.resetPassword(newPassword);

  /// Persist a profile field server-side (themeMode/lang/...) and refresh.
  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _api.updateProfile(data);
    await refreshUser();
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  Future<void> _saveToken(String token) async {
    if (token.isEmpty) throw ApiException('Sign-in failed', -1);
    await TokenStore.write(token, TokenStore.originOf(_baseUrl));
  }

  Future<void> _loadUser() async {
    final info = await _api.loginUserInfo();
    _user = UserModel.fromJson(info);
    _state = AuthState.authenticated;
    notifyListeners();
  }
}
