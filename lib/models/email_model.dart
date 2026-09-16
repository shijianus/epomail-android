import 'dart:convert';

/// Email data model — aligned 1:1 with the epomail web backend
/// (mail-worker/src/entity/email.js + email-service.list response).
///
/// Backend contract notes:
/// - `unread`: 0 = UNREAD, 1 = READ (emailConst.unread)
/// - `type`:   0 = RECEIVE (inbox), 1 = SEND (sent); trash/spam/snoozed are
///             queried via the `folder` param, not `type`.
/// - `cc` / `labels` arrive as JSON-encoded strings.
/// - `attList` is attached server-side by emailAddAtt (attachments rows).
/// - `isStar` / `isOfficial` are computed server-side (1/0).
class EmailModel {
  final String emailId;
  final String accountId;
  final String from; // backend `sendEmail`
  final String fromName; // backend `name`
  final String toEmail; // backend `toEmail` (comma separated)
  final String toName; // backend `toName`
  final List<String> to;
  final List<String> cc;
  final String subject;
  final String content; // HTML
  final String? textBody; // backend `text`
  final String createTime;
  final bool isRead; // derived: unread == 1
  final bool isStar;
  final int type; // 0=inbox 1=sent
  final int status; // 6 = SAVING (draft marker server-side)
  final bool isSpam;
  final bool isDel;
  final bool isOfficial;
  final int expireDays;
  final String? code; // AI-extracted verification code
  final String? size;
  final List<String> labels;
  final String? snoozedTime;
  final List<AttachmentModel> attList;

  const EmailModel({
    required this.emailId,
    required this.accountId,
    required this.from,
    required this.fromName,
    this.toEmail = '',
    this.toName = '',
    this.to = const [],
    this.cc = const [],
    required this.subject,
    required this.content,
    this.textBody,
    required this.createTime,
    required this.isRead,
    required this.isStar,
    required this.type,
    this.status = 0,
    this.isSpam = false,
    this.isDel = false,
    this.isOfficial = false,
    this.expireDays = 0,
    this.code,
    this.size,
    this.labels = const [],
    this.snoozedTime,
    this.attList = const [],
  });

