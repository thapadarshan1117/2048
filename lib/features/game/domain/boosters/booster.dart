import '../game_board.dart';
import '../game_state.dart';
import '../merge_engine.dart';
import '../merge_event.dart';

/// Everything a booster is allowed to know about the session it runs in.
///
/// Boosters are pure use cases: they receive a context and return a brand new
/// [GameState]. They never touch widgets, the Flame layer, navigation,
/// analytics or storage.
class BoosterContext {
  const BoosterContext({
    required this.state,
    this.selectedBlockId,
    this.selectedColumn,
  });

  final GameState state;

  /// Block the player is pointing at (hammer / wildcard / +1).
  final int? selectedBlockId;

  /// Column the player is pointing at.
  final int? selectedColumn;

  BoosterContext copyWith({
    GameState? state,
    int? selectedBlockId,
    int? selectedColumn,
  }) {
    return BoosterContext(
      state: state ?? this.state,
      selectedBlockId: selectedBlockId ?? this.selectedBlockId,
      selectedColumn: selectedColumn ?? this.selectedColumn,
    );
  }
}

/// What kind of change a booster made - drives analytics and animation.
enum BoosterEffectKind { undo, remove, shuffle, wildcard, upgrade }

/// Result of applying a booster.
class BoosterOutcome {
  const BoosterOutcome({
    required this.state,
    required this.effect,
    this.transitions = const <BoardTransition>[],
    this.affectedBlockIds = const <int>[],
    this.applied = true,
    this.rejectionKey,
  });

  /// Session state after the booster.
  final GameState state;

  final BoosterEffectKind effect;

  /// Board transitions the animation layer should replay.
  final List<BoardTransition> transitions;

  /// Blocks that were removed or changed.
  final List<int> affectedBlockIds;

  final bool applied;

  /// Localisation key explaining why the booster was refused.
  final String? rejectionKey;

  int get scoreGained {
    var total = 0;
    for (final transition in transitions) {
      for (final merge in transition.merges) {
        total += merge.scoreGained;
      }
    }
    return total;
  }

  static const String rejectionNoUndo = 'booster_reject_no_undo';
  static const String rejectionNoTarget = 'booster_reject_no_target';
  static const String rejectionTooFewBlocks = 'booster_reject_too_few_blocks';
  static const String rejectionGameOver = 'booster_reject_game_over';
}

/// A single, self-contained booster.
///
/// The interface mirrors the shape from the design brief - `canUse` answers
/// "is this legal right now?" and `apply` returns a brand new state. The
/// [BoosterContext] wrapper exists because several boosters need to know which
/// block the player selected, which a bare `GameState` cannot express.
abstract interface class Booster {
  /// Stable id used by saves, analytics and the shop.
  String get id;

  /// Localisation key for the booster name.
  String get nameKey;

  /// Localisation key for the one-line explanation.
  String get descriptionKey;

  /// Coin price when bought mid-run.
  int get price;

  /// `true` when the player must tap a block first.
  bool get requiresTargetBlock => false;

  /// `true` when the booster can be used right now.
  bool canUse(BoosterContext context);

  /// Applies the booster and returns the resulting state.
  BoosterOutcome apply(BoosterContext context);
}

/// Shared helpers so every booster resolves the board identically.
abstract final class BoosterSupport {
  const BoosterSupport._();

  /// Runs gravity + merge resolution and folds the outcome into the stats.
  static ({
    GameState state,
    List<BoardTransition> transitions,
  }) settle(
    GameState state, {
    MergeEngine? engine,
    bool countAsMove = false,
  }) {
    final mergeEngine = engine ?? const MergeEngine();
    final resolution = mergeEngine.resolve(
      board: state.board,
      nextBlockId: state.nextBlockId,
    );
    final stats = state.stats.applyDrop(
      scoreGained: resolution.scoreGained,
      merges: resolution.mergeCount,
      longestChain: resolution.longestChain,
      boardHighest: resolution.highestValue,
    );
    final next = state.copyWith(
      board: resolution.board,
      nextBlockId: resolution.nextBlockId,
      stats: stats,
      score: stats.score,
      movesUsed: state.movesUsed + (countAsMove ? 1 : 0),
      isGameOver: !resolution.board.hasLegalDrop,
    );
    return (state: next, transitions: resolution.transitions);
  }

  /// Folds a freshly resolved board into the statistics without changing the
  /// move counter (used by boosters that should not consume a move).
  static GameState applyResolution(GameState state, MergeResolution resolution) {
    final stats = state.stats.applyDrop(
      scoreGained: resolution.scoreGained,
      merges: resolution.mergeCount,
      longestChain: resolution.longestChain,
      boardHighest: resolution.highestValue,
    );
    return state.copyWith(
      board: resolution.board,
      nextBlockId: resolution.nextBlockId,
      stats: stats,
      score: stats.score,
      isGameOver: !resolution.board.hasLegalDrop,
    );
  }

  /// Board restricted to the cells a booster may target.
  static GameBoard boardOf(GameState state) => state.board;
}
