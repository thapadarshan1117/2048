import 'dart:math' as math;

import '../../game/domain/block_state.dart';
import '../../game/domain/game_board.dart';
import '../../game/domain/game_engine.dart';
import '../../game/domain/game_stats.dart';
import '../../game/domain/rng.dart';
import '../domain/level.dart';

/// A deterministic greedy bot used to balance the level catalogue.
///
/// It estimates completion probability, average score and average move count
/// without a human in the loop, which is what makes it possible to validate
/// 500+ levels before shipping them.
///
/// The bot deliberately favours *consolidating* value into fewer, larger blocks
/// over farming small merges: that is what a strong human does, and a purely
/// greedy bot plateaus around 128 and would make every value-based level look
/// impossible.
class GameSimulator {
  const GameSimulator({
    this.rows = defaultRows,
    this.columns = defaultColumns,
    this.maxMoves = 400,
    this.skill = 0.75,
  });

  static const int defaultRows = 12;
  static const int defaultColumns = 6;

  final int rows;
  final int columns;

  /// Hard cap on drops when the level has no move limit.
  final int maxMoves;

  /// `1.0` plays perfectly; lower values inject human-like mistakes so the
  /// estimates model a real player rather than a theoretical optimum.
  final double skill;

  /// Ranks a candidate drop.
  static double heuristic(DropOutcome outcome) {
    final resolution = outcome.resolution;
    final merges = resolution?.mergeCount ?? 0;
    final chain = resolution?.longestChain ?? 0;
    final board = outcome.state.board;
    final blocks = board.blocks;
    var maxValue = 0;
    for (final block in blocks) {
      if (block.value > maxValue) maxValue = block.value;
    }
    final emptyCells = board.rows * board.columns - blocks.length;
    final distinctValues = blocks.map((b) => b.value).toSet().length;

    return outcome.scoreGained +
        100 * merges +
        80 * chain +
        350 * (maxValue > 0 ? math.log(maxValue) / math.ln2 : 0) +
        45 * emptyCells -
        16 * blocks.length -
        22 * distinctValues;
  }

  /// Plays [level] once with seed [seed] and returns the final state.
  GameState playOnce(Level level, int seed) {
    final engine = GameEngine.start(
      _initialBoard(level),
      level.difficulty,
      seed: seed,
      level: level,
    );
    final skillRng = Rng(seed ^ 0x5F3759DF);
    var moves = 0;

    while (!engine.state.isGameOver && moves < maxMoves) {
      final legal = <int>[];
      for (var c = 0; c < columns; c++) {
        if (engine.canDrop(c)) legal.add(c);
      }
      if (legal.isEmpty) break;

      var chosen = legal.first;
      if (skill < 1.0 && skillRng.nextDouble() > skill) {
        chosen = legal[skillRng.nextIntBelow(legal.length)];
      } else {
        var best = double.negativeInfinity;
        for (final column in legal) {
          final value = heuristic(engine.clone().drop(column));
          if (value > best) {
            best = value;
            chosen = column;
          }
        }
      }

      engine.drop(chosen);
      moves++;

      // A move limit always ends the level: the player either met the objective
      // inside the budget or they did not. Stopping only on failure would let
      // the validator silently measure an unlimited game and declare a
      // move-limited level impossible.
      final limit = level.effectiveMoveLimit;
      if (limit > 0 && moves >= limit) break;
    }

    return engine.state;
  }

  GameBoard _initialBoard(Level level) {
    final blocks = <BlockState>[];
    for (var i = 0; i < level.initialBlocks.length; i++) {
      final spawn = level.initialBlocks[i];
      blocks.add(BlockState(
        id: i + 1,
        value: spawn.value,
        row: spawn.row,
        column: spawn.column,
      ));
    }
    return GameBoard(rows: rows, columns: columns, blocks: blocks);
  }

