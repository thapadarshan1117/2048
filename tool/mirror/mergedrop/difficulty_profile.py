"""Mirror of lib/features/levels/domain/difficulty_profile.dart."""

DEFAULT_WEIGHTS = {2: 65, 4: 25, 8: 10}


class BoardRestriction:
    """Sealed-ish restriction base (mirrors the Dart sealed hierarchy)."""

    kind = "none"

    def allows(self, row, column):
        return True

    def to_json(self):
        return self.kind


class NoRestriction(BoardRestriction):
    kind = "none"


class RestrictedColumnsRestriction(BoardRestriction):
    kind = "restrictedColumns"

    def __init__(self, columns):
        self.columns = set(columns)

    def allows(self, row, column):
        return column not in self.columns


class HeightLimitRestriction(BoardRestriction):
    kind = "maxHeight"

    def __init__(self, top_row):
        self.top_row = top_row

    def allows(self, row, column):
        return row >= self.top_row


class DifficultyProfile:
    def __init__(self, spawn_weights=None, spawn_probability=1.0, max_spawn_value=8,
                 target_score=0, restriction=None, move_limit=None,
                 chain_bonus_multiplier=1.0):
        self.spawn_weights = dict(spawn_weights) if spawn_weights else dict(DEFAULT_WEIGHTS)
        self.spawn_probability = spawn_probability
        self.max_spawn_value = max_spawn_value
        self.target_score = target_score
        self.restriction = restriction if restriction is not None else NoRestriction()
        self.move_limit = move_limit
        self.chain_bonus_multiplier = chain_bonus_multiplier

    @property
    def min_spawn_value(self):
        return min(self.spawn_weights) if self.spawn_weights else 2

    @property
    def spawnable_values(self):
        values = sorted(v for v in self.spawn_weights if v <= self.max_spawn_value)
        return values if values else [2]

    def copy_with(self, **kw):
        data = {
            "spawn_weights": self.spawn_weights,
            "spawn_probability": self.spawn_probability,
            "max_spawn_value": self.max_spawn_value,
            "target_score": self.target_score,
            "restriction": self.restriction,
            "move_limit": self.move_limit,
            "chain_bonus_multiplier": self.chain_bonus_multiplier,
        }
        data.update(kw)
        return DifficultyProfile(**data)

    def to_json(self):
        data = {"spawnWeights": {str(k): v for k, v in self.spawn_weights.items()},
                "spawnProbability": self.spawn_probability,
                "maxSpawnValue": self.max_spawn_value,
                "targetScore": self.target_score,
                "restriction": self.restriction.kind,
                "moveLimit": self.move_limit,
                "chainBonusMultiplier": self.chain_bonus_multiplier}
        if isinstance(self.restriction, HeightLimitRestriction):
            data["restrictionTopRow"] = self.restriction.top_row
        if isinstance(self.restriction, RestrictedColumnsRestriction):
            data["restrictedColumns"] = sorted(self.restriction.columns)
        return data

    @staticmethod
    def from_json(data):
        weights = {}
        for k, v in (data.get("spawnWeights") or {}).items():
            try:
                key = int(k)
            except (TypeError, ValueError):
                continue
            if key > 0:
                weights[key] = int(v)
        if not weights:
            weights = dict(DEFAULT_WEIGHTS)
        kind = data.get("restriction")
        top_row = data.get("restrictionTopRow")
        columns = data.get("restrictedColumns")
        restriction = NoRestriction()
        if kind == "restrictedColumns" and columns:
            restriction = RestrictedColumnsRestriction({int(c) for c in columns})
        elif kind == "maxHeight" and top_row is not None:
            restriction = HeightLimitRestriction(int(top_row))
        return DifficultyProfile(
            spawn_weights=weights,
            spawn_probability=float(data.get("spawnProbability", 1.0)),
            max_spawn_value=int(data.get("maxSpawnValue", 8)),
            target_score=int(data.get("targetScore", 0)),
            restriction=restriction,
            move_limit=data.get("moveLimit"),
            chain_bonus_multiplier=float(data.get("chainBonusMultiplier", 1.0)))
