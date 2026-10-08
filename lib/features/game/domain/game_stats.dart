/// Cumulative, purely-derived statistics for a single game session.
///
/// Every objective in the game is a function of this object, which keeps
/// objective evaluation free of side effects and trivially testable.
class GameStats {
  const GameStats({
    this.score = 0,
    this.mergeCount = 0,
    this.movesUsed = 0,
    this.highestValueCreated = 0,
    this.highestValueOnBoard = 0,
    this.longestCombo = 0,
    this.totalScoreFromMerges = 0,
  });

  final int score;
  final int mergeCount;
  final int movesUsed;

  /// Highest value ever *produced* by a merge (monotonically increasing).
  final int highestValueCreated;

  /// Highest value ever *present* on the board at the same time.
  final int highestValueOnBoard;

  /// Longest chain reaction triggered by a single drop.
  final int longestCombo;

  final int totalScoreFromMerges;

  GameStats copyWith({
    int? score,
    int? mergeCount,
    int? movesUsed,
    int? highestValueCreated,
    int? highestValueOnBoard,
    int? longestCombo,
    int? totalScoreFromMerges,
  }) {
    return GameStats(
      score: score ?? this.score,
      mergeCount: mergeCount ?? this.mergeCount,
      movesUsed: movesUsed ?? this.movesUsed,
      highestValueCreated: highestValueCreated ?? this.highestValueCreated,
      highestValueOnBoard: highestValueOnBoard ?? this.highestValueOnBoard,
      longestCombo: longestCombo ?? this.longestCombo,
      totalScoreFromMerges: totalScoreFromMerges ?? this.totalScoreFromMerges,
    );
  }

  /// Folds the result of one drop into the running statistics.
  GameStats applyDrop({
    required int scoreGained,
    required int merges,
    required int longestChain,
    required int boardHighest,
  }) {
    return GameStats(
      score: score + scoreGained,
      mergeCount: mergeCount + merges,
      movesUsed: movesUsed + 1,
      highestValueCreated:
          highestValueCreated > boardHighest ? highestValueCreated : boardHighest,
      highestValueOnBoard:
          highestValueOnBoard > boardHighest ? highestValueOnBoard : boardHighest,
      longestCombo: longestCombo > longestChain ? longestCombo : longestChain,
      totalScoreFromMerges: totalScoreFromMerges + scoreGained,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'score': score,
        'merges': mergeCount,
        'moves': movesUsed,
        'highestCreated': highestValueCreated,
        'highestOnBoard': highestValueOnBoard,
        'longestCombo': longestCombo,
      };

  factory GameStats.fromJson(Map<String, dynamic> json) => GameStats(
        score: (json['score'] as num? ?? 0).toInt(),
        mergeCount: (json['merges'] as num? ?? 0).toInt(),
        movesUsed: (json['moves'] as num? ?? 0).toInt(),
        highestValueCreated: (json['highestCreated'] as num? ?? 0).toInt(),
        highestValueOnBoard: (json['highestOnBoard'] as num? ?? 0).toInt(),
        longestCombo: (json['longestCombo'] as num? ?? 0).toInt(),
      );
}
