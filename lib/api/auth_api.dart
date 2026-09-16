import 'api_client.dart';

class AuthApi {
  final _c = ApiClient.instance;

  /// GET /setting/websiteConfig  (public - no auth)
  /// Returns register (0=open,1=close), regKey (0=required,1=disabled,2=optional),
  /// domainList, title, notice fields...
  Future<Map<String, dynamic>> websiteConfig() => _c.get(
        '/setting/websiteConfig',
        parse: (d) => Map<String, dynamic>.from(d ?? {}),
      );

  /// POST /login  →  { token } | { mfaRequired: true, tempToken }
  Future<Map<String, dynamic>> login(String email, String password) => _c.post(
        '/login',
        body: {'email': email, 'password': password},
        parse: (d) => Map<String, dynamic>.from(d ?? {}),
      );

  /// POST /login/totp  →  { token }
  Future<String> verifyTotp(String tempToken, String code) => _c.post(
        '/login/totp',
        body: {'tempToken': tempToken, 'code': code},
        parse: (d) => (d as Map<String, dynamic>)['token']?.toString() ?? '',
      );

  /// POST /register — { email, password, code? (regKey) }.
  /// register: 0=open / 1=close; regKey: 0=required, 1=disabled, 2=optional.
  Future<String> register(String email, String password, {String? regKey}) =>
      _c.post(
        '/register',
        body: {
          'email': email,
          'password': password,
          if (regKey != null && regKey.isNotEmpty) 'code': regKey,
        },
        parse: (d) => d?.toString() ?? '',
      );

  /// DELETE /logout
  Future<void> logout() => _c.delete('/logout', parse: (_) {});

  /// GET /my/loginUserInfo
  Future<Map<String, dynamic>> loginUserInfo() => _c.get(
        '/my/loginUserInfo',
        parse: (d) => Map<String, dynamic>.from(d ?? {}),
      );

  /// PUT /my/resetPassword — backend contract is { password } (no old pwd).
  Future<void> resetPassword(String newPassword) => _c.put(
        '/my/resetPassword',
        body: {'password': newPassword},
        parse: (_) {},
      );

  /// PUT /my/updateProfile — arbitrary profile fields merged server-side
  /// (themeMode, lang, nickname, ...).
  Future<void> updateProfile(Map<String, dynamic> data) =>
      _c.put('/my/updateProfile', body: data, parse: (_) {});

  /// GET /my/totp/status
  Future<Map<String, dynamic>> totpStatus() => _c.get(
        '/my/totp/status',
        parse: (d) => Map<String, dynamic>.from(d ?? {}),
      );

  /// GET /my/storage — storage usage (usedBytes/quotaMb/isVisitor/...).
  Future<Map<String, dynamic>> storage() => _c.get(
        '/my/storage',
        parse: (d) => Map<String, dynamic>.from(d ?? {}),
      );
}
