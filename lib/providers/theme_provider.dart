import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get themeMode => _mode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _mode = _parse(p.getString('theme_mode') ?? 'system');
    notifyListeners();
  }

  Future<void> set(ThemeMode m) async {
    _mode = m;
    final p = await SharedPreferences.getInstance();
    await p.setString('theme_mode', _serialize(m));
    notifyListeners();
  }

  /// Server profile is the single source of truth on login
  /// (mirrors mail-vue init: applyUserInfo overrides local ui store).
  void applyServer(String? mode) {
    final m = _parse(mode ?? 'system');
    if (m != _mode) {
      _mode = m;
      SharedPreferences.getInstance()
          .then((p) => p.setString('theme_mode', _serialize(m)));
      notifyListeners();
    }
  }

  ThemeMode _parse(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _serialize(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}
