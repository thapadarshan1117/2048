"""Mirror of lib/features/levels/data/level_generator.dart.

Levels are *generated*, never hand-written past the tutorial band. The first 20
levels are curated for pedagogy; everything after that comes from a
deterministic formula with deliberate pacing dips so the difficulty curve
breathes instead of climbing monotonically.

Crucially, every level is **measured** by the [GameSimulator] before it ships:
score targets, value targets, move limits and star thresholds are all derived
from simulated play rather than guessed. That is what keeps a 500-level
catalogue free of impossible and trivial levels.
"""
import math

from .difficulty_profile import DifficultyProfile, HeightLimitRestriction, \
    RestrictedColumnsRestriction
from .level import BlockSpawn, Level
from .level_objective import (ComboCountObjective, CompleteWithinMovesObjective,
                              CreateNumberObjective, MergeCountObjective,
                              ReachNumberObjective, ReachScoreObjective)
from .rng import Rng
from .star_thresholds import StarThresholds

DEFAULT_ROWS = 12
DEFAULT_COLUMNS = 6
LEVELS_PER_CHAPTER = 25

ALL_BOOSTERS = ["undo", "hammer", "shuffle"]


def calibration_budget_for(level, base_moves):
    """Move budget a level must be measured with.

    Value objectives need a far longer window than score objectives - a 512
    cannot be built in 120 drops - and *both* the generator and the validator
    must agree on the budget, otherwise a level is tuned against one game
    length and judged against another.
    """
    budget = base_moves
    if level.objective.type in ("createNumber", "reachNumber"):
        budget = _calibration_budget(level.objective.target, base_moves)
    # A move limit always wins: a 60-move level can never be judged on a
    # 120-move game, however generous the base budget is.
    limit = level.effective_move_limit
    if limit > 0:
        budget = min(budget, limit)
    return budget


def validation_seed(level_id):
    """Single seed base shared by calibration and validation.

    Using one seed means the numbers a level is tuned against are exactly the
    numbers it is checked against, which removes the false 'unreachable star'
    warnings caused by two independent random draws.
    """
    return 9001 + level_id


def _clamp(value, low, high):
    return max(low, min(high, value))


def _nice(value):
    """Rounds a target to a human-friendly number."""
    if value <= 0:
        return 0
    for step in (10, 25, 50, 100, 250, 500, 1000, 2500, 5000):
        if value < step * 20:
            return max(step, int(round(value / step)) * step)
    return int(round(value / 5000.0)) * 5000


def _pow2_down(value):
    if value < 2:
        return 2
    return 1 << int(math.floor(math.log2(value)))


def _weights_for(d):
    if d < 0.10:
        return {2: 100}
    if d < 0.25:
        return {2: 90, 4: 10}
    if d < 0.40:
        return {2: 85, 4: 13, 8: 2}
    if d < 0.55:
        return {2: 80, 4: 16, 8: 4}
    if d < 0.70:
        return {2: 72, 4: 20, 8: 8}
    if d < 0.85:
        return {2: 62, 4: 24, 8: 12, 16: 2}
    return {2: 52, 4: 26, 8: 16, 16: 6}


def _max_spawn_value_for(d):
    if d < 0.15:
        return 2
    if d < 0.45:
        return 4
    if d < 0.80:
        return 8
    return 16


def difficulty_of(level_id, total_levels=500):
    """Difficulty in 0..1 with deliberate pacing dips."""
    progress = (level_id - 1) / max(1, total_levels - 1)
    base = progress ** 0.85
    wave = 0.10 * math.sin(level_id * 0.55) + 0.05 * math.sin(level_id * 1.9)
    return _clamp(base + wave, 0.02, 1.0)


def _value_ceiling_for(difficulty):
    """Largest value a level asks the player to create.

    Measurement shows a strong player roughly doubles their best block every
    120 drops, so the ceiling is tied to difficulty and capped at 512: the
    1024/2048/4096 milestones belong to infinite mode, where a session can run
    for thousands of drops.
    """
    return int(_clamp(_pow2_down(2 ** (4.5 + 5.5 * difficulty)), 16, 512))


def _calibration_budget(target_value, base_moves):
    """Drops the simulator needs before a value target becomes reachable."""
    if target_value <= 0:
        return base_moves
    return int(_clamp(120 * target_value / 128, 60, 520))


