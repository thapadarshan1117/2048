import 'dart:math' as math;

import '../../game/domain/rng.dart';
import '../domain/block_spawn.dart';
import '../domain/difficulty_profile.dart';
import '../domain/level.dart';
import '../domain/level_objective.dart';
import '../domain/star_thresholds.dart';
import 'game_simulator.dart';

/// Generates and calibrates the level catalogue.
///
/// Levels are never hand-written past the tutorial band. The first 20 levels
/// are curated for pedagogy; everything after that comes from a deterministic
/// formula with deliberate pacing dips so the difficulty curve breathes instead
/// of climbing monotonically.
///
/// Every level is then **measured** by a [GameSimulator] before it ships:
/// score targets, value targets, move limits and star thresholds are all
/// derived from simulated play rather than guessed. That is what keeps a
/// 500-level catalogue free of impossible and trivial levels.
class LevelGenerator {
  const LevelGenerator({
    this.totalLevels = 500,
    this.rows = defaultRows,
    this.columns = defaultColumns,
    this.levelsPerChapter = defaultLevelsPerChapter,
    this.seed = 20260101,
    this.simulator,
    this.games = 4,
    this.skill = 0.8,
    this.maxMoves = 120,
  });

  static const int defaultRows = 12;
  static const int defaultColumns = 6;
  static const int defaultLevelsPerChapter = 25;

  static const List<String> allBoosters = <String>['undo', 'hammer', 'shuffle'];

  final int totalLevels;
  final int rows;
  final int columns;
  final int levelsPerChapter;
  final int seed;

  /// When `null`, levels are generated uncalibrated (fast, used by tests).
  final GameSimulator? simulator;
  final int games;
  final double skill;
  final int maxMoves;

  // --- public API ---------------------------------------------------------

  /// Every level in the catalogue.
  List<Level> generateAll({bool calibrate = true}) => List<Level>.generate(
        totalLevels,
        (index) => generate(index + 1, calibrate: calibrate),
      );

  Level generate(int levelId, {bool calibrate = true}) =>
      generateWithReport(levelId, calibrate: calibrate).$1;

  /// Returns the level together with the simulation it was tuned against, so
  /// the validator can judge a level against the very numbers it was balanced
  /// with instead of rolling a second, slightly different set of games.
  (Level, SimulationReport?) generateWithReport(int levelId,
      {bool calibrate = true}) {
    if (levelId < 1) {
      throw ArgumentError.value(levelId, 'levelId', 'level ids start at 1');
    }
    final draft = _draft(levelId);
    if (!calibrate || simulator == null) return (draft, null);
    return _calibrate(draft);
  }

  int chapterOf(int levelId) => 1 + (levelId - 1) ~/ levelsPerChapter;

  /// Inclusive `[start, end]` level ids of [chapter].
  (int, int) chapterRange(int chapter) {
    final start = (chapter - 1) * levelsPerChapter + 1;
    final end = math.min(totalLevels, chapter * levelsPerChapter);
    return (start, end);
  }

  // --- drafting -----------------------------------------------------------

  Level _draft(int levelId) => _curatedDraft(levelId) ?? _formulaDraft(levelId);

  Level? _curatedDraft(int levelId) {
    for (final entry in _curated) {
      if (entry.id != levelId) continue;
      return Level(
        id: levelId,
        chapter: chapterOf(levelId),
        objective: entry.objective,
        moveLimit: entry.moveLimit,
        initialBlocks: entry.initialBlocks,
        allowedBoosters: entry.allowedBoosters,
        difficulty: DifficultyProfile(
          spawnWeights: entry.spawnWeights,
          maxSpawnValue: entry.maxSpawnValue,
        ),
        stars: StarThresholds(
          twoStarScore: entry.twoStarScore,
          threeStarScore: entry.threeStarScore,
        ),
        isCurated: true,
        tutorialStepKey: entry.tutorialStepKey,
      );
    }
    return null;
  }

