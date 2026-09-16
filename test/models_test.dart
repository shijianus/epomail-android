import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:epomail/models/email_model.dart';
import 'package:epomail/models/user_model.dart';
import 'package:epomail/providers/email_provider.dart';

/// Model parsing tests — fixtures mirror the REAL epomail backend shapes
/// (mail-worker/src/entity/email.js, account.js, user-service.loginUserInfo,
/// email-service.getSidebarStats, storage-quota-service).
void main() {
  group('EmailModel (real backend row)', () {
    final welcomeEmail = {
      'emailId': 4096,
      'accountId': 7,
      'userId': 3,
      'sendEmail': 'admin@epocanvas.com',
      'name': 'EpoCanvas 官方',
      'toEmail': 'tester@epomail.bond',
      'toName': 'tester',
      'cc': '[]',
      'bcc': '[]',
      'subject': '欢迎来到 EpoCanvas Mail',
      'content': '<div dir="ltr">Welcome! This is your official guide...</div>',
      'text': 'Welcome! This is your official guide...',
      'code': '',
      'type': 0,
      'status': 0,
      'unread': 0, // 0 = UNREAD
      'createTime': '2026-09-15 10:00:00',
      'isDel': 0,
      'isSpam': 0,
      'labels': '["官方"]',
      'snoozedTime': null,
      'starId': 12,
      'isStar': 1,
      'isOfficial': 1,
      'expireDays': 7,
      'attList': [
        {
          'attId': 1,
          'filename': 'guide.pdf',
          'key': 'att/abc123.pdf',
          'mimeType': 'application/pdf',
          'size': 2048,
        }
      ],
    };

    test('parses real field names (sendEmail/name/toEmail, unread, type)', () {
      final m = EmailModel.fromJson(welcomeEmail);
      expect(m.emailId, '4096');
      expect(m.from, 'admin@epocanvas.com');
      expect(m.fromName, 'EpoCanvas 官方');
      expect(m.to, ['tester@epomail.bond']);
      expect(m.subject, contains('欢迎'));
      expect(m.isRead, isFalse, reason: 'unread=0 means UNREAD');
      expect(m.isStar, isTrue);
      expect(m.isOfficial, isTrue);
      expect(m.type, 0, reason: 'type 0 = receive/inbox');
      expect(m.labels, ['官方']);
      expect(m.hasAttachments, isTrue);
      expect(m.attList.first.filename, 'guide.pdf');
      expect(m.attList.first.sizeLabel, '2.0 KB');
    });

    test('sent row flips correspondent to recipient', () {
      final m = EmailModel.fromJson({
        ...welcomeEmail,
        'emailId': 5000,
        'type': 1,
        'sendEmail': 'tester@epomail.bond',
        'name': '',
        'toEmail': 'friend@example.com, other@example.com',
        'toName': '',
        'unread': 1,
      });
      expect(m.type, 1);
      expect(m.isRead, isTrue, reason: 'unread=1 means READ');
      expect(m.correspondentLabel, 'friend@example.com');
      expect(m.correspondentAddress, 'friend@example.com, other@example.com');
    });

    test('unread flag semantics match emailConst (0=unread, 1=read)', () {
      expect(
          EmailModel.fromJson({...welcomeEmail, 'unread': 0}).isRead, isFalse);
      expect(
          EmailModel.fromJson({...welcomeEmail, 'unread': 1}).isRead, isTrue);
    });

    test('status 6 marks a draft row', () {
      final m = EmailModel.fromJson({...welcomeEmail, 'status': 6});
      expect(m.isDraft, isTrue);
    });

    test('previewText strips html including style blocks', () {
      final m = EmailModel.fromJson({
        ...welcomeEmail,
        'text': '',
        'content': '<style>.x{color:red}</style><p>Hello   world</p>',
      });
      expect(m.previewText, 'Hello world');
    });
  });

  group('UserModel / loginUserInfo', () {
    test('parses single account object + permKeys + profile', () {
      final u = UserModel.fromJson({
        'userId': 3,
        'email': 'tester@epomail.bond',
        'type': 2,
        'name': 'tester',
        'nickname': 'Kevin',
        'avatarUrl': '',
        'account': {
          'accountId': 7,
          'email': 'tester@epomail.bond',
          'name': 'tester',
          'status': 0,
          'allReceive': 0,
          'sort': 0,
          'isDel': 0,
        },
        'permKeys': ['email:send', 'account:list-x'],
        'customLabels':
            '{"allLabels":[{"name":"工作","icon":"ic:outline-work-outline","color":"#8b5cf6","listVis":true,"stats":{"total":0,"current":0,"unread":0},"rules":[]}]}',
        'themeMode': 'dark',
        'lang': 'zh',
        'sendCount': 1,
        'totpEnabled': 0,
        'quota': {'maxStorageMb': 500},
      });
      expect(u.displayName, 'Kevin');
      expect(u.account?.accountId, '7');
      expect(u.isAdmin, isFalse);
      expect(u.customLabels.single.name, '工作');
      expect(u.themeMode, 'dark');
    });

    test('admin is wildcard permKeys', () {
      final u = UserModel.fromJson({
        'userId': 1,
        'email': 'admin@epomail.bond',
        'type': 0,
        'permKeys': ['*'],
      });
      expect(u.isAdmin, isTrue);
    });
  });

  group('SidebarStats (real SQL aliases)', () {
    test('maps unread counters and labelStats', () {
      final s = SidebarStats.fromJson({
        'inboxUnread': 3,
        'draftUnread': 0,
        'sentUnread': 1,
        'spamUnread': 2,
        'spamRead': 4,
        'trashUnread': 0,
        'trashRead': 1,
        'snoozedUrgent': 0,
        'snoozedWaiting': 5,
        'allUnread': 6,
        'labelStats': {
          '工作': {'unread': 2, 'read': 1},
        },
      });
      expect(s.inboxUnread, 3);
      expect(s.spamUnread, 2);
      expect(s.snoozedWaiting, 5);
      expect(s.labelUnread['工作'], 2);
    });
  });

  group('StorageUsage (/my/storage)', () {
    test('parses quota contract', () {
      final s = StorageUsage.fromJson({
        'userId': 3,
        'usedBytes': 1048576,
        'usedMb': '1.00',
        'quotaMb': 500,
        'quotaBytes': 524288000,
        'usedPercentage': 0,
        'isExceeded': false,
        'isVisitor': false,
        'roleCode': 'user_base',
        'fileCount': 2,
      });
      expect(s.usedMb, '1.00');
      expect(s.quotaMb, 500);
      expect(s.isVisitor, isFalse);
      expect(s.roleCode, 'user_base');
    });
  });

  group('EmailListResult', () {
    test('parses {list,total} envelope data', () {
      final r = EmailListResult.fromJson({
        'list': [
          {'emailId': 4096, 'sendEmail': 'a@b.c', 'unread': 0, 'type': 0}
        ],
        'total': 42,
        'latestEmail': {'emailId': 4096},
      });
      expect(r.total, 42);
      expect(r.list.single.emailId, '4096');
    });
  });

  group('LocalDraft json roundtrip', () {
    test('serializes and restores', () {
      final d = LocalDraft(
        id: '1',
        accountId: '7',
        accountEmail: 'x@y.z',
        to: 'a@b.c',
        subject: 'S',
        content: 'C',
        updatedAt: '2026-09-15T00:00:00.000',
      );
      final restored = LocalDraft.fromJson(
          jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
      expect(restored.content, 'C');
      expect(restored.accountEmail, 'x@y.z');
    });
  });
}
