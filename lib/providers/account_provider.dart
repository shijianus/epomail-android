import 'package:flutter/foundation.dart';
import '../api/account_api.dart';
import '../api/email_api.dart';
import '../models/user_model.dart';

class AccountProvider extends ChangeNotifier {
  final _accountApi = AccountApi();
  final _emailApi = EmailApi();

  List<AccountModel> _accounts = [];
  AccountModel? _current;
  SidebarStats _stats = const SidebarStats();
  bool _loading = false;

  List<AccountModel> get accounts => _accounts;
  AccountModel? get current => _current;
  SidebarStats get stats => _stats;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final raw = await _accountApi.list();
      _accounts = raw
          .map((e) => AccountModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (_current == null && _accounts.isNotEmpty) {
        _current = _accounts.first;
      } else if (_current != null) {
        final updated =
            _accounts.where((a) => a.accountId == _current!.accountId);
        _current = updated.isNotEmpty
            ? updated.first
            : (_accounts.isNotEmpty ? _accounts.first : null);
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshStats() async {
    try {
      final raw = await _emailApi.sidebarStats();
      _stats = SidebarStats.fromJson(raw);
      notifyListeners();
    } catch (_) {}
  }

  void select(AccountModel account) {
    _current = account;
    notifyListeners();
  }

  void clear() {
    _accounts = [];
    _current = null;
    _stats = const SidebarStats();
    notifyListeners();
  }

  Future<void> addAccount(String email) async {
    await _accountApi.add(email);
    await load();
  }

  Future<void> removeAccount(String accountId) async {
    await _accountApi.delete(accountId);
    await load();
  }

  Future<void> setAsTop(String accountId) async {
    await _accountApi.setAsTop(accountId);
    await load();
  }
}