  Level _formulaDraft(int levelId) {
    final d = difficultyOf(levelId, totalLevels);
    final rng = Rng(seed + levelId * 7919);

    final weights = _weightsFor(d);
    final maxSpawn = _maxSpawnValueFor(d);
    final phase = levelId % 6;

    final LevelObjective objective;
    switch (phase) {
      case 1:
        objective = LevelObjective.createNumber(_valueCeilingFor(d));
      case 2:
        objective = LevelObjective.mergeCount((20 + 180 * d).round());
      case 3:
        objective = LevelObjective.reachNumber(_valueCeilingFor(d));
      case 4:
        objective = LevelObjective.comboCount(_comboFor(levelId));
      case 0:
      case 5:
      // Reach-score levels are calibrated in pass 1, so the draft target is a
      // placeholder that the simulator replaces.
      // ignore: no_default_cases
      default:
        objective = const LevelObjective.reachScore(0);
    }

    var restriction = const BoardRestriction.none();
    if (levelId % 37 == 0) {
      restriction = BoardRestriction.restrictedColumns(
          <int>{rng.nextIntBelow(columns)});
    } else if (levelId % 53 == 0) {
      restriction = BoardRestriction.maxHeight(rows - (3 + 3 * d).round());
    }

    // Dense starting boards appear once the player is comfortable.
    final initialBlocks = <BlockSpawn>[];
    if (d > 0.30) {
      final wanted = (d * 5).floor();
      final occupied = <(int, int)>{};
      var attempts = 0;
      while (initialBlocks.length < wanted && attempts < wanted * 8) {
        attempts++;
        final value = rng.pick(const <int>[2, 2, 4, 4, 8, 8, 16, 16]) ?? 2;
        final row = rows - 1 - rng.nextIntBelow(3);
        final column = rng.nextIntBelow(columns);
        if (occupied.contains((row, column))) continue;
        // Never seal a column completely: a dead-end start is unplayable.
        var columnFill = 0;
        for (final cell in occupied) {
          if (cell.$2 == column) columnFill++;
        }
        if (columnFill >= rows - 1) continue;
        occupied.add((row, column));
        initialBlocks.add(BlockSpawn(value: value, row: row, column: column));
      }
    }

    return Level(
      id: levelId,
      chapter: chapterOf(levelId),
      objective: objective,
      initialBlocks: initialBlocks,
      allowedBoosters: allBoosters,
      difficulty: DifficultyProfile(
        spawnWeights: weights,
        maxSpawnValue: maxSpawn,
        restriction: restriction,
      ),
      isCurated: false,
    );
  }

  // --- calibration --------------------------------------------------------

  /// Two-pass calibration.
  ///
  /// Pass 1 decides *what the level asks for*, using the move budget that
  /// target implies. Pass 2 re-measures the finished level with the budget the
  /// validator will use, and only then sets the star thresholds.
  ///
  /// Measuring stars during pass 1 would compare them against a longer or
  /// shorter game than the one they are finally judged on - exactly the kind of
  /// silent mismatch that produces unreachable 3-star ratings.
  (Level, SimulationReport) _calibrate(Level draft) {
    final engine = simulator!;
    final level = _setObjective(draft);

    final budget = calibrationBudgetFor(level, maxMoves);
    final report = engine.simulate(
      _withoutMoveLimit(level),
      games: games,
      seed: validationSeed(level.id),
      skill: skill,
      maxMoves: budget,
    );

    final avgScore = math.max(1, report.averageScore);
    final int twoStar;
    final int threeStar;
    if (level.isCurated) {
      // Hand-authored levels keep their designer's thresholds, clamped so a
      // 3-star rating stays attainable by a strong player.
      twoStar = math.min(level.stars.twoStarScore, (avgScore * 0.45).round())
          .clamp(1, 1 << 30);
      threeStar = math.min(level.stars.threeStarScore, (avgScore * 0.75).round())
          .clamp(1, 1 << 30);
    } else {
      // Thresholds sit well below the measured average: stars are awarded on
      // the player's *best* run, and a good human beats the bot.
      twoStar = _nice(avgScore * 0.35);
      threeStar = _nice(avgScore * 0.55);
    }
    var two = twoStar;
    var three = threeStar;
    if (three <= two) {
      // Lower the 2-star bar rather than inflating the 3-star one.
      two = math.max(1, three ~/ 2);
    }

    final calibrated = level.copyWith(
      stars: StarThresholds(twoStarScore: two, threeStarScore: three),
    );
    return (calibrated, report.forLevel(calibrated));
  }

