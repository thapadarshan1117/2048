import 'block_state.dart';
import 'game_board.dart';
import 'merge_event.dart';
import 'score_calculator.dart';

/// The deterministic merge engine.
///
/// Responsibilities:
///  1. apply gravity so blocks rest on the floor / on other blocks,
///  2. discover every group of adjacent equal blocks,
///  3. resolve each group into pairs and double them,
///  4. repeat until the board is stable.
///
/// The engine is pure: it takes a [GameBoard] and returns a [MergeResolution]
/// describing *every* intermediate step. Nothing here knows about Flutter,
/// Flame, widgets or time, which means the whole cascade can be replayed by
/// the animation layer, unit-tested, or simulated head-lessly.
class MergeEngine {
  const MergeEngine({this.score = const ScoreCalculator()});

  final ScoreCalculator score;

  /// Resolves [board] to a stable state.
  ///
  /// [nextBlockId] is the first unused block id; the returned resolution
  /// reports the next free id so a caller can keep allocating ids safely.
  MergeResolution resolve({
    required GameBoard board,
    required int nextBlockId,
    int? preferredAnchorBlockId,
  }) {
    if (board.rows <= 0 || board.columns <= 0) return MergeResolution.empty;

    var current = board;

    // Defensive id allocation: never hand out an id that is already in use,
    // even if a caller (or a restored snapshot) passes a stale counter. Id
    // collisions would silently corrupt the board because blocks are keyed by
    // id throughout the engine.
    var nextId = nextBlockId < 1 ? 1 : nextBlockId;
    final highestExistingId = _highestBlockId(board);
    if (nextId <= highestExistingId) nextId = highestExistingId + 1;
    final transitions = <BoardTransition>[];
    final events = <MergeEvent>[];
    var totalScore = 0;
    var chainStep = 0;
    var longestChain = 0;

    // Each merge removes exactly one block, so a board can never produce more
    // than `rows * columns` merge waves. The bound is a defensive guard.
    final maxSteps = board.rows * board.columns + 2;

    for (var step = 0; step < maxSteps; step++) {
      final gravity = applyGravity(current);
      current = gravity.board;

      final groups = findMergeGroups(current);
      if (groups.isEmpty) {
        transitions.add(
          BoardTransition(
            board: current,
            moves: gravity.moves,
            merges: const <MergeEvent>[],
          ),
        );
        break;
      }

      final stepEvents = <MergeEvent>[];
      var stepScore = 0;
      final consumed = <int>{};
      final produced = <BlockState>[];

      for (final group in groups) {
        if (!group.canMerge) continue;
        for (final pair in _pairGroup(group.members)) {
          final a = pair.$1;
          final b = pair.$2;
          final newValue = a.value * 2;
          final anchor = _anchorOf(a, b, preferredAnchorBlockId);
          final block = BlockState(
            id: nextId++,
            value: newValue,
            row: anchor.row,
            column: anchor.column,
          );
          consumed
            ..add(a.id)
            ..add(b.id);
          produced.add(block);

          final gained = score.mergeScore(newValue: newValue, chainStep: chainStep) +
              score.bigMergeBonus(newValue);
          stepScore += gained;
          stepEvents.add(
            MergeEvent(
              sourceBlockIds: <int>[a.id, b.id],
              targetBlockId: block.id,
              oldValue: a.value,
              newValue: newValue,
              row: block.row,
              column: block.column,
              chainStep: chainStep,
              scoreGained: gained,
            ),
          );
        }
      }

      // Rebuild the grid in a single pass instead of calling
      // `withoutBlock`/`withBlock` per block: a merge wave can touch dozens of
      // blocks and this keeps the hot loop allocation-light on mid-range
      // devices (and lets the simulator run thousands of games quickly).
      final grid = List<List<BlockState?>>.generate(
        current.rows,
        (r) => List<BlockState?>.of(current.cells[r]),
      );
      for (var r = 0; r < current.rows; r++) {
        for (var c = 0; c < current.columns; c++) {
          final block = grid[r][c];
          if (block != null && consumed.contains(block.id)) {
            grid[r][c] = null;
          }
        }
      }
      for (final block in produced) {
        grid[block.row][block.column] = block;
      }
      current = GameBoard.fromCells(current.rows, current.columns, grid);
      events.addAll(stepEvents);
      totalScore += stepScore;
      longestChain = chainStep + 1;
      transitions.add(
        BoardTransition(
          board: current,
          moves: gravity.moves,
          merges: stepEvents,
        ),
      );
      chainStep++;
    }

    return MergeResolution(
      transitions: transitions,
      board: current,
      events: events,
      scoreGained: totalScore,
      mergeCount: events.length,
      longestChain: longestChain,
      highestValue: highestValue(current),
      nextBlockId: nextId,
    );
  }

