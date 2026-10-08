import '../game_state.dart';
import 'booster.dart';

/// Removes one selected block, then lets gravity and merges resolve.
class HammerBooster implements Booster {
  const HammerBooster();

  @override
  String get id => 'hammer';

  @override
  String get nameKey => 'booster_hammer_name';

  @override
  String get descriptionKey => 'booster_hammer_description';

  @override
  int get price => 90;

  @override
  bool get requiresTargetBlock => true;

  @override
  bool canUse(BoosterContext context) {
    final id = context.selectedBlockId;
    if (id == null) return false;
    return context.state.board.blockById(id) != null;
  }

  @override
  BoosterOutcome apply(BoosterContext context) {
    final state = context.state;
    final targetId = context.selectedBlockId;
    if (targetId == null || !canUse(context)) {
      return BoosterOutcome(
        state: state,
        effect: BoosterEffectKind.remove,
        applied: false,
        rejectionKey: BoosterOutcome.rejectionNoTarget,
      );
    }

    final removed = state.board.withoutBlock(targetId);
    final settled = BoosterSupport.settle(state.copyWith(board: removed));
    return BoosterOutcome(
      state: settled.state,
      effect: BoosterEffectKind.remove,
      transitions: settled.transitions,
      affectedBlockIds: <int>[targetId],
    );
  }
}