  /// Plays [level] [games] times and aggregates the results.
  ///
  /// The raw per-game statistics are kept in [SimulationReport.runs] and every
  /// derived figure is computed from them *against the level currently attached
  /// to the report*. That matters because the generator measures a draft,
  /// rewrites its objective and then wants to validate the finished level:
  /// re-deriving completion from the raw runs keeps the two in sync instead of
  /// reporting a completion rate measured against a target that no longer
  /// exists.
  SimulationReport simulate(
    Level level, {
    int games = 10,
    int seed = 1,
    double? skillOverride,
    int? maxMovesOverride,
  }) {
    final bot = (skillOverride == null && maxMovesOverride == null)
        ? this
        : GameSimulator(
            rows: rows,
            columns: columns,
            maxMoves: maxMovesOverride ?? maxMoves,
            skill: skillOverride ?? skill,
          );

    final report = SimulationReport(level.id, level);
    for (var i = 0; i < games; i++) {
      final state = bot.playOnce(level, seed + i * 104729);
      report.add(state.stats);
    }
    return report;
  }
}

/// Aggregated result of simulating one level.
class SimulationReport {
  SimulationReport(this.levelId, this.level);

  final int levelId;

  /// The level every derived figure is evaluated against. Re-pointing this at
  /// a calibrated level is what keeps completion rates honest.
  Level? level;

  final List<GameStats> runs = <GameStats>[];

  void add(GameStats stats) => runs.add(stats);

  int get games => runs.length;

  List<int> get scores => runs.map((s) => s.score).toList(growable: false);

  List<int> get moves => runs.map((s) => s.movesUsed).toList(growable: false);

  List<int> get merges => runs.map((s) => s.mergeCount).toList(growable: false);

  List<int> get chains => runs.map((s) => s.longestCombo).toList(growable: false);

  /// Fraction of games that met the level objective.
  double get completionRate {
    final current = level;
    if (runs.isEmpty || current == null) return 0;
    var hits = 0;
    for (final stats in runs) {
      if (current.objective.isSatisfied(stats)) hits++;
    }
    return hits / runs.length;
  }

  int get completions {
    final current = level;
    if (runs.isEmpty || current == null) return 0;
    var hits = 0;
    for (final stats in runs) {
      if (current.objective.isSatisfied(stats)) hits++;
    }
    return hits;
  }

  double get averageScore =>
      runs.isEmpty ? 0 : runs.map((s) => s.score).reduce((a, b) => a + b) / runs.length;

  double get averageMoves => runs.isEmpty
      ? 0
      : runs.map((s) => s.movesUsed).reduce((a, b) => a + b) / runs.length;

  double get averageMerges => runs.isEmpty
      ? 0
      : runs.map((s) => s.mergeCount).reduce((a, b) => a + b) / runs.length;

  double get averageChain => runs.isEmpty
      ? 0
      : runs.map((s) => s.longestCombo).reduce((a, b) => a + b) / runs.length;

  double get averageHighestValue => runs.isEmpty
      ? 0
      : runs.map((s) => s.highestValueCreated).reduce((a, b) => a + b) /
          runs.length;

  double get averageStars {
    final current = level;
    if (runs.isEmpty || current == null) return 0;
    var total = 0;
    for (final stats in runs) {
      total += current.stars.starsFor(stats.score);
    }
    return total / runs.length;
  }

  int get bestScore => runs.isEmpty
      ? 0
      : runs.map((s) => s.score).reduce((a, b) => a > b ? a : b);

  /// Returns a copy of this report evaluated against [newLevel].
  SimulationReport forLevel(Level newLevel) {
    final copy = SimulationReport(levelId, newLevel);
    copy.runs.addAll(runs);
    return copy;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'level': levelId,
        'games': games,
        'completion': double.parse(completionRate.toStringAsFixed(1)),
        'avgScore': averageScore.round(),
        'bestScore': bestScore,
        'avgMoves': averageMoves.round(),
        'avgMerges': averageMerges.round(),
        'avgHighest': averageHighestValue.round(),
        'avgStars': double.parse(averageStars.toStringAsFixed(2)),
      };

  String get summary =>
      'Level $levelId | games $games | completion '
      '${(completionRate * 100).toStringAsFixed(1)}% | avg score '
      '${averageScore.round()} | avg moves ${averageMoves.round()} | '
      'avg highest ${averageHighestValue.round()}';
}
