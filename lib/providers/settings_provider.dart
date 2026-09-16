import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  int _refreshInterval = 30; // seconds, 0 = manual only
  int get refreshInterval => _refreshInterval;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _refreshInterval = p.getInt('refresh_interval') ?? 30;
  }

  Future<void> setRefreshInterval(int seconds) async {
    _refreshInterval = seconds;
    final p = await SharedPreferences.getInstance();
    await p.setInt('refresh_interval', seconds);
    notifyListeners();
  }
}
