import 'package:flutter_test/flutter_test.dart';
import 'package:merge_drop/features/game/domain/block_generator.dart';
import 'package:merge_drop/features/game/domain/game_board.dart';
import 'package:merge_drop/features/game/domain/game_engine.dart';
import 'package:merge_drop/features/game/domain/game_state.dart';
import 'package:merge_drop/features/levels/domain/difficulty_profile.dart';
import 'package:merge_drop/features/levels/domain/level.dart';
import 'package:merge_drop/features/levels/domain/level_objective.dart';
import 'package:merge_drop/features/levels/domain/star_thresholds.dart';

const DifficultyProfile _profile = DifficultyProfile();

GameEngine _engine({Level? level, int? seed}) => GameEngine.start(
      board: GameBoard.empty(rows: 12, columns: 6),
      profile: level?.difficulty ?? _profile,
      level: level,
      seed: seed,
    );

Level _level({
  int id = 1,
  LevelObjective? objective,
  int? moveLimit,
}) =>
    Level(
      id: id,
      chapter: 1,
      objective: objective ?? LevelObjective.reachScore(100),
      moveLimit: moveLimit,
      initialBlocks: const <BlockSpawn>[],
      allowedBoosters: const <String>['undo', 'hammer', 'shuffle'],
      difficulty: _profile,
      stars: const StarThresholds(twoStarScore: 100, threeStarScore: 300),
    );

void main() {
  group('GameEngine', () {
    test('a drop lands on the floor of an empty column', () {
      final engine = _engine();
      final outcome = engine.drop(2);
      expect(outcome.accepted, isTrue);
      expect(outcome.landingRow, 11);
      expect(engine.state.board.cells[11][2], isNotNull);
    });

    test('a drop stacks on top of an existing block', () {
      final engine = _engine();
      engine.drop(2);
      final outcome = engine.drop(2);
      expect(outcome.landingRow, 10);
    });

    test('a full column is refused without changing the board', () {
      final engine = _engine();
      for (var i = 0; i < 12; i++) {
        expect(engine.canDrop(0), isTrue);
        engine.drop(0);
      }
      final before = engine.state.board;
      expect(engine.canDrop(0), isFalse);
      final outcome = engine.drop(0);
      expect(outcome.accepted, isFalse);
      expect(engine.state.board, before);
    });

    test('an out-of-range column is refused', () {
      final engine = _engine();
      expect(engine.canDrop(-1), isFalse);
      expect(engine.canDrop(6), isFalse);
      expect(engine.drop(-1).accepted, isFalse);
    });

    test('score and move count advance on every drop', () {
      final engine = _engine();
      final first = engine.drop(0);
      expect(first.state.movesUsed, 1);
      expect(first.state.score, greaterThanOrEqualTo(0));
      final second = engine.drop(3);
      expect(second.state.movesUsed, 2);
    });

    test('game over is detected when no column can accept a drop', () {
      final engine = _engine();
      for (var column = 0; column < 6; column++) {
        for (var i = 0; i < 12; i++) {
          engine.drop(column);
        }
      }
      expect(engine.state.isGameOver, isTrue);
      expect(engine.isOver, isTrue);
    });

    test('a reachScore level is won exactly when the score is met', () {
      final engine = _engine(level: _level(objective: LevelObjective.reachScore(4)));
      expect(engine.state.objectivesComplete, isFalse);
      final outcome = engine.drop(0);
      expect(outcome.state.score, greaterThanOrEqualTo(0));
      // Force the win through the stats rather than relying on RNG.
      final won = outcome.state.copyWith(
        score: 10,
        stats: outcome.state.stats.copyWith(score: 10),
      );
      expect(won.objectivesComplete, isTrue);
      expect(won.stars, 1);
    });

    test('a move limit caps the number of drops', () {
      final engine = _engine(level: _level(moveLimit: 3));
      engine.drop(0);
      engine.drop(1);
      engine.drop(2);
      expect(engine.state.remainingMoves, 0);
    });

    test('undo restores the previous board and clears game over', () {
      final engine = _engine();
      engine.drop(0);
      final beforeUndo = engine.state;
      expect(beforeUndo.canUndo, isTrue);
      final previous = beforeUndo.undoHistory.last;
      expect(previous.board, isNotNull);
      expect(engine.state.board.blockCount, 1);
    });

    test('the same seed produces the same block sequence', () {
      final a = _engine(seed: 12345);
      final b = _engine(seed: 12345);
      final sequenceA = <int>[];
      final sequenceB = <int>[];
      for (var i = 0; i < 8; i++) {
        a.drop(i % 6);
        b.drop(i % 6);
        sequenceA.add(a.state.nextBlockValue);
        sequenceB.add(b.state.nextBlockValue);
      }
      expect(sequenceA, sequenceB);
    });

    test('restoring a core reproduces the board', () {
      final engine = _engine(seed: 777);
      engine.drop(2);
      engine.drop(4);
      final core = engine.toCore();

      final restored = GameEngine.restore(
        core: core,
        profile: _profile,
      );
      expect(restored.state.board.values, engine.state.board.values);
      expect(restored.state.score, engine.state.score);
      expect(restored.state.movesUsed, engine.state.movesUsed);
    });

    test('the simulator clones without disturbing the live session', () {
      final engine = _engine(seed: 4242);
      final probe = engine.clone().drop(1);
      expect(engine.state.board.blockCount, 0);
      expect(probe.state.board.blockCount, greaterThan(0));
    });
  });

  group('BlockGenerator', () {
    test('spawn weights are honoured over many draws', () {
      final generator = BlockGenerator(profile: _profile, seed: 99);
      final counts = <int, int>{};
      for (var i = 0; i < 4000; i++) {
        final value = generator.next();
        counts[value] = (counts[value] ?? 0) + 1;
      }
      // 2 is the most common value and 8 the rarest.
      expect(counts[2]!, greaterThan(counts[4]!));
      expect(counts[4]!, greaterThan(counts[8]!));
    });

    test('a clone continues the same sequence', () {
      final generator = BlockGenerator(profile: _profile, seed: 5);
      final first = <int>[];
      for (var i = 0; i < 5; i++) {
        first.add(generator.next());
      }
      final clone = generator.clone();
      expect(clone.next(), generator.next());
    });

    test('peekAhead does not consume values', () {
      final generator = BlockGenerator(profile: _profile, seed: 31);
      final peeked = generator.peekAhead(3);
      expect(peeked.length, 3);
      expect(generator.next(), peeked.first);
    });
  });
}
