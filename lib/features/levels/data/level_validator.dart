import '../../game/domain/block_state.dart';
import '../../game/domain/game_board.dart';
import '../domain/level.dart';
import 'game_simulator.dart';
import 'level_generator.dart';

/// Severity of a validation finding.
enum ValidationSeverity { error, warning, info }

/// A single problem found in a level.
class ValidationIssue {
  const ValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
  });

  final ValidationSeverity severity;
  final String code;
  final String message;

  @override
  String toString() => '[${severity.name}] $code: $message';
}

/// The result of validating one level.
class ValidationReport {
  ValidationReport(this.levelId);

  final int levelId;
  final List<ValidationIssue> issues = <ValidationIssue>[];
  SimulationReport? simulation;

  void add(ValidationSeverity severity, String code, String message) {
    issues.add(ValidationIssue(
      severity: severity,
      code: code,
      message: message,
    ));
  }

  List<ValidationIssue> get errors =>
      issues.where((i) => i.severity == ValidationSeverity.error).toList();

  List<ValidationIssue> get warnings =>
      issues.where((i) => i.severity == ValidationSeverity.warning).toList();

  bool get ok => errors.isEmpty;

  String get summary {
    if (ok && warnings.isEmpty) return 'level $levelId: OK';
    return 'level $levelId: ${issues.map((i) => i.toString()).join('; ')}';
  }
}

/// Static and simulation-backed checks for a single level.
///
/// A level is only shipped when it passes, which is what keeps a 500-level
/// catalogue free of impossible, trivial and dead-end levels.
class LevelValidator {
  const LevelValidator({
    this.rows = 12,
    this.columns = 6,
    this.simulator,
    this.games = 6,
    this.skill = 0.8,
    this.minCompletion = 0.15,
    this.maxCompletion = 0.995,
    this.trivialScoreMultiplier = 2.5,
    this.trivialExemptIds = LevelGeneratorBridge.tutorialExemptIds,
  });

  final int rows;
  final int columns;

  /// When `null` only the static checks run.
  final GameSimulator? simulator;
  final int games;
  final double skill;
  final double minCompletion;
  final double maxCompletion;
  final double trivialScoreMultiplier;

  /// The opening tutorial band is *meant* to be trivial: the player is still
  /// learning where to tap. Flagging it as a balance problem would just train
  /// designers to ignore the warning.
  final Set<int> trivialExemptIds;

  /// Validates [level].
  ///
  /// When [simulation] is supplied, the simulation-backed checks reuse it
  /// instead of rolling a second, slightly different set of games.
  ValidationReport validate(Level level, {SimulationReport? simulation}) {
    final report = ValidationReport(level.id);
    _staticIssues(report, level);

    final existing = simulation;
    if (existing != null) {
      report.simulation = existing;
      _simulationIssues(report, level, existing);
      return report;
    }

    final bot = simulator;
    if (bot == null) return report;

    // Value objectives must be measured with the same generous budget the
    // generator calibrated them with, otherwise a 512 target looks impossible
    // simply because the validator stopped after 120 drops.
    final budget = LevelGenerator.calibrationBudgetFor(level, bot.maxMoves);
    final result = bot.simulate(
      level,
      games: games,
      seed: LevelGenerator.validationSeed(level.id),
      skill: skill,
      maxMovesOverride: budget,
    );
    report.simulation = result;
    _simulationIssues(report, level, result);
    return report;
  }