def _combo_for(level_id):
    if level_id < 150:
        return 2
    if level_id < 300:
        return 3
    if level_id < 420:
        return 4
    return 5


# --- curated tutorial band -------------------------------------------------
# (id, objective kind, fallback target, weights, maxSpawn, moveLimit,
#  initial blocks, boosters, tutorial hint)
_CURATED = [
    # (id, objective kind, target, weights, maxSpawn, moveLimit,
    #  initial blocks, boosters, twoStar, threeStar, tutorial hint)
    #
    # Every target below was chosen by hand for its teaching purpose and then
    # *measured* with the simulator: see LEVEL_DESIGN.md for the numbers.
    (1, "reachScore", 20, {2: 100}, 2, None, [], [], 100, 500, "tut_drop"),
    (2, "reachScore", 60, {2: 100}, 2, None, [], ["undo"], 150, 800, "tut_merge"),
    (3, "reachScore", 150, {2: 100}, 2, None, [], ["undo"], 250, 1200,
     "tut_merge_again"),
    (4, "reachScore", 300, {2: 90, 4: 10}, 4, None, [], ["undo"], 400, 1800,
     "tut_chain"),
    (5, "reachScore", 500, {2: 85, 4: 15}, 4, None, [], ["undo"], 500, 2400, None),
    (6, "reachScore", 900, {2: 80, 4: 20}, 4, None, [], ["undo"], 800, 3400, None),
    (7, "reachScore", 1400, {2: 78, 4: 20, 8: 2}, 8, None, [], ["undo"], 1000,
     4200, None),
    (8, "reachScore", 1200, {2: 78, 4: 20, 8: 2}, 8, None, [], ["undo"], 900,
     3800, None),
    (9, "comboCount", 2, {2: 78, 4: 20, 8: 2}, 8, None, [], ["undo"], 700, 3000,
     None),
    (10, "mergeCount", 25, {2: 75, 4: 22, 8: 3}, 8, None, [], ALL_BOOSTERS, 900,
     3800, "tut_boosters"),
    (11, "reachScore", 1600, {2: 75, 4: 22, 8: 3}, 8, None, [], ALL_BOOSTERS, 900,
     3800, None),
    (12, "reachScore", 600, {2: 75, 4: 22, 8: 3}, 8, 60, [], ALL_BOOSTERS, 800,
     3400, None),
    (13, "createNumber", 32, {2: 75, 4: 22, 8: 3}, 8, None, [], ALL_BOOSTERS, 700,
     3000, None),
    (14, "comboCount", 3, {2: 74, 4: 22, 8: 4}, 8, None, [], ALL_BOOSTERS, 1000,
     4200, None),
    (15, "reachScore", 2200, {2: 74, 4: 22, 8: 4}, 8, None,
     [(2, 11, 0), (4, 11, 1), (2, 10, 0), (8, 11, 5)], ALL_BOOSTERS, 1100, 4600,
     None),
    (16, "createNumber", 64, {2: 72, 4: 23, 8: 5}, 8, None, [],
     ["hammer", "shuffle"], 900, 3800, None),
    (17, "createNumber", 128, {2: 70, 4: 24, 8: 6}, 8, None, [], ALL_BOOSTERS,
     1100, 4600, None),
    (18, "comboCount", 4, {2: 68, 4: 25, 8: 7}, 8, None, [], ALL_BOOSTERS, 1200,
     5000, None),
    (19, "createNumber", 256, {2: 66, 4: 26, 8: 8}, 8, None, [], ALL_BOOSTERS,
     2000, 8000, None),
    (20, "createNumber", 512, {2: 62, 4: 27, 8: 11}, 8, None,
     [(4, 11, 2), (8, 11, 3), (16, 10, 2)], ALL_BOOSTERS, 6000, 20000, None),
]

_OBJECTIVE_BUILDERS = {
    "reachScore": ReachScoreObjective,
    "createNumber": CreateNumberObjective,
    "mergeCount": MergeCountObjective,
    "reachNumber": ReachNumberObjective,
    "comboCount": ComboCountObjective,
    "completeWithinMoves": CompleteWithinMovesObjective,
}


