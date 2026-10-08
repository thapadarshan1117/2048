import 'block_state.dart';
import 'game_state.dart';
import 'merge_event.dart';

/// Why a drop was refused.
enum DropRejection {
  none,
  invalidColumn,
  columnFull,
  boardFull,
  sessionOver;

  String get messageKey => switch (this) {
        DropRejection.none => 'drop_error_none',
        DropRejection.invalidColumn => 'drop_error_invalid_column',
        DropRejection.columnFull => 'drop_error_column_full',
        DropRejection.boardFull => 'drop_error_board_full',
        DropRejection.sessionOver => 'drop_error_session_over',
      };
}

/// Everything the presentation layer needs in order to play a drop.
///
/// The logical outcome is already final when this object is returned; the
/// Flame layer only animates what is described here.
class DropOutcome {
  const DropOutcome({
    required this.accepted,
    required this.rejection,
    required this.state,
    this.droppedBlock,
    this.landingRow,
    this.resolution,
    this.levelCompleted = false,
    this.gameOver = false,
  });

  final bool accepted;
  final DropRejection rejection;

  /// State after the drop was applied.
  final GameState state;

  /// The block that was dropped (its position is the landing row).
  final BlockState? droppedBlock;

  final int? landingRow;

  /// Merge cascade produced by the drop.
  final MergeResolution? resolution;

  /// `true` when the level objectives are met after this drop.
  final bool levelCompleted;

  /// `true` when no legal drop remains.
  final bool gameOver;

  bool get hadMerges => resolution?.hadMerges ?? false;
  int get scoreGained => resolution?.scoreGained ?? 0;
  List<MergeEvent> get mergeEvents => resolution?.events ?? const <MergeEvent>[];
}
