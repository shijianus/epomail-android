/// Email data model
class EmailModel {
  final String emailId;
  final String accountId;
  final String from;
  final String fromName;
  final List<String> to;
  final List<String> cc;
  final String subject;
  final String content;   // HTML
  final String? textBody; // Plain text preview
  final String createTime;
  final bool isRead;
  final bool isStar;
  final int type;         // 0=inbox 1=sent 2=draft 3=trash 4=spam
  final String? code;     // AI-extracted verification code
  final String? size;
  final List<dynamic>? attachments;

  const EmailModel({
    required this.emailId,
    required this.accountId,
    required this.from,
    required this.fromName,
    required this.to,
    this.cc = const [],
    required this.subject,
    required this.content,
    this.textBody,
    required this.createTime,
    required this.isRead,
    required this.isStar,
    required this.type,
    this.code,
    this.size,
    this.attachments,
  });

  factory EmailModel.fromJson(Map<String, dynamic> j) => EmailModel(
        emailId: j['emailId']?.toString() ?? '',
        accountId: j['accountId']?.toString() ?? '',
        from: j['from']?.toString() ?? '',
        fromName: j['fromName']?.toString().isNotEmpty == true
            ? j['fromName'].toString()
            : j['from']?.toString() ?? '',
        to: _parseStrList(j['to']),
        cc: _parseStrList(j['cc']),
        subject: j['subject']?.toString() ?? '(No Subject)',
        content: j['content']?.toString() ?? '',
        textBody: j['text']?.toString(),
        createTime: j['createTime']?.toString() ?? '',
        isRead: j['isRead'] == 1 || j['isRead'] == true,
        isStar: j['isStar'] == 1 || j['isStar'] == true,
        type: (j['type'] as num?)?.toInt() ?? 0,
        code: j['code']?.toString(),
        size: j['size']?.toString(),
        attachments: j['attachments'] as List<dynamic>?,
      );

  EmailModel copyWith({bool? isRead, bool? isStar}) => EmailModel(
        emailId: emailId,
        accountId: accountId,
        from: from,
        fromName: fromName,
        to: to,
        cc: cc,
        subject: subject,
        content: content,
        textBody: textBody,
        createTime: createTime,
        isRead: isRead ?? this.isRead,
        isStar: isStar ?? this.isStar,
        type: type,
        code: code,
        size: size,
        attachments: attachments,
      );

  // ─── Helpers ─────────────────────────────────────────────────────────────

  bool get hasAttachments => attachments?.isNotEmpty == true;
  bool get hasCode => code?.isNotEmpty == true;

  String get previewText {
    if (textBody?.isNotEmpty == true) return textBody!;
    // Strip HTML tags for preview
    return content
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String get senderLabel => fromName.isNotEmpty ? fromName : from;

  String get senderInitials {
    final s = senderLabel;
    if (s.isEmpty) return '?';
    final parts = s.trim().split(RegExp(r'[\s@.]+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return s[0].toUpperCase();
  }

  static List<String> _parseStrList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String) return v.isNotEmpty ? [v] : [];
    return [];
  }
}

/// Paginated email list result
class EmailListResult {
  final List<EmailModel> list;
  final int total;
  final int unreadCount;

  const EmailListResult({required this.list, required this.total, this.unreadCount = 0});

  factory EmailListResult.fromJson(Map<String, dynamic> j) {
    final raw = (j['list'] as List<dynamic>?) ?? [];
    return EmailListResult(
      list: raw.map((e) => EmailModel.fromJson(Map<String, dynamic>.from(e))).toList(),
      total: (j['total'] as num?)?.toInt() ?? 0,
      unreadCount: (j['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}
