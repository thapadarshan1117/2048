import 'dart:convert';

import '../../../core/services/preferences_service.dart';
import '../domain/daily_reward_state.dart';
import '../domain/milestone.dart';
import '../domain/player_progress.dart';

/// Everything the player has earned, plus the derived statistics screen data.
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.progress,
    required this.coins,
    required this.dailyReward,
    required this.stats,
    required this.claimedMilestones,
    this.boosterInventory = const <String, int>{},
  });

  final PlayerProgress progress;
  final int coins;
  final DailyRewardState dailyReward;
  final MilestoneStats stats;

  /// Milestone ids whose coin reward has already been paid.
  final Set<String> claimedMilestones;

  /// Booster charges owned outside of a session.
  final Map<String, int> boosterInventory;

  static const ProgressSnapshot empty = ProgressSnapshot(
    progress: PlayerProgress.empty,
    coins: 0,
    dailyReward: DailyRewardState.empty,
    stats: MilestoneStats.empty,
    claimedMilestones: <String>{},
    boosterInventory: <String, int>{},
  );

  int get levelsCompleted => progress.levelsCompleted;

  int get starsEarned => progress.starsEarned;

  ProgressSnapshot copyWithCoins(int value) => ProgressSnapshot(
        progress: progress,
        coins: value,
        dailyReward: dailyReward,
        stats: stats,
        claimedMilestones: claimedMilestones,
        boosterInventory: boosterInventory,
      );

  ProgressSnapshot copyWithProgress(PlayerProgress value) => ProgressSnapshot(
        progress: value,
        coins: coins,
        dailyReward: dailyReward,
        stats: stats,
        claimedMilestones: claimedMilestones,
        boosterInventory: boosterInventory,
      );

  ProgressSnapshot copyWithStats(MilestoneStats value) => ProgressSnapshot(
        progress: progress,
        coins: coins,
        dailyReward: dailyReward,
        stats: value,
        claimedMilestones: claimedMilestones,
        boosterInventory: boosterInventory,
      );

  ProgressSnapshot copyWithDailyReward(DailyRewardState value) => ProgressSnapshot(
        progress: progress,
        coins: coins,
        dailyReward: value,
        stats: stats,
        claimedMilestones: claimedMilestones,
        boosterInventory: boosterInventory,
      );

  ProgressSnapshot copyWithClaimedMilestones(Set<String> value) => ProgressSnapshot(
        progress: progress,
        coins: coins,
        dailyReward: dailyReward,
        stats: stats,
        claimedMilestones: value,
        boosterInventory: boosterInventory,
      );

  ProgressSnapshot copyWithBoosterInventory(Map<String, int> value) =>
      ProgressSnapshot(
        progress: progress,
        coins: coins,
        dailyReward: dailyReward,
        stats: stats,
        claimedMilestones: claimedMilestones,
        boosterInventory: value,
      );
}

/// Where progression is stored.
abstract interface class ProgressRepository {
  ProgressSnapshot read();

  Future<void> write(ProgressSnapshot snapshot);

  Future<void> reset();
}

/// `SharedPreferences`-backed progression storage.
///
/// The on-disk shape is deliberately flat JSON so it can be migrated to a
/// database or a cloud document later without a translation step.
class LocalProgressRepository implements ProgressRepository {
  const LocalProgressRepository(this._prefs);

  static const String _key = 'progress.v1';

  final PreferencesService _prefs;

  @override
  ProgressSnapshot read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return ProgressSnapshot.empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return ProgressSnapshot.empty;
      final progressJson = decoded['progress'];
      final statsJson = decoded['stats'];
      final dailyJson = decoded['dailyReward'];
      return ProgressSnapshot(
        progress: progressJson is Map<String, dynamic>
            ? PlayerProgress.fromJson(progressJson)
            : PlayerProgress.empty,
        coins: (decoded['coins'] as num? ?? 0).toInt(),
        dailyReward: dailyJson is Map<String, dynamic>
            ? DailyRewardState.fromJson(dailyJson)
            : DailyRewardState.empty,
        stats: statsJson is Map<String, dynamic>
            ? MilestoneStats.fromJson(statsJson)
            : MilestoneStats.empty,
        claimedMilestones:
            ((decoded['milestones'] as List<dynamic>?) ?? const <dynamic>[])
                .map((e) => e.toString())
                .toSet(),
        boosterInventory:
            ((decoded['boosters'] as Map<String, dynamic>?) ??
                    const <String, dynamic>{})
                .map((key, value) => MapEntry(key, (value as num).toInt())),
      );
    } on Object {
      // A corrupt save must never crash the app. Progress is discarded only
      // when it cannot be parsed at all; partial data is preserved field by
      // field because each section is decoded independently.
      return ProgressSnapshot.empty;
    }
  }

  @override
  Future<void> write(ProgressSnapshot snapshot) {
    return _prefs.putString(
      _key,
      jsonEncode(<String, dynamic>{
        'progress': snapshot.progress.toJson(),
        'coins': snapshot.coins,
        'dailyReward': snapshot.dailyReward.toJson(),
        'stats': snapshot.stats.toJson(),
        'milestones': snapshot.claimedMilestones.toList(),
        'boosters': snapshot.boosterInventory,
      }),
    );
  }

  @override
  Future<void> reset() => _prefs.remove(_key);
}
