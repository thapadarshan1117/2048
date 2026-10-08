import 'package:equatable/equatable.dart';

import 'block_state.dart';

/// The logical game board.
///
/// The board is a plain immutable value object with **no** dependency on
/// Flutter, Flame or any widget type, which makes the entire rules engine
/// unit-testable in isolation.
///
/// Coordinate system:
/// ```text
///        column 0   column 1  ...  column C-1
/// row 0    [ ]        [ ]              [ ]
/// row 1    [ ]        [ ]              [ ]
///   ...
/// row R-1  [ ]        [ ]              [ ]      <- floor
/// ```
class GameBoard extends Equatable {
  GameBoard({
    required this.rows,
    required this.columns,
    Iterable<BlockState> blocks = const <BlockState>[],
  }) : cells = _buildCells(rows, columns, blocks);

  GameBoard._({
    required this.rows,
    required this.columns,
    required this.cells,
  });

  /// An empty board of [rows] x [columns].
  static GameBoard empty({required int rows, required int columns}) =>
      GameBoard(rows: rows, columns: columns);

  /// Builds the 2-D cell grid from a flat list of blocks.
  static List<List<BlockState?>> _buildCells(
    int rows,
    int columns,
    Iterable<BlockState> blocks,
  ) {
    final grid = List<List<BlockState?>>.generate(
      rows,
      (_) => List<BlockState?>.filled(columns, null),
    );
    for (final block in blocks) {
      assert(
        block.row >= 0 && block.row < rows && block.column >= 0 && block.column < columns,
        'Block $block is outside the ${rows}x$columns board',
      );
      grid[block.row][block.column] = block;
    }
    return grid;
  }

  final int rows;
  final int columns;

  /// `cells[row][column]` - `null` means the cell is empty.
  final List<List<BlockState?>> cells;

  bool get isInBounds(int row, int column) =>
      row >= 0 && row < rows && column >= 0 && column < columns;

  BlockState? getBlock(int row, int column) {
    if (!isInBounds(row, column)) return null;
    return cells[row][column];
  }

  BlockState? blockById(int id) {
    for (final row in cells) {
      for (final block in row) {
        if (block != null && block.id == id) return block;
      }
    }
    return null;
  }

  bool isEmpty(int row, int column) => getBlock(row, column) == null;

  bool isFull(int row, int column) => !isEmpty(row, column);

  /// Every block currently on the board, in row-major order.
  Iterable<BlockState> get blocks =>
      cells.expand((row) => row).whereType<BlockState>();

  int get blockCount => blocks.length;

  /// The board as a grid of values (`null` for an empty cell).
  ///
  /// Handy for assertions, debugging and the dev tools.
  List<List<int?>> get values => List<List<int?>>.generate(
        rows,
        (r) => List<int?>.generate(columns, (c) => cells[r][c]?.value),
      );

  /// `true` when [column] still has a free cell at the bottom.
  bool hasFreeCellInColumn(int column) => findLandingRow(column) != null;

  /// `true` when every cell is occupied - the board can never be filled in
  /// normal play because gravity compacts columns, but the check is kept for
  /// defensive correctness and for the validator/simulator.
  bool get isCompletelyFull => blockCount == rows * columns;

  /// Returns the lowest (largest row index) empty row in [column], or `null`
  /// when the column is completely full.
  ///
  /// This is the *logical* landing row and is always computed before any
  /// animation starts, so the visuals merely replay a decided outcome.
  int? findLandingRow(int column) {
    if (column < 0 || column >= columns) return null;
    for (var row = rows - 1; row >= 0; row--) {
      if (cells[row][column] == null) return row;
    }
    return null;
  }

  /// `true` when at least one column still accepts a block.
  bool get hasLegalDrop => List<bool>.generate(
        columns,
        (c) => findLandingRow(c) != null,
      ).any((legal) => legal);

  /// The four orthogonal neighbours of a cell, clamped to the board.
  List<BlockState> getNeighbors(int row, int column) {
    final result = <BlockState>[];
    const deltas = <int>[-1, 1];
    for (final d in deltas) {
      final up = getBlock(row + d, column);
      if (up != null) result.add(up);
      final side = getBlock(row, column + d);
      if (side != null) result.add(side);
    }
    return result;
  }

