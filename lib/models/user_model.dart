import 'dart:convert';

/// User model — aligned with backend GET /my/loginUserInfo
/// (mail-worker/src/service/user-service.js loginUserInfo).
class UserModel {
  final int userId;
  final String email;
  final int type; // role id; master role / admin resolves server-side
  final String name; // display name from the primary account
  final String? nickname;
  final String? avatarUrl;
  final AccountModel? account; // backend returns the primary account object
  final bool totpEnabled;
  final String? createTime;
  final List<String> permKeys; // ['*'] for the admin
  final List<CustomLabel> customLabels;
  final String themeMode; // 'auto' | 'light' | 'dark'
  final String lang; // '' | 'zh' | 'en' ...
  final int sendCount;
  final Map<String, dynamic> quota;

  const UserModel({
    required this.userId,
    required this.email,
    required this.type,
    this.name = '',
    this.nickname,
    this.avatarUrl,
    this.account,
    this.totpEnabled = false,
    this.createTime,
    this.permKeys = const [],
    this.customLabels = const [],
    this.themeMode = 'auto',
    this.lang = '',
    this.sendCount = 0,
    this.quota = const {},
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        userId: (j['userId'] as num?)?.toInt() ?? 0,
        email: j['email']?.toString() ?? '',
        type: (j['type'] as num?)?.toInt() ?? 1,
        name: j['name']?.toString() ?? '',
        nickname: j['nickname']?.toString(),
        avatarUrl: j['avatarUrl']?.toString(),
        account: j['account'] is Map<String, dynamic>
            ? AccountModel.fromJson(j['account'] as Map<String, dynamic>)
            : null,
        totpEnabled: j['totpEnabled'] == 1 || j['totpEnabled'] == true,
        createTime: j['createTime']?.toString(),
        permKeys: ((j['permKeys'] as List<dynamic>?) ?? [])
            .map((e) => e.toString())
            .toList(),
        customLabels: _parseCustomLabels(j['customLabels']),
        themeMode: j['themeMode']?.toString() ?? 'auto',
        lang: j['lang']?.toString() ?? '',
        sendCount: (j['sendCount'] as num?)?.toInt() ?? 0,
        quota: j['quota'] is Map<String, dynamic>
            ? j['quota'] as Map<String, dynamic>
            : const {},
      );

  /// Admin is signalled by the wildcard permission key (server-side).
  bool get isAdmin => permKeys.contains('*');

  String get displayName {
    if (nickname?.isNotEmpty == true) return nickname!;
    if (name.isNotEmpty) return name;
    return email.split('@').first;
  }

  String get initials {
    final s = displayName;
    if (s.isEmpty) return '?';
    final parts = s.trim().split(RegExp(r'[\s@.]+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return s[0].toUpperCase();
  }

  static List<CustomLabel> _parseCustomLabels(dynamic v) {
    if (v == null) return const [];
    List<dynamic>? decoded;
    if (v is List) {
      decoded = v;
    } else {
      final s = v.toString().trim();
      if (s.isEmpty || s == '[]') return const [];
      try {
        final parsed = jsonDecode(s);
        if (parsed is Map<String, dynamic>) {
          decoded = parsed['allLabels'] as List<dynamic>?;
        } else if (parsed is List) {
          decoded = parsed;
        }
      } catch (_) {
        return const [];
      }
    }
    if (decoded == null) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map((e) => CustomLabel.fromJson(e))
        .toList();
  }
}

/// Custom label definition from `user.customLabels.allLabels`.
class CustomLabel {
  final String name;
  final String icon;
  final String color;

  const CustomLabel(
      {required this.name, this.icon = '', this.color = '#3b82f6'});

  factory CustomLabel.fromJson(Map<String, dynamic> j) => CustomLabel(
        name: j['name']?.toString() ?? '',
        icon: j['icon']?.toString() ?? '',
        color: j['color']?.toString() ?? '#3b82f6',
      );
}

/// Email account (alias) row — backend `account` table.
/// Note: the backend row has no unreadCount / isTop fields.
class AccountModel {
  final String accountId;
  final String email;
  final String? name;
  final bool allReceive;
  final int sort;
  final String? latestEmailTime;

  const AccountModel({
    required this.accountId,
    required this.email,
    this.name,
    this.allReceive = false,
    this.sort = 0,
    this.latestEmailTime,
  });

  factory AccountModel.fromJson(Map<String, dynamic> j) => AccountModel(
        accountId: j['accountId']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        name: j['name']?.toString(),
        allReceive: j['allReceive'] == 1 || j['allReceive'] == true,
        sort: (j['sort'] as num?)?.toInt() ?? 0,
        latestEmailTime: j['latestEmailTime']?.toString(),
      );

  String get displayLabel =>
      name?.isNotEmpty == true ? name! : email.split('@').first;
  String get shortEmail => email;
  String get initials =>
      displayLabel.isNotEmpty ? displayLabel[0].toUpperCase() : '?';
}

/// Sidebar counters — backend GET /email/sidebarStats.
/// Key contract: `unread = 0` means UNREAD, so the *Unread columns count
/// unread messages (see email-service.getSidebarStats SQL).
class SidebarStats {
  final int inboxUnread;
  final int draftUnread;
  final int sentUnread;
  final int spamUnread;
  final int trashUnread;
  final int allUnread;
  final int snoozedUrgent;
  final int snoozedWaiting;
  final Map<String, int> labelUnread;

  const SidebarStats({
    this.inboxUnread = 0,
    this.draftUnread = 0,
    this.sentUnread = 0,
    this.spamUnread = 0,
    this.trashUnread = 0,
    this.allUnread = 0,
    this.snoozedUrgent = 0,
    this.snoozedWaiting = 0,
    this.labelUnread = const {},
  });

  factory SidebarStats.fromJson(Map<String, dynamic> j) {
    int n(String key) => (j[key] as num?)?.toInt() ?? 0;
    final labelStats = j['labelStats'];
    final labelUnread = <String, int>{};
    if (labelStats is Map<String, dynamic>) {
      labelStats.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          labelUnread[k] = (v['unread'] as num?)?.toInt() ?? 0;
        }
      });
    }
    return SidebarStats(
      inboxUnread: n('inboxUnread'),
      draftUnread: n('draftUnread'),
      sentUnread: n('sentUnread'),
      spamUnread: n('spamUnread'),
      trashUnread: n('trashUnread'),
      allUnread: n('allUnread'),
      snoozedUrgent: n('snoozedUrgent'),
      snoozedWaiting: n('snoozedWaiting'),
      labelUnread: labelUnread,
    );
  }
}

