import 'package:flutter_test/flutter_test.dart';
import 'package:merge_drop/features/game/domain/game_stats.dart';
import 'package:merge_drop/features/levels/domain/block_spawn.dart';
import 'package:merge_drop/features/levels/domain/chapter.dart';
import 'package:merge_drop/features/levels/domain/difficulty_profile.dart';
import 'package:merge_drop/features/levels/domain/level.dart';
import 'package:merge_drop/features/levels/domain/level_objective.dart';
import 'package:merge_drop/features/levels/domain/star_thresholds.dart';

const DifficultyProfile _profile = DifficultyProfile();

GameStats _stats({
  int score = 0,
  int merges = 0,
  int moves = 0,
  int highestCreated = 0,
  int highestOnBoard = 0,
  int combo = 0,
}) =>
    GameStats(
      score: score,
      mergeCount: merges,
      movesUsed: moves,
      highestValueCreated: highestCreated,
      highestValueOnBoard: highestOnBoard,
      longestCombo: combo,
    );

Level _level({
  int id = 1,
  int chapter = 1,
  LevelObjective? objective,
  int? moveLimit,
  StarThresholds? stars,
}) =>
    Level(
      id: id,
      chapter: chapter,
      objective: objective ?? LevelObjective.reachScore(100),
      moveLimit: moveLimit,
      initialBlocks: const <BlockSpawn>[],
      allowedBoosters: const <String>['undo', 'hammer', 'shuffle'],
      difficulty: _profile,
      stars: stars ?? const StarThresholds(twoStarScore: 100, threeStarScore: 300),
    );

void main() {
  group('LevelObjective', () {
    test('reachScore is satisfied once the score is met', () {
      const objective = LevelObjective.reachScore(100);
      expect(objective.isSatisfied(_stats(score: 99)), isFalse);
      expect(objective.isSatisfied(_stats(score: 100)), isTrue);
      expect(objective.progress(_stats(score: 50)), 0.5);
      expect(objective.progress(_stats(score: 999)), 1.0);
    });

    test('reachNumber reads the highest value on the board', () {
      const objective = LevelObjective.reachNumber(64);
      expect(objective.isSatisfied(_stats(highestOnBoard: 32)), isFalse);
      expect(objective.isSatisfied(_stats(highestOnBoard: 64)), isTrue);
    });

    test('createNumber reads the highest value ever produced', () {
      const objective = LevelObjective.createNumber(128);
      expect(objective.isSatisfied(_stats(highestCreated: 64)), isFalse);
      expect(objective.isSatisfied(_stats(highestCreated: 128)), isTrue);
    });

    test('mergeCount and comboCount read the right counters', () {
      const merge = LevelObjective.mergeCount(10);
      expect(merge.isSatisfied(_stats(merges: 10)), isTrue);
      expect(merge.isSatisfied(_stats(merges: 9)), isFalse);

      const combo = LevelObjective.comboCount(3);
      expect(combo.isSatisfied(_stats(combo: 3)), isTrue);
      expect(combo.isSatisfied(_stats(combo: 2)), isFalse);
    });

    test('completeWithinMoves counts down as moves are spent', () {
      const objective = LevelObjective.completeWithinMoves(20);
      expect(objective.isSatisfied(_stats(moves: 20)), isTrue);
      expect(objective.isSatisfied(_stats(moves: 21)), isFalse);
      expect(objective.progress(_stats(moves: 0)), 1.0);
      expect(objective.progress(_stats(moves: 10)), 0.5);
      expect(objective.progress(_stats(moves: 25)), 0.0);
    });

    test('round-trips every objective type through JSON', () {
      const objectives = <LevelObjective>[
        LevelObjective.reachScore(150),
        LevelObjective.createNumber(8),
        LevelObjective.mergeCount(12),
        LevelObjective.reachNumber(64),
        LevelObjective.completeWithinMoves(30),
        LevelObjective.comboCount(4),
      ];
      for (final objective in objectives) {
        final restored = LevelObjective.decode(objective.toJson());
        expect(restored.type, objective.type);
        expect(restored.target, objective.target);
      }
    });

    test('an unknown type decodes to a safe score goal', () {
      final decoded =
          LevelObjective.decode(<String, dynamic>{'type': 'nope', 'target': 5});
      expect(decoded.type, ObjectiveType.reachScore);
      expect(decoded.target, greaterThan(0));
    });
  });

  group('StarThresholds', () {
    const stars = StarThresholds(twoStarScore: 100, threeStarScore: 300);

    test('stars follow the score thresholds', () {
      expect(stars.starsFor(0), 1);
      expect(stars.starsFor(99), 1);
      expect(stars.starsFor(100), 2);
      expect(stars.starsFor(299), 2);
      expect(stars.starsFor(300), 3);
      expect(stars.starsFor(5000), 3);
    });

    test('progress to the next star moves the goal', () {
      expect(stars.progressToNextStar(50, 1), 0.5);
      expect(stars.progressToNextStar(100, 1), 1.0);
      expect(stars.progressToNextStar(150, 2), 0.5);
      expect(stars.progressToNextStar(300, 3), 1.0);
    });

    test('round-trips through JSON', () {
      expect(StarThresholds.fromJson(stars.toJson()), stars);
    });
  });

  group('Level', () {
    test('effectiveMoveLimit prefers the level limit over the profile', () {
      expect(_level(moveLimit: 30).effectiveMoveLimit, 30);
      expect(_level(moveLimit: 0).hasMoveLimit, isFalse);
    });

    test('allowsBooster reflects the allowed list', () {
      final level = _level();
      expect(level.allowsBooster('undo'), isTrue);
      expect(level.allowsBooster('wildcard'), isFalse);
    });

    test('restricted columns survive a JSON round-trip', () {
      final restricted = _level().copyWith(
        difficulty: _profile.copyWith(
          restriction: const BoardRestriction.restrictedColumns(<int>{1, 3}),
        ),
      );
      final restored = Level.fromJson(restricted.toJson());
      expect(restored.difficulty.restriction, isA<RestrictedColumnsRestriction>());
      expect(
        (restored.difficulty.restriction as RestrictedColumnsRestriction).columns,
        <int>{1, 3},
      );
    });

    test('height limits survive a JSON round-trip', () {
      final heightLimited = _level().copyWith(
        difficulty: _profile.copyWith(
          restriction: const BoardRestriction.maxHeight(2),
        ),
      );
      final restored = Level.fromJson(heightLimited.toJson());
      expect(restored.difficulty.restriction, isA<HeightLimitRestriction>());
      expect(
        (restored.difficulty.restriction as HeightLimitRestriction).topRow,
        2,
      );
    });

    test('initial blocks survive a JSON round-trip', () {
      final level = _level().copyWith(
        initialBlocks: const <BlockSpawn>[
          BlockSpawn(row: 11, column: 0, value: 2),
          BlockSpawn(row: 10, column: 4, value: 4),
        ],
      );
      final restored = Level.fromJson(level.toJson());
      expect(restored.initialBlocks.length, 2);
      expect(restored.initialBlocks.first.value, 2);
      expect(restored.initialBlocks.last.column, 4);
    });

    test('chapters contain their level range and round-trip', () {
      const chapter = Chapter(
        id: 1,
        startLevel: 1,
        endLevel: 25,
        themeKey: 'theme_1',
        nameKey: 'chapter_1',
      );
      expect(chapter.contains(1), isTrue);
      expect(chapter.contains(25), isTrue);
      expect(chapter.contains(26), isFalse);
      expect(chapter.levelCount, 25);
      expect(Chapter.fromJson(chapter.toJson()), chapter);
    });
  });
}
