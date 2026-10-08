import '../../levels/domain/difficulty_profile.dart';
import '../../levels/domain/level.dart';
import 'block_generator.dart';
import 'block_state.dart';
import 'drop_result.dart';
import 'game_board.dart';
import 'game_mode.dart';
import 'game_state.dart';
import 'game_stats.dart';
import 'merge_engine.dart';
import 'rng.dart';

/// Orchestrates a single game session.
///
/// The engine owns the authoritative [GameState] and is the only place where
/// the rules are applied. Flutter widgets and Flame components observe the
/// state it produces; neither of them ever mutates the board directly.
///
/// ```text
/// GameController (Flutter)  ->  GameEngine (domain)  ->  GameState
///                                     |
///                                     +-> MergeEngine / ScoreCalculator
///                                     +-> BlockGenerator
/// ```
class GameEngine {
  GameEngine._({
    required GameState initialState,
    required this.profile,
    required this.generator,
  }) : _state = initialState;

  /// Starts a fresh session on [board] (usually empty).
  factory GameEngine.start({
    required GameBoard board,
    required DifficultyProfile profile,
    int? seed,
    Level? level,
    GameMode mode = GameMode.level,
    int? initialNextValue,
    MergeEngine? mergeEngine,
  }) {
    final generator = BlockGenerator(profile: profile, seed: seed);
    final nextValue = initialNextValue ?? generator.next();
    final state = GameState(
      board: board,
      nextBlockId: _initialBlockId(board),
      nextBlockValue: nextValue,
      stats: GameStats(),
      level: level,
      mode: mode,
      rngState: generator.rng.state,
    );
    return GameEngine._(
      initialState: state,
      profile: profile,
      generator: generator,
    );
  }

  /// Rebuilds a session from persisted data.
  ///
  /// Any corrupt piece of data is repaired rather than thrown, so a bad save
  /// can never brick the game.
  factory GameEngine.restore({
    required GameStateCore core,
    required DifficultyProfile profile,
    Level? level,
    GameMode mode = GameMode.level,
    List<GameState> undoHistory = const <GameState>[],
    MergeEngine? mergeEngine,
  }) {
    final generator = BlockGenerator(profile: profile, rng: Rng(core.rngState));
    final state = GameState(
      board: core.board,
      nextBlockId: core.nextBlockId < 1 ? 1 : core.nextBlockId,
      nextBlockValue: core.nextBlockValue <= 0 ? 2 : core.nextBlockValue,
      stats: core.stats,
      score: core.score,
      movesUsed: core.movesUsed,
      level: level,
      mode: mode,
      undoHistory: undoHistory,
      rngState: core.rngState,
      isGameOver: !core.board.hasLegalDrop,
    );
    return GameEngine._(initialState: state, profile: profile, generator: generator);
  }

  /// Builds the board described by [level]'s pre-placed blocks.
  ///
  /// Block ids start at 1 and count upwards, which keeps them stable for the
  /// animation layer while still being unique.
  static GameBoard initialBoardForLevel(Level level, int rows, int columns) {
    final grid = List<List<BlockState?>>.generate(
      rows,
      (_) => List<BlockState?>.filled(columns, null),
    );
    for (var i = 0; i < level.initialBlocks.length; i++) {
      final spawn = level.initialBlocks[i];
      if (spawn.row < 0 || spawn.row >= rows) continue;
      if (spawn.column < 0 || spawn.column >= columns) continue;
      grid[spawn.row][spawn.column] = BlockState(
        id: i + 1,
        value: spawn.value,
        row: spawn.row,
        column: spawn.column,
      );
    }
    return GameBoard.fromCells(rows, columns, grid);
  }

  static int _initialBlockId(GameBoard board) {
    var maxId = 0;
    for (final block in board.blocks) {
      if (block.id > maxId) maxId = block.id;
    }
    return maxId + 1;
  }

  final DifficultyProfile profile;
  final BlockGenerator generator;
  final MergeEngine mergeEngine = const MergeEngine();

  /// Maximum number of undo steps retained.
  static const int maxUndoDepth = 20;

  late GameState _state;

  GameState get state => _state;

