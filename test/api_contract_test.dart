import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epomail/api/api_client.dart';
import 'package:epomail/api/auth_api.dart';
import 'package:epomail/api/email_api.dart';

/// HTTP contract tests — verify the app emits exactly the payloads that the
/// epomail web backend (mail-worker/src/api/*.js) expects, against a stubbed
/// transport while using the real URL builder / token injector / unwrapper.
class _MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions opts) handler;
  final List<RequestRecord> calls = [];
  _MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    dynamic body = options.data;
    if (body is Stream) {
      final bytes = <int>[];
      await for (final chunk in body) {
        bytes.addAll(chunk);
      }
      body = utf8.decode(bytes);
    }
    calls.add(RequestRecord(
        options.method, options.uri, options.queryParameters, body));
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class RequestRecord {
  final String method;
  final Uri uri;
  final Map<String, dynamic> query;
  final dynamic body;
  RequestRecord(this.method, this.uri, this.query, this.body);

  Map<String, dynamic> get jsonBody => body is String
      ? jsonDecode(body) as Map<String, dynamic>
      : (body ?? {}) as Map<String, dynamic>;
}

final _jsonHeaders = {
  Headers.contentTypeHeader: [Headers.jsonContentType]
};

ResponseBody _raw(String payload) => ResponseBody(
      Stream.value(Uint8List.fromList(utf8.encode(payload))),
      200,
      headers: _jsonHeaders,
    );

ResponseBody _ok(dynamic data) => _raw(
      jsonEncode({'code': 200, 'message': 'ok', 'data': data}),
    );

