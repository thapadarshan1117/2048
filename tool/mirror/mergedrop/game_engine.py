"""Mirror of lib/features/game/domain/game_engine.dart."""
from .block_generator import BlockGenerator
from .block_state import BlockState
from .game_board import GameBoard
from .game_state import GameState, GameStateCore
from .game_stats import GameStats
from .merge_engine import MergeEngine
from .rng import Rng

MAX_UNDO_DEPTH = 20


class DropRejection:
    NONE = "none"
    INVALID_COLUMN = "invalidColumn"
    COLUMN_FULL = "columnFull"
    BOARD_FULL = "boardFull"
    SESSION_OVER = "sessionOver"


class DropOutcome:
    __slots__ = ("accepted", "rejection", "state", "dropped_block", "landing_row",
                 "resolution", "level_completed", "game_over")

    def __init__(self, accepted, rejection, state, dropped_block=None, landing_row=None,
                 resolution=None, level_completed=False, game_over=False):
        self.accepted = accepted
        self.rejection = rejection
        self.state = state
        self.dropped_block = dropped_block
        self.landing_row = landing_row
        self.resolution = resolution
        self.level_completed = level_completed
        self.game_over = game_over

    @property
    def had_merges(self):
        return bool(self.resolution and self.resolution.had_merges)

    @property
    def score_gained(self):
        return self.resolution.score_gained if self.resolution else 0

    @property
    def merge_events(self):
        return self.resolution.events if self.resolution else []


class GameEngine:
    def __init__(self, initial_state, profile, generator, merge_engine=None):
        self._state = initial_state
        self.profile = profile
        self.generator = generator
        self.merge_engine = merge_engine or MergeEngine()

    @staticmethod
    def _initial_block_id(board):
        max_id = 0
        for b in board.blocks:
            max_id = max(max_id, b.id)
        return max_id + 1

    @classmethod
    def start(cls, board, profile, seed=None, level=None, mode="level",
              initial_next_value=None, merge_engine=None):
        generator = BlockGenerator(profile, seed=seed)
        next_value = initial_next_value if initial_next_value is not None else generator.next()
        state = GameState(board=board, next_block_id=cls._initial_block_id(board),
                          next_block_value=next_value, stats=GameStats(),
                          level=level, mode=mode, rng_state=generator.rng.state)
        return cls(state, profile, generator, merge_engine)

    @classmethod
    def restore(cls, core, profile, level=None, mode="level", undo_history=None,
                merge_engine=None):
        generator = BlockGenerator(profile, rng=Rng(core.rng_state))
        state = GameState(
            board=core.board,
            next_block_id=max(1, core.next_block_id),
            next_block_value=core.next_block_value if core.next_block_value > 0 else 2,
            stats=core.stats, score=core.score, moves_used=core.moves_used,
            level=level, mode=mode,
            undo_history=list(undo_history or []),
            rng_state=core.rng_state,
            is_game_over=not core.board.has_legal_drop)
        return cls(state, profile, generator, merge_engine)

    def clone(self):
        return GameEngine(self._state, self.profile, self.generator.clone(),
                          self.merge_engine)

    @property
    def state(self):
        return self._state

    @property
    def is_over(self):
        return self._state.is_game_over

    def can_drop(self, column):
        if self._state.is_game_over:
            return False
        if column < 0 or column >= self._state.board.columns:
            return False
        return self.landing_row_for(column) is not None

    def landing_row_for(self, column):
        board = self._state.board
        if column < 0 or column >= board.columns:
            return None
        restriction = self.profile.restriction
        for row in range(board.rows - 1, -1, -1):
            if not restriction.allows(row, column):
                return None
            if board.cells[row][column] is None:
                return row
        return None

    def drop(self, column):
        current = self._state
        if current.is_game_over:
            return DropOutcome(False, DropRejection.SESSION_OVER, current)
        if column < 0 or column >= current.board.columns:
            return DropOutcome(False, DropRejection.INVALID_COLUMN, current)

        landing_row = self.landing_row_for(column)
        if landing_row is None:
            return DropOutcome(False, DropRejection.COLUMN_FULL, current)

        value = current.next_block_value
        dropped = BlockState(current.next_block_id, value, landing_row, column)
        board_after_drop = current.board.with_block(dropped)
        resolution = self.merge_engine.resolve(
            board_after_drop, current.next_block_id + 1,
            preferred_anchor_block_id=dropped.id)

        new_stats = current.stats.apply_drop(
            score_gained=resolution.score_gained, merges=resolution.merge_count,
            longest_chain=resolution.longest_chain,
            board_highest=resolution.highest_value)

        next_value = self.generator.next()
        history = list(current.undo_history) + [current]
        if len(history) > MAX_UNDO_DEPTH:
            history = history[len(history) - MAX_UNDO_DEPTH:]

        next_state = current.copy_with(
            board=resolution.board, next_block_id=resolution.next_block_id,
            next_block_value=next_value, stats=new_stats, score=new_stats.score,
            moves_used=new_stats.moves_used,
            is_game_over=not resolution.board.has_legal_drop,
            undo_history=history, rng_state=self.generator.rng.state)
        self._state = next_state

        return DropOutcome(
            True, DropRejection.NONE, next_state, dropped_block=dropped,
            landing_row=landing_row, resolution=resolution,
            level_completed=next_state.objectives_complete and next_state.mode == "level",
            game_over=next_state.is_game_over)

    def _append_history(self, previous):
        history = list(previous.undo_history) + [previous]
        if len(history) > MAX_UNDO_DEPTH:
            history = history[len(history) - MAX_UNDO_DEPTH:]
        return history

    def replace_state(self, new_state):
        self._state = new_state

    def to_core(self):
        s = self._state
        return GameStateCore(s.board, s.next_block_id, s.next_block_value, s.stats,
                             s.score, s.moves_used, s.rng_state)
