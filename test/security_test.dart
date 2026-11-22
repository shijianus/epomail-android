import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epomail/api/api_client.dart';
import 'package:epomail/security/token_store.dart';
import 'package:epomail/utils/email_html.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('server URL', () {
    test('https URLs are normalised', () {
      expect(ApiClient.normalizeBaseUrl(' https://Mail.Example.com/ '),
          'https://mail.example.com');
      expect(ApiClient.normalizeBaseUrl('mail.example.com:8443/x//'),
          'https://mail.example.com:8443/x');
      expect(ApiClient.normalizeBaseUrl(''), ApiClient.defaultBaseUrl);
    });

    test('cleartext, credentials and junk are rejected', () {
      for (final bad in [
        'http://mail.example.com',
        'ftp://mail.example.com',
        'https://user:pw@mail.example.com',
        'https://mail.example.com/?x=1',
        'https://',
        'javascript:alert(1)',
      ]) {
        expect(() => ApiClient.normalizeBaseUrl(bad),
            throwsA(isA<ApiException>()),
            reason: bad);
      }
    });

    test('attachment keys cannot leave the attachment route', () async {
      SharedPreferences.setMockInitialValues(
          {'base_url': 'https://mail.example.com'});
      final api = ApiClient.instance;
      expect(await api.attachmentUrl('a/b.pdf'),
          'https://mail.example.com/attachments/a/b.pdf');
      for (final bad in ['../api/user/list', '/../x', '']) {
        expect(() => api.attachmentUrl(bad), throwsA(isA<ApiException>()),
            reason: bad);
      }
    });
  });

  group('TokenStore', () {
    test('legacy plaintext token is migrated out of SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues(
          {'base_url': 'https://mail.example.com/', 'auth_token': 'T1'});
      final session = await TokenStore.read();
      expect(session?.token, 'T1');
      expect(session?.origin, 'https://mail.example.com');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('auth_token'), isFalse);

      await TokenStore.clear();
      expect(await TokenStore.read(), isNull);
    });

    test('originOf', () {
      expect(TokenStore.originOf('https://a.example.com/api/x?y=1'),
          'https://a.example.com');
      expect(TokenStore.originOf('https://a.example.com:8443/'),
          'https://a.example.com:8443');
      expect(TokenStore.originOf('/relative'), '');
    });
  });

  group('email HTML', () {
    test('only web, mail and phone links are allowed', () {
      expect(EmailHtml.safeLink('https://example.com/a')?.host, 'example.com');
      expect(EmailHtml.safeLink('MAILTO:a@b.c'), isNotNull);
      expect(EmailHtml.safeLink('tel:+123'), isNotNull);
      for (final bad in [
        'intent://x#Intent;scheme=http;end',
        'file:///data/data/x',
        'content://com.android.contacts/1',
        'javascript:alert(1)',
        'market://details?id=x',
        'https:///nohost',
        '/relative',
        '',
        null,
      ]) {
        expect(EmailHtml.safeLink(bad), isNull, reason: '$bad');
      }
    });

    test('remote images are blocked, inline ones kept', () {
      const html = '<p>hi</p>'
          '<img width="1" src="https://t.example.com/p.gif">'
          "<IMG SRC='http://t.example.com/q.gif' srcset=\"//t.example.com/r 2x\">"
          '<img src=https://t.example.com/u.gif>'
          '<img src="https&#58;//t.example.com/e.gif">'
          '<img src="&#104;ttps://t.example.com/f.gif">'
          '<img\nsrc="HTTPS://t.example.com/g.gif">'
          '<img src="data:image/png;base64,AAAA">'
          '<img src="cid:logo">'
          '<a href="https://example.com">link</a>';
      expect(EmailHtml.hasRemoteImages(html), isTrue);
      final out = EmailHtml.blockRemoteImages(html);
      expect(out.contains('t.example.com'), isFalse);
      expect(out, contains('data:image/png;base64,AAAA'));
      expect(out, contains('cid:logo'));
      expect(out, contains('<a href="https://example.com">link</a>'));
      expect(EmailHtml.hasRemoteImages(out), isFalse);
      expect(EmailHtml.hasRemoteImages('<img src="cid:logo">'), isFalse);
    });
  });
}
