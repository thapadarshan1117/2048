import 'package:flutter_test/flutter_test.dart';
import 'package:merge_drop/features/game/domain/block_state.dart';
import 'package:merge_drop/features/game/domain/boosters/booster.dart';
import 'package:merge_drop/features/game/domain/boosters/booster_registry.dart';
import 'package:merge_drop/features/game/domain/boosters/hammer_booster.dart';
import 'package:merge_drop/features/game/domain/boosters/shuffle_booster.dart';
import 'package:merge_drop/features/game/domain/boosters/undo_booster.dart';
import 'package:merge_drop/features/game/domain/game_board.dart';
import 'package:merge_drop/features/game/domain/game_state.dart';

GameState _state(List<List<int?>> values, {int rngState = 7}) {
  final rows = values.length;
  final columns = values.first.length;
  final blocks = <BlockState>[];
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < columns; c++) {
      final value = values[r][c];
      if (value != null) {
        blocks.add(BlockState(id: r * columns + c + 1, value: value, row: r, column: c));
      }
    }
  }
  return GameState(
    board: GameBoard(rows: rows, columns: columns, blocks: blocks),
    nextBlockId: 100,
    nextBlockValue: 2,
    stats: const GameStats(),
    rngState: rngState,
  );
}

int _total(GameState state) =>
    state.board.blocks.fold<int>(0, (sum, b) => sum + b.value);

void main() {
  group('Booster registry', () {
    test('every core booster has a stable id', () {
      expect(BoosterRegistry.core.map((b) => b.id).toList(),
          <String>['undo', 'hammer', 'shuffle']);
    });

    test('byId finds a booster and returns null for an unknown id', () {
      expect(BoosterRegistry.byId('hammer'), isA<HammerBooster>());
      expect(BoosterRegistry.byId('nope'), isNull);
      expect(BoosterRegistry.byIdOrDefault('nope').id, 'undo');
    });

    test('every booster has localisation keys', () {
      for (final booster in BoosterRegistry.all) {
        expect(booster.nameKey.startsWith('booster_'), isTrue);
        expect(booster.descriptionKey.startsWith('booster_'), isTrue);
        expect(booster.price, greaterThan(0));
      }
    });
  });

  group('UndoBooster', () {
    test('is refused when there is no history', () {
      final state = _state(<List<int?>>[
        <int?>[null, null],
        <int?>[null, null],
      ]);
      final outcome = const UndoBooster().apply(BoosterContext(state: state));
      expect(outcome.applied, isFalse);
      expect(outcome.rejectionKey, BoosterOutcome.rejectionNoUndo);
    });

    test('restores the previous board', () {
      final state = _state(<List<int?>>[
        <int?>[null, null],
        <int?>[2, null],
      ]);
      final previous = _state(<List<int?>>[
        <int?>[null, null],
        <int?>[null, null],
      ]);
      final withHistory = state.copyWith(
        undoHistory: <GameState>[previous],
        isGameOver: true,
      );
      final outcome =
          const UndoBooster().apply(BoosterContext(state: withHistory));
      expect(outcome.applied, isTrue);
      expect(outcome.state.board.blockCount, 0);
      expect(outcome.state.isGameOver, isFalse);
      expect(outcome.effect, BoosterEffectKind.undo);
    });

    test('repeated undo walks back the history', () {
      var state = _state(<List<int?>>[
        <int?>[null, null],
        <int?>[8, null],
      ]);
      for (var i = 0; i < 3; i++) {
        state = state.copyWith(
          undoHistory: <GameState>[
            ...state.undoHistory,
            _state(<List<int?>>[
              <int?>[null, null],
              <int?>[null, null],
            ]),
          ],
        );
      }
      var depth = state.undoHistory.length;
      expect(depth, 3);
      for (var i = 0; i < depth; i++) {
        final outcome = const UndoBooster().apply(BoosterContext(state: state));
        state = outcome.state;
      }
      expect(state.canUndo, isFalse);
    });
  });

  group('HammerBooster', () {
    test('removes the targeted block', () {
      final state = _state(<List<int?>>[
        <int?>[null, null],
        <int?>[2, 4],
      ]);
      final target = state.board.cells[1][0]!.id;
      final outcome = const HammerBooster().apply(
        BoosterContext(state: state, selectedBlockId: target),
      );
      expect(outcome.applied, isTrue);
      expect(outcome.state.board.blockById(target), isNull);
      expect(outcome.effect, BoosterEffectKind.remove);
    });

    test('is refused without a target', () {
      final state = _state(<List<int?>>[
        <int?>[null, null],
        <int?>[2, 4],
      ]);
      final outcome = const HammerBooster().apply(BoosterContext(state: state));
      expect(outcome.applied, isFalse);
      expect(outcome.rejectionKey, BoosterOutcome.rejectionNoTarget);
    });
  });

  group('ShuffleBooster', () {
    test('conserves the total board value', () {
      final state = _state(<List<int?>>[
        <int?>[2, 4, 8],
        <int?>[16, 32, 64],
      ]);
      final outcome = const ShuffleBooster().apply(BoosterContext(state: state));
      expect(outcome.applied, isTrue);
      expect(outcome.state.board.blockCount, state.board.blockCount);
      expect(_total(outcome.state), _total(state));
      expect(outcome.effect, BoosterEffectKind.shuffle);
    });

    test('is refused when the board is nearly empty', () {
      final state = _state(<List<int?>>[
        <int?>[null, null],
        <int?>[2, null],
      ]);
      expect(const ShuffleBooster().canUse(BoosterContext(state: state)), isTrue);
      final empty = _state(<List<int?>>[
        <int?>[null, null],
        <int?>[null, null],
      ]);
      expect(const ShuffleBooster().canUse(BoosterContext(state: empty)), isFalse);
    });

    test('is deterministic for a given RNG state', () {
      final state = _state(<List<int?>>[
        <int?>[2, 4, 8, 16],
      ], rngState: 12345);
      final first = const ShuffleBooster().apply(BoosterContext(state: state));
      final second = const ShuffleBooster().apply(BoosterContext(state: state));
      expect(first.state.board.values, second.state.board.values);
    });
  });

  group('BoosterSupport', () {
    test('settle folds merges into the statistics', () {
      final state = _state(<List<int?>>[
        <int?>[null, null],
        <int?>[2, 2],
      ]);
      final result = BoosterSupport.settle(state);
      expect(result.state.board.blockCount, 1);
      expect(result.state.board.blocks.single.value, 4);
      expect(result.state.stats.mergeCount, 1);
      expect(result.transitions, isNotEmpty);
    });
  });
}
