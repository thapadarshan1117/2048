import '../game_state.dart';
import 'booster.dart';

/// "+1" - doubles the value of the selected block.
class UpgradeBooster implements Booster {
  const UpgradeBooster();

  @override
  String get id => 'upgrade';

  @override
  String get nameKey => 'booster_upgrade_name';

  @override
  String get descriptionKey => 'booster_upgrade_description';

  @override
  int get price => 200;

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
    final target = targetId == null ? null : state.board.blockById(targetId);

    if (target == null || !canUse(context)) {
      return BoosterOutcome(
        state: state,
        effect: BoosterEffectKind.upgrade,
        applied: false,
        rejectionKey: BoosterOutcome.rejectionNoTarget,
      );
    }

    final upgraded = target.copyWith(value: target.doubledValue);
    final settled = BoosterSupport.settle(
      state.copyWith(board: state.board.withBlock(upgraded)),
    );

    return BoosterOutcome(
      state: settled.state,
      effect: BoosterEffectKind.upgrade,
      transitions: settled.transitions,
      affectedBlockIds: <int>[target.id],
    );
  }
}
