import 'package:equatable/equatable.dart';

import 'level_progress.dart';

/// Everything the player has earned, persisted locally.
///
/// The whole progression system is offline-first: this object is the only thing
/// that needs to survive an app restart, and it is deliberately a plain value
/// object so it can later be swapped for a cloud-synced implementation without
/// touching any UI.
class PlayerProgress extends Equatable {
  const PlayerProgress({
    this.currentLevel = 1,
    this.levelProgress = const <int, LevelProgress>{},
    this.highestUnlockedLevel = 1,
  });

  /// Level the player should be offered next.
  final int currentLevel;

  /// Per-level stars / best score / completion.
  final Map<int, LevelProgress> levelProgress;

  /// Highest level the player is allowed to enter.
  final int highestUnlockedLevel;

  static const PlayerProgress empty = PlayerProgress();

  int get starsEarned =>
      levelProgress.values.fold<int>(0, (sum, p) => sum + p.stars);

  int get levelsCompleted =>
      levelProgress.values.where((p) => p.completed).length;

  int get totalMerges => 0;

  LevelProgress progressFor(int levelId) =>
      levelProgress[levelId] ?? LevelProgress.empty;

  bool isUnlocked(int levelId) => levelId <= highestUnlockedLevel;

  /// Records a finished run and unlocks the next level when the player wins.
  PlayerProgress applyRun({
    required int levelId,
    required int stars,
    required int score,
    required bool completed,
  }) {
    final previous = progressFor(levelId);
    final updated = previous.applyRun(
      stars: stars,
      score: score,
      completed: completed,
    );
    final nextProgress = Map<int, LevelProgress>.from(levelProgress);
    nextProgress[levelId] = updated;

    return PlayerProgress(
      currentLevel: completed && levelId >= currentLevel
          ? levelId + 1
          : currentLevel,
      levelProgress: nextProgress,
      highestUnlockedLevel: completed && levelId + 1 > highestUnlockedLevel
          ? levelId + 1
          : highestUnlockedLevel,
    );
  }

  /// Unlocks [levelId] without recording a run (debug tools, cloud sync).
  PlayerProgress unlock(int levelId) {
    if (levelId <= highestUnlockedLevel) return this;
    return PlayerProgress(
      currentLevel: levelId > currentLevel ? levelId : currentLevel,
      levelProgress: levelProgress,
      highestUnlockedLevel: levelId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'currentLevel': currentLevel,
        'highestUnlocked': highestUnlockedLevel,
        'levels': levelProgress.map(
          (key, value) => MapEntry(key.toString(), value.toJson()),
        ),
      };

  static PlayerProgress fromJson(Map<String, dynamic> json) {
    final rawLevels = (json['levels'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final levels = <int, LevelProgress>{};
    rawLevels.forEach((key, value) {
      final id = int.tryParse(key);
      if (id == null || value is! Map<String, dynamic>) return;
      levels[id] = LevelProgress.fromJson(value);
    });

    final highest = (json['highestUnlocked'] as num? ?? 1).toInt();
    return PlayerProgress(
      currentLevel: (json['currentLevel'] as num? ?? highest).toInt(),
      levelProgress: levels,
      highestUnlockedLevel: highest < 1 ? 1 : highest,
    );
  }

  @override
  List<Object?> get props => <Object?>[currentLevel, highestUnlockedLevel, levelsCompleted, starsEarned];
}
