import 'api_client.dart';

class AuthApi {
  final _c = ApiClient.instance;

  /// GET /setting/websiteConfig  (public - no auth)
  Future<Map<String, dynamic>> websiteConfig() => _c.get(
        '/setting/websiteConfig',
        parse: (d) => Map<String, dynamic>.from(d ?? {}),
      );

  /// POST /login  →  { token } | { mfaRequired: true, tempToken }
  Future<Map<String, dynamic>> login(String email, String password) =>
      _c.post('/login',
        body: {'email': email, 'password': password},
        parse: (d) => Map<String, dynamic>.from(d ?? {}),
      );

  /// POST /login/totp  →  { token }
  Future<String> verifyTotp(String tempToken, String code) => _c.post(
        '/login/totp',
        body: {'tempToken': tempToken, 'code': code},
        parse: (d) => (d as Map<String, dynamic>)['token']?.toString() ?? '',
      );

  /// DELETE /logout
  Future<void> logout() =>
      _c.delete('/logout', parse: (_) {});

  /// GET /my/loginUserInfo
  Future<Map<String, dynamic>> loginUserInfo() => _c.get(
        '/my/loginUserInfo',
        parse: (d) => Map<String, dynamic>.from(d ?? {}),
      );

  /// PUT /my/resetPassword
  Future<void> resetPassword(String oldPwd, String newPwd) =>
      _c.put('/my/resetPassword',
        body: {'oldPassword': oldPwd, 'newPassword': newPwd},
        parse: (_) {},
      );

  /// PUT /my/updateProfile
  Future<void> updateProfile(Map<String, dynamic> data) =>
      _c.put('/my/updateProfile', body: data, parse: (_) {});

  /// GET /my/totp/status
  Future<Map<String, dynamic>> totpStatus() => _c.get(
        '/my/totp/status',
        parse: (d) => Map<String, dynamic>.from(d ?? {}),
      );
}