  factory EmailModel.fromJson(Map<String, dynamic> j) {
    final unread = (j['unread'] as num?)?.toInt() ?? 1;
    return EmailModel(
      emailId: j['emailId']?.toString() ?? '',
      accountId: j['accountId']?.toString() ?? '',
      from: j['sendEmail']?.toString() ?? '',
      fromName: j['name']?.toString() ?? '',
      toEmail: j['toEmail']?.toString() ?? '',
      toName: j['toName']?.toString() ?? '',
      to: _splitEmails(j['toEmail']),
      cc: _parseJsonStringList(j['cc']),
      subject: j['subject']?.toString() ?? '',
      content: j['content']?.toString() ?? '',
      textBody: j['text']?.toString(),
      createTime: j['createTime']?.toString() ?? '',
      isRead: unread == 1,
      isStar: j['isStar'] == 1 || j['isStar'] == true,
      type: (j['type'] as num?)?.toInt() ?? 0,
      status: (j['status'] as num?)?.toInt() ?? 0,
      isSpam: j['isSpam'] == 1 || j['isSpam'] == true,
      isDel: j['isDel'] == 1 || j['isDel'] == true,
      isOfficial: j['isOfficial'] == 1 || j['isOfficial'] == true,
      expireDays: (j['expireDays'] as num?)?.toInt() ?? 0,
      code: j['code']?.toString(),
      size: j['size']?.toString(),
      labels: _parseJsonStringList(j['labels']),
      snoozedTime: j['snoozedTime']?.toString(),
      attList: ((j['attList'] as List<dynamic>?) ?? [])
          .map((e) => AttachmentModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  EmailModel copyWith({
    bool? isRead,
    bool? isStar,
    bool? isSpam,
    bool? isDel,
    List<String>? labels,
    String? content,
    String? snoozedTime,
  }) =>
      EmailModel(
        emailId: emailId,
        accountId: accountId,
        from: from,
        fromName: fromName,
        toEmail: toEmail,
        toName: toName,
        to: to,
        cc: cc,
        subject: subject,
        content: content ?? this.content,
        textBody: textBody,
        createTime: createTime,
        isRead: isRead ?? this.isRead,
        isStar: isStar ?? this.isStar,
        type: type,
        status: status,
        isSpam: isSpam ?? this.isSpam,
        isDel: isDel ?? this.isDel,
        isOfficial: isOfficial,
        expireDays: expireDays,
        code: code,
        size: size,
        labels: labels ?? this.labels,
        snoozedTime: snoozedTime ?? this.snoozedTime,
        attList: attList,
      );

  // ─── Helpers ─────────────────────────────────────────────────────────────

  bool get hasAttachments => attList.isNotEmpty;
  bool get hasCode => code?.isNotEmpty == true;
  bool get isSnoozed => snoozedTime != null && snoozedTime!.isNotEmpty;
  bool get isDraft => status == 6;

  String get previewText {
    if (textBody?.isNotEmpty == true) return textBody!;
    return content
        .replaceAll(
            RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// In sent folder the counterpart is the recipient; otherwise the sender.
  String get correspondentLabel {
    if (type == 1) {
      final first = to.isNotEmpty ? to.first : toEmail;
      return toName.isNotEmpty ? toName : first;
    }
    return fromName.isNotEmpty ? fromName : from;
  }

  String get correspondentAddress => type == 1 ? toEmail : from;

  String get senderInitials {
    final s = correspondentLabel;
    if (s.isEmpty) return '?';
    final parts = s.trim().split(RegExp(r'[\s@.]+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return s[0].toUpperCase();
  }

  static List<String> _splitEmails(dynamic v) {
    if (v == null) return const [];
    if (v is List) return v.map((e) => e.toString()).toList();
    final s = v.toString().trim();
    if (s.isEmpty) return const [];
    return s
        .split(RegExp(r'[,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<String> _parseJsonStringList(dynamic v) {
    if (v == null) return const [];
    if (v is List)
      return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    final s = v.toString().trim();
    if (s.isEmpty || s == '[]') return const [];
    try {
      final decoded = jsonDecode(s);
      if (decoded is List)
        return decoded
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
    } catch (_) {}
    return const [];
  }
}

/// Attachment row — backend `attachments` table (mail-worker/src/entity/att.js).
class AttachmentModel {
  final String attId;
  final String filename;
  final String key; // storage key → download URL
  final String? mimeType;
  final int size;

  const AttachmentModel({
    required this.attId,
    required this.filename,
    required this.key,
    this.mimeType,
    this.size = 0,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> j) => AttachmentModel(
        attId: j['attId']?.toString() ?? '',
        filename: j['filename']?.toString() ?? 'attachment',
        key: j['key']?.toString() ?? '',
        mimeType: j['mimeType']?.toString(),
        size: (j['size'] as num?)?.toInt() ?? 0,
      );

  String get sizeLabel {
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Paginated email list result — backend `{ list, total, latestEmail }`.
class EmailListResult {
  final List<EmailModel> list;
  final int total;

  const EmailListResult({required this.list, required this.total});

  factory EmailListResult.fromJson(Map<String, dynamic> j) {
    final raw = (j['list'] as List<dynamic>?) ?? [];
    return EmailListResult(
      list: raw
          .map((e) => EmailModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: (j['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// AI translation result — backend POST /email/translate.
class TranslateResult {
  final String translatedText;
  final String translatedHtml;
  final bool isHtml;
  final String? model;

  const TranslateResult({
    required this.translatedText,
    required this.translatedHtml,
    required this.isHtml,
    this.model,
  });

  factory TranslateResult.fromJson(Map<String, dynamic> j) => TranslateResult(
        translatedText: j['translatedText']?.toString() ?? '',
        translatedHtml: j['translatedHtml']?.toString() ?? '',
        isHtml: j['isHtml'] == true || j['isHtml'] == 1,
        model: j['model']?.toString(),
      );
}
