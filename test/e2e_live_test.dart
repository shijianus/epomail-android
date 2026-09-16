import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:epomail/api/api_client.dart';
import 'package:epomail/api/auth_api.dart';
import 'package:epomail/api/email_api.dart';
import 'package:epomail/api/account_api.dart';
import 'package:epomail/models/email_model.dart';
import 'package:epomail/models/user_model.dart';

/// LIVE end-to-end contract test against a real epomail deployment.
///
/// Mirrors the web repo's `tests/test-welcome-email-visitor-and-all-accounts.mjs`
/// discipline: creates a temporary real user through the ADMIN API, exercises
/// every Android client endpoint against the real backend, and PHYSICALLY
/// deletes the account in `finally` — zero fake data residue.
///
/// Overrides (passed via `flutter test --dart-define=...`):
///   E2E_BASE_URL       (default https://epomail.epocanvas.workers.dev)
///   E2E_ADMIN_EMAIL    (default admin@epomail.bond)
///   E2E_ADMIN_PASSWORD (default 123456)
void main() {
  final base = const String.fromEnvironment('E2E_BASE_URL',
      defaultValue: 'https://epomail.epocanvas.workers.dev');
  final adminEmail = const String.fromEnvironment('E2E_ADMIN_EMAIL',
      defaultValue: 'admin@epomail.bond');
  final adminPassword = const String.fromEnvironment('E2E_ADMIN_PASSWORD',
      defaultValue: '123456');

  late AuthApi authApi;
  late EmailApi emailApi;
  late AccountApi accountApi;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(
        {'base_url': base, 'auth_token': ''});
    authApi = AuthApi();
    emailApi = EmailApi();
    accountApi = AccountApi();
  });

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<List<EmailModel>> fetchRows(String accountId) async {
    final page = await emailApi.list(accountId: accountId);
    return ((page['list'] as List<dynamic>?) ?? [])
        .map((e) => EmailModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  test(
      'full-stack: login → welcome email → star/read/labels/snooze → send → cleanup',
      timeout: const Timeout(Duration(minutes: 4)), () async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final testEmail = 'android_e2e_$ts@epomail.bond';
    const testPassword = 'Password123!';
    final testSubject = 'Android E2E self-send $ts';

    int? userId;

    try {
      // ── 0. Public websiteConfig ────────────────────────────────────────
      final cfg = await authApi.websiteConfig();
      expect(cfg.containsKey('register'), isTrue,
          reason: 'websiteConfig.register');
      expect(cfg.containsKey('regKey'), isTrue, reason: 'websiteConfig.regKey');
      expect(cfg['domainList'], isA<List<dynamic>>(),
          reason: 'domainList must be a parsed array of @domain strings');

      // ── 1. Admin login & pick a normal (non-banned) role ───────────────
      final adminLogin = await authApi.login(adminEmail, adminPassword);
      final adminToken = adminLogin['token']?.toString() ?? '';
      expect(adminToken, isNotEmpty, reason: 'admin login must yield a JWT');
      await setToken(adminToken);

      final roles = (await ApiClient.instance
              .get('/role/list', parse: (d) => (d as List<dynamic>?) ?? []))
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      expect(roles, isNotEmpty);

      var role = roles.firstWhere(
        (r) =>
            r['roleCode'] == 'user_base' ||
            r['name'].toString().contains('普通用户'),
        orElse: () => roles.first,
      );
      final canSend = role['sendType'] != 'ban';

      // ── 2. Create a real temp user via /user/add ───────────────────────
      await ApiClient.instance.post('/user/add',
          body: {
            'email': testEmail,
            'password': testPassword,
            'name': 'Android_E2E',
            'type': role['roleId'],
          },
          parse: (_) => true);

      final found = await ApiClient.instance.get('/user/list',
          query: {'email': testEmail},
          parse: (d) => Map<String, dynamic>.from(d ?? {}));
      final matches = ((found['list'] as List<dynamic>?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((u) => u['email'].toString().toLowerCase() == testEmail)
          .toList();
      expect(matches, isNotEmpty, reason: 'created user must be retrievable');
      userId = (matches.first['userId'] as num).toInt();

      // ── 3. Login as the temp user THROUGH THE APP'S OWN CLIENT ────────
      final userLogin = await authApi.login(testEmail, testPassword);
      final userToken = userLogin['token']?.toString() ?? '';
      expect(userToken, isNotEmpty);
      await setToken(userToken);

      final info = await authApi.loginUserInfo();
      final me = UserModel.fromJson(info);
      expect(me.email.toLowerCase(), testEmail);
      expect(me.account, isNotNull,
          reason: 'loginUserInfo must embed the primary account');
      expect(me.account!.accountId, isNotEmpty);

      // ── 4. Welcome email guaranteed on inbox fetch ─────────────────────
      EmailModel? welcome;
      for (var attempt = 0; attempt < 12; attempt++) {
        final rows = await fetchRows(me.account!.accountId);
        final official = rows.where((e) => e.isOfficial).toList();
        if (official.isNotEmpty) {
          welcome = official.first;
          expect(welcome.from, 'admin@epocanvas.com',
              reason: 'welcome email must come from the official sender');
          expect(welcome.isStar, isTrue,
              reason: 'welcome email must be starred by default');
          expect(welcome.subject, contains('欢迎'),
              reason: 'welcome subject must include the greeting');
          expect(welcome.content.length, greaterThan(100),
              reason: 'welcome content must be the full template');
          break;
        }
        await Future.delayed(const Duration(seconds: 2));
      }
      expect(welcome, isNotNull,
          reason:
              'welcome email must arrive for a fresh account (official + starred)');
      final welcomeId = welcome!.emailId;

      // ── 5. Read / unread roundtrip (unread: 0=UNREAD, 1=READ) ─────────
      await emailApi.markRead([welcomeId], unread: true);
      expect(
          (await _fetchRow(
              emailApi, welcomeId, me.account!.accountId))['unread'],
          1,
          reason: 'markRead must set unread=1 (READ)');

      await emailApi.markRead([welcomeId], unread: false);
      expect(
          (await _fetchRow(
              emailApi, welcomeId, me.account!.accountId))['unread'],
          0,
          reason: 'markUnread must set unread=0 (UNREAD)');

      // ── 6. Star roundtrip through /star/* ──────────────────────────────
      await emailApi.removeStar(welcomeId);
      var starIds = await _starIds(emailApi);
      expect(starIds.contains(welcomeId), isFalse,
          reason: 'star must be removable');

      await emailApi.addStar(welcomeId);
      starIds = await _starIds(emailApi);
      expect(starIds.contains(welcomeId), isTrue,
          reason: 'star must be addable via /star/add');

      // ── 7. Labels via PUT /email/labels ────────────────────────────────
      await emailApi.setLabels(welcomeId, ['工作']);
      final labeled =
          await _fetchRow(emailApi, welcomeId, me.account!.accountId);
      expect(labeled['labels'].toString().contains('工作'), isTrue,
          reason: 'labels must persist as JSON');

      // ── 8. Snooze + unsnooze ───────────────────────────────────────────
      await emailApi
          .snooze([welcomeId], '2026-09-15 18:00:00', '2026-09-16 18:00:00');
      final snoozed =
          await _fetchRow(emailApi, welcomeId, me.account!.accountId);
      expect(snoozed['snoozedTime'], '2026-09-15 18:00:00');
      await emailApi.unsnooze([welcomeId]);

      // ── 9. Sidebar stats & storage endpoints ───────────────────────────
      final stats = await emailApi.sidebarStats();
      expect(stats.containsKey('inboxUnread'), isTrue,
          reason: 'sidebarStats must expose real SQL aliases');
      expect(stats['labelStats'], isA<Map<String, dynamic>>());

      final storage = await authApi.storage();
      expect(storage.containsKey('usedBytes'), isTrue);
      expect(storage.containsKey('quotaMb'), isTrue);

      // ── 10. Account list contains the account ──────────────────────────
      final accounts = await accountApi.list();
      final accEmails = accounts
          .map((e) => (e as Map)['email'].toString().toLowerCase())
          .toList();
      expect(accEmails, contains(testEmail));

      // ── 11. Send (real /email/send payload contract) → Sent folder ────
      if (canSend) {
        await emailApi.send(
          accountId: me.account!.accountId,
          name: me.account!.displayLabel,
          receiveEmail: [testEmail],
          subject: testSubject,
          content: '<div dir="ltr">Self test from epomail-android E2E.</div>',
        );
        final sent =
            await emailApi.list(accountId: me.account!.accountId, type: 1);
        final sentRows = ((sent['list'] as List<dynamic>?) ?? [])
            .map(
                (e) => EmailModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final mine = sentRows.where((e) => e.subject == testSubject).toList();
        expect(mine, isNotEmpty,
            reason: 'sent mail must appear with type=1 (SEND)');
        expect(mine.first.type, 1);
        // physical delete to keep the account clean before removal
        await emailApi.delete(
            emailIds: mine.map((e) => e.emailId).toList(), physical: true);
      }

      // ── 12. /email/latest contract ─────────────────────────────────────
      final latest =
          await emailApi.latest(accountId: me.account!.accountId, emailId: '0');
      expect(latest, isA<List<dynamic>>());
    } finally {
      // ── CLEANUP: physical delete of the temp user (zero residue) ──────
      try {
        final adminLogin = await authApi.login(adminEmail, adminPassword);
        await setToken(adminLogin['token']?.toString() ?? '');
        if (userId != null) {
          await ApiClient.instance.delete('/user/delete',
              query: {'userIds': '$userId'}, parse: (_) => true);
        }
        final check = await ApiClient.instance.get('/user/list',
            query: {'email': testEmail},
            parse: (d) => Map<String, dynamic>.from(d ?? {}));
        final still = ((check['list'] as List<dynamic>?) ?? [])
            .where((u) =>
                (u as Map)['email'].toString().toLowerCase() == testEmail)
            .toList();
        expect(still, isEmpty,
            reason: 'cleanup must physically remove the temp user');
        await setToken('');
      } catch (e) {
        fail('CLEANUP FAILED — manual removal required for $testEmail: $e');
      }
    }
  });
}

Future<List<String>> _starIds(EmailApi api) async {
  final page = await api.starList();
  return ((page['list'] as List<dynamic>?) ?? [])
      .map((e) => (e as Map)['emailId'].toString())
      .toList();
}

Future<Map<String, dynamic>> _fetchRow(
    EmailApi api, String emailId, String accountId) async {
  final page = await api.list(accountId: accountId);
  final rows = ((page['list'] as List<dynamic>?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  return rows.firstWhere((r) => r['emailId'].toString() == emailId,
      orElse: () => rows.first);
}

// Silence dart:io import if unused on some platforms (env override hook).
// ignore: unused_element
final _ = Platform.environment;