/// Storage usage — backend GET /my/storage (storage-quota-service).
class StorageUsage {
  final int usedBytes;
  final String usedMb;
  final int quotaMb;
  final int usedPercentage;
  final bool isExceeded;
  final bool isVisitor;
  final String roleCode;
  final int fileCount;

  const StorageUsage({
    this.usedBytes = 0,
    this.usedMb = '0.00',
    this.quotaMb = 0,
    this.usedPercentage = 0,
    this.isExceeded = false,
    this.isVisitor = false,
    this.roleCode = '',
    this.fileCount = 0,
  });

  factory StorageUsage.fromJson(Map<String, dynamic> j) => StorageUsage(
        usedBytes: (j['usedBytes'] as num?)?.toInt() ?? 0,
        usedMb: j['usedMb']?.toString() ?? '0.00',
        quotaMb: (j['quotaMb'] as num?)?.toInt() ?? 0,
        usedPercentage: (j['usedPercentage'] as num?)?.toInt() ?? 0,
        isExceeded: j['isExceeded'] == true || j['isExceeded'] == 1,
        isVisitor: j['isVisitor'] == true || j['isVisitor'] == 1,
        roleCode: j['roleCode']?.toString() ?? '',
        fileCount: (j['fileCount'] as num?)?.toInt() ?? 0,
      );
}
