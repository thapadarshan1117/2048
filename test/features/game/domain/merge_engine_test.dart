import 'package:flutter_test/flutter_test.dart';
import 'package:merge_drop/features/game/domain/block_state.dart';
import 'package:merge_drop/features/game/domain/game_board.dart';
import 'package:merge_drop/features/game/domain/merge_engine.dart';
import 'package:merge_drop/features/game/domain/merge_event.dart';

/// Board helpers, mirroring `tool/mirror/tests/helpers.py`.
GameBoard boardFrom(List<List<int?>> values) {
  final rows = values.length;
  final columns = values.first.length;
  final grid = List<List<BlockState?>>.generate(
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
  );
  return GameBoard.fromCells(rows, columns, grid);
}

List<List<int?>> values(GameBoard board) => List<List<int?>>.generate(
      board.rows,
      (r) => List<int?>.generate(
        board.columns,
        (c) => board.cells[r][c]?.value,
      ),
    );

List<int?> bottomRow(GameBoard board) => values(board).last;

void main() {
  group('MergeEngine', () {
    test('two equal blocks merge into one doubled block', () {
      final board = boardFrom(<List<int?>>[
        <int?>[null, null, null, null],
        <int?>[null, null, null, null],
        <int?>[null, null, null, null],
        <int?>[2, 2, null, null],
      ]);

      final resolution = const MergeEngine().resolve(
        board: board,
        nextBlockId: 100,
      );

      expect(resolution.mergeCount, 1);
      expect(resolution.events.single.newValue, 4);
      expect(bottomRow(resolution.board), <int?>[4, null, null, null]);
    });

    test('a merge produces exactly one block and conserves total value', () {
      final board = boardFrom(<List<int?>>[
        <int?>[4, 4, null, null],
        <int?>[4, 4, null, null],
      ]);

      final before = board.blocks.fold<int>(0, (sum, b) => sum + b.value);
      final resolution = const MergeEngine().resolve(
        board: board,
        nextBlockId: 1,
      );
      final after =
          resolution.board.blocks.fold<int>(0, (sum, b) => sum + b.value);

      expect(before, after);
      expect(resolution.board.blockCount, 2);
    });

    test('a staircase of equal blocks resolves in one wave', () {
      // Independent pairs all merge in the same wave, not bottom-up in
      // sequence. This is the documented engine behaviour.
      final board = boardFrom(<List<int?>>[
        <int?>[2, null, 2, null],
        <int?>[null, 2, null, 2],
      ]);

      final resolution = const MergeEngine().resolve(
        board: board,
        nextBlockId: 1,
      );

      expect(resolution.mergeCount, 2);
      expect(resolution.events.map((e) => e.newValue),
          everyElement(4));
    });

    test('a chain reaction resolves automatically', () {
      // Dropping onto a column of 2,2,4 creates a 4 then a 8 in one cascade.
      final board = boardFrom(<List<int?>>[
        <int?>[null, null, null, null],
        <int?>[2, null, null, null],
        <int?>[2, null, null, null],
        <int?>[4, null, null, null],
      ]);

      final resolution = const MergeEngine().resolve(
        board: board,
        nextBlockId: 1,
      );

      expect(resolution.mergeCount, 2);
      expect(resolution.longestChain, 1);
      final produced = resolution.events.map((e) => e.newValue).toSet();
      expect(produced, <int>{4, 8});
      expect(resolution.board.blocks.single.value, 8);
    });

    test('score grows with the chain step', () {
      final engine = const MergeEngine();
      final first = engine.resolve(
        board: boardFrom(<List<int?>>[
          <int?>[null, null, null, null],
          <int?>[null, null, null, null],
          <int?>[null, null, null, null],
          <int?>[8, 8, null, null],
        ]),
        nextBlockId: 1,
      );
      final chained = engine.resolve(
        board: boardFrom(<List<int?>>[
          <int?>[null, null, null, null],
          <int?>[8, null, null, null],
          <int?>[8, null, null, null],
          <int?>[16, null, null, null],
        ]),
        nextBlockId: 1,
      );

      // Both produce a 16, but the chained one earns the combo multiplier.
      expect(chained.scoreGained, greaterThan(first.scoreGained));
    });

    test('block ids are never reused', () {
      final board = boardFrom(<List<int?>>[
        <int?>[2, 2, 2, 2],
      ]);
      final resolution = const MergeEngine().resolve(
        board: board,
        nextBlockId: 500,
      );
      expect(
        resolution.board.blocks.every((b) => b.id >= 500),
        isTrue,
        reason: 'merged blocks must get fresh ids above the caller watermark',
      );
    });

    test('an empty board stays empty', () {
      final board = GameBoard.empty(rows: 12, columns: 6);
      final resolution = const MergeEngine().resolve(
        board: board,
        nextBlockId: 1,
      );
      expect(resolution.board.blockCount, 0);
      expect(resolution.mergeCount, 0);
    });

    test('preferredAnchorBlockId keeps the merge under the dropped block', () {
      // Two vertical pairs of 2s side by side: the anchor of the pair the
      // player dropped onto must win, and ties break to the smaller column.
      final board = boardFrom(<List<int?>>[
        <int?>[null, null, null, null],
        <int?>[2, 2, null, null],
        <int?>[2, 2, null, null],
        <int?>[2, 2, null, null],
      ]);
      final engine = const MergeEngine();
      final right = engine.resolve(
        board: board,
        nextBlockId: 1,
        preferredAnchorBlockId: board.cells[3][1]!.id,
      );
      expect(right.events.single.column, 1);

      final left = engine.resolve(
        board: board,
        nextBlockId: 1,
        preferredAnchorBlockId: board.cells[3][0]!.id,
      );
      expect(left.events.single.column, 0);
    });

    test('resolution terminates and reaches a stable board', () {
      final board = boardFrom(<List<int?>>[
        <int?>[2, 2, 4, 4],
        <int?>[4, 4, 2, 2],
        <int?>[2, 2, 4, 4],
        <int?>[4, 4, 2, 2],
      ]);
      final resolution = const MergeEngine().resolve(
        board: board,
        nextBlockId: 1,
      );
      // Resolving the result again must be a no-op.
      final second = const MergeEngine().resolve(
        board: resolution.board,
        nextBlockId: 1,
      );
      expect(second.mergeCount, 0);
      expect(second.board, resolution.board);
    });

    test('transitions describe gravity moves and merges in order', () {
      final board = boardFrom(<List<int?>>[
        <int?>[null, null, null, null],
        <int?>[null, null, null, null],
        <int?>[null, null, null, null],
        <int?>[2, 2, null, null],
      ]);
      final resolution = const MergeEngine().resolve(
        board: board,
        nextBlockId: 1,
      );
      expect(resolution.transitions, isNotEmpty);
      final last = resolution.transitions.last;
      expect(last.hasMerges, isTrue);
      expect(last.merges.single, isA<MergeEvent>());
    });
  });
}