void main() {
  late _MockAdapter adapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'base_url': 'https://srv.example',
      'auth_token': 'TESTTOKEN',
    });
    adapter = _MockAdapter((opts) async => _ok({}));
    ApiClient.instance.dioForTest.httpClientAdapter = adapter;
  });

  group('ApiClient URL & envelope', () {
    test('prefixes /api and unwraps {code,data,message}', () async {
      adapter = _MockAdapter((opts) async => _ok({'token': 'jwt123'}));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      final token = await AuthApi().login('a@b.c', 'secret');
      expect(token['token'], 'jwt123');

      final call = adapter.calls.single;
      expect(call.method, 'POST');
      expect(call.uri.toString(), 'https://srv.example/api/login');
      expect(call.uri.path, '/api/login');
    });

    test('injects Authorization header', () async {
      final dio = ApiClient.instance.dioForTest;
      final headers = <String, List<String>>{};
      adapter = _MockAdapter((opts) async {
        headers['Authorization'] = [opts.headers['Authorization'].toString()];
        return _ok({});
      });
      dio.httpClientAdapter = adapter;
      await AuthApi().logout();
      expect(headers['Authorization']!.single, 'TESTTOKEN');
    });

    test('401 → ApiException(isAuthError)', () async {
      adapter = _MockAdapter(
        (opts) async => _raw(
          jsonEncode({'code': 401, 'message': 'authExpired', 'data': null}),
        ),
      );
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;
      await expectLater(
        AuthApi().loginUserInfo(),
        throwsA(isA<ApiException>()
            .having((e) => e.isAuthError, 'isAuthError', isTrue)),
      );
    });
  });

  group('EmailApi contract', () {
    test('list: cursor pagination + folder mapping (inbox type=0)', () async {
      adapter = _MockAdapter((opts) async => _ok({'list': [], 'total': 0}));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      await EmailApi().list(accountId: '7', type: 0, cursorEmailId: 4096);

      final call = adapter.calls.single;
      expect(call.uri.path, '/api/email/list');
      expect(call.query['accountId'], '7');
      expect(call.query['type'], 0);
      expect(call.query['emailId'], 4096,
          reason: 'backend uses emailId cursor, not page');
      expect(call.query['size'], 30);
      expect(call.query.containsKey('folder'), isFalse);
    });

    test('list: trash / spam / snoozed / all use folder param', () async {
      adapter = _MockAdapter((opts) async => _ok({'list': [], 'total': 0}));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      await EmailApi().list(folder: 'trash');
      expect(adapter.calls.last.query['folder'], 'trash');

      await EmailApi().list(folder: 'spam');
      expect(adapter.calls.last.query['folder'], 'spam');

      await EmailApi().list(folder: 'snoozed');
      expect(adapter.calls.last.query['folder'], 'snoozed');

      await EmailApi().list(folder: 'all', allReceive: true);
      expect(adapter.calls.last.query['folder'], 'all');
      expect(adapter.calls.last.query['allReceive'], '1');
      expect(adapter.calls.last.query.containsKey('type'), isFalse);
    });

    test('read: {emailIds:"1,2", unread} — 0=UNREAD 1=READ', () async {
      adapter = _MockAdapter((opts) async => _ok({}));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      await EmailApi().markRead(['1', '2'], unread: true);
      expect(adapter.calls.last.uri.path, '/api/email/read');
      expect(adapter.calls.last.method, 'PUT');
      expect(adapter.calls.last.jsonBody['emailIds'], '1,2');
      expect(adapter.calls.last.jsonBody['unread'], 1);

      await EmailApi().markRead(['3'], unread: false);
      expect(adapter.calls.last.jsonBody['unread'], 0);
    });

    test('delete: query emailIds + physical (logic default)', () async {
      adapter = _MockAdapter((opts) async => _ok({}));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      await EmailApi().delete(emailIds: ['1', '2']);
      final call = adapter.calls.single;
      expect(call.method, 'DELETE');
      expect(call.uri.path, '/api/email/delete');
      expect(call.query['emailIds'], '1,2');
      expect(call.query['physical'], 'false');
    });

    test(
        'send: real backend payload (receiveEmail list, attachments, no cc/bcc)',
        () async {
      adapter = _MockAdapter((opts) async => _ok({}));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      await EmailApi().send(
        accountId: '7',
        name: 'tester',
        receiveEmail: ['a@b.c', 'd@e.f'],
        subject: 'Hello',
        content: '<div dir="ltr">Hi<br></div>',
        sendType: 'reply',
        emailId: '42',
        attachments: [
          {
            'content': 'aGk=',
            'filename': 'hi.txt',
            'size': 2,
            'contentType': 'text/plain'
          }
        ],
      );

      final call = adapter.calls.single;
      expect(call.uri.path, '/api/email/send');
      final body = call.jsonBody;
      expect(body['accountId'], '7');
      expect(body['name'], 'tester');
      expect(body['sendType'], 'reply');
      expect(body['emailId'], '42');
      expect(body['receiveEmail'], ['a@b.c', 'd@e.f'],
          reason: 'backend field is receiveEmail, not to');
      expect(body['subject'], 'Hello');
      expect((body['attachments'] as List).single['filename'], 'hi.txt');
      expect(body.containsKey('to'), isFalse,
          reason: 'backend has no `to` field');
      expect(body.containsKey('attIds'), isFalse,
          reason: 'attachments travel inline');
      expect(body['text'], isNotEmpty,
          reason: 'backend expects a plain-text copy');
    });

    test('setSpam / reportNotSpam: comma-joined string emailIds', () async {
      adapter = _MockAdapter((opts) async => _ok({}));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      await EmailApi().setSpam(['1', '2'], true);
      expect(adapter.calls.last.uri.path, '/api/email/spam');
      expect(adapter.calls.last.jsonBody['emailIds'], '1,2');
      expect(adapter.calls.last.jsonBody['isSpam'], true);

      await EmailApi().reportNotSpam(['3']);
      expect(adapter.calls.last.uri.path, '/api/email/reportNotSpam');
      expect(adapter.calls.last.jsonBody['emailIds'], '3');
    });

    test('reportSpam / restore / snooze / labels paths & bodies', () async {
      adapter = _MockAdapter((opts) async => _ok({}));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      await EmailApi().reportSpam(['5']);
      expect(adapter.calls.last.uri.path, '/api/email/reportSpam');

      await EmailApi().restore(['5']);
      expect(adapter.calls.last.uri.path, '/api/email/restore');
      expect(adapter.calls.last.method, 'PUT');

      await EmailApi()
          .snooze(['5'], '2026-09-15 18:00:00', '2026-09-16 18:00:00');
      expect(adapter.calls.last.uri.path, '/api/email/snooze');
      expect(adapter.calls.last.jsonBody['time'], '2026-09-15 18:00:00');

      await EmailApi().setLabels('5', ['工作']);
      expect(adapter.calls.last.uri.path, '/api/email/labels');
      expect(adapter.calls.last.jsonBody['emailId'], '5');
      expect(adapter.calls.last.jsonBody['labels'], ['工作']);
    });

    test('searchSuggestions uses `query` param (not keyword)', () async {
      adapter = _MockAdapter((opts) async => _ok([]));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      await EmailApi().searchSuggestions('hel');
      expect(adapter.calls.last.uri.path, '/api/email/searchSuggestions');
      expect(adapter.calls.last.query['query'], 'hel');
    });

    test('star endpoints: add body / cancel query / list cursor', () async {
      adapter = _MockAdapter((opts) async => _ok({'list': [], 'total': 0}));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      await EmailApi().addStar('9');
      expect(adapter.calls.last.method, 'POST');
      expect(adapter.calls.last.uri.path, '/api/star/add');
      expect(adapter.calls.last.jsonBody['emailId'], '9');
      expect(adapter.calls.last.jsonBody.containsKey('accountId'), isFalse);

      await EmailApi().removeStar('9');
      expect(adapter.calls.last.method, 'DELETE');
      expect(adapter.calls.last.uri.path, '/api/star/cancel');
      expect(adapter.calls.last.query['emailId'], '9');

      await EmailApi().starList(cursorEmailId: '100');
      expect(adapter.calls.last.uri.path, '/api/star/list');
      expect(adapter.calls.last.query['emailId'], '100');
      expect(adapter.calls.last.query['size'], 30);
      expect(adapter.calls.last.query.containsKey('page'), isFalse);
    });

    test('translate posts text/html + targetLang', () async {
      adapter = _MockAdapter(
        (opts) async => _ok({
          'translatedText': '你好',
          'translatedHtml': '<div>你好</div>',
          'isHtml': true,
          'model': '@cf/meta/llama-3.1-8b-instruct',
          'tokens': 10,
        }),
      );
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      final res = await EmailApi()
          .translate(html: '<div>hello</div>', targetLang: 'zh');
      expect(adapter.calls.last.uri.path, '/api/email/translate');
      expect(adapter.calls.last.jsonBody['targetLang'], 'zh');
      expect(res['translatedText'], '你好');
    });
  });

  group('AuthApi contract', () {
    test('resetPassword sends {password} (no oldPassword field)', () async {
      adapter = _MockAdapter((opts) async => _ok({}));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      await AuthApi().resetPassword('newSecret1');
      expect(adapter.calls.last.uri.path, '/api/my/resetPassword');
      expect(adapter.calls.last.jsonBody.keys, ['password']);
    });

    test('register posts email/password (+code regKey)', () async {
      adapter = _MockAdapter((opts) async => _ok('jwt-token'));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      final token = await AuthApi()
          .register('new@epomail.bond', 'secret1', regKey: 'KEY1');
      expect(adapter.calls.last.uri.path, '/api/register');
      expect(adapter.calls.last.jsonBody['email'], 'new@epomail.bond');
      expect(adapter.calls.last.jsonBody['code'], 'KEY1');
      expect(token, 'jwt-token');
    });

    test('updateProfile merges arbitrary fields', () async {
      adapter = _MockAdapter((opts) async => _ok({}));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      await AuthApi().updateProfile({'themeMode': 'dark'});
      expect(adapter.calls.last.uri.path, '/api/my/updateProfile');
      expect(adapter.calls.last.jsonBody['themeMode'], 'dark');
    });

    test('login/totp posts tempToken+code', () async {
      adapter = _MockAdapter((opts) async => _ok({'token': 't2'}));
      ApiClient.instance.dioForTest.httpClientAdapter = adapter;

      final t = await AuthApi().verifyTotp('totp_tmp_abc', '123456');
      expect(adapter.calls.last.uri.path, '/api/login/totp');
      expect(adapter.calls.last.jsonBody['tempToken'], 'totp_tmp_abc');
      expect(adapter.calls.last.jsonBody['code'], '123456');
      expect(t, 't2');
    });
  });

  group('Attachment URL', () {
    test('builds /attachments/<key> OUTSIDE /api prefix', () async {
      final url = await ApiClient.instance.attachmentUrl('att/abc.pdf');
      expect(url, 'https://srv.example/attachments/att/abc.pdf');
      expect(url.contains('/api/'), isFalse);
    });
  });
}
