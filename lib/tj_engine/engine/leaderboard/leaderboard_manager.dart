import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'leaderboard_entry.dart';

class LeaderboardManager {
  static const _storageKey = 'tj_leaderboard_v1';
  static const int maxEntries = 10;

  List<LeaderboardEntry> _entries = [];

  List<LeaderboardEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null) {
      _entries = [];
      return;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List<dynamic>) {
        throw const FormatException(
          'Leaderboard data must be a JSON list.',
        );
      }

      _entries = decoded
          .map(
            (entry) => LeaderboardEntry.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();

      _sortAndTrim();
    } catch (_) {
      // Corrupt leaderboard data must never prevent app startup.
      _entries = [];
      await prefs.remove(_storageKey);
    }
  }

  Future<int?> submit(LeaderboardEntry entry) async {
    _entries.add(entry);
    _entries.sort((a, b) => b.score.compareTo(a.score));

    final placement = _entries.indexOf(entry);

    if (placement < 0 || placement >= maxEntries) {
      _entries.remove(entry);
      _sortAndTrim();
      return null;
    }

    _sortAndTrim();
    await _persist();

    return placement + 1; // 1-based ranking for UI
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _entries.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_storageKey, encoded);
  }

  void _sortAndTrim() {
    _entries.sort((a, b) => b.score.compareTo(a.score));
    if (_entries.length > maxEntries) {
      _entries = _entries.take(maxEntries).toList();
    }
  }
}
