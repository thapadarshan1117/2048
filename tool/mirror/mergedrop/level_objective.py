"""Mirror of lib/features/levels/domain/level_objective.dart."""


class ObjectiveType:
    REACH_SCORE = "reachScore"
    CREATE_NUMBER = "createNumber"
    MERGE_COUNT = "mergeCount"
    REACH_NUMBER = "reachNumber"
    COMPLETE_WITHIN_MOVES = "completeWithinMoves"
    COMBO_COUNT = "comboCount"

    ALL = (REACH_SCORE, CREATE_NUMBER, MERGE_COUNT, REACH_NUMBER,
           COMPLETE_WITHIN_MOVES, COMBO_COUNT)


def _ratio(value, target):
    if target <= 0:
        return 1.0
    return max(0.0, min(1.0, value / target))


class LevelObjective:
    type = ObjectiveType.REACH_SCORE
    localization_key = "objective_reach_score"

    def __init__(self, target):
        self.target = int(target)

    def is_satisfied(self, stats):
        raise NotImplementedError

    def progress(self, stats):
        raise NotImplementedError

    def to_json(self):
        return {"type": self.type, "target": self.target}

    @staticmethod
    def decode(data):
        t = data.get("type")
        target = int(data.get("target", 0) or 0)
        if t == ObjectiveType.CREATE_NUMBER:
            return CreateNumberObjective(target)
        if t == ObjectiveType.MERGE_COUNT:
            return MergeCountObjective(target)
        if t == ObjectiveType.REACH_NUMBER:
            return ReachNumberObjective(target)
        if t == ObjectiveType.COMPLETE_WITHIN_MOVES:
            return CompleteWithinMovesObjective(target)
        if t == ObjectiveType.COMBO_COUNT:
            return ComboCountObjective(target)
        return ReachScoreObjective(target if target > 0 else 100)


class ReachScoreObjective(LevelObjective):
    type = ObjectiveType.REACH_SCORE
    localization_key = "objective_reach_score"

    def is_satisfied(self, stats):
        return stats.score >= self.target

    def progress(self, stats):
        return _ratio(stats.score, self.target)


class CreateNumberObjective(LevelObjective):
    type = ObjectiveType.CREATE_NUMBER
    localization_key = "objective_create_number"

    def is_satisfied(self, stats):
        return stats.highest_value_created >= self.target

    def progress(self, stats):
        return _ratio(stats.highest_value_created, self.target)


class MergeCountObjective(LevelObjective):
    type = ObjectiveType.MERGE_COUNT
    localization_key = "objective_merge_count"

    def is_satisfied(self, stats):
        return stats.merge_count >= self.target

    def progress(self, stats):
        return _ratio(stats.merge_count, self.target)


class ReachNumberObjective(LevelObjective):
    type = ObjectiveType.REACH_NUMBER
    localization_key = "objective_reach_number"

    def is_satisfied(self, stats):
        return stats.highest_value_on_board >= self.target

    def progress(self, stats):
        return _ratio(stats.highest_value_on_board, self.target)


class CompleteWithinMovesObjective(LevelObjective):
    type = ObjectiveType.COMPLETE_WITHIN_MOVES
    localization_key = "objective_complete_within_moves"

    def is_satisfied(self, stats):
        return stats.moves_used <= self.target

    def progress(self, stats):
        if self.target <= 0:
            return 1.0
        return max(0.0, min(1.0, 1 - stats.moves_used / self.target))


class ComboCountObjective(LevelObjective):
    type = ObjectiveType.COMBO_COUNT
    localization_key = "objective_combo_count"

    def is_satisfied(self, stats):
        return stats.longest_combo >= self.target

    def progress(self, stats):
        return _ratio(stats.longest_combo, self.target)
