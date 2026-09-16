import 'api_client.dart';

/// Account (alias) endpoints — mail-worker/src/api/account-api.js.
/// Rows are plain `account` table records (no unreadCount/isTop fields).
class AccountApi {
  final _c = ApiClient.instance;

  Future<List<dynamic>> list() =>
      _c.get('/account/list', parse: (d) => (d as List<dynamic>?) ?? []);

  Future<Map<String, dynamic>> add(String email) => _c.post('/account/add',
      body: {'email': email}, parse: (d) => Map<String, dynamic>.from(d ?? {}));

  Future<void> delete(String accountId) => _c.delete('/account/delete',
      query: {'accountId': accountId}, parse: (_) {});

  Future<void> setName(String accountId, String name) =>
      _c.put('/account/setName',
          body: {'accountId': accountId, 'name': name}, parse: (_) {});

  Future<void> setAllReceive(String accountId, bool v) =>
      _c.put('/account/setAllReceive',
          body: {'accountId': accountId, 'allReceive': v}, parse: (_) {});

  Future<void> setAsTop(String accountId) => _c.put('/account/setAsTop',
      body: {'accountId': accountId}, parse: (_) {});
}