  /// Returns an independent engine positioned at the current state.
  ///
  /// Used by the simulator to probe every candidate column without disturbing
  /// the live session. The generator is cloned too, because probing a drop
  /// draws the next block value and would otherwise desynchronise the RNG.
  GameEngine clone() => GameEngine._(
        initialState: _state,
        profile: profile,
        generator: generator.clone(),
      );

  bool get isOver => _state.isGameOver;

  /// `true` when the player is allowed to drop into [column].
  ///
  /// Deliberately delegates to [landingRowFor]: testing `allows(0, column)`
  /// would wrongly reject every column of a height-limited board, because a
  /// height restriction rejects *rows*, not columns.
  bool canDrop(int column) {
    if (_state.isGameOver) return false;
    if (column < 0 || column >= _state.board.columns) return false;
    return landingRowFor(column) != null;
  }

  /// The logical landing row for [column], honouring board restrictions.
  /// Returns `null` when the column cannot accept a block.
  int? landingRowFor(int column) {
    final board = _state.board;
    if (column < 0 || column >= board.columns) return null;
    final restriction = profile.restriction;
    for (var row = board.rows - 1; row >= 0; row--) {
      if (!restriction.allows(row, column)) return null;
      if (board.cells[row][column] == null) return row;
    }
    return null;
  }

  /// Drops the next block into [column].
  ///
  /// The full outcome - landing row, merge cascade, score, game over - is
  /// decided here, before a single pixel moves.
  DropOutcome drop(int column) {
    final current = _state;

    if (current.isGameOver) {
      return DropOutcome(
        accepted: false,
        rejection: DropRejection.sessionOver,
        state: current,
      );
    }
    if (column < 0 || column >= current.board.columns) {
      return DropOutcome(
        accepted: false,
        rejection: DropRejection.invalidColumn,
        state: current,
      );
    }

    final landingRow = landingRowFor(column);
    if (landingRow == null) {
      return DropOutcome(
        accepted: false,
        rejection: DropRejection.columnFull,
        state: current,
      );
    }

    final value = current.nextBlockValue;
    final dropped = BlockState(
      id: current.nextBlockId,
      value: value,
      row: landingRow,
      column: column,
    );

    final boardAfterDrop = current.board.withBlock(dropped);
    final resolution = mergeEngine.resolve(
      board: boardAfterDrop,
      nextBlockId: current.nextBlockId + 1,
      preferredAnchorBlockId: dropped.id,
    );

    final newStats = current.stats.applyDrop(
      scoreGained: resolution.scoreGained,
      merges: resolution.mergeCount,
      longestChain: resolution.longestChain,
      boardHighest: resolution.highestValue,
    );

    final nextValue = generator.next();
    final nextState = current.copyWith(
      board: resolution.board,
      nextBlockId: resolution.nextBlockId,
      nextBlockValue: nextValue,
      stats: newStats,
      score: newStats.score,
      movesUsed: newStats.movesUsed,
      isGameOver: !resolution.board.hasLegalDrop,
      undoHistory: _appendHistory(current),
      rngState: generator.rng.state,
    );
    _state = nextState;

    return DropOutcome(
      accepted: true,
      rejection: DropRejection.none,
      state: nextState,
      droppedBlock: dropped,
      landingRow: landingRow,
      resolution: resolution,
      levelCompleted: nextState.objectivesComplete && nextState.mode == GameMode.level,
      gameOver: nextState.isGameOver,
    );
  }

  List<GameState> _appendHistory(GameState previous) {
    final history = List<GameState>.of(previous.undoHistory)..add(previous);
    if (history.length > maxUndoDepth) {
      history.removeRange(0, history.length - maxUndoDepth);
    }
    return history;
  }

  /// Replaces the current state - used by boosters and by the debug tools.
  void replaceState(GameState newState) {
    _state = newState;
  }

  /// Snapshot of the current session for persistence.
  GameStateCore toCore() {
    final s = _state;
    return GameStateCore(
      board: s.board,
      nextBlockId: s.nextBlockId,
      nextBlockValue: s.nextBlockValue,
      stats: s.stats,
      score: s.score,
      movesUsed: s.movesUsed,
      rngState: s.rngState,
    );
  }
}
