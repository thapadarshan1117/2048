import '../game_state.dart';
import 'booster.dart';

/// Turns the selected block into a copy of one of its neighbours so that it
/// merges immediately.
///
/// The neighbour is chosen deterministically (lowest value first, then the
/// lowest cell) so the result is reproducible for a given board.
class WildcardBooster implements Booster {
  const WildcardBooster();

  @override
  String get id => 'wildcard';

  @override
  String get nameKey => 'booster_wildcard_name';

  @override
  String get descriptionKey => 'booster_wildcard_description';

  @override
  int get price => 150;

  @override
  bool get requiresTargetBlock => true;

  @override
  bool canUse(BoosterContext context) {
    final id = context.selectedBlockId;
    if (id == null) return false;
    final block = context.state.board.blockById(id);
    if (block == null) return false;
    return context.state.board.getNeighbors(block.row, block.column).isNotEmpty;
  }

  @override
  BoosterOutcome apply(BoosterContext context) {
    final state = context.state;
    final targetId = context.selectedBlockId;
    final target = targetId == null ? null : state.board.blockById(targetId);

    if (target == null || !canUse(context)) {
      return BoosterOutcome(
        state: state,
        effect: BoosterEffectKind.wildcard,
        applied: false,
        rejectionKey: BoosterOutcome.rejectionNoTarget,
      );
    }

    final neighbors = state.board.getNeighbors(target.row, target.column)
      ..sort((a, b) {
        final byValue = a.value.compareTo(b.value);
        if (byValue != 0) return byValue;
        final byRow = a.row.compareTo(b.row);
        if (byRow != 0) return byRow;
        return a.column.compareTo(b.column);
      });

    final donor = neighbors.first;
    final mutated = target.copyWith(value: donor.value);
    final settled = BoosterSupport.settle(state.copyWith(
      board: state.board.withBlock(mutated),
    ));

    return BoosterOutcome(
      state: settled.state,
      effect: BoosterEffectKind.wildcard,
      transitions: settled.transitions,
      affectedBlockIds: <int>[target.id],
    );
  }
}