class LevelGenerator:
    def __init__(self, total_levels=500, rows=DEFAULT_ROWS, columns=DEFAULT_COLUMNS,
                 levels_per_chapter=LEVELS_PER_CHAPTER, seed=20260101,
                 simulator=None, games=3, skill=0.75, max_moves=120):
        self.total_levels = total_levels
        self.rows = rows
        self.columns = columns
        self.levels_per_chapter = levels_per_chapter
        self.seed = seed
        self.simulator = simulator
        self.games = games
        self.skill = skill
        self.max_moves = max_moves

    # --- public API --------------------------------------------------------
    def generate_all(self, calibrate=True):
        return [self.generate(n, calibrate=calibrate)
                for n in range(1, self.total_levels + 1)]

    def generate(self, level_id, calibrate=True):
        return self.generate_with_report(level_id, calibrate=calibrate)[0]

    def generate_with_report(self, level_id, calibrate=True):
        """Returns `(level, simulation_report_or_None)`.

        Exposing the report lets the validator check the level against the very
        simulation it was tuned with, instead of rolling a second, slightly
        different set of games.
        """
        if level_id < 1:
            raise ValueError("level ids start at 1")
        draft = self._draft(level_id)
        if not calibrate or self.simulator is None:
            return draft, None
        return self._calibrate(draft)

    def chapter_of(self, level_id):
        return 1 + (level_id - 1) // self.levels_per_chapter

    def chapter_range(self, chapter):
        start = (chapter - 1) * self.levels_per_chapter + 1
        end = min(self.total_levels, chapter * self.levels_per_chapter)
        return start, end

    # --- drafts ------------------------------------------------------------
    def _draft(self, level_id):
        curated = self._curated_draft(level_id)
        if curated is not None:
            return curated
        return self._formula_draft(level_id)

    def _curated_draft(self, level_id):
        for entry in _CURATED:
            if entry[0] != level_id:
                continue
            (_, kind, target, weights, max_spawn, move_limit, initial,
             boosters, two_star, three_star, hint) = entry
            return Level(
                id=level_id, chapter=self.chapter_of(level_id),
                objective=_OBJECTIVE_BUILDERS[kind](target),
                move_limit=move_limit,
                initial_blocks=[BlockSpawn(v, r, c) for (v, r, c) in initial],
                allowed_boosters=list(boosters),
                difficulty=DifficultyProfile(spawn_weights=dict(weights),
                                             max_spawn_value=max_spawn),
                stars=StarThresholds(two_star, three_star),
                is_curated=True, tutorial_step_key=hint)
        return None

    def _formula_draft(self, level_id):
        d = difficulty_of(level_id, self.total_levels)
        rng = Rng(self.seed + level_id * 7919)

        weights = _weights_for(d)
        max_spawn = _max_spawn_value_for(d)
        phase = level_id % 6

        if phase == 0:
            kind, fallback = "reachScore", 0
        elif phase == 1:
            kind, fallback = "createNumber", _value_ceiling_for(d)
        elif phase == 2:
            kind, fallback = "mergeCount", int(round(20 + 180 * d))
        elif phase == 3:
            kind, fallback = "reachNumber", _value_ceiling_for(d)
        elif phase == 4:
            kind, fallback = "comboCount", _combo_for(level_id)
        else:
            kind, fallback = "reachScore", 0

        restriction = DifficultyProfile().restriction
        if level_id % 37 == 0:
            restriction = RestrictedColumnsRestriction({rng.next_int_below(self.columns)})
        elif level_id % 53 == 0:
            restriction = HeightLimitRestriction(self.rows - int(round(3 + 3 * d)))

        initial = []
        if d > 0.30:
            occupied = set()
            attempts = 0
            wanted = int(math.floor(d * 5))
            while len(initial) < wanted and attempts < wanted * 8:
                attempts += 1
                value = rng.pick([2, 2, 4, 4, 8, 8, 16, 16])
                row = self.rows - 1 - rng.next_int_below(3)
                column = rng.next_int_below(self.columns)
                if (row, column) in occupied:
                    continue
                # Never seal a column completely: a dead-end start is an
                # unplayable level, and the validator would reject it.
                if sum(1 for r in range(self.rows)
                       if (r, column) in occupied) >= self.rows - 1:
                    continue
                occupied.add((row, column))
                initial.append(BlockSpawn(value, row, column))

        return Level(
            id=level_id, chapter=self.chapter_of(level_id),
            objective=_OBJECTIVE_BUILDERS[kind](fallback),
            move_limit=None,
            initial_blocks=initial,
            allowed_boosters=list(ALL_BOOSTERS),
            difficulty=DifficultyProfile(spawn_weights=dict(weights),
                                         max_spawn_value=max_spawn,
                                         restriction=restriction),
            stars=StarThresholds(0, 0), is_curated=False)

    # --- calibration -------------------------------------------------------
    def _calibrate(self, draft):
        """Two-pass calibration.

        Pass 1 decides *what the level asks for*, using the move budget that
        target implies. Pass 2 re-measures the finished level with the budget
        the validator will use, and only then sets the star thresholds.

        Measuring stars during pass 1 would compare them against a longer or
        shorter game than the one they are finally judged on - exactly the kind
        of silent mismatch that produces unreachable 3-star ratings.
        """
        level, _ = self._set_objective(draft)

        probe = level.copy_with(move_limit=None)
        probe.difficulty.move_limit = None
        budget = calibration_budget_for(level, self.max_moves)
        report = self.simulator.simulate(
            probe, games=self.games, seed=validation_seed(level.id),
            skill=self.skill, max_moves=budget)

        avg_score = max(1.0, report.average_score)
        if level.is_curated:
            # Hand-authored levels keep their designer's thresholds, clamped so
            # a 3-star rating stays attainable by a strong player.
            two_star = min(level.stars.two_star_score,
                           max(1, int(round(avg_score * 0.45))))
            three_star = min(level.stars.three_star_score,
                             max(1, int(round(avg_score * 0.75))))
            if three_star <= two_star:
                # Lower the 2-star bar rather than inflating the 3-star one.
                two_star = max(1, three_star // 2)
        else:
            # Thresholds sit well below the measured average: stars are awarded
            # on the player's *best* run, and a good human beats the bot.
            two_star = _nice(avg_score * 0.35)
            three_star = _nice(avg_score * 0.55)
            if three_star <= two_star:
                three_star = two_star + max(10, two_star // 2)

        calibrated = level.copy_with(stars=StarThresholds(two_star, three_star))
        # Re-point the report at the finished level so completion and star
        # averages are derived from the objective that actually shipped.
        report.level = calibrated
        return calibrated, report

    def _set_objective(self, draft):
        """Pass 1: pick the objective target from a measured game."""
        probe = draft.copy_with(move_limit=None)
        probe.difficulty.move_limit = None
        budget = calibration_budget_for(draft, self.max_moves)
        report = self.simulator.simulate(
            probe, games=self.games, seed=validation_seed(draft.id),
            skill=self.skill, max_moves=budget)

        avg_score = max(1.0, report.average_score)
        avg_moves = max(1.0, report.average_moves)
        avg_highest = max(2.0, report.average_highest_value)
        avg_merges = max(1.0, report.average_merges)
        avg_chain = max(1.0, sum(report.chains) / max(1, len(report.chains)))

        kind = draft.objective.type
        objective = draft.objective
        move_limit = draft.move_limit

        if not draft.is_curated:
            # A generated level is measured *without* its limit, so its target
            # is set conservatively: the player has to hit it inside a budget
            # that is only 40% longer than the measurement window.
            if kind == "reachScore":
                share = 0.70 if draft.id % 6 == 5 else 0.85
                objective = ReachScoreObjective(_nice(avg_score * share))
            elif kind in ("createNumber", "reachNumber"):
                target = _pow2_down(avg_highest * 0.9)
                target = min(target, _value_ceiling_for(
                    difficulty_of(draft.id, self.total_levels)))
                builder = (CreateNumberObjective if kind == "createNumber"
                           else ReachNumberObjective)
                objective = builder(max(4, target))
            elif kind == "mergeCount":
                objective = MergeCountObjective(
                    max(3, int(round(avg_merges * 0.8))))
            elif kind == "comboCount":
                objective = ComboCountObjective(
                    max(2, int(round(avg_chain * 0.8))))

            if kind == "reachScore" and draft.id % 6 == 5:
                move_limit = max(15, int(round(avg_moves * 1.4)))

        level = draft.copy_with(objective=objective, move_limit=move_limit)
        report.level = level
        return level, report
