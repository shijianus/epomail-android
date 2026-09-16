import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/auth_api.dart';
import '../api/api_client.dart';
import '../models/user_model.dart';

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

  // ─── Initialisation ──────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('base_url');
    if (savedUrl == null || savedUrl.trim().isEmpty) {
      _baseUrl = ApiClient.defaultBaseUrl;
      await prefs.setString('base_url', _baseUrl);
    } else {
      _baseUrl = savedUrl.trim();
    }

    try {
      _serverConfig = await _api.websiteConfig();
    } catch (_) {
      // Server config fetch is non-blocking
    }

    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) {
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final info = await _api.loginUserInfo();
      _user = UserModel.fromJson(info);
      _state = AuthState.authenticated;
    } catch (_) {
      await prefs.remove('auth_token');
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  // ─── Server setup ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> connectServer(String url) async {
    var cleaned = url.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (cleaned.isEmpty) cleaned = ApiClient.defaultBaseUrl;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', cleaned);
    _baseUrl = cleaned;
    notifyListeners();

    final config = await _api.websiteConfig();
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
    return true;
  }

  Future<void> loginTotp(String code) async {
    if (_tempToken == null) throw ApiException('No session', -1);
    final token = await _api.verifyTotp(_tempToken!, code);
    await _saveToken(token);
    await _loadUser();
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
    try {
      await _api.logout();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> _loadUser() async {
    final info = await _api.loginUserInfo();
    _user = UserModel.fromJson(info);
    _state = AuthState.authenticated;
    notifyListeners();
  }
}
