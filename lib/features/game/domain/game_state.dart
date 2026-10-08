import '../../levels/domain/level.dart';
import 'game_board.dart';
import 'game_mode.dart';
import 'game_stats.dart';

/// Complete, immutable logical state of a game session.
///
/// This object - never a Flame component - is the source of truth. The Flutter
/// UI reads it through a Cubit, and the Flame layer mirrors it visually.
class GameState {
  const GameState({
    required this.board,
    required this.nextBlockId,
    required this.nextBlockValue,
    required this.stats,
    this.score = 0,
    this.movesUsed = 0,
    this.level,
    this.mode = GameMode.level,
    this.isGameOver = false,
    this.undoHistory = const <GameState>[],
    this.rngState = 1,
  });

  final GameBoard board;

  /// First unused block id.
  final int nextBlockId;

  /// Value that the next drop will place.
  final int nextBlockValue;

  final GameStats stats;

  /// Convenience mirror of [GameStats.score].
  final int score;
  final int movesUsed;

  /// The level being played, or `null` for infinite mode.
  final Level? level;

  final GameMode mode;

  final bool isGameOver;

  /// Previous states available to the Undo booster (oldest first).
  final List<GameState> undoHistory;

  /// Persisted RNG state so a resumed game keeps generating the same values.
  final int rngState;

  bool get canUndo => undoHistory.isNotEmpty;

  /// `true` when every objective of the level has been met.
  bool get objectivesComplete {
    final level = this.level;
    if (level == null) return false;
    return level.objective.isSatisfied(stats);
  }

  int get stars => level?.stars.starsFor(score) ?? 0;

  int get remainingMoves {
    final limit = level?.effectiveMoveLimit ?? 0;
    if (limit <= 0) return -1;
    final left = limit - movesUsed;
    return left < 0 ? 0 : left;
  }

  /// Objective progress in `0..1` for the HUD.
  double get objectiveProgress {
    final level = this.level;
    if (level == null) return 0;
    return level.objective.progress(stats);
  }

  GameState copyWith({
    GameBoard? board,
    int? nextBlockId,
    int? nextBlockValue,
    GameStats? stats,
    int? score,
    int? movesUsed,
    Level? level,
    GameMode? mode,
    bool? isGameOver,
    List<GameState>? undoHistory,
    int? rngState,
  }) {
    return GameState(
      board: board ?? this.board,
      nextBlockId: nextBlockId ?? this.nextBlockId,
      nextBlockValue: nextBlockValue ?? this.nextBlockValue,
      stats: stats ?? this.stats,
      score: score ?? this.score,
      movesUsed: movesUsed ?? this.movesUsed,
      level: level ?? this.level,
      mode: mode ?? this.mode,
      isGameOver: isGameOver ?? this.isGameOver,
      undoHistory: undoHistory ?? this.undoHistory,
      rngState: rngState ?? this.rngState,
    );
  }

  @override
  String toString() =>
      'GameState(mode: $mode, level: ${level?.id}, score: $score, '
      'moves: $movesUsed, blocks: ${board.blockCount}, over: $isGameOver)';
}

/// Rebuilds a live state from a persisted core.
///
/// Used to restore undo history across app restarts: the cores are stored
/// without their `level`/`mode`, which the caller supplies from the session it
/// is resuming.
factory GameState.fromCore(
  GameStateCore core, {
  Level? level,
  GameMode mode = GameMode.level,
}) {
  return GameState(
    board: core.board,
    nextBlockId: core.nextBlockId,
    nextBlockValue: core.nextBlockValue,
    stats: core.stats,
    score: core.score,
    movesUsed: core.movesUsed,
    level: level,
    mode: mode,
    rngState: core.rngState,
    isGameOver: !core.board.hasLegalDrop,
  );
}

/// A lightweight, serialisable projection of [GameState] used to persist an
/// in-progress game.
class GameStateCore {
  const GameStateCore({
    required this.board,
    required this.nextBlockId,
    required this.nextBlockValue,
    required this.stats,
    required this.score,
    required this.movesUsed,
    required this.rngState,
  });

  final GameBoard board;
  final int nextBlockId;
  final int nextBlockValue;
  final GameStats stats;
  final int score;
  final int movesUsed;
  final int rngState;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'board': board.toJson(),
        'nextBlockId': nextBlockId,
        'nextBlockValue': nextBlockValue,
        'stats': stats.toJson(),
        'score': score,
        'moves': movesUsed,
        'rng': rngState,
      };

  static GameStateCore? tryFromJson(Map<String, dynamic> json) {
    try {
      final boardJson = json['board'] as Map<String, dynamic>?;
      if (boardJson == null) return null;
      final board = GameBoard.fromJson(boardJson);
      final stats = GameStats.fromJson(
        (json['stats'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      );
      return GameStateCore(
        board: board,
        nextBlockId: (json['nextBlockId'] as num? ?? 1).toInt(),
        nextBlockValue: (json['nextBlockValue'] as num? ?? 2).toInt(),
        stats: stats,
        score: (json['score'] as num? ?? 0).toInt(),
        movesUsed: (json['moves'] as num? ?? 0).toInt(),
        rngState: (json['rng'] as num? ?? 1).toInt(),
      );
    } on Object {
      return null;
    }
  }
}
