import 'package:equatable/equatable.dart';

import '../../../core/utils/daily_seed.dart';
import '../../levels/domain/level.dart';

/// The deterministic daily puzzle.
///
/// Every player in the world gets the same board on the same calendar day,
/// because the whole challenge is derived from the date string. Nothing here
/// reads the clock beyond formatting it.
class DailyChallenge extends Equatable {
  const DailyChallenge({
    required this.key,
    required this.seed,
    required this.level,
    required this.date,
  });

  /// `YYYY-MM-DD`.
  final String key;

  /// Seed fed to the block generator.
  final int seed;

  /// The level played (fixed parameters, fresh board each attempt).
  final Level level;

  final DateTime date;

  /// The challenge for [date].
  ///
  /// The board is generated from the seed, so it is stable for the whole day
  /// and different every day.
  factory DailyChallenge.forDate(DateTime date, {Level? level}) {
    final key = DailySeed.keyFor(date);
    final seed = DailySeed.seedFor(key);
    return DailyChallenge(
      key: key,
      seed: seed,
      date: date,
      level: level ?? DailyChallenge.defaultLevel(seed),
    );
  }

  /// Builds the daily level from the seed.
  ///
  /// The objective and thresholds are fixed constants rather than simulated, so
  /// the challenge is identical on every device and every year.
  static Level defaultLevel(int seed) {
    final objectiveKind = seed % 4;
    return Level(
      id: -1,
      chapter: 0,
      objective: switch (objectiveKind) {
        0 => LevelObjective.reachScore(1500),
        1 => LevelObjective.reachNumber(128),
        2 => LevelObjective.mergeCount(60),
        _ => LevelObjective.comboCount(3),
      },
      moveLimit: null,
      initialBlocks: const <BlockSpawn>[
        BlockSpawn(row: 11, column: 1, value: 2),
        BlockSpawn(row: 11, column: 4, value: 2),
      ],
      allowedBoosters: const <String>['undo', 'hammer', 'shuffle'],
      difficulty: const DifficultyProfile(),
      stars: const StarThresholds(twoStarScore: 1500, threeStarScore: 3000),
    );
  }

  bool get isToday => key == DailySeed.keyFor(DateTime.now());

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'seed': seed,
        'level': level.toJson(),
      };

  @override
  List<Object?> get props => <Object?>[key, seed, level];
}

/// Localised label helpers for the daily challenge screen.
abstract final class DailyLabels {
  const DailyLabels._();

  static String objectiveText(DailyChallenge challenge) {
    final level = challenge.level;
    return switch (level.objective.type) {
      ObjectiveType.reachScore => 'Reach ${level.objective.target} points',
      ObjectiveType.reachNumber =>
        'Create a ${level.objective.target} block',
      ObjectiveType.mergeCount => 'Merge ${level.objective.target} times',
      ObjectiveType.comboCount => 'Make a ${level.objective.target}x chain',
      ObjectiveType.createNumber =>
        'Create ${level.objective.target} blocks',
      ObjectiveType.completeWithinMoves =>
        'Finish within ${level.objective.target} moves',
    };
  }
}
