import 'game_mode.dart';
import 'game_state.dart';

/// A persisted, resumable game session.
///
/// Everything needed to continue *exactly* where the player left off:
/// level/mode, board, score, moves, next block, RNG state and a short undo
/// history.
class GameSnapshot {
  const GameSnapshot({
    required this.version,
    required this.mode,
    required this.core,
    this.levelId,
    this.undo = const <GameStateCore>[],
    this.savedAtMs = 0,
  });

  /// Bumped whenever the on-disk shape changes; older snapshots are discarded
  /// rather than migrated incorrectly.
  static const int currentVersion = 1;

  final int version;
  final GameMode mode;

  /// `null` for infinite mode.
  final int? levelId;

  final GameStateCore core;

  /// Most recent undo entries, oldest first.
  final List<GameStateCore> undo;

  final int savedAtMs;

  bool get isCurrentVersion => version == currentVersion;

  GameSnapshot copyWith({
    int? version,
    GameMode? mode,
    int? levelId,
    GameStateCore? core,
    List<GameStateCore>? undo,
    int? savedAtMs,
  }) {
    return GameSnapshot(
      version: version ?? this.version,
      mode: mode ?? this.mode,
      levelId: levelId ?? this.levelId,
      core: core ?? this.core,
      undo: undo ?? this.undo,
      savedAtMs: savedAtMs ?? this.savedAtMs,
    );
  }
}
