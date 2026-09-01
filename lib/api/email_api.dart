import 'api_client.dart';

class EmailApi {
  final _c = ApiClient.instance;

  /// GET /email/list
  /// [type]: 0=inbox, 1=sent, 2=draft, 3=trash, 4=spam  (null = allReceive)
  Future<Map<String, dynamic>> list({
    required String accountId,
    int? type,
    bool allReceive = false,
    String? keyword,
    int page = 1,
    int pageSize = 30,
    int timeSort = 0,
  }) {
    final q = <String, dynamic>{
      'accountId': accountId,
      'page': page,
      'pageSize': pageSize,
      'timeSort': timeSort,
    };
    if (type != null) q['type'] = type;
    if (allReceive) q['allReceive'] = '1';
    if (keyword?.isNotEmpty == true) q['keyword'] = keyword;

    return _c.get('/email/list',
        query: q,
        parse: (d) => Map<String, dynamic>.from(d ?? {}));
  }

  /// GET /email/latest
  Future<List<dynamic>> latest({required String accountId, String? latestId, bool allReceive = false}) {
    final q = <String, dynamic>{'accountId': accountId};
    if (latestId != null) q['latestId'] = latestId;
    if (allReceive) q['allReceive'] = '1';
    return _c.get('/email/latest', query: q,
        parse: (d) => (d as List<dynamic>?) ?? []);
  }

  /// PUT /email/read
  Future<void> markRead(List<String> emailIds) =>
      _c.put('/email/read', body: {'emailIds': emailIds}, parse: (_) {});

  /// DELETE /email/delete
  Future<void> delete({
    required List<String> emailIds,
    required String accountId,
    bool logic = true,
  }) =>
      _c.delete('/email/delete',
          query: {
            'emailIds': emailIds.join(','),
            'accountId': accountId,
            'logic': logic.toString(),
          },
          parse: (_) {});

  /// POST /email/send
  Future<void> send({
    required String accountId,
    required List<String> to,
    List<String> cc = const [],
    List<String> bcc = const [],
    required String subject,
    required String content,
    List<String> attIds = const [],
  }) =>
      _c.post('/email/send',
          body: {
            'accountId': accountId,
            'to': to,
            'cc': cc,
            'bcc': bcc,
            'subject': subject,
            'content': content,
            'attIds': attIds,
          },
          parse: (_) {});

  /// PUT /email/spam
  Future<void> markSpam(List<String> emailIds, String accountId) =>
      _c.put('/email/spam',
          body: {'emailIds': emailIds, 'accountId': accountId},
          parse: (_) {});

  /// PUT /email/reportNotSpam
  Future<void> reportNotSpam(List<String> emailIds, String accountId) =>
      _c.put('/email/reportNotSpam',
          body: {'emailIds': emailIds, 'accountId': accountId},
          parse: (_) {});

  /// PUT /email/restore
  Future<void> restore(List<String> emailIds, String accountId) =>
      _c.put('/email/restore',
          body: {'emailIds': emailIds, 'accountId': accountId},
          parse: (_) {});

  /// GET /email/sidebarStats
  Future<Map<String, dynamic>> sidebarStats() =>
      _c.get('/email/sidebarStats',
          parse: (d) => Map<String, dynamic>.from(d ?? {}));

  /// GET /email/attList
  Future<List<dynamic>> attList(String emailId) =>
      _c.get('/email/attList',
          query: {'emailId': emailId},
          parse: (d) => (d as List<dynamic>?) ?? []);

  /// GET /email/searchSuggestions
  Future<List<dynamic>> searchSuggestions(String keyword) =>
      _c.get('/email/searchSuggestions',
          query: {'keyword': keyword},
          parse: (d) => (d as List<dynamic>?) ?? []);

  // ─── Star endpoints ─────────────────────────────────────────────────────
  Future<void> addStar(String emailId, String accountId) =>
      _c.post('/star/add',
          body: {'emailId': emailId, 'accountId': accountId},
          parse: (_) {});

  Future<void> removeStar(String emailId, String accountId) =>
      _c.delete('/star/cancel',
          query: {'emailId': emailId, 'accountId': accountId},
          parse: (_) {});

  Future<Map<String, dynamic>> starList(
          {required String accountId, int page = 1, int pageSize = 30}) =>
      _c.get('/star/list',
          query: {'accountId': accountId, 'page': page, 'pageSize': pageSize},
          parse: (d) => Map<String, dynamic>.from(d ?? {}));
}