  /// Pass 1: pick the objective target from a measured game.
  Level _setObjective(Level draft) {
    final engine = simulator!;
    final budget = calibrationBudgetFor(draft, maxMoves);
    final report = engine.simulate(
      _withoutMoveLimit(draft),
      games: games,
      seed: validationSeed(draft.id),
      skill: skill,
      maxMoves: budget,
    );

    if (draft.isCurated) {
      // A curated objective is a teaching decision, not something a bot should
      // be allowed to rewrite.
      return draft;
    }

    final avgScore = math.max(1, report.averageScore);
    final avgMoves = math.max(1, report.averageMoves);
    final avgHighest = math.max(2, report.averageHighestValue);
    final avgMerges = math.max(1, report.averageMerges);
    final avgChain = math.max(1, report.averageChain);

    var objective = draft.objective;
    var moveLimit = draft.moveLimit;
    final kind = draft.objective.type;

    if (kind == ObjectiveType.reachScore) {
      // A move-limited level is measured without its limit, so its target is
      // set conservatively: the player has to hit it inside a budget that is
      // only 40% longer than the measurement window.
      final share = draft.id % 6 == 5 ? 0.70 : 0.85;
      objective = LevelObjective.reachScore(_nice(avgScore * share));
    } else if (kind == ObjectiveType.createNumber ||
        kind == ObjectiveType.reachNumber) {
      var target = _pow2Down(avgHighest * 0.9);
      target = math.min(
          target, _valueCeilingFor(difficultyOf(draft.id, totalLevels)));
      objective = kind == ObjectiveType.createNumber
          ? LevelObjective.createNumber(math.max(4, target))
          : LevelObjective.reachNumber(math.max(4, target));
    } else if (kind == ObjectiveType.mergeCount) {
      objective = LevelObjective.mergeCount(math.max(3, (avgMerges * 0.8).round()));
    } else if (kind == ObjectiveType.comboCount) {
      objective = LevelObjective.comboCount(math.max(2, (avgChain * 0.8).round()));
    }

    if (kind == ObjectiveType.reachScore && draft.id % 6 == 5) {
      moveLimit = math.max(15, (avgMoves * 1.4).round());
    }

    return draft.copyWith(objective: objective, moveLimit: moveLimit);
  }

  Level _withoutMoveLimit(Level level) => level.copyWith(moveLimit: null);

  // --- shared helpers -----------------------------------------------------

  /// Move budget a level must be measured with.
  ///
  /// Value objectives need a far longer window than score objectives - a 512
  /// cannot be built in 120 drops - and *both* the generator and the validator
  /// must agree on the budget, otherwise a level is tuned against one game
  /// length and judged against another.
  static int calibrationBudgetFor(Level level, int baseMoves) {
    var budget = baseMoves;
    if (level.objective.type == ObjectiveType.createNumber ||
        level.objective.type == ObjectiveType.reachNumber) {
      budget = _calibrationBudget(level.objective.target, baseMoves);
    }
    // A move limit always wins: a 60-move level can never be judged on a
    // 120-move game, however generous the base budget is.
    final limit = level.effectiveMoveLimit;
    if (limit > 0) budget = math.min(budget, limit);
    return budget;
  }

  static int _calibrationBudget(int targetValue, int baseMoves) {
    if (targetValue <= 0) return baseMoves;
    return (120 * targetValue / 128).clamp(60, 520).round();
  }

  /// Single seed base shared by calibration and validation.
  ///
  /// Using one seed means the numbers a level is tuned against are exactly the
  /// numbers it is checked against, which removes the false "unreachable star"
  /// warnings caused by two independent random draws.
  static int validationSeed(int levelId) => 9001 + levelId;
}

/// Difficulty in `0..1` with deliberate pacing dips.
double difficultyOf(int levelId, int totalLevels) {
  final progress = (levelId - 1) / math.max(1, totalLevels - 1);
  final base = math.pow(progress, 0.85).toDouble();
  final wave = 0.10 * math.sin(levelId * 0.55) + 0.05 * math.sin(levelId * 1.9);
  return (base + wave).clamp(0.02, 1.0);
}

Map<int, int> _weightsFor(double d) {
  if (d < 0.10) return const <int, int>{2: 100};
  if (d < 0.25) return const <int, int>{2: 90, 4: 10};
  if (d < 0.40) return const <int, int>{2: 85, 4: 13, 8: 2};
  if (d < 0.55) return const <int, int>{2: 80, 4: 16, 8: 4};
  if (d < 0.70) return const <int, int>{2: 72, 4: 20, 8: 8};
  if (d < 0.85) return const <int, int>{2: 62, 4: 24, 8: 12, 16: 2};
  return const <int, int>{2: 52, 4: 26, 8: 16, 16: 6};
}

int _maxSpawnValueFor(double d) {
  if (d < 0.15) return 2;
  if (d < 0.45) return 4;
  if (d < 0.80) return 8;
  return 16;
}

