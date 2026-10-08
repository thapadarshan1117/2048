"""Mirror of lib/features/game/domain/game_snapshot.dart and
lib/features/game/data/game_snapshot_codec.dart."""
import json

from .game_state import GameStateCore

CURRENT_VERSION = 1
SUPPORTED_VERSION = 1


class GameSnapshot:
    __slots__ = ("version", "mode", "level_id", "core", "undo", "saved_at_ms")

    def __init__(self, version, mode, core, level_id=None, undo=None,
                 saved_at_ms=0):
        self.version = version
        self.mode = mode
        self.level_id = level_id
        self.core = core
        self.undo = list(undo or [])
        self.saved_at_ms = saved_at_ms

    @property
    def is_current_version(self):
        return self.version == CURRENT_VERSION

    def copy_with(self, **kw):
        data = {"version": self.version, "mode": self.mode,
                "level_id": self.level_id, "core": self.core,
                "undo": self.undo, "saved_at_ms": self.saved_at_ms}
        data.update(kw)
        return GameSnapshot(**data)


class GameSnapshotCodec:
    @staticmethod
    def encode(snapshot):
        return json.dumps({
            "v": snapshot.version,
            "mode": snapshot.mode,
            "levelId": snapshot.level_id,
            "savedAt": snapshot.saved_at_ms,
            "core": snapshot.core.to_json(),
            "undo": [c.to_json() for c in snapshot.undo],
        })

    @staticmethod
    def decode(raw):
        """Total decode: any malformed payload yields None, never an throw."""
        if not raw:
            return None
        try:
            decoded = json.loads(raw)
            if not isinstance(decoded, dict):
                return None
            version = decoded.get("v")
            if not isinstance(version, int) or version > SUPPORTED_VERSION:
                return None
            core_json = decoded.get("core")
            if not isinstance(core_json, dict):
                return None
            core = GameStateCore.try_from_json(core_json)
            if core is None:
                return None
            # A restored board must be playable: a board that cannot accept a
            # single drop is a finished game, not a resumable one.
            if not core.board.has_legal_drop:
                return None
            undo = []
            for entry in decoded.get("undo") or []:
                if not isinstance(entry, dict):
                    continue
                parsed = GameStateCore.try_from_json(entry)
                if parsed is not None:
                    undo.append(parsed)
            return GameSnapshot(version=version, mode=decoded.get("mode") or "level",
                                level_id=decoded.get("levelId"), core=core,
                                undo=undo, saved_at_ms=decoded.get("savedAt") or 0)
        except Exception:
            return None
