import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/email_api.dart';
import '../models/email_model.dart';

/// Folders — mapped to the REAL backend query contract:
/// inbox  → type=0 (RECEIVE)
/// sent   → type=1 (SEND)
/// trash  → folder='trash' (isDel=1)
/// spam   → folder='spam'  (isSpam=1)
/// snoozed→ folder='snoozed'
/// all    → folder='all'   (all received mail, cross-account via allReceive)
/// starred→ /star/list
/// drafts → client-local (the web app keeps drafts in localStorage too).
enum MailFolder { inbox, all, sent, drafts, snoozed, spam, trash, starred }

extension MailFolderExt on MailFolder {
  String get label {
    switch (this) {
      case MailFolder.inbox:
        return 'Inbox';
      case MailFolder.all:
        return 'All Mail';
      case MailFolder.sent:
        return 'Sent';
      case MailFolder.drafts:
        return 'Drafts';
      case MailFolder.snoozed:
        return 'Snoozed';
      case MailFolder.spam:
        return 'Spam';
      case MailFolder.trash:
        return 'Trash';
      case MailFolder.starred:
        return 'Starred';
    }
  }

  int? get apiType {
    switch (this) {
      case MailFolder.inbox:
        return 0;
      case MailFolder.sent:
        return 1;
      default:
        return null;
    }
  }

  String? get apiFolder {
    switch (this) {
      case MailFolder.trash:
        return 'trash';
      case MailFolder.spam:
        return 'spam';
      case MailFolder.snoozed:
        return 'snoozed';
      case MailFolder.all:
        return 'all';
      default:
        return null;
    }
  }
}

class LocalDraft {
  final String id;
  final String accountId;
  final String accountEmail;
  final String to;
  final String subject;
  final String content;
  final String updatedAt;

  const LocalDraft({
    required this.id,
    required this.accountId,
    required this.accountEmail,
    required this.to,
    required this.subject,
    required this.content,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'accountEmail': accountEmail,
        'to': to,
        'subject': subject,
        'content': content,
        'updatedAt': updatedAt,
      };

  factory LocalDraft.fromJson(Map<String, dynamic> j) => LocalDraft(
        id: j['id']?.toString() ?? '',
        accountId: j['accountId']?.toString() ?? '',
        accountEmail: j['accountEmail']?.toString() ?? '',
        to: j['to']?.toString() ?? '',
        subject: j['subject']?.toString() ?? '',
        content: j['content']?.toString() ?? '',
        updatedAt: j['updatedAt']?.toString() ?? '',
      );
}

class EmailProvider extends ChangeNotifier {
  final _api = EmailApi();

  // ─── State ───────────────────────────────────────────────────────────────
  MailFolder _folder = MailFolder.inbox;
  List<EmailModel> _emails = [];
  int _total = 0;
  int? _cursor; // keyset pagination cursor (emailId)
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _keyword;
  String? _labelFilter; // when set, filter client-side by label
  EmailModel? _selected;

  List<LocalDraft> _drafts = [];

  // ─── Getters ─────────────────────────────────────────────────────────────
  MailFolder get folder => _folder;
  List<EmailModel> get emails => _labelFilter == null
      ? _emails
      : _emails.where((e) => e.labels.contains(_labelFilter)).toList();
  int get total => _total;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get keyword => _keyword;
  String? get labelFilter => _labelFilter;
  EmailModel? get selected => _selected;
  List<LocalDraft> get drafts => _drafts;

  // ─── Load / refresh (cursor pagination) ──────────────────────────────────

