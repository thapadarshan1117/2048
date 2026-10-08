"""Mirror of lib/features/game/domain/game_stats.dart."""


class GameStats:
    __slots__ = ("score", "merge_count", "moves_used", "highest_value_created",
                 "highest_value_on_board", "longest_combo", "total_score_from_merges")

    def __init__(self, score=0, merge_count=0, moves_used=0, highest_value_created=0,
                 highest_value_on_board=0, longest_combo=0, total_score_from_merges=0):
        self.score = score
        self.merge_count = merge_count
        self.moves_used = moves_used
        self.highest_value_created = highest_value_created
        self.highest_value_on_board = highest_value_on_board
        self.longest_combo = longest_combo
        self.total_score_from_merges = total_score_from_merges

    def copy_with(self, **kw):
        data = {
            "score": self.score, "merge_count": self.merge_count,
            "moves_used": self.moves_used,
            "highest_value_created": self.highest_value_created,
            "highest_value_on_board": self.highest_value_on_board,
            "longest_combo": self.longest_combo,
            "total_score_from_merges": self.total_score_from_merges,
        }
        data.update(kw)
        return GameStats(**data)

    def apply_drop(self, score_gained, merges, longest_chain, board_highest):
        return GameStats(
            score=self.score + score_gained,
            merge_count=self.merge_count + merges,
            moves_used=self.moves_used + 1,
            highest_value_created=max(self.highest_value_created, board_highest),
            highest_value_on_board=max(self.highest_value_on_board, board_highest),
            longest_combo=max(self.longest_combo, longest_chain),
            total_score_from_merges=self.total_score_from_merges + score_gained,
        )

    def to_json(self):
        return {"score": self.score, "merges": self.merge_count, "moves": self.moves_used,
                "highestCreated": self.highest_value_created,
                "highestOnBoard": self.highest_value_on_board,
                "longestCombo": self.longest_combo}

    @staticmethod
    def from_json(data):
        return GameStats(
            score=int(data.get("score", 0)), merge_count=int(data.get("merges", 0)),
            moves_used=int(data.get("moves", 0)),
            highest_value_created=int(data.get("highestCreated", 0)),
            highest_value_on_board=int(data.get("highestOnBoard", 0)),
            longest_combo=int(data.get("longestCombo", 0)))
