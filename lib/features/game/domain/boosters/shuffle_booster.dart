import '../game_state.dart';
import '../rng.dart';
import 'booster.dart';

/// Rearranges the blocks that are eligible to move.
///
/// Shuffling is deterministic for a given RNG state, which keeps the daily
/// challenge reproducible and the simulator stable.
class ShuffleBooster implements Booster {
  const ShuffleBooster();

  @override
  String get id => 'shuffle';

  @override
  String get nameKey => 'booster_shuffle_name';

  @override
  String get descriptionKey => 'booster_shuffle_description';

  @override
  int get price => 120;

  @override
  bool canUse(BoosterContext context) => context.state.board.blockCount >= 2;

  @override
  BoosterOutcome apply(BoosterContext context) {
    final state = context.state;
    if (!canUse(context)) {
      return BoosterOutcome(
        state: state,
        effect: BoosterEffectKind.shuffle,
        applied: false,
        rejectionKey: BoosterOutcome.rejectionTooFewBlocks,
      );
    }

    // Blocks are re-seated into the currently occupied cells, bottom-aligned
    // per column, so the board never gains or loses blocks.
    final board = state.board;
    final blocks = board.blocks.toList();
    final cells = <({int row, int column})>[];
    for (var c = 0; c < board.columns; c++) {
      for (var r = board.rows - 1; r >= 0; r--) {
        if (board.cells[r][c] != null) cells.add((row: r, column: c));
      }
    }

    final rng = Rng(state.rngState);
    rng.shuffle(blocks);

    var grid = board.cleared();
    for (var i = 0; i < cells.length && i < blocks.length; i++) {
      final cell = cells[i];
      final block = blocks[i].moveTo(row: cell.row, column: cell.column);
      grid = grid.withBlock(block);
    }

    final settled = BoosterSupport.settle(
      state.copyWith(board: grid, rngState: rng.state),
    );
    return BoosterOutcome(
      state: settled.state,
      effect: BoosterEffectKind.shuffle,
      transitions: settled.transitions,
      affectedBlockIds: blocks.map((b) => b.id).toList(),
    );
  }
}