  Future<void> load({
    required String accountId,
    MailFolder? folder,
    String? keyword,
    bool refresh = false,
  }) async {
    if (refresh) {
      _emails = [];
      _hasMore = true;
      _total = 0;
      _cursor = null;
    }
    if (_loading || (!_hasMore && !refresh)) return;

    if (folder != null) _folder = folder;
    _keyword = keyword;
    _loading = true;
    notifyListeners();

    try {
      if (_folder == MailFolder.drafts) {
        await _loadLocalDrafts();
        _total = _drafts.length;
        _hasMore = false;
      } else if (_folder == MailFolder.starred) {
        final raw = await _api.starList(
          cursorEmailId: _cursor?.toString(),
          keyword: _keyword,
        );
        final result = EmailListResult.fromJson(raw);
        _mergePage(result);
      } else {
        final raw = await _api.list(
          accountId: accountId,
          type: _folder.apiType,
          folder: _folder.apiFolder,
          allReceive: _folder == MailFolder.all,
          keyword: _keyword,
          cursorEmailId: _cursor,
        );
        final result = EmailListResult.fromJson(raw);
        _mergePage(result);
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _mergePage(EmailListResult result) {
    final known = _emails.map((e) => e.emailId).toSet();
    final fresh = result.list.where((e) => !known.contains(e.emailId)).toList();
    _emails = [..._emails, ...fresh];
    _total = result.total;
    if (_emails.isNotEmpty) {
      _cursor = int.tryParse(_emails.last.emailId);
    }
    _hasMore = _emails.length < _total && fresh.isNotEmpty;
  }

  Future<void> loadMore(String accountId) async {
    if (_loadingMore || !_hasMore || _loading) return;
    _loadingMore = true;
    notifyListeners();
    try {
      await load(accountId: accountId);
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String accountId) =>
      load(accountId: accountId, refresh: true);

  void setLabelFilter(String? label) {
    _labelFilter = (label?.isNotEmpty == true) ? label : null;
    notifyListeners();
  }

  // ─── Email actions ───────────────────────────────────────────────────────

  Future<void> markRead(String emailId) async {
    await _api.markRead([emailId], unread: true); // 1 = READ
    _update(emailId, (e) => e.copyWith(isRead: true));
  }

  Future<void> markUnread(String emailId) async {
    await _api.markRead([emailId], unread: false); // 0 = UNREAD
    _update(emailId, (e) => e.copyWith(isRead: false));
  }

  Future<void> toggleStar(EmailModel email) async {
    if (email.isStar) {
      await _api.removeStar(email.emailId);
    } else {
      await _api.addStar(email.emailId);
    }
    final newStar = !email.isStar;
    _update(email.emailId, (e) => e.copyWith(isStar: newStar));
    if (_selected?.emailId == email.emailId) {
      _selected = _selected!.copyWith(isStar: newStar);
    }
    notifyListeners();
  }

  /// Move to trash (logic delete, isDel=1).
  Future<void> deleteEmail(String emailId) async {
    await _api.delete(emailIds: [emailId], physical: false);
    _remove(emailId);
  }

  /// Physical delete from trash.
  Future<void> permanentDelete(String emailId) async {
    await _api.delete(emailIds: [emailId], physical: true);
    _remove(emailId);
  }

  /// PUT /email/spam — plain move in/out of spam folder.
  Future<void> setSpam(String emailId, bool isSpam) async {
    await _api.setSpam([emailId], isSpam);
    _remove(emailId);
  }

  /// PUT /email/reportSpam — spam + personal blacklist rule for the sender.
  Future<void> reportSpam(String emailId) async {
    await _api.reportSpam([emailId]);
    _remove(emailId);
  }

  /// PUT /email/reportNotSpam — back to inbox + remove blacklist rule.
  Future<void> reportNotSpam(String emailId) async {
    await _api.reportNotSpam([emailId]);
    _remove(emailId);
  }

  /// PUT /email/restore — trash back to inbox.
  Future<void> restore(String emailId) async {
    await _api.restore([emailId]);
    _remove(emailId);
  }

  Future<void> snooze(String emailId, String time, String endTime) async {
    await _api.snooze([emailId], time, endTime);
    _update(emailId, (e) => e.copyWith(snoozedTime: time));
  }

  Future<void> unsnooze(String emailId) async {
    await _api.unsnooze([emailId]);
    _update(emailId, (e) => e.copyWith(snoozedTime: ''));
  }

  Future<void> setLabels(String emailId, List<String> labels) async {
    await _api.setLabels(emailId, labels);
    _update(emailId, (e) => e.copyWith(labels: labels));
  }

  Future<TranslateResult> translate(EmailModel email, String targetLang) async {
    final raw = await _api.translate(
      text: email.content.isEmpty ? email.previewText : null,
      html: email.content.isEmpty ? null : email.content,
      targetLang: targetLang,
    );
    return TranslateResult.fromJson(raw);
  }

  Future<void> send({
    required String accountId,
    String? accountName,
    required List<String> receiveEmail,
    required String subject,
    required String content,
    List<Map<String, dynamic>> attachments = const [],
  }) =>
      _api.send(
        accountId: accountId,
        name: accountName ?? '',
        receiveEmail: receiveEmail,
        subject: subject,
        content: content,
        attachments: attachments,
      );

  // ─── Local drafts (web keeps drafts client-side as well) ────────────────

  // Drafts are stored per signed-in user so accounts sharing a device never
  // see each other's drafts.
  String _owner = '';
  Set<String> _addresses = {};
  static const _legacyDraftsKey = 'local_drafts';
  String get _draftsKey => 'local_drafts:$_owner';

  /// Sets the signed-in user (email) owning the local drafts.
  /// [addresses] are the user's own mailboxes (aliases included).
  void setOwner(String owner, {Iterable<String> addresses = const []}) {
    final next = owner.trim().toLowerCase();
    _addresses = {next, ...addresses.map((a) => a.trim().toLowerCase())}
      ..remove('');
    if (next == _owner) return;
    _owner = next;
    _drafts = [];
  }

  /// Drafts saved by versions <= 1.1.0 lived under one shared key; hand each
  /// one to the user who owns the address that wrote it.
  Future<void> _adoptLegacyDrafts(SharedPreferences prefs) async {
    final raw = prefs.getString(_legacyDraftsKey);
    if (raw == null || _owner.isEmpty) return;
    try {
      final all = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      bool mine(Map<String, dynamic> d) =>
          _addresses.contains(d['accountEmail']?.toString().toLowerCase());
      final adopted = all.where(mine).toList();
      if (adopted.isEmpty) return;
      final existing =
          jsonDecode(prefs.getString(_draftsKey) ?? '[]') as List<dynamic>;
      await prefs.setString(_draftsKey, jsonEncode([...existing, ...adopted]));
      final rest = all.where((d) => !mine(d)).toList();
      if (rest.isEmpty) {
        await prefs.remove(_legacyDraftsKey);
      } else {
        await prefs.setString(_legacyDraftsKey, jsonEncode(rest));
      }
    } catch (_) {
      await prefs.remove(_legacyDraftsKey);
    }
  }

  Future<void> _loadLocalDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    if (_owner.isEmpty) {
      _drafts = [];
      return;
    }
    await _adoptLegacyDrafts(prefs);
    final raw = prefs.getString(_draftsKey) ?? '[]';
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => LocalDraft.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _drafts = list;
    } catch (_) {
      _drafts = [];
    }
  }

  Future<void> saveDraft(LocalDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await _loadLocalDrafts();
    final idx = _drafts.indexWhere((d) => d.id == draft.id);
    if (idx >= 0) {
      _drafts[idx] = draft;
    } else {
      _drafts.insert(0, draft);
    }
    if (_owner.isEmpty) return;
    await prefs.setString(
        _draftsKey, jsonEncode(_drafts.map((d) => d.toJson()).toList()));
    notifyListeners();
  }

  Future<void> deleteDraft(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await _loadLocalDrafts();
    _drafts.removeWhere((d) => d.id == id);
    if (_owner.isEmpty) return;
    await prefs.setString(
        _draftsKey, jsonEncode(_drafts.map((d) => d.toJson()).toList()));
    notifyListeners();
  }

  // ─── Selection ───────────────────────────────────────────────────────────

  void select(EmailModel? email) {
    _selected = email;
    notifyListeners();
  }

  void clear() {
    _emails = [];
    _total = 0;
    _cursor = null;
    _hasMore = true;
    _keyword = null;
    _labelFilter = null;
    _selected = null;
    _folder = MailFolder.inbox;
    _drafts = [];
    _owner = '';
    _addresses = {};
    _loading = false;
    _loadingMore = false;
    notifyListeners();
  }

  // ─── Internal helpers ────────────────────────────────────────────────────

  void _update(String id, EmailModel Function(EmailModel) fn) {
    _emails = _emails.map((e) => e.emailId == id ? fn(e) : e).toList();
    if (_selected?.emailId == id) {
      _selected = fn(_selected!);
    }
    notifyListeners();
  }

  void _remove(String id) {
    _emails = _emails.where((e) => e.emailId != id).toList();
    if (_total > 0) _total--;
    if (_selected?.emailId == id) _selected = null;
    notifyListeners();
  }
}
