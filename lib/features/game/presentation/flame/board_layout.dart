import 'package:flame/components.dart';

/// Responsive geometry for the playfield.
///
/// Every size is derived from the area the game is given, so the board works on
/// any phone, tablet or window without a single hardcoded pixel.
class BoardLayout {
  const BoardLayout({
    required this.boardSize,
    required this.rows,
    required this.columns,
    required this.cellSize,
    required this.origin,
    required this.gap,
  });

  factory BoardLayout.compute(
    Vector2 boardSize,
    int rows,
    int columns, {
    double gapRatio = 0.09,
    double marginRatio = 0.035,
  }) {
    final margin = boardSize.x * marginRatio;
    final usable = Vector2(
      boardSize.x - margin * 2,
      boardSize.y - margin * 2,
    );
    final gap = usable.x * gapRatio;
    final cellSize = Vector2(
      (usable.x - gap * (columns - 1)) / columns,
      (usable.y - gap * (rows - 1)) / rows,
    );
    // Keep blocks square: the board is taller than wide, so height decides.
    final square = cellSize.y < cellSize.x ? cellSize.y : cellSize.x;
    final origin = Vector2(
      (boardSize.x - (square * columns + gap * (columns - 1))) / 2,
      (boardSize.y - (square * rows + gap * (rows - 1))) / 2,
    );
    return BoardLayout(
      boardSize: boardSize,
      rows: rows,
      columns: columns,
      cellSize: Vector2.all(square),
      origin: origin,
      gap: gap,
    );
  }

  final Vector2 boardSize;
  final int rows;
  final int columns;
  final Vector2 cellSize;
  final Vector2 origin;

  /// Space between neighbouring cells.
  final double gap;

  /// Top-left corner of the cell at [row]/[column].
  Vector2 cellPosition(int row, int column) => Vector2(
        origin.x + column * (cellSize.x + gap),
        origin.y + row * (cellSize.y + gap),
      );

  /// Centre of the cell at [row]/[column].
  Vector2 cellCenter(int row, int column) =>
      cellPosition(row, column) + (cellSize / 2);

  /// Column whose cell contains [x], or `null`.
  int? columnAt(double x) {
    for (var c = 0; c < columns; c++) {
      final left = origin.x + c * (cellSize.x + gap);
      if (x >= left - gap / 2 && x < left + cellSize.x + gap / 2) return c;
    }
    return null;
  }

  /// `true` when [x] is over the board at all.
  bool containsX(double x) => x >= origin.x - gap && x <= boardSize.x - origin.x + gap;
}
