"""Mirror of lib/features/levels/data/game_simulator.dart.

A deterministic greedy bot used to balance the level catalogue: it estimates
completion probability, average score and average move count without a human
in the loop.
"""
from .block_state import BlockState
from .game_board import GameBoard
from .game_engine import GameEngine

DEFAULT_ROWS = 12
DEFAULT_COLUMNS = 6


class SimulationReport:
    """Aggregated result of simulating one level.

    The raw per-game statistics are kept in `runs` and every derived figure is
    computed from them *against the level currently attached to the report*.
    That matters because the level generator measures a draft, rewrites its
    objective and then wants to validate the finished level: re-deriving
    completion from the raw runs keeps the two in sync instead of reporting a
    completion rate measured against a target that no longer exists.
    """

    __slots__ = ("level_id", "level", "runs", "scores", "moves", "merges",
                 "highest_values", "chains")

    def __init__(self, level_id, level=None):
        self.level_id = level_id
        self.level = level
        self.runs = []
        self.scores = []
        self.moves = []
        self.merges = []
        self.highest_values = []
        self.chains = []

    @property
    def games(self):
        return len(self.runs)

    @property
    def completion_rate(self):
        if not self.runs or self.level is None:
            return 0.0
        hits = sum(1 for stats in self.runs
                   if self.level.objective.is_satisfied(stats))
        return hits / len(self.runs)

    @property
    def average_score(self):
        return sum(self.scores) / len(self.scores) if self.scores else 0.0

    @property
    def average_moves(self):
        return sum(self.moves) / len(self.moves) if self.moves else 0.0

    @property
    def average_merges(self):
        return sum(self.merges) / len(self.merges) if self.merges else 0.0

    @property
    def average_highest_value(self):
        return (sum(self.highest_values) / len(self.highest_values)
                if self.highest_values else 0.0)

    @property
    def average_stars(self):
        if not self.runs or self.level is None:
            return 0.0
        return sum(self.level.stars.stars_for(stats.score)
                   for stats in self.runs) / len(self.runs)

    @property
    def best_score(self):
        return max(self.scores) if self.scores else 0

    def to_dict(self):
        return {
            "level": self.level_id,
            "games": self.games,
            "completion": round(self.completion_rate * 100, 1),
            "avgScore": int(round(self.average_score)),
            "bestScore": self.best_score,
            "avgMoves": int(round(self.average_moves)),
            "avgMerges": int(round(self.average_merges)),
            "avgHighest": int(round(self.average_highest_value)),
            "avgStars": round(self.average_stars, 2),
            "completions": sum(1 for s in self.runs
                               if self.level and self.level.objective.is_satisfied(s)),
        }

    def summary(self):
        return ("Level %d | games %d | completion %.1f%% | avg score %d | "
                "avg moves %d | avg highest %d" % (
                    self.level_id, self.games, self.completion_rate * 100,
                    self.average_score, self.average_moves,
                    self.average_highest_value))


class GameSimulator:
    """Plays levels with a deterministic greedy bot."""

    def __init__(self, rows=DEFAULT_ROWS, columns=DEFAULT_COLUMNS, max_moves=400,
                 skill=0.75):
        self.rows = rows
        self.columns = columns
        self.max_moves = max_moves
        # 1.0 plays perfectly; lower values inject human-like mistakes so the
        # estimates model a real player rather than a theoretical optimum.
        self.skill = max(0.0, min(1.0, skill))
        self._skill_rng = None

    @staticmethod
    def _heuristic(outcome):
        """Ranks a candidate drop.

        The bot deliberately favours *consolidating* value into fewer, larger
        blocks over farming small merges: that is what a strong human does, and
        a purely greedy bot plateaus around 128 and would make every
        value-based level look impossible.
        """
        import math
        resolution = outcome.resolution
        merges = resolution.merge_count if resolution else 0
        chain = resolution.longest_chain if resolution else 0
        board = outcome.state.board
        blocks = board.blocks
        max_value = max((b.value for b in blocks), default=0)
        empty_cells = board.rows * board.columns - len(blocks)
        distinct_values = len({b.value for b in blocks})
        return (outcome.score_gained
                + 100 * merges
                + 80 * chain
                + 350 * (math.log2(max_value) if max_value > 0 else 0)
                + 45 * empty_cells
                - 16 * len(blocks)
                - 22 * distinct_values)

    @staticmethod
    def _initial_board(level):
        blocks = [BlockState(i + 1, s.value, s.row, s.column)
                  for i, s in enumerate(level.initial_blocks)]
        return GameBoard(DEFAULT_ROWS, DEFAULT_COLUMNS, blocks)

    def play_once(self, level, seed):
        from .rng import Rng
        engine = GameEngine.start(self._initial_board(level), level.difficulty,
                                  seed=seed, level=level)
        skill_rng = Rng(seed ^ 0x5F3759DF)
        moves = 0
        while not engine.state.is_game_over and moves < self.max_moves:
            legal = [c for c in range(self.columns) if engine.can_drop(c)]
            if not legal:
                break
            chosen = None
            if self.skill < 1.0 and skill_rng.next_double() > self.skill:
                chosen = legal[skill_rng.next_int_below(len(legal))]
            if chosen is None:
                best_column = None
                best_value = None
                for column in legal:
                    outcome = engine.clone().drop(column)
                    value = self._heuristic(outcome)
                    if best_value is None or value > best_value:
                        best_value = value
                        best_column = column
                chosen = best_column
            if chosen is None:
                break
            engine.drop(chosen)
            moves += 1
            # A move limit always ends the level: the player either met the
            # objective inside the budget or they did not. Stopping only on
            # failure would let the validator silently measure an unlimited
            # game and declare a move-limited level impossible.
            if level.effective_move_limit and moves >= level.effective_move_limit:
                break
        return engine.state

    def simulate(self, level, games=10, seed=1, skill=None, max_moves=None):
        """Plays `level` `games` times and aggregates the results."""
        skill = self.skill if skill is None else skill
        max_moves = self.max_moves if max_moves is None else max_moves
        previous_skill, previous_moves = self.skill, self.max_moves
        self.skill, self.max_moves = skill, max_moves
        report = SimulationReport(level.id, level)
        for i in range(games):
            state = self.play_once(level, seed + i * 104729)
            report.runs.append(state.stats)
            report.scores.append(state.score)
            report.moves.append(state.moves_used)
            report.merges.append(state.stats.merge_count)
            report.highest_values.append(state.stats.highest_value_created)
            report.chains.append(state.stats.longest_combo)
        self.skill, self.max_moves = previous_skill, previous_moves
        return report
