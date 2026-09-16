import 'api_client.dart';

/// Email endpoints — aligned with mail-worker/src/api/email-api.js.
///
/// Contract highlights:
/// - GET /email/list is **cursor** paginated: `emailId` cursor + `size` (<=50).
/// - Folders are queried with `type` (0=inbox, 1=sent) or `folder`
///   ('trash' | 'spam' | 'snoozed' | 'all'); drafts are client-local on web.
/// - Mutations that take `emailIds` expect a comma-joined STRING for
///   /email/spam and /email/reportNotSpam (`emailIds.split(',')`), the rest
///   accept both; we always send comma-joined strings for consistency.
class EmailApi {
  final _c = ApiClient.instance;

  /// GET /email/list
  Future<Map<String, dynamic>> list({
    String? accountId,
    int? type,
    String? folder,
    bool allReceive = false,
    String? keyword,
    int? cursorEmailId,
    int size = 30,
    int timeSort = 0,
  }) {
    final q = <String, dynamic>{
      'size': size,
      'timeSort': timeSort,
      'allReceive': allReceive ? '1' : '0',
    };
    if (accountId != null && accountId.isNotEmpty && accountId != '0') {
      q['accountId'] = accountId;
    }
    if (type != null) q['type'] = type;
    if (folder != null && folder.isNotEmpty) q['folder'] = folder;
    if (keyword?.isNotEmpty == true) q['keyword'] = keyword;
    if (cursorEmailId != null && cursorEmailId > 0)
      q['emailId'] = cursorEmailId;

    return _c.get('/email/list',
        query: q, parse: (d) => Map<String, dynamic>.from(d ?? {}));
  }

  /// GET /email/latest — params are `emailId` (cursor) + accountId/allReceive.
  Future<List<dynamic>> latest({
    required String accountId,
    String? emailId,
    bool allReceive = false,
  }) {
    final q = <String, dynamic>{'accountId': accountId};
    if (emailId != null) q['emailId'] = emailId;
    if (allReceive) q['allReceive'] = '1';
    return _c.get('/email/latest',
        query: q, parse: (d) => (d as List<dynamic>?) ?? []);
  }

  /// PUT /email/read — body { emailIds, unread }.
  /// Backend enum: unread 0 = UNREAD, 1 = READ.
  Future<void> markRead(List<String> emailIds, {bool unread = false}) =>
      _c.put('/email/read',
          body: {'emailIds': emailIds.join(','), 'unread': unread ? 1 : 0},
          parse: (_) {});

  /// DELETE /email/delete — query params emailIds + physical.
  Future<void> delete({
    required List<String> emailIds,
    bool physical = false,
  }) =>
      _c.delete('/email/delete',
          query: {
            'emailIds': emailIds.join(','),
            'physical': physical.toString()
          },
          parse: (_) {});

  /// POST /email/send — backend contract:
  /// { accountId, name, sendType, emailId, receiveEmail: [], text, content,
  ///   subject, attachments: [{ content(base64), filename, size, contentType }] }
  /// NOTE: the web backend has no cc/bcc fields on send.
  Future<void> send({
    required String accountId,
    required List<String> receiveEmail,
    required String subject,
    required String content,
    String? name,
    String sendType = '',
    String? emailId,
    String? text,
    List<Map<String, dynamic>> attachments = const [],
  }) =>
      _c.post('/email/send',
          body: {
            'accountId': accountId,
            'name': name ?? '',
            'sendType': sendType,
            if (emailId != null && emailId.isNotEmpty) 'emailId': emailId,
            'receiveEmail': receiveEmail,
            'text': text ?? _stripHtml(content),
            'content': content,
            'subject': subject,
            'attachments': attachments,
          },
          parse: (_) {});

  /// PUT /email/spam — { emailIds: "1,2", isSpam: bool }
  Future<void> setSpam(List<String> emailIds, bool isSpam) =>
      _c.put('/email/spam',
          body: {'emailIds': emailIds.join(','), 'isSpam': isSpam},
          parse: (_) {});

  /// PUT /email/reportNotSpam — moves back to inbox + removes personal rule.
  Future<void> reportNotSpam(List<String> emailIds) =>
      _c.put('/email/reportNotSpam',
          body: {'emailIds': emailIds.join(',')}, parse: (_) {});

  /// PUT /email/reportSpam — marks spam + adds personal blacklist rule.
  Future<void> reportSpam(List<String> emailIds) => _c.put('/email/reportSpam',
      body: {'emailIds': emailIds.join(',')}, parse: (_) {});

  /// PUT /email/restore — back from trash to inbox.
  Future<void> restore(List<String> emailIds) => _c.put('/email/restore',
      body: {'emailIds': emailIds.join(',')}, parse: (_) {});

  /// PUT /email/snooze — time format "YYYY-MM-DD HH:mm:ss" (local).
  Future<void> snooze(List<String> emailIds, String time, String endTime) =>
      _c.put('/email/snooze',
          body: {
            'emailIds': emailIds.join(','),
            'time': time,
            'endTime': endTime
          },
          parse: (_) {});

  /// PUT /email/snooze with empty times = unsnooze.
  Future<void> unsnooze(List<String> emailIds) => _c.put('/email/snooze',
      body: {'emailIds': emailIds.join(','), 'time': '', 'endTime': ''},
      parse: (_) {});

  /// PUT /email/labels — { emailId, labels: [..] }
  Future<void> setLabels(String emailId, List<String> labels) =>
      _c.put('/email/labels',
          body: {'emailId': emailId, 'labels': labels}, parse: (_) {});

  /// POST /email/translate — { text?, html?, targetLang } → TranslateResult.
  Future<Map<String, dynamic>> translate({
    String? text,
    String? html,
    String targetLang = 'zh',
  }) =>
      _c.post('/email/translate',
          body: {
            if (text != null && text.isNotEmpty) 'text': text,
            if (html != null && html.isNotEmpty) 'html': html,
            'targetLang': targetLang,
          },
          parse: (d) => Map<String, dynamic>.from(d ?? {}));

  /// GET /email/sidebarStats
  Future<Map<String, dynamic>> sidebarStats() => _c.get('/email/sidebarStats',
      parse: (d) => Map<String, dynamic>.from(d ?? {}));

  /// GET /email/attList
  Future<List<dynamic>> attList(String emailId) => _c.get('/email/attList',
      query: {'emailId': emailId}, parse: (d) => (d as List<dynamic>?) ?? []);

  /// GET /email/searchSuggestions — param is `query` (not keyword).
  Future<List<dynamic>> searchSuggestions(String query) =>
      _c.get('/email/searchSuggestions',
          query: {'query': query}, parse: (d) => (d as List<dynamic>?) ?? []);

  // ─── Star endpoints ─────────────────────────────────────────────────────
  Future<void> addStar(String emailId) =>
      _c.post('/star/add', body: {'emailId': emailId}, parse: (_) {});

  Future<void> removeStar(String emailId) =>
      _c.delete('/star/cancel', query: {'emailId': emailId}, parse: (_) {});

  /// GET /star/list — cursor pagination via `emailId` + `size`.
  Future<Map<String, dynamic>> starList({
    String? cursorEmailId,
    int size = 30,
    String? keyword,
  }) {
    final q = <String, dynamic>{'size': size};
    if (cursorEmailId != null &&
        cursorEmailId.isNotEmpty &&
        cursorEmailId != '0') {
      q['emailId'] = cursorEmailId;
    }
    if (keyword?.isNotEmpty == true) q['keyword'] = keyword;
    return _c.get('/star/list',
        query: q, parse: (d) => Map<String, dynamic>.from(d ?? {}));
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
