import '../../game/domain/game_stats.dart';

/// The kind of goal a level can ask the player to achieve.
enum ObjectiveType {
  reachScore,
  createNumber,
  mergeCount,
  reachNumber,
  completeWithinMoves,
  comboCount;

  static ObjectiveType? fromName(String name) {
    for (final type in ObjectiveType.values) {
      if (type.name == name) return type;
    }
    return null;
  }
}

/// A level goal.
///
/// Sealed hierarchy so new objective types can be added without touching the
/// engine: implement [isSatisfied] and [progress] and register the type name
/// in [decode].
sealed class LevelObjective {
  const LevelObjective();

  const factory LevelObjective.reachScore(int target) = ReachScoreObjective;

  const factory LevelObjective.createNumber(int target) = CreateNumberObjective;

  const factory LevelObjective.mergeCount(int target) = MergeCountObjective;

  const factory LevelObjective.reachNumber(int target) = ReachNumberObjective;

  const factory LevelObjective.completeWithinMoves(int target) =
      CompleteWithinMovesObjective;

  const factory LevelObjective.comboCount(int target) = ComboCountObjective;

  /// Numeric goal.
  int get target;

  ObjectiveType get type;

  /// Localisation key describing the goal, e.g. `objective_reach_score`.
  String get localizationKey;

  /// `true` when the goal has been met by [stats].
  bool isSatisfied(GameStats stats);

  /// Completion ratio in `0..1`, clamped.
  double progress(GameStats stats);

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'type': type.name, 'target': target};

  /// Parses an objective from JSON. Falls back to a trivial score goal so a
  /// corrupt level file can never crash the game.
  static LevelObjective decode(Map<String, dynamic> json) {
    final type = ObjectiveType.fromName(json['type'] as String? ?? '');
    final target = (json['target'] as num? ?? 0).toInt();
    return switch (type) {
      ObjectiveType.createNumber => LevelObjective.createNumber(target),
      ObjectiveType.mergeCount => LevelObjective.mergeCount(target),
      ObjectiveType.reachNumber => LevelObjective.reachNumber(target),
      ObjectiveType.completeWithinMoves =>
        LevelObjective.completeWithinMoves(target),
      ObjectiveType.comboCount => LevelObjective.comboCount(target),
      _ => LevelObjective.reachScore(target <= 0 ? 100 : target),
    };
  }

  static double _ratio(int value, int target) {
    if (target <= 0) return 1;
    return (value / target).clamp(0.0, 1.0);
  }
}

/// Reach a total score, e.g. "Reach score 500".
class ReachScoreObjective extends LevelObjective {
  const ReachScoreObjective(this.target);

  @override
  final int target;

  @override
  ObjectiveType get type => ObjectiveType.reachScore;

  @override
  String get localizationKey => 'objective_reach_score';

  @override
  bool isSatisfied(GameStats stats) => stats.score >= target;

  @override
  double progress(GameStats stats) => LevelObjective._ratio(stats.score, target);
}

/// Produce a block of at least [target] by merging, e.g. "Create 128".
class CreateNumberObjective extends LevelObjective {
  const CreateNumberObjective(this.target);

  @override
  final int target;

  @override
  ObjectiveType get type => ObjectiveType.createNumber;

  @override
  String get localizationKey => 'objective_create_number';

  @override
  bool isSatisfied(GameStats stats) => stats.highestValueCreated >= target;

  @override
  double progress(GameStats stats) =>
      LevelObjective._ratio(stats.highestValueCreated, target);
}

/// Perform [target] merges, e.g. "Perform 10 merges".
class MergeCountObjective extends LevelObjective {
  const MergeCountObjective(this.target);

  @override
  final int target;

  @override
  ObjectiveType get type => ObjectiveType.mergeCount;

  @override
  String get localizationKey => 'objective_merge_count';

  @override
  bool isSatisfied(GameStats stats) => stats.mergeCount >= target;

  @override
  double progress(GameStats stats) =>
      LevelObjective._ratio(stats.mergeCount, target);
}

/// Have a block of at least [target] on the board, e.g. "Reach 512".
class ReachNumberObjective extends LevelObjective {
  const ReachNumberObjective(this.target);

  @override
  final int target;

  @override
  ObjectiveType get type => ObjectiveType.reachNumber;

  @override
  String get localizationKey => 'objective_reach_number';

  @override
  bool isSatisfied(GameStats stats) => stats.highestValueOnBoard >= target;

  @override
  double progress(GameStats stats) =>
      LevelObjective._ratio(stats.highestValueOnBoard, target);
}

/// Finish the level within [target] moves, e.g. "Create 2048 within 80 moves".
class CompleteWithinMovesObjective extends LevelObjective {
  const CompleteWithinMovesObjective(this.target);

  @override
  final int target;

  @override
  ObjectiveType get type => ObjectiveType.completeWithinMoves;

  @override
  String get localizationKey => 'objective_complete_within_moves';

  @override
  bool isSatisfied(GameStats stats) => stats.movesUsed <= target;

  @override
  double progress(GameStats stats) {
    if (target <= 0) return 1;
    // Progress counts down as moves are spent.
    return (1 - stats.movesUsed / target).clamp(0.0, 1.0);
  }
}

/// Trigger a chain reaction of [target] merges from a single drop,
/// e.g. "Perform a 5x combo".
class ComboCountObjective extends LevelObjective {
  const ComboCountObjective(this.target);

  @override
  final int target;

  @override
  ObjectiveType get type => ObjectiveType.comboCount;

  @override
  String get localizationKey => 'objective_combo_count';

  @override
  bool isSatisfied(GameStats stats) => stats.longestCombo >= target;

  @override
  double progress(GameStats stats) =>
      LevelObjective._ratio(stats.longestCombo, target);
}
