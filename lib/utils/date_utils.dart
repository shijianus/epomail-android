import 'package:intl/intl.dart';

class EpoDate {
  static final _todayFmt = DateFormat('HH:mm');
  static final _thisYearFmt = DateFormat('MMM d');
  static final _fullFmt = DateFormat('MMM d, yyyy HH:mm');

  /// Short: "14:32" for today, "Jan 5" for this year, "Jan 5, 2025" otherwise.
  static String short(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      if (_sameDay(d, now)) return _todayFmt.format(d);
      if (d.year == now.year) return _thisYearFmt.format(d);
      return _fullFmt.format(d);
    } catch (_) {
      return raw;
    }
  }

  /// Full: "Jan 5, 2025 14:32"
  static String full(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      return _fullFmt.format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  /// Relative: "Just now", "5m ago", "3h ago", "2d ago"
  static String relative(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return short(raw);
    } catch (_) {
      return raw;
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
