"""Mirror of lib/features/levels/domain/level.dart."""
from .difficulty_profile import DifficultyProfile
from .level_objective import LevelObjective
from .star_thresholds import StarThresholds

DEFAULT_BOOSTERS = ["undo", "hammer", "shuffle"]


class BlockSpawn:
    __slots__ = ("value", "row", "column")

    def __init__(self, value, row, column):
        self.value = value
        self.row = row
        self.column = column

    def to_json(self):
        return {"value": self.value, "row": self.row, "column": self.column}

    @staticmethod
    def from_json(data):
        return BlockSpawn(int(data["value"]), int(data["row"]), int(data["column"]))


class Level:
    def __init__(self, id, objective, difficulty, move_limit=None, initial_blocks=None,
                 allowed_boosters=None, stars=None, chapter=1, is_curated=False,
                 tutorial_step_key=None, name_key=None):
        self.id = id
        self.objective = objective
        self.difficulty = difficulty
        self.move_limit = move_limit
        self.initial_blocks = list(initial_blocks or [])
        self.allowed_boosters = list(allowed_boosters) if allowed_boosters is not None else list(DEFAULT_BOOSTERS)
        self.stars = stars if stars is not None else StarThresholds(0, 0)
        self.chapter = chapter
        self.is_curated = is_curated
        self.tutorial_step_key = tutorial_step_key
        self.name_key = name_key

    def allows_booster(self, booster_id):
        return booster_id in self.allowed_boosters

    @property
    def effective_move_limit(self):
        if self.move_limit:
            return self.move_limit
        return self.difficulty.move_limit or 0

    @property
    def has_move_limit(self):
        return self.effective_move_limit > 0

    def copy_with(self, **kw):
        data = {
            "id": self.id, "objective": self.objective, "move_limit": self.move_limit,
            "initial_blocks": self.initial_blocks,
            "allowed_boosters": self.allowed_boosters, "difficulty": self.difficulty,
            "stars": self.stars, "chapter": self.chapter,
            "is_curated": self.is_curated,
            "tutorial_step_key": self.tutorial_step_key, "name_key": self.name_key,
        }
        data.update(kw)
        return Level(**data)

    def to_json(self):
        return {
            "id": self.id, "chapter": self.chapter, "objective": self.objective.to_json(),
            "moveLimit": self.move_limit,
            "initialBlocks": [b.to_json() for b in self.initial_blocks],
            "allowedBoosters": self.allowed_boosters,
            "difficulty": self.difficulty.to_json(), "stars": self.stars.to_json(),
            "curated": self.is_curated,
            **({"tutorialStep": self.tutorial_step_key} if self.tutorial_step_key else {}),
            **({"nameKey": self.name_key} if self.name_key else {}),
        }

    @staticmethod
    def from_json(data):
        return Level(
            id=int(data["id"]), chapter=int(data.get("chapter", 1)),
            objective=LevelObjective.decode(data.get("objective") or {}),
            move_limit=data.get("moveLimit"),
            initial_blocks=[BlockSpawn.from_json(b) for b in (data.get("initialBlocks") or [])],
            allowed_boosters=list(data.get("allowedBoosters") or []),
            difficulty=DifficultyProfile.from_json(data.get("difficulty") or {}),
            stars=StarThresholds.from_json(data.get("stars") or {}),
            is_curated=bool(data.get("curated", False)),
            tutorial_step_key=data.get("tutorialStep"),
            name_key=data.get("nameKey"))