/// Largest value a level asks the player to create.
///
/// Measurement shows a strong player roughly doubles their best block every
/// 120 drops, so the ceiling is tied to difficulty and capped at 512: the
/// 1024/2048/4096 milestones belong to infinite mode, where a session can run
/// for thousands of drops.
int _valueCeilingFor(double difficulty) =>
    _pow2Down(math.pow(2, 4.5 + 5.5 * difficulty).toDouble())
        .clamp(16, 512)
        .toInt();

int _comboFor(int levelId) {
  if (levelId < 150) return 2;
  if (levelId < 300) return 3;
  if (levelId < 420) return 4;
  return 5;
}

/// Rounds a target to a human-friendly number.
int _nice(double value) {
  if (value <= 0) return 0;
  const steps = <int>[10, 25, 50, 100, 250, 500, 1000, 2500, 5000];
  for (final step in steps) {
    if (value < step * 20) {
      return math.max(step, (value / step).round() * step);
    }
  }
  return (value / 5000).round() * 5000;
}

int _pow2Down(double value) {
  if (value < 2) return 2;
  return 1 << (math.log(value) / math.ln2).floor();
}

/// A hand-authored tutorial level.
class _CuratedLevel {
  const _CuratedLevel({
    required this.id,
    required this.objective,
    required this.spawnWeights,
    required this.maxSpawnValue,
    required this.moveLimit,
    required this.initialBlocks,
    required this.allowedBoosters,
    required this.twoStarScore,
    required this.threeStarScore,
    this.tutorialStepKey,
  });

  final int id;
  final LevelObjective objective;
  final Map<int, int> spawnWeights;
  final int maxSpawnValue;
  final int? moveLimit;
  final List<BlockSpawn> initialBlocks;
  final List<String> allowedBoosters;
  final int twoStarScore;
  final int threeStarScore;
  final String? tutorialStepKey;
}

BlockSpawn _spawn(int value, int row, int column) =>
    BlockSpawn(value: value, row: row, column: column);

