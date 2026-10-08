import 'package:flutter_test/flutter_test.dart';
import 'package:merge_drop/features/game/domain/block_state.dart';
import 'package:merge_drop/features/game/domain/game_board.dart';

GameBoard _board(List<List<int?>> values) {
  final rows = values.length;
  final columns = values.first.length;
  return GameBoard.fromCells(
    rows,
    columns,
    List<List<BlockState?>>.generate(
      rows,
      (r) => List<BlockState?>.generate(
        columns,
        (c) => values[r][c] == null
            ? null
            : BlockState(
                id: r * columns + c + 1,
                value: values[r][c]!,
                row: r,
                column: c,
              ),
      ),
    ),
  );
}

void main() {
  group('GameBoard', () {
    test('an empty board has a legal drop in every column', () {
      final board = GameBoard.empty(rows: 12, columns: 6);
      expect(board.hasLegalDrop, isTrue);
      expect(board.blockCount, 0);
    });

    test('a full board has no legal drop', () {
      final board = _board(List<List<int?>>.generate(
        12,
        (_) => <int?>[2, 4, 8, 16, 32, 64],
      ));
      expect(board.hasLegalDrop, isFalse);
    });

    test('landingRowFor returns the lowest free cell in a column', () {
      final board = _board(<List<int?>>[
        <int?>[null, null],
        <int?>[null, null],
        <int?>[2, null],
        <int?>[4, null],
      ]);
      expect(board.findLandingRow(0), 2);
      expect(board.findLandingRow(1), 3);
    });

    test('landingRowFor returns null for a full column', () {
      final board = _board(<List<int?>>[
        <int?>[2],
        <int?>[4],
      ]);
      expect(board.findLandingRow(0), isNull);
    });

    test('a restricted column refuses drops through the engine', () {
      final board = _board(<List<int?>>[
        <int?>[null, null],
        <int?>[null, null],
        <int?>[null, null],
        <int?>[null, null],
      ]);
      final restriction = const BoardRestriction.restrictedColumns(<int>{1});
      expect(restriction.allows(3, 0), isTrue);
      expect(restriction.allows(3, 1), isFalse);
      expect(board.findLandingRow(0), 3);
    });

    test('a height limit seals the top rows', () {
      // topRow 2 means only rows 2..3 may hold a block.
      const restriction = BoardRestriction.maxHeight(2);
      expect(restriction.allows(0, 0), isFalse);
      expect(restriction.allows(1, 0), isFalse);
      expect(restriction.allows(2, 0), isTrue);
      expect(restriction.allows(3, 0), isTrue);
      expect(restriction.kind, 'maxHeight');
    });

    test('withBlock and withoutBlock keep every other block', () {
      final board = _board(<List<int?>>[
        <int?>[null, null],
        <int?>[2, 4],
      ]);
      final withNew = board.withBlock(
        const BlockState(id: 50, value: 8, row: 0, column: 0),
      );
      expect(withNew.blockCount, 3);
      final without = withNew.withoutBlock(50);
      expect(without.blockCount, 2);
      expect(without.cells[1][0]!.value, 2);
    });

    test('round-trips through JSON', () {
      final board = _board(<List<int?>>[
        <int?>[null, 4],
        <int?>[2, 8],
      ]);
      final restored = GameBoard.fromJson(board.toJson());
      expect(restored.values, board.values);
      expect(restored.toJson(), board.toJson());
      expect(restored.rows, board.rows);
      expect(restored.columns, board.columns);
    });
  });
}