  /// All blocks that share the same value and are orthogonally connected to
  /// the block at [row]/[column] (including itself).
  ///
  /// Used by the merge engine to discover merge groups deterministically.
  Set<BlockState> connectedGroupOf(int row, int column) {
    final seed = getBlock(row, column);
    if (seed == null) return <BlockState>{};
    final seen = <int>{seed.id};
    final stack = <BlockState>[seed];
    final group = <BlockState>{};
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      group.add(current);
      for (final neighbor in getNeighbors(current.row, current.column)) {
        if (neighbor.value != seed.value) continue;
        if (!seen.add(neighbor.id)) continue;
        stack.add(neighbor);
      }
    }
    return group;
  }

  /// Returns a copy of the board with [block] written at its own coordinates.
  ///
  /// The original board is never mutated: every engine step produces a new
  /// board, which is what makes undo, replay and snapshotting trivial.
  GameBoard withBlock(BlockState block) {
    if (!isInBounds(block.row, block.column)) return this;
    final next = _copyGrid();
    next[block.row][block.column] = block;
    return GameBoard._(rows: rows, columns: columns, cells: next);
  }

  /// Low-level constructor used by the merge engine, which already owns a grid
  /// it has finished mutating. Callers must not retain or mutate [cells].
  factory GameBoard.fromCells(
    int rows,
    int columns,
    List<List<BlockState?>> cells,
  ) {
    return GameBoard._(rows: rows, columns: columns, cells: cells);
  }

  /// Returns a copy of the board with the block identified by [id] removed.
  GameBoard withoutBlock(int id) {
    var changed = false;
    final next = _copyGrid();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        final block = next[r][c];
        if (block != null && block.id == id) {
          next[r][c] = null;
          changed = true;
        }
      }
    }
    if (!changed) return this;
    return GameBoard._(rows: rows, columns: columns, cells: next);
  }

  /// Returns a copy of the board with every block removed.
  GameBoard cleared() => GameBoard(rows: rows, columns: columns);

  /// Deep-enough copy: block objects are immutable, so copying the grid
  /// structure is sufficient to obtain full value semantics.
  GameBoard clone() => GameBoard._(rows: rows, columns: columns, cells: _copyGrid());

  List<List<BlockState?>> _copyGrid() =>
      List<List<BlockState?>>.generate(rows, (r) => List<BlockState?>.of(cells[r]));

  /// Compact serialisation used by the save system.
  ///
  /// Cells are stored as `value` only (`0` for empty) which keeps a saved
  /// board to a handful of bytes; block ids are regenerated on load.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'rows': rows,
        'columns': columns,
        'cells': List<List<int>>.generate(
          rows,
          (r) => List<int>.generate(
            columns,
            (c) => cells[r][c]?.value ?? 0,
          ),
        ),
      };

  factory GameBoard.fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as num).toInt();
    final columns = (json['columns'] as num).toInt();
    final rawCells = (json['cells'] as List<dynamic>).cast<List<dynamic>>();
    if (rawCells.length != rows) {
      throw const FormatException('Board row count does not match declared rows');
    }
    var nextId = 1;
    final blocks = <BlockState>[];
    for (var r = 0; r < rows; r++) {
      final row = rawCells[r].cast<num>();
      if (row.length != columns) {
        throw const FormatException('Board column count does not match declared columns');
      }
      for (var c = 0; c < columns; c++) {
        final value = row[c].toInt();
        if (value <= 0) continue;
        blocks.add(BlockState(id: nextId++, value: value, row: r, column: c));
      }
    }
    return GameBoard(rows: rows, columns: columns, blocks: blocks);
  }

  /// Debug/test helper: the board reduced to a grid of plain numbers.
  List<List<int?>> toValueGrid() => List<List<int?>>.generate(
        rows,
        (r) => List<int?>.generate(columns, (c) => cells[r][c]?.value),
      );

  @override
  List<Object?> get props => <Object?>[rows, columns, blockCount];

  @override
  String toString() {
    final buffer = StringBuffer('GameBoard(${rows}x$columns)\n');
    for (final row in cells) {
      buffer.writeln(row.map((b) => (b?.value ?? 0).toString().padLeft(5)).join());
    }
    return buffer.toString();
  }
}
