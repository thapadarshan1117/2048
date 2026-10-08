import 'package:equatable/equatable.dart';

/// How far the player got on a single level.
class LevelProgress extends Equatable {
  const LevelProgress({
    this.stars = 0,
    this.bestScore = 0,
    this.completed = false,
    this.attempts = 0,
  });

  /// Highest star rating ever achieved (0-3).
  final int stars;

  /// Best score ever achieved.
  final int bestScore;

  final bool completed;

  /// How many times the level has been started.
  final int attempts;

  static const LevelProgress empty = LevelProgress();

  /// Folds a finished run into the stored progress.
  ///
  /// Stars and best score are monotonic - replaying a level can only improve
  /// them, never lose them.
  LevelProgress applyRun({
    required int stars,
    required int score,
    required bool completed,
  }) {
    return LevelProgress(
      stars: stars > this.stars ? stars : this.stars,
      bestScore: score > bestScore ? score : bestScore,
      completed: completed || this.completed,
      attempts: attempts + 1,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'stars': stars,
        'best': bestScore,
        'done': completed,
        'attempts': attempts,
      };

  static LevelProgress fromJson(Map<String, dynamic> json) => LevelProgress(
        stars: (json['stars'] as num? ?? 0).toInt().clamp(0, 3),
        bestScore: (json['best'] as num? ?? 0).toInt(),
        completed: json['done'] as bool? ?? false,
        attempts: (json['attempts'] as num? ?? 0).toInt(),
      );

  @override
  List<Object?> get props => <Object?>[stars, bestScore, completed, attempts];
}
