import 'package:flutter/foundation.dart';
import '../api/email_api.dart';
import '../models/email_model.dart';

enum MailFolder { inbox, all, sent, drafts, spam, trash, starred }

extension MailFolderExt on MailFolder {
  String get label {
    switch (this) {
      case MailFolder.inbox: return 'Inbox';
      case MailFolder.all: return 'All Mail';
      case MailFolder.sent: return 'Sent';
      case MailFolder.drafts: return 'Drafts';
      case MailFolder.spam: return 'Spam';
      case MailFolder.trash: return 'Trash';
      case MailFolder.starred: return 'Starred';
    }
  }

  int? get apiType {
    switch (this) {
      case MailFolder.inbox: return 0;
      case MailFolder.sent: return 1;
      case MailFolder.drafts: return 2;
      case MailFolder.trash: return 3;
      case MailFolder.spam: return 4;
      default: return null;
    }
  }
}

class EmailProvider extends ChangeNotifier {
  final _api = EmailApi();

  // ─── State ───────────────────────────────────────────────────────────────
  MailFolder _folder = MailFolder.inbox;
  List<EmailModel> _emails = [];
  int _total = 0;
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _keyword;
  EmailModel? _selected;

  // ─── Getters ─────────────────────────────────────────────────────────────
  MailFolder get folder => _folder;
  List<EmailModel> get emails => _emails;
  int get total => _total;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get keyword => _keyword;
  EmailModel? get selected => _selected;

  // ─── Load / refresh ──────────────────────────────────────────────────────

  Future<void> load({
    required String accountId,
    MailFolder? folder,
    String? keyword,
    bool refresh = false,
  }) async {
    if (refresh) {
      _page = 1;
      _emails = [];
      _hasMore = true;
      _total = 0;
    }
    if (_loading || (!_hasMore && !refresh)) return;

    if (folder != null) _folder = folder;
    _keyword = keyword;
    _loading = true;
    notifyListeners();

    try {
      EmailListResult result;
      if (_folder == MailFolder.starred) {
        final raw = await _api.starList(accountId: accountId, page: _page);
        result = EmailListResult.fromJson(raw);
      } else {
        final raw = await _api.list(
          accountId: accountId,
          type: _folder.apiType,
          allReceive: _folder == MailFolder.all,
          keyword: _keyword,
          page: _page,
        );
        result = EmailListResult.fromJson(raw);
      }
      _emails = [..._emails, ...result.list];
      _total = result.total;
      _hasMore = _emails.length < _total;
      _page++;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore(String accountId) async {
    if (_loadingMore || !_hasMore) return;
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

  // ─── Email actions ───────────────────────────────────────────────────────

  Future<void> markRead(String emailId) async {
    await _api.markRead([emailId]);
    _update(emailId, (e) => e.copyWith(isRead: true));
  }

  Future<void> toggleStar(EmailModel email, String accountId) async {
    if (email.isStar) {
      await _api.removeStar(email.emailId, accountId);
    } else {
      await _api.addStar(email.emailId, accountId);
    }
    final newStar = !email.isStar;
    _update(email.emailId, (e) => e.copyWith(isStar: newStar));
    if (_selected?.emailId == email.emailId) {
      _selected = _selected!.copyWith(isStar: newStar);
    }
  }

  Future<void> deleteEmail(String emailId, String accountId) async {
    await _api.delete(emailIds: [emailId], accountId: accountId, logic: true);
    _remove(emailId);
  }

  Future<void> permanentDelete(String emailId, String accountId) async {
    await _api.delete(emailIds: [emailId], accountId: accountId, logic: false);
    _remove(emailId);
  }

  Future<void> markSpam(String emailId, String accountId) async {
    await _api.markSpam([emailId], accountId);
    _remove(emailId);
  }

  Future<void> restore(String emailId, String accountId) async {
    await _api.restore([emailId], accountId);
    _remove(emailId);
  }

  Future<void> send({
    required String accountId,
    required List<String> to,
    List<String> cc = const [],
    List<String> bcc = const [],
    required String subject,
    required String content,
  }) =>
      _api.send(
        accountId: accountId,
        to: to,
        cc: cc,
        bcc: bcc,
        subject: subject,
        content: content,
      );

  // ─── Selection ───────────────────────────────────────────────────────────

  void select(EmailModel? email) {
    _selected = email;
    notifyListeners();
  }

  void clear() {
    _emails = [];
    _total = 0;
    _page = 1;
    _hasMore = true;
    _keyword = null;
    _selected = null;
    _folder = MailFolder.inbox;
    notifyListeners();
  }

  // ─── Internal helpers ────────────────────────────────────────────────────

  void _update(String id, EmailModel Function(EmailModel) fn) {
    _emails = _emails.map((e) => e.emailId == id ? fn(e) : e).toList();
    notifyListeners();
  }

  void _remove(String id) {
    _emails = _emails.where((e) => e.emailId != id).toList();
    if (_total > 0) _total--;
    if (_selected?.emailId == id) _selected = null;
    notifyListeners();
  }
}
