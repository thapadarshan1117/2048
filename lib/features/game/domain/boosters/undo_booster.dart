import '../game_state.dart';
import 'booster.dart';

/// Restores the previous valid board state.
///
/// Undo is a pure state rollback: the engine keeps a bounded history of
/// immutable states, so "undo" is simply popping one off the stack. Nothing is
/// re-simulated, which guarantees the restored board is byte-identical to what
/// the player actually saw.
class UndoBooster implements Booster {
  const UndoBooster();

  @override
  String get id => 'undo';

  @override
  String get nameKey => 'booster_undo_name';

  @override
  String get descriptionKey => 'booster_undo_description';

  @override
  int get price => 60;

  @override
  bool canUse(BoosterContext context) => context.state.canUndo;

  @override
  BoosterOutcome apply(BoosterContext context) {
    final state = context.state;
    if (!canUse(context)) {
      return BoosterOutcome(
        state: state,
        effect: BoosterEffectKind.undo,
        applied: false,
        rejectionKey: BoosterOutcome.rejectionNoUndo,
      );
    }

    final history = List<GameState>.of(state.undoHistory);
    final previous = history.removeLast();
    final restored = previous.copyWith(
      mode: state.mode,
      level: state.level,
      undoHistory: history,
      isGameOver: false,
    );

    return BoosterOutcome(
      state: restored,
      effect: BoosterEffectKind.undo,
      affectedBlockIds: restored.board.blocks.map((b) => b.id).toList(),
    );
  }
}
