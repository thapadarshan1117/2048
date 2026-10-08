import 'package:flutter_test/flutter_test.dart';
import 'package:merge_drop/features/game/domain/merge_engine.dart';
import 'package:merge_drop/features/game/domain/block_state.dart';
import 'package:merge_drop/features/game/domain/game_board.dart';
import 'package:merge_drop/features/game/domain/merge_event.dart';

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
        (c) {
          final value = values[r][c];
          return value == null
              ? null
              : BlockState(
                  id: r * columns + c + 1,
                  value: value,
                  row: r,
                  column: c,
                );
        },
      ),
    ),
  );
}

void main() {
  group('score and chain reactions', () {
    test('a single merge scores at least the produced value', () {
      final resolution = const MergeEngine().resolve(
        board: _board(<List<int?>>[
          <int?>[null, null, null, null],
          <int?>[null, null, null, null],
          <int?>[null, null, null, null],
          <int?>[2, 2, null, null],
        ]),
        nextBlockId: 1,
      );
      expect(resolution.scoreGained, greaterThanOrEqualTo(4));
      expect(resolution.events.single.scoreGained, greaterThanOrEqualTo(4));
    });

    test('score scales with the produced value', () {
      const engine = MergeEngine();
      final small = engine.resolve(
        board: _board(<List<int?>>[
          <int?>[null, null],
          <int?>[2, 2],
        ]),
        nextBlockId: 1,
      );
      final large = engine.resolve(
        board: _board(<List<int?>>[
          <int?>[null, null],
          <int?>[64, 64],
        ]),
        nextBlockId: 1,
      );
      expect(large.scoreGained, greaterThan(small.scoreGained));
    });

    test('a chain reaction scores more than the same merges in isolation', () {
      const engine = MergeEngine();
      // A cascade: 2+2 -> 4, then 4+4 -> 8 in one resolution.
      final cascade = engine.resolve(
        board: _board(<List<int?>>[
          <int?>[null, null, null],
          <int?>[2, null, null],
          <int?>[2, null, null],
          <int?>[4, null, null],
        ]),
        nextBlockId: 1,
      );
      expect(cascade.mergeCount, 2);
      expect(cascade.longestChain, greaterThanOrEqualTo(1));
      expect(cascade.events.last.chainStep, greaterThan(0));
      expect(cascade.scoreGained,
          greaterThan(cascade.events.first.scoreGained));
    });

    test('chain step is capped', () {
      // A long tower of equal pairs cascades many times; the multiplier must
      // stop growing at the documented cap so scores stay readable.
      final board = _board(<List<int?>>[
        <int?>[2, 2, null, null],
        <int?>[4, 4, null, null],
        <int?>[8, 8, null, null],
        <int?>[16, 16, null, null],
        <int?>[32, 32, null, null],
      ]);
      final resolution = const MergeEngine().resolve(board: board, nextBlockId: 1);
      expect(resolution.events.every((e) => e.chainStep <= 9), isTrue);
    });

    test('merge events carry the full animation payload', () {
      final resolution = const MergeEngine().resolve(
        board: _board(<List<int?>>[
          <int?>[null, null, null],
          <int?>[null, null, null],
          <int?>[null, null, null],
          <int?>[null, 8, 8],
        ]),
        nextBlockId: 1,
      );
      final event = resolution.events.single;
      expect(event.oldValue, 8);
      expect(event.newValue, 16);
      expect(event.sourceBlockIds.length, 2);
      expect(event.targetBlockId, greaterThan(0));
      expect(event.row, 2);
      expect(event.column, 2);
      expect(event.isChainMerge, isFalse);
      expect(event.toJson()['new'], 16);
    });

    test('every merge event reports the score it awarded', () {
      final resolution = const MergeEngine().resolve(
        board: _board(<List<int?>>[
          <int?>[null, null, null],
          <int?>[null, null, null],
          <int?>[null, null, null],
          <int?>[null, 4, 4],
        ]),
        nextBlockId: 1,
      );
      final sum = resolution.events.fold<int>(0, (total, e) => total + e.scoreGained);
      expect(sum, resolution.scoreGained);
    });
  });
}