  /// Highest block id present on [board], or 0 when the board is empty.
  int _highestBlockId(GameBoard board) {
    var highest = 0;
    for (final block in board.blocks) {
      if (block.id > highest) highest = block.id;
    }
    return highest;
  }

  /// Pulls every block down to its lowest legal cell, column by column.
  ///
  /// Returns the settled board together with the list of moves so the
  /// animation layer can show blocks falling after a merge clears space.
  ({GameBoard board, List<BlockMove> moves}) applyGravity(GameBoard board) {
    final moves = <BlockMove>[];
    final grid = List<List<BlockState?>>.generate(
      board.rows,
      (r) => List<BlockState?>.of(board.cells[r]),
    );

    for (var c = 0; c < board.columns; c++) {
      var writeRow = board.rows - 1;
      for (var r = board.rows - 1; r >= 0; r--) {
        final block = grid[r][c];
        if (block == null) continue;
        if (r != writeRow) {
          grid[r][c] = null;
          grid[writeRow][c] = block.moveTo(row: writeRow, column: c);
          moves.add(
            BlockMove(
              blockId: block.id,
              fromRow: r,
              fromColumn: c,
              toRow: writeRow,
              toColumn: c,
            ),
          );
        }
        writeRow--;
      }
    }

    return (
      board: GameBoard.fromCells(board.rows, board.columns, grid),
      moves: moves,
    );
  }

  /// Every group of two or more orthogonally connected blocks that share the
  /// same value.
  ///
  /// Groups are returned in row-major discovery order, which makes the
  /// resolution order stable for a given board.
  List<MergeGroup> findMergeGroups(GameBoard board) {
    final groups = <MergeGroup>[];
    final visited = <int>{};

    for (var r = 0; r < board.rows; r++) {
      for (var c = 0; c < board.columns; c++) {
        final block = board.cells[r][c];
        if (block == null) continue;
        if (!visited.add(block.id)) continue;

        final group = board.connectedGroupOf(r, c);
        for (final member in group) {
          visited.add(member.id);
        }
        if (group.length >= 2) {
          groups.add(MergeGroup(group.toList()));
        }
      }
    }
    return groups;
  }

  /// Highest value currently on the board (0 when empty).
  int highestValue(GameBoard board) {
    var highest = 0;
    for (final block in board.blocks) {
      if (block.value > highest) highest = block.value;
    }
    return highest;
  }

  /// Splits a same-valued group into pairs.
  ///
  /// Pairing is deterministic: blocks are considered lowest-first, and each
  /// block is paired with its closest group-mate, preferring an orthogonally
  /// adjacent partner. An odd block is simply left behind and will be paired
  /// on the next resolution wave if gravity brings it a partner.
  List<(BlockState, BlockState)> _pairGroup(List<BlockState> members) {
    final pool = members.toList()
      ..sort((a, b) {
        final byRow = b.row.compareTo(a.row); // lower block first
        if (byRow != 0) return byRow;
        return a.column.compareTo(b.column);
      });

    final pairs = <(BlockState, BlockState)>[];
    while (pool.length >= 2) {
      final a = pool.removeAt(0);
      BlockState? best;
      var bestDistance = 0;
      var bestIsAdjacent = false;

      for (final candidate in pool) {
        final distance = _manhattan(a, candidate);
        final adjacent = distance == 1;
        if (best == null) {
          best = candidate;
          bestDistance = distance;
          bestIsAdjacent = adjacent;
          continue;
        }
        if (adjacent && !bestIsAdjacent) {
          best = candidate;
          bestDistance = distance;
          bestIsAdjacent = true;
          continue;
        }
        if (adjacent == bestIsAdjacent && distance < bestDistance) {
          best = candidate;
          bestDistance = distance;
        }
      }

      if (best == null) break;
      pool.remove(best);
      pairs.add((a, best));
    }
    return pairs;
  }

  /// Cell the merged block occupies.
  ///
  /// Preference order:
  ///  1. the cell of [preferredAnchorBlockId] when it takes part in the merge,
  ///     so a merge triggered by a drop always resolves *where the player
  ///     aimed* - this is what makes the drop feel responsive;
  ///  2. otherwise the lower of the two blocks (the one closer to the floor),
  ///     which keeps cascades visually anchored to the bottom;
  ///  3. ties broken to the left for a stable, predictable layout.
  BlockState _anchorOf(BlockState a, BlockState b, int? preferredAnchorBlockId) {
    if (preferredAnchorBlockId != null) {
      if (a.id == preferredAnchorBlockId) return a;
      if (b.id == preferredAnchorBlockId) return b;
    }
    if (a.row != b.row) return a.row > b.row ? a : b;
    return a.column < b.column ? a : b;
  }

  int _manhattan(BlockState a, BlockState b) =>
      (a.row - b.row).abs() + (a.column - b.column).abs();
}
