import 'block_state.dart';

/// A single block moving from one cell to another because gravity pulled it
/// down after blocks below it were removed by a merge.
class BlockMove {
  const BlockMove({
    required this.blockId,
    required this.fromRow,
    required this.fromColumn,
    required this.toRow,
    required this.toColumn,
  });

  final int blockId;
  final int fromRow;
  final int fromColumn;
  final int toRow;
  final int toColumn;

  bool get didMove => fromRow != toRow || fromColumn != toColumn;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': blockId,
        'from': <int>[fromRow, fromColumn],
        'to': <int>[toRow, toColumn],
      };
}

/// One completed merge, emitted by the engine so the Flame layer can animate
/// exactly what happened and in which order.
///
/// ```text
/// MergeEvent(
///   sourceBlockIds: [7, 12],
///   targetBlockId:  19,
///   oldValue:       8,
///   newValue:       16,
///   row: 11, column: 3,
///   chainStep: 1,   // second wave of a chain reaction
/// )
/// ```
class MergeEvent {
  const MergeEvent({
    required this.sourceBlockIds,
    required this.targetBlockId,
    required this.oldValue,
    required this.newValue,
    required this.row,
    required this.column,
    required this.chainStep,
    required this.scoreGained,
  });

  /// Ids of the blocks that were consumed.
  final List<int> sourceBlockIds;

  /// Id of the block that was produced.
  final int targetBlockId;

  /// Value of every consumed block (they are always equal).
  final int oldValue;

  /// `oldValue * 2`.
  final int newValue;

  /// Cell the produced block occupies.
  final int row;
  final int column;

  /// 0 for a merge triggered directly by the drop, 1+ for chain reactions.
  final int chainStep;

  /// Score awarded for this specific merge.
  final int scoreGained;

  /// `true` when this merge happened as part of a chain reaction.
  bool get isChainMerge => chainStep > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sources': sourceBlockIds,
        'target': targetBlockId,
        'old': oldValue,
        'new': newValue,
        'row': row,
        'column': column,
        'chain': chainStep,
        'score': scoreGained,
      };
}

/// One atomic step of a resolution: gravity is applied, then every available
/// merge group is resolved. The Flame layer plays these back in order.
class BoardTransition {
  const BoardTransition({
    required this.board,
    required this.moves,
    required this.merges,
  });

  /// The board state after this step.
  final GameBoard board;

  /// Blocks that fell during this step (may be empty).
  final List<BlockMove> moves;

  /// Merges that completed during this step (may be empty on the final,
  /// merge-free settling step).
  final List<MergeEvent> merges;

  bool get hasMerges => merges.isNotEmpty;
}

/// The complete, deterministic outcome of resolving a board to a stable state.
class MergeResolution {
  const MergeResolution({
    required this.transitions,
    required this.board,
    required this.events,
    required this.scoreGained,
    required this.mergeCount,
    required this.longestChain,
    required this.highestValue,
    required this.nextBlockId,
  });

  static final MergeResolution empty = MergeResolution(
    transitions: <BoardTransition>[],
    board: GameBoard(rows: 0, columns: 0),
    events: <MergeEvent>[],
    scoreGained: 0,
    mergeCount: 0,
    longestChain: 0,
    highestValue: 0,
    nextBlockId: 1,
  );

  /// Ordered steps the animation layer should replay.
  final List<BoardTransition> transitions;

  /// Final, stable board.
  final GameBoard board;

  /// Flattened list of every merge, in execution order.
  final List<MergeEvent> events;

  final int scoreGained;
  final int mergeCount;

  /// Longest chain reaction produced by this resolution.
  final int longestChain;

  /// Highest value present on the final board.
  final int highestValue;

  /// Next free block id after the resolution consumed ids.
  final int nextBlockId;

  bool get hadMerges => events.isNotEmpty;
}

/// A set of blocks that are eligible to merge.
class MergeGroup {
  const MergeGroup(this.members);

  final List<BlockState> members;

  int get value => members.isEmpty ? 0 : members.first.value;
  int get size => members.length;
  bool get canMerge => members.length >= 2;
}
