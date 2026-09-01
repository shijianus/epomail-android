class UserModel {
  final int userId;
  final String email;
  final int type;    // 99 = admin
  final int status;
  final String? nickname;
  final String? avatar;
  final List<AccountModel> accounts;
  final bool totpEnabled;
  final String? createTime;

  const UserModel({
    required this.userId,
    required this.email,
    required this.type,
    required this.status,
    this.nickname,
    this.avatar,
    this.accounts = const [],
    this.totpEnabled = false,
    this.createTime,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        userId: (j['userId'] as num?)?.toInt() ?? 0,
        email: j['email']?.toString() ?? '',
        type: (j['type'] as num?)?.toInt() ?? 1,
        status: (j['status'] as num?)?.toInt() ?? 0,
        nickname: j['nickname']?.toString(),
        avatar: j['avatar']?.toString(),
        accounts: ((j['accounts'] as List<dynamic>?) ?? [])
            .map((a) => AccountModel.fromJson(Map<String, dynamic>.from(a)))
            .toList(),
        totpEnabled: j['totpEnabled'] == 1 || j['totpEnabled'] == true,
        createTime: j['createTime']?.toString(),
      );

  bool get isAdmin => type == 99;
  String get displayName => nickname?.isNotEmpty == true ? nickname! : email;
  String get initials {
    final s = nickname?.isNotEmpty == true ? nickname! : email;
    final parts = s.trim().split(RegExp(r'[\s@.]+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return s.isNotEmpty ? s[0].toUpperCase() : '?';
  }
}

class AccountModel {
  final String accountId;
  final String email;
  final String? name;
  final bool allReceive;
  final int unreadCount;
  final bool isTop;

  const AccountModel({
    required this.accountId,
    required this.email,
    this.name,
    this.allReceive = false,
    this.unreadCount = 0,
    this.isTop = false,
  });

  factory AccountModel.fromJson(Map<String, dynamic> j) => AccountModel(
        accountId: j['accountId']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        name: j['name']?.toString(),
        allReceive: j['allReceive'] == 1 || j['allReceive'] == true,
        unreadCount: (j['unreadCount'] as num?)?.toInt() ?? 0,
        isTop: j['isTop'] == 1 || j['isTop'] == true,
      );

  String get displayLabel => name?.isNotEmpty == true ? name! : email.split('@').first;
  String get shortEmail => email;
  String get initials => displayLabel.isNotEmpty ? displayLabel[0].toUpperCase() : '?';
}

class SidebarStats {
  final int inbox;
  final int all;
  final int sent;
  final int draft;
  final int spam;
  final int trash;
  final int star;
  final int snoozed;

  const SidebarStats({
    this.inbox = 0, this.all = 0, this.sent = 0, this.draft = 0,
    this.spam = 0, this.trash = 0, this.star = 0, this.snoozed = 0,
  });

  factory SidebarStats.fromJson(Map<String, dynamic> j) => SidebarStats(
        inbox: (j['inbox'] as num?)?.toInt() ?? 0,
        all: (j['all'] as num?)?.toInt() ?? 0,
        sent: (j['sent'] as num?)?.toInt() ?? 0,
        draft: (j['draft'] as num?)?.toInt() ?? 0,
        spam: (j['spam'] as num?)?.toInt() ?? 0,
        trash: (j['trash'] as num?)?.toInt() ?? 0,
        star: (j['star'] as num?)?.toInt() ?? 0,
        snoozed: (j['snoozed'] as num?)?.toInt() ?? 0,
      );
}
