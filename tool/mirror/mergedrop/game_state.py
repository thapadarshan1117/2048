"""Mirror of lib/features/game/domain/game_state.dart."""
from .game_board import GameBoard
from .game_stats import GameStats


class GameStateCore:
    __slots__ = ("board", "next_block_id", "next_block_value", "stats", "score",
                 "moves_used", "rng_state")

    def __init__(self, board, next_block_id, next_block_value, stats, score,
                 moves_used, rng_state):
        self.board = board
        self.next_block_id = next_block_id
        self.next_block_value = next_block_value
        self.stats = stats
        self.score = score
        self.moves_used = moves_used
        self.rng_state = rng_state

    def to_json(self):
        return {"board": self.board.to_json(), "nextBlockId": self.next_block_id,
                "nextBlockValue": self.next_block_value, "stats": self.stats.to_json(),
                "score": self.score, "moves": self.moves_used, "rng": self.rng_state}

    @staticmethod
    def try_from_json(data):
        try:
            board_json = data.get("board")
            if not isinstance(board_json, dict):
                return None
            board = GameBoard.from_json(board_json)
            stats = GameStats.from_json(data.get("stats") or {})
            return GameStateCore(
                board, int(data.get("nextBlockId", 1)),
                int(data.get("nextBlockValue", 2)), stats,
                int(data.get("score", 0)), int(data.get("moves", 0)),
                int(data.get("rng", 1)))
        except Exception:
            return None


class GameState:
    __slots__ = ("board", "next_block_id", "next_block_value", "stats", "score",
                 "moves_used", "level", "mode", "is_game_over", "undo_history",
                 "rng_state")

    def __init__(self, board, next_block_id, next_block_value, stats, score=0,
                 moves_used=0, level=None, mode="level", is_game_over=False,
                 undo_history=None, rng_state=1):
        self.board = board
        self.next_block_id = next_block_id
        self.next_block_value = next_block_value
        self.stats = stats
        self.score = score
        self.moves_used = moves_used
        self.level = level
        self.mode = mode
        self.is_game_over = is_game_over
        self.undo_history = undo_history if undo_history is not None else []
        self.rng_state = rng_state

    @property
    def can_undo(self):
        return len(self.undo_history) > 0

    @property
    def objectives_complete(self):
        if self.level is None:
            return False
        return self.level.objective.is_satisfied(self.stats)

    @property
    def stars(self):
        return self.level.stars.stars_for(self.score) if self.level else 0

    @property
    def remaining_moves(self):
        limit = self.level.effective_move_limit if self.level else 0
        if limit <= 0:
            return -1
        return max(0, limit - self.moves_used)

    @property
    def objective_progress(self):
        return self.level.objective.progress(self.stats) if self.level else 0.0

    def copy_with(self, **kw):
        data = {
            "board": self.board, "next_block_id": self.next_block_id,
            "next_block_value": self.next_block_value, "stats": self.stats,
            "score": self.score, "moves_used": self.moves_used, "level": self.level,
            "mode": self.mode, "is_game_over": self.is_game_over,
            "undo_history": self.undo_history, "rng_state": self.rng_state,
        }
        data.update(kw)
        return GameState(**data)
