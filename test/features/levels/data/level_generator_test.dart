import 'package:flutter_test/flutter_test.dart';
import 'package:merge_drop/features/game/domain/game_board.dart';
import 'package:merge_drop/features/game/domain/game_engine.dart';
import 'package:merge_drop/features/levels/data/game_simulator.dart';
import 'package:merge_drop/features/levels/data/level_generator.dart';
import 'package:merge_drop/features/levels/data/level_validator.dart';
import 'package:merge_drop/features/levels/domain/difficulty_profile.dart';
import 'package:merge_drop/features/levels/domain/level.dart';
import 'package:merge_drop/features/levels/domain/level_objective.dart';

/// Generator + validator behaviour.
///
/// The heavy 500-level calibration lives in `tool/mirror` (see
/// `tool/mirror/generate_levels.py`); these tests cover the rules the Dart
/// port must honour so a locally regenerated catalogue stays consistent with
/// the shipped one.
void main() {
  group('LevelGenerator', () {
    const generator = LevelGenerator(games: 0);

    test('produces a level for every id', () {
      for (final id in <int>[1, 7, 25, 26, 100, 250, 500]) {
        final level = generator.generate(id, calibrate: false);
        expect(level.id, id);
        expect(level.objective.target, greaterThan(0));
        expect(level.stars.twoStarScore, greaterThanOrEqualTo(0));
        expect(level.stars.threeStarScore,
            greaterThanOrEqualTo(level.stars.twoStarScore));
      }
    });

    test('chapters hold 25 levels each', () {
      for (var id = 1; id <= 500; id++) {
        final level = generator.generate(id, calibrate: false);
        expect(level.chapter, (id - 1) ~/ 25 + 1);
      }
    });

    test('the tutorial band is hand-curated and keeps its authored targets', () {
      const curated = <int, int>{
        1: 20,
        2: 60,
        3: 150,
        4: 300,
        5: 500,
      };
      curated.forEach((id, target) {
        final level = generator.generate(id, calibrate: false);
        expect(level.isCurated, isTrue);
        expect(level.objective.target, target);
      });
    });

    test('difficulty rises monotonically-ish across the catalogue', () {
      final early = LevelGenerator.difficultyOf(5, 500);
      final mid = LevelGenerator.difficultyOf(250, 500);
      final late = LevelGenerator.difficultyOf(500, 500);
      expect(early, lessThan(mid));
      expect(mid, lessThan(late));
      expect(early, greaterThan(0));
      expect(late, lessThanOrEqualTo(1));
    });

    test('difficulty is clamped to the 0..1 band', () {
      for (var id = 1; id <= 500; id += 37) {
        final d = LevelGenerator.difficultyOf(id, 500);
        expect(d, greaterThanOrEqualTo(0.02));
        expect(d, lessThanOrEqualTo(1.0));
      }
    });

    test('validation seeds are stable and unique', () {
      expect(LevelGenerator.validationSeed(1), 9002);
      expect(LevelGenerator.validationSeed(500), 9501);
      expect(LevelGenerator.validationSeed(7), LevelGenerator.validationSeed(7));
    });

    test('the calibration budget grows with a value objective', () {
      Level levelWith(int target) => Level(
            id: 1,
            chapter: 1,
            objective: LevelObjective.createNumber(target),
            initialBlocks: const <BlockSpawn>[],
            allowedBoosters: const <String>[],
            difficulty: const DifficultyProfile(),
            stars: const StarThresholds(twoStarScore: 0, threeStarScore: 0),
          );

      final small = LevelGenerator.calibrationBudgetFor(levelWith(16), 400);
      final large = LevelGenerator.calibrationBudgetFor(levelWith(256), 400);
      expect(large, greaterThan(small));
      expect(small, greaterThanOrEqualTo(60));
      expect(large, lessThanOrEqualTo(520));
    });

    test('a move limit caps the calibration budget', () {
      final level = Level(
        id: 1,
        chapter: 1,
        objective: LevelObjective.reachScore(100),
        moveLimit: 30,
        initialBlocks: const <BlockSpawn>[],
        allowedBoosters: const <String>[],
        difficulty: const DifficultyProfile(),
        stars: const StarThresholds(twoStarScore: 0, threeStarScore: 0),
      );
      expect(LevelGenerator.calibrationBudgetFor(level, 400), 30);
    });

    test('every generated level passes the static validator checks', () {
      const validator = LevelValidator(games: 0);
      for (final id in <int>[1, 10, 25, 60, 120, 300, 500]) {
        final level = generator.generate(id, calibrate: false);
        final report = validator.validate(level);
        expect(report.errors, isEmpty,
            reason: 'level $id: ${report.summary}');
      }
    });
  });

  group('GameSimulator', () {
    test('plays a level to completion without throwing', () {
      const simulator = GameSimulator(maxMoves: 80, skill: 0.75);
      final level = Level(
        id: 1,
        chapter: 1,
        objective: LevelObjective.reachScore(50),
        initialBlocks: const <BlockSpawn>[],
        allowedBoosters: const <String>[],
        difficulty: const DifficultyProfile(),
        stars: const StarThresholds(twoStarScore: 50, threeStarScore: 200),
      );

      final state = simulator.playOnce(level, 1);
      expect(state.movesUsed, greaterThan(0));
      expect(state.board.rows, 12);
      expect(state.board.columns, 6);
    });

    test('is deterministic for a given seed', () {
      const simulator = GameSimulator(maxMoves: 40, skill: 1.0);
      final level = Level(
        id: 1,
        chapter: 1,
        objective: LevelObjective.reachScore(100),
        initialBlocks: const <BlockSpawn>[],
        allowedBoosters: const <String>[],
        difficulty: const DifficultyProfile(),
        stars: const StarThresholds(twoStarScore: 100, threeStarScore: 300),
      );
      final a = simulator.simulate(level, games: 2, seed: 42);
      final b = simulator.simulate(level, games: 2, seed: 42);
      expect(a.scores, b.scores);
    });

    test('aggregates the raw runs into a report', () {
      const simulator = GameSimulator(maxMoves: 60);
      final level = Level(
        id: 1,
        chapter: 1,
        objective: LevelObjective.reachScore(30),
        initialBlocks: const <BlockSpawn>[],
        allowedBoosters: const <String>[],
        difficulty: const DifficultyProfile(),
        stars: const StarThresholds(twoStarScore: 30, threeStarScore: 100),
      );
      final report = simulator.simulate(level, games: 4, seed: 7);
      expect(report.games, 4);
      expect(report.runs.length, 4);
      expect(report.averageScore, greaterThan(0));
      expect(report.completionRate, inInclusiveRange(0, 1));
      expect(report.summary, contains('Level 1'));
    });

    test('re-pointing the report at a new level re-derives completion', () {
      const simulator = GameSimulator(maxMoves: 60);
      final easy = Level(
        id: 1,
        chapter: 1,
        objective: LevelObjective.reachScore(10),
        initialBlocks: const <BlockSpawn>[],
        allowedBoosters: const <String>[],
        difficulty: const DifficultyProfile(),
        stars: const StarThresholds(twoStarScore: 10, threeStarScore: 50),
      );
      final report = simulator.simulate(easy, games: 3, seed: 3);
      final easyRate = report.completionRate;

      final hard = easy.copyWith(objective: LevelObjective.reachScore(999999));
      final rePointed = report.forLevel(hard);
      expect(easyRate, greaterThan(0));
      expect(rePointed.completionRate, 0);
      expect(rePointed.runs.length, report.runs.length);
    });

    test('the heuristic prefers a merge over a wasted drop', () {
      // Two equal neighbours must out-score an isolated block.
      final engine = GameEngine.start(
        board: GameBoard.empty(rows: 12, columns: 6),
        profile: const DifficultyProfile(),
        seed: 4242,
      );
      engine.drop(0);
      engine.drop(0);
      final merged = engine.clone().drop(0);

      final isolatedEngine = GameEngine.start(
        board: GameBoard.empty(rows: 12, columns: 6),
        profile: const DifficultyProfile(),
        seed: 99,
      );
      isolatedEngine.drop(1);
      final isolated = isolatedEngine.clone().drop(3);

      expect(
        GameSimulator.heuristic(merged),
        greaterThan(GameSimulator.heuristic(isolated)),
      );
    });
  });

  group('LevelValidator', () {
    const validator = LevelValidator(games: 0);

    test('flags a level whose objective can never be met', () {
      final level = Level(
        id: 1,
        chapter: 1,
        objective: LevelObjective.reachScore(-5),
        initialBlocks: const <BlockSpawn>[],
        allowedBoosters: const <String>[],
        difficulty: const DifficultyProfile(),
        stars: const StarThresholds(twoStarScore: 0, threeStarScore: 0),
      );
      final report = validator.validate(level);
      expect(report.ok, isFalse);
      expect(report.errors.any((i) => i.code == 'invalid_objective'), isTrue);
    });

    test('flags a level whose board is sealed at the start', () {
      final level = Level(
        id: 1,
        chapter: 1,
        objective: LevelObjective.reachScore(10),
        initialBlocks: const <BlockSpawn>[
          BlockSpawn(row: 11, column: 0, value: 2),
          BlockSpawn(row: 11, column: 1, value: 4),
          BlockSpawn(row: 11, column: 2, value: 8),
          BlockSpawn(row: 11, column: 3, value: 16),
          BlockSpawn(row: 11, column: 4, value: 32),
          BlockSpawn(row: 11, column: 5, value: 64),
          BlockSpawn(row: 10, column: 0, value: 2),
          BlockSpawn(row: 10, column: 1, value: 4),
          BlockSpawn(row: 10, column: 2, value: 8),
          BlockSpawn(row: 10, column: 3, value: 16),
          BlockSpawn(row: 10, column: 4, value: 32),
          BlockSpawn(row: 10, column: 5, value: 64),
          BlockSpawn(row: 9, column: 0, value: 2),
          BlockSpawn(row: 9, column: 1, value: 4),
          BlockSpawn(row: 9, column: 2, value: 8),
          BlockSpawn(row: 9, column: 3, value: 16),
          BlockSpawn(row: 9, column: 4, value: 32),
          BlockSpawn(row: 9, column: 5, value: 64),
          BlockSpawn(row: 8, column: 0, value: 2),
          BlockSpawn(row: 8, column: 1, value: 4),
          BlockSpawn(row: 8, column: 2, value: 8),
          BlockSpawn(row: 8, column: 3, value: 16),
          BlockSpawn(row: 8, column: 4, value: 32),
          BlockSpawn(row: 8, column: 5, value: 64),
          BlockSpawn(row: 7, column: 0, value: 2),
          BlockSpawn(row: 7, column: 1, value: 4),
          BlockSpawn(row: 7, column: 2, value: 8),
          BlockSpawn(row: 7, column: 3, value: 16),
          BlockSpawn(row: 7, column: 4, value: 32),
          BlockSpawn(row: 7, column: 5, value: 64),
          BlockSpawn(row: 6, column: 0, value: 2),
          BlockSpawn(row: 6, column: 1, value: 4),
          BlockSpawn(row: 6, column: 2, value: 8),
          BlockSpawn(row: 6, column: 3, value: 16),
          BlockSpawn(row: 6, column: 4, value: 32),
          BlockSpawn(row: 6, column: 5, value: 64),
          BlockSpawn(row: 5, column: 0, value: 2),
          BlockSpawn(row: 5, column: 1, value: 4),
          BlockSpawn(row: 5, column: 2, value: 8),
          BlockSpawn(row: 5, column: 3, value: 16),
          BlockSpawn(row: 5, column: 4, value: 32),
          BlockSpawn(row: 5, column: 5, value: 64),
          BlockSpawn(row: 4, column: 0, value: 2),
          BlockSpawn(row: 4, column: 1, value: 4),
          BlockSpawn(row: 4, column: 2, value: 8),
          BlockSpawn(row: 4, column: 3, value: 16),
          BlockSpawn(row: 4, column: 4, value: 32),
          BlockSpawn(row: 4, column: 5, value: 64),
          BlockSpawn(row: 3, column: 0, value: 2),
          BlockSpawn(row: 3, column: 1, value: 4),
          BlockSpawn(row: 3, column: 2, value: 8),
          BlockSpawn(row: 3, column: 3, value: 16),
          BlockSpawn(row: 3, column: 4, value: 32),
          BlockSpawn(row: 3, column: 5, value: 64),
          BlockSpawn(row: 2, column: 0, value: 2),
          BlockSpawn(row: 2, column: 1, value: 4),
          BlockSpawn(row: 2, column: 2, value: 8),
          BlockSpawn(row: 2, column: 3, value: 16),
          BlockSpawn(row: 2, column: 4, value: 32),
          BlockSpawn(row: 2, column: 5, value: 64),
          BlockSpawn(row: 1, column: 0, value: 2),
          BlockSpawn(row: 1, column: 1, value: 4),
          BlockSpawn(row: 1, column: 2, value: 8),
          BlockSpawn(row: 1, column: 3, value: 16),
          BlockSpawn(row: 1, column: 4, value: 32),
          BlockSpawn(row: 1, column: 5, value: 64),
          BlockSpawn(row: 0, column: 0, value: 2),
          BlockSpawn(row: 0, column: 1, value: 4),
          BlockSpawn(row: 0, column: 2, value: 8),
          BlockSpawn(row: 0, column: 3, value: 16),
          BlockSpawn(row: 0, column: 4, value: 32),
          BlockSpawn(row: 0, column: 5, value: 64),
        ],
        allowedBoosters: const <String>[],
        difficulty: const DifficultyProfile(),
        stars: const StarThresholds(twoStarScore: 0, threeStarScore: 0),
      );
      final report = validator.validate(level);
      expect(report.errors.any((i) => i.code == 'dead_end_start'), isTrue);
    });

    test('flags a move limit that is too small to play', () {
      final level = Level(
        id: 1,
        chapter: 1,
        objective: LevelObjective.reachScore(10),
        moveLimit: 3,
        initialBlocks: const <BlockSpawn>[],
        allowedBoosters: const <String>[],
        difficulty: const DifficultyProfile(),
        stars: const StarThresholds(twoStarScore: 0, threeStarScore: 0),
      );
      final report = validator.validate(level);
      expect(report.errors.any((i) => i.code == 'move_limit_too_small'), isTrue);
    });

    test('reports an info (not a warning) when a level allows no boosters', () {
      final level = Level(
        id: 1,
        chapter: 1,
        objective: LevelObjective.reachScore(10),
        initialBlocks: const <BlockSpawn>[],
        allowedBoosters: const <String>[],
        difficulty: const DifficultyProfile(),
        stars: const StarThresholds(twoStarScore: 10, threeStarScore: 30),
      );
      final report = validator.validate(level);
      expect(report.warnings, isEmpty);
      expect(report.issues.any((i) => i.code == 'no_boosters'), isTrue);
    });
  });
}