  void _staticIssues(ValidationReport report, Level level) {
    final seen = <(int, int)>{};
    for (final spawn in level.initialBlocks) {
      if (spawn.row < 0 ||
          spawn.row >= rows ||
          spawn.column < 0 ||
          spawn.column >= columns) {
        report.add(
          ValidationSeverity.error,
          'initial_block_out_of_bounds',
          'initial block (${spawn.value}) at ${spawn.row}x${spawn.column} is '
          'outside the ${rows}x$columns board',
        );
      }
      final cell = (spawn.row, spawn.column);
      if (seen.contains(cell)) {
        report.add(
          ValidationSeverity.error,
          'duplicate_initial_block',
          'two initial blocks occupy ${cell.$1}x${cell.$2}',
        );
      }
      seen.add(cell);
      if (spawn.value < 2 || spawn.value & (spawn.value - 1) != 0) {
        report.add(
          ValidationSeverity.error,
          'invalid_block_value',
          'initial block value ${spawn.value} is not a power of two >= 2',
        );
      }
    }

    if (!_hasFreeCell(level)) {
      report.add(
        ValidationSeverity.error,
        'dead_end_start',
        'no column can accept a drop - the level cannot be played',
      );
    }

    if (level.objective.target <= 0) {
      report.add(
        ValidationSeverity.error,
        'invalid_objective',
        'objective ${level.objective.type.name} has a non-positive target',
      );
    }

    if (level.effectiveMoveLimit > 0 && level.effectiveMoveLimit < 10) {
      report.add(
        ValidationSeverity.error,
        'move_limit_too_small',
        'move limit ${level.effectiveMoveLimit} leaves no room to play',
      );
    }

    final weights = level.difficulty.spawnWeights;
    if (weights.isEmpty || weights.values.reduce((a, b) => a + b) <= 0) {
      report.add(
        ValidationSeverity.error,
        'empty_spawn_weights',
        'spawn weights are empty',
      );
    }

    if (level.stars.twoStarScore >= level.stars.threeStarScore) {
      report.add(
        ValidationSeverity.warning,
        'flat_star_thresholds',
        '2-star threshold (${level.stars.twoStarScore}) is not below the '
        '3-star threshold (${level.stars.threeStarScore})',
      );
    }

    if (level.allowedBoosters.isEmpty) {
      report.add(
        ValidationSeverity.info,
        'no_boosters',
        'level allows no boosters',
      );
    }
  }

  bool _hasFreeCell(Level level) {
    final grid = List<List<BlockState?>>.generate(
      rows,
      (_) => List<BlockState?>.filled(columns, null),
    );
    for (var i = 0; i < level.initialBlocks.length; i++) {
      final spawn = level.initialBlocks[i];
      if (spawn.row >= 0 &&
          spawn.row < rows &&
          spawn.column >= 0 &&
          spawn.column < columns) {
        grid[spawn.row][spawn.column] = BlockState(
          id: i + 1,
          value: spawn.value,
          row: spawn.row,
          column: spawn.column,
        );
      }
    }
    return GameBoard.fromCells(rows, columns, grid).hasLegalDrop;
  }

  void _simulationIssues(
    ValidationReport report,
    Level level,
    SimulationReport simulation,
  ) {
    final completion = simulation.completionRate;
    final avgScore = simulation.averageScore;
    final starFloor = mathMax1(level.stars.threeStarScore);

    if (completion < minCompletion) {
      report.add(
        ValidationSeverity.error,
        'impossible_level',
        'only ${(completion * 100).round()}% of simulated games complete the '
        'objective',
      );
    } else if (completion > maxCompletion &&
        !trivialExemptIds.contains(level.id) &&
        avgScore > trivialScoreMultiplier * starFloor) {
      report.add(
        ValidationSeverity.warning,
        'trivial_level',
        '${(completion * 100).round()}% completion with an average score '
        '${(avgScore / starFloor).toStringAsFixed(1)}x the 3-star threshold',
      );
    }

    if (simulation.bestScore < level.stars.twoStarScore) {
      report.add(
        ValidationSeverity.warning,
        'unreachable_two_star',
        'best simulated score (${simulation.bestScore}) never reaches the '
        '2-star threshold (${level.stars.twoStarScore})',
      );
    }
    if (simulation.bestScore < level.stars.threeStarScore) {
      report.add(
        ValidationSeverity.warning,
        'unreachable_three_star',
        'best simulated score (${simulation.bestScore}) never reaches the '
        '3-star threshold (${level.stars.threeStarScore})',
      );
    }
  }
}

/// Keeps the "1 or more" guard in one place.
double mathMax1(int value) => value <= 1 ? 1 : value.toDouble();

/// Alias so the tutorial exemption list has a single home.
abstract final class LevelGeneratorBridge {
  const LevelGeneratorBridge._();

  static const Set<int> tutorialExemptIds = <int>{1, 2, 3};
}
