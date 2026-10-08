import 'package:shared_preferences/shared_preferences.dart';

import '../domain/daily_challenge.dart';

/// Outcome of one daily attempt.
class DailyAttempt {
  const DailyAttempt({
    required this.key,
    required this.score,
    required this.stars,
    required this.completed,
  });

  final String key;
  final int score;
  final int stars;
  final bool completed;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'score': score,
        'stars': stars,
        'completed': completed,
      };

  static DailyAttempt? fromJson(Map<String, dynamic> json) {
    final key = json['key'] as String?;
    if (key == null) return null;
    return DailyAttempt(
      key: key,
      score: (json['score'] as num? ?? 0).toInt(),
      stars: (json['stars'] as num? ?? 0).toInt().clamp(0, 3),
      completed: json['completed'] as bool? ?? false,
    );
  }
}

/// Daily challenge history.
abstract interface class DailyChallengeRepository {
  /// Attempt recorded for [key], or `null`.
  DailyAttempt? attemptFor(String key);

  Future<void> recordAttempt(DailyAttempt attempt);

  /// Number of distinct days with a completed attempt.
  int completedCount();
}

/// `SharedPreferences`-backed history.
class LocalDailyChallengeRepository implements DailyChallengeRepository {
  LocalDailyChallengeRepository(this._prefs);

  static const String _key = 'daily.history.v1';

  final SharedPreferences _prefs;

  @override
  DailyAttempt? attemptFor(String key) {
    final all = _readAll();
    return all[key];
  }

  @override
  Future<void> recordAttempt(DailyAttempt attempt) async {
    final all = _readAll();
    all[attempt.key] = attempt;
    await _prefs.setStringList(
      _key,
      all.values.map((a) => _encode(a)).toList(),
    );
  }

  @override
  int completedCount() {
    return _readAll().values.where((a) => a.completed).length;
  }

  /// Decodes one packed history row. Returns `null` for malformed rows.
  static DailyAttempt? tryDecode(String row) {
    final parts = row.split('|');
    if (parts.length < 4) return null;
    final key = parts[0];
    if (key.length != 10) return null;
    final score = int.tryParse(parts[1]);
    final stars = int.tryParse(parts[2]);
    if (score == null || stars == null) return null;
    return DailyAttempt(
      key: key,
      score: score,
      stars: stars.clamp(0, 3),
      completed: parts[3] == 'true',
    );
  }

  Map<String, DailyAttempt> _readAll() {
    final raw = _prefs.getStringList(_key) ?? const <String>[];
    final result = <String, DailyAttempt>{};
    for (final entry in raw) {
      final parsed = DailyAttempt.tryDecode(entry);
      if (parsed != null) result[parsed.key] = parsed;
    }
    return result;
  }

  static String _encode(DailyAttempt attempt) =>
      '${attempt.key}|${attempt.score}|${attempt.stars}|${attempt.completed}';
}