/// The curated tutorial band.
///
/// Every target below was chosen by hand for its teaching purpose and then
/// *measured* with the simulator - see `LEVEL_DESIGN.md` for the numbers.
const List<_CuratedLevel> _curated = <_CuratedLevel>[
  _CuratedLevel(
    id: 1,
    objective: LevelObjective.reachScore(20),
    spawnWeights: <int, int>{2: 100},
    maxSpawnValue: 2,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: <String>[],
    twoStarScore: 100,
    threeStarScore: 500,
    tutorialStepKey: 'tut_drop',
  ),
  _CuratedLevel(
    id: 2,
    objective: LevelObjective.reachScore(60),
    spawnWeights: <int, int>{2: 100},
    maxSpawnValue: 2,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: <String>['undo'],
    twoStarScore: 150,
    threeStarScore: 800,
    tutorialStepKey: 'tut_merge',
  ),
  _CuratedLevel(
    id: 3,
    objective: LevelObjective.reachScore(150),
    spawnWeights: <int, int>{2: 100},
    maxSpawnValue: 2,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: <String>['undo'],
    twoStarScore: 250,
    threeStarScore: 1200,
    tutorialStepKey: 'tut_merge_again',
  ),
  _CuratedLevel(
    id: 4,
    objective: LevelObjective.reachScore(300),
    spawnWeights: <int, int>{2: 90, 4: 10},
    maxSpawnValue: 4,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: <String>['undo'],
    twoStarScore: 400,
    threeStarScore: 1800,
    tutorialStepKey: 'tut_chain',
  ),
  _CuratedLevel(
    id: 5,
    objective: LevelObjective.reachScore(500),
    spawnWeights: <int, int>{2: 85, 4: 15},
    maxSpawnValue: 4,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: <String>['undo'],
    twoStarScore: 500,
    threeStarScore: 2400,
  ),
  _CuratedLevel(
    id: 6,
    objective: LevelObjective.reachScore(900),
    spawnWeights: <int, int>{2: 80, 4: 20},
    maxSpawnValue: 4,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: <String>['undo'],
    twoStarScore: 800,
    threeStarScore: 3400,
  ),
  _CuratedLevel(
    id: 7,
    objective: LevelObjective.reachScore(1400),
    spawnWeights: <int, int>{2: 78, 4: 20, 8: 2},
    maxSpawnValue: 8,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: <String>['undo'],
    twoStarScore: 1000,
    threeStarScore: 4200,
  ),
  _CuratedLevel(
    id: 8,
    objective: LevelObjective.reachScore(1200),
    spawnWeights: <int, int>{2: 78, 4: 20, 8: 2},
    maxSpawnValue: 8,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: <String>['undo'],
    twoStarScore: 900,
    threeStarScore: 3800,
  ),
  _CuratedLevel(
    id: 9,
    objective: LevelObjective.comboCount(2),
    spawnWeights: <int, int>{2: 78, 4: 20, 8: 2},
    maxSpawnValue: 8,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: <String>['undo'],
    twoStarScore: 700,
    threeStarScore: 3000,
  ),
  _CuratedLevel(
    id: 10,
    objective: LevelObjective.mergeCount(25),
    spawnWeights: <int, int>{2: 75, 4: 22, 8: 3},
    maxSpawnValue: 8,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: LevelGenerator.allBoosters,
    twoStarScore: 900,
    threeStarScore: 3800,
    tutorialStepKey: 'tut_boosters',
  ),
  _CuratedLevel(
    id: 11,
    objective: LevelObjective.reachScore(1600),
    spawnWeights: <int, int>{2: 75, 4: 22, 8: 3},
    maxSpawnValue: 8,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: LevelGenerator.allBoosters,
    twoStarScore: 900,
    threeStarScore: 3800,
  ),
  _CuratedLevel(
    id: 12,
    objective: LevelObjective.reachScore(600),
    spawnWeights: <int, int>{2: 75, 4: 22, 8: 3},
    maxSpawnValue: 8,
    moveLimit: 60,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: LevelGenerator.allBoosters,
    twoStarScore: 800,
    threeStarScore: 3400,
  ),
  _CuratedLevel(
    id: 13,
    objective: LevelObjective.createNumber(32),
    spawnWeights: <int, int>{2: 75, 4: 22, 8: 3},
    maxSpawnValue: 8,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: LevelGenerator.allBoosters,
    twoStarScore: 700,
    threeStarScore: 3000,
  ),
  _CuratedLevel(
    id: 14,
    objective: LevelObjective.comboCount(3),
    spawnWeights: <int, int>{2: 74, 4: 22, 8: 4},
    maxSpawnValue: 8,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: LevelGenerator.allBoosters,
    twoStarScore: 1000,
    threeStarScore: 4200,
  ),
  _CuratedLevel(
    id: 15,
    objective: LevelObjective.reachScore(2200),
    spawnWeights: <int, int>{2: 74, 4: 22, 8: 4},
    maxSpawnValue: 8,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[
      _spawn(2, 11, 0),
      _spawn(4, 11, 1),
      _spawn(2, 10, 0),
      _spawn(8, 11, 5),
    ],
    allowedBoosters: LevelGenerator.allBoosters,
    twoStarScore: 1100,
    threeStarScore: 4600,
  ),
  _CuratedLevel(
    id: 16,
    objective: LevelObjective.createNumber(64),
    spawnWeights: <int, int>{2: 72, 4: 23, 8: 5},
    maxSpawnValue: 8,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: <String>['hammer', 'shuffle'],
    twoStarScore: 900,
    threeStarScore: 3800,
  ),
  _CuratedLevel(
    id: 17,
    objective: LevelObjective.createNumber(128),
    spawnWeights: <int, int>{2: 70, 4: 24, 8: 6},
    maxSpawnValue: 8,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: LevelGenerator.allBoosters,
    twoStarScore: 1100,
    threeStarScore: 4600,
  ),
  _CuratedLevel(
    id: 18,
    objective: LevelObjective.comboCount(4),
    spawnWeights: <int, int>{2: 68, 4: 25, 8: 7},
    maxSpawnValue: 8,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: LevelGenerator.allBoosters,
    twoStarScore: 1200,
    threeStarScore: 5000,
  ),
  _CuratedLevel(
    id: 19,
    objective: LevelObjective.createNumber(256),
    spawnWeights: <int, int>{2: 66, 4: 26, 8: 8},
    maxSpawnValue: 8,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[],
    allowedBoosters: LevelGenerator.allBoosters,
    twoStarScore: 2000,
    threeStarScore: 8000,
  ),
  _CuratedLevel(
    id: 20,
    objective: LevelObjective.createNumber(512),
    spawnWeights: <int, int>{2: 62, 4: 27, 8: 11},
    maxSpawnValue: 8,
    moveLimit: null,
    initialBlocks: <BlockSpawn>[
      _spawn(4, 11, 2),
      _spawn(8, 11, 3),
      _spawn(16, 10, 2),
    ],
    allowedBoosters: LevelGenerator.allBoosters,
    twoStarScore: 6000,
    threeStarScore: 20000,
  ),
];
