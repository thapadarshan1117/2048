"""Mirror of lib/features/levels/data/level_validator.dart.

Static checks plus simulation-backed checks. A level is only shipped when it
passes, which is what keeps a 500-level catalogue free of impossible, trivial
and dead-end levels.
"""
from .block_state import BlockState
from .game_board import GameBoard
from .level import Level
from .level_generator import validation_seed

ERROR = "error"
WARNING = "warning"
INFO = "info"

DEFAULT_ROWS = 12
DEFAULT_COLUMNS = 6


class ValidationIssue:
    __slots__ = ("severity", "code", "message")

    def __init__(self, severity, code, message):
        self.severity = severity
        self.code = code
        self.message = message

    def __repr__(self):
        return "[%s] %s: %s" % (self.severity, self.code, self.message)


class ValidationReport:
    __slots__ = ("level_id", "issues", "simulation")

    def __init__(self, level_id):
        self.level_id = level_id
        self.issues = []
        self.simulation = None

    def add(self, severity, code, message):
        self.issues.append(ValidationIssue(severity, code, message))

    @property
    def errors(self):
        return [i for i in self.issues if i.severity == ERROR]

    @property
    def warnings(self):
        return [i for i in self.issues if i.severity == WARNING]

    @property
    def ok(self):
        return not self.errors

    def summary(self):
        if self.ok and not self.warnings:
            return "level %d: OK" % self.level_id
        return "level %d: %s" % (self.level_id, "; ".join(
            str(i) for i in self.issues))


class LevelValidator:
    def __init__(self, rows=DEFAULT_ROWS, columns=DEFAULT_COLUMNS,
                 simulator=None, games=6, skill=0.8,
                 min_completion=0.15, max_completion=0.995,
                 trivial_score_multiplier=2.5, trivial_exempt_ids=None):
        self.rows = rows
        self.columns = columns
        self.simulator = simulator
        self.games = games
        self.skill = skill
        self.min_completion = min_completion
        self.max_completion = max_completion
        self.trivial_score_multiplier = trivial_score_multiplier
        # The opening tutorial band is *meant* to be trivial: the player is
        # still learning where to tap. Flagging it as a balance problem would
        # just train designers to ignore the warning.
        self.trivial_exempt_ids = set(trivial_exempt_ids or ())

    # --- static checks -----------------------------------------------------
    def static_issues(self, level):
        issues = []
        seen = set()
        for spawn in level.initial_blocks:
            if not (0 <= spawn.row < self.rows and 0 <= spawn.column < self.columns):
                issues.append(ValidationIssue(
                    ERROR, "initial_block_out_of_bounds",
                    "initial block (%d) at %dx%d is outside the %dx%d board"
                    % (spawn.value, spawn.row, spawn.column, self.rows, self.columns)))
            key = (spawn.row, spawn.column)
            if key in seen:
                issues.append(ValidationIssue(
                    ERROR, "duplicate_initial_block",
                    "two initial blocks occupy %dx%d" % key))
            seen.add(key)
            if spawn.value < 2 or spawn.value & (spawn.value - 1):
                issues.append(ValidationIssue(
                    ERROR, "invalid_block_value",
                    "initial block value %d is not a power of two >= 2"
                    % spawn.value))

        if not self._has_free_cell(level):
            issues.append(ValidationIssue(
                ERROR, "dead_end_start",
                "no column can accept a drop - the level cannot be played"))

        if level.objective.target <= 0:
            issues.append(ValidationIssue(
                ERROR, "invalid_objective",
                "objective %s has a non-positive target"
                % level.objective.type))

        if level.effective_move_limit and level.effective_move_limit < 10:
            issues.append(ValidationIssue(
                ERROR, "move_limit_too_small",
                "move limit %d leaves no room to play"
                % level.effective_move_limit))

        weights = level.difficulty.spawn_weights
        if not weights or sum(weights.values()) <= 0:
            issues.append(ValidationIssue(
                ERROR, "empty_spawn_weights", "spawn weights are empty"))

        if level.stars.two_star_score >= level.stars.three_star_score:
            issues.append(ValidationIssue(
                WARNING, "flat_star_thresholds",
                "2-star threshold (%d) is not below the 3-star threshold (%d)"
                % (level.stars.two_star_score, level.stars.three_star_score)))

        if not level.allowed_boosters:
            issues.append(ValidationIssue(
                INFO, "no_boosters", "level allows no boosters"))

        return issues

    def _has_free_cell(self, level):
        grid = [[None] * self.columns for _ in range(self.rows)]
        for spawn in level.initial_blocks:
            if 0 <= spawn.row < self.rows and 0 <= spawn.column < self.columns:
                grid[spawn.row][spawn.column] = BlockState(1, spawn.value,
                                                           spawn.row, spawn.column)
        board = GameBoard.from_cells(self.rows, self.columns, grid)
        return board.has_legal_drop

    # --- full validation ---------------------------------------------------
    def validate(self, level, simulation=None):
        report = ValidationReport(level.id)
        report.issues.extend(self.static_issues(level))

        if simulation is not None:
            report.simulation = simulation
            self._simulation_issues(report, level, simulation)
            return report

        if self.simulator is None:
            return report

        # Value objectives must be measured with the same generous budget the
        # generator calibrated them with, otherwise a 512 target looks
        # impossible simply because the validator stopped after 120 drops.
        # `calibration_budget_for` (not the raw helper) so a move-limited level
        # is still judged inside its own limit - exactly what
        # lib/features/levels/data/level_validator.dart does.
        from .level_generator import calibration_budget_for
        budget = calibration_budget_for(level, self.simulator.max_moves)
        simulation = self.simulator.simulate(
            level, games=self.games, seed=validation_seed(level.id),
            skill=self.skill, max_moves=budget)
        report.simulation = simulation
        self._simulation_issues(report, level, simulation)
        return report

    def _simulation_issues(self, report, level, simulation):
        if True:
            completion = simulation.completion_rate
        avg_score = simulation.average_score

        if completion < self.min_completion:
            report.add(ERROR, "impossible_level",
                       "only %.0f%% of simulated games complete the objective"
                       % (completion * 100))
        elif (completion > self.max_completion
              and level.id not in self.trivial_exempt_ids
              and avg_score > (
                  self.trivial_score_multiplier
                  * max(1, level.stars.three_star_score))):
            report.add(WARNING, "trivial_level",
                       "100%% completion with an average score %.0fx the 3-star "
                       "threshold" % (avg_score / max(1, level.stars.three_star_score)))

        if simulation.best_score < level.stars.two_star_score:
            report.add(WARNING, "unreachable_two_star",
                       "best simulated score (%d) never reaches the 2-star "
                       "threshold (%d)" % (simulation.best_score,
                                           level.stars.two_star_score))
        if simulation.best_score < level.stars.three_star_score:
            report.add(WARNING, "unreachable_three_star",
                       "best simulated score (%d) never reaches the 3-star "
                       "threshold (%d)" % (simulation.best_score,
                                           level.stars.three_star_score))
