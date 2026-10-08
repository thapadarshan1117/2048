"""Save/resume round-trips and the deterministic daily seed."""
import json
import unittest

from helpers import ROWS, COLUMNS, board_from, empty_board, values
from mergedrop.daily import (daily_key, daily_seed, daily_seed_for_date, fnv1a32)
from mergedrop.difficulty_profile import DifficultyProfile
from mergedrop.game_engine import GameEngine
from mergedrop.game_snapshot import (CURRENT_VERSION, GameSnapshot,
                                        GameSnapshotCodec)
from mergedrop.game_state import GameStateCore
from mergedrop.level import Level
from mergedrop.level_objective import ReachScoreObjective
from mergedrop.star_thresholds import StarThresholds


class TestSnapshotCodec(unittest.TestCase):
    def _engine(self, seed=21):
        level = Level(7, ReachScoreObjective(1500), DifficultyProfile(),
                      stars=StarThresholds(600, 1100))
        engine = GameEngine.start(empty_board(), level.difficulty, seed=seed,
                                  level=level)
        for i in range(9):
            engine.drop(i % COLUMNS)
        return engine, level

    def _snapshot(self, engine, level):
        return GameSnapshot(version=CURRENT_VERSION,
                            mode="level", level_id=level.id,
                            core=engine.to_core(), saved_at_ms=1234567)

    def test_round_trip_restores_the_exact_board(self):
        engine, level = self._engine()
        raw = GameSnapshotCodec.encode(self._snapshot(engine, level))
        decoded = GameSnapshotCodec.decode(raw)
        self.assertIsNotNone(decoded)
        self.assertEqual(values(decoded.core.board), values(engine.state.board))
        self.assertEqual(decoded.core.score, engine.state.score)
        self.assertEqual(decoded.core.moves_used, engine.state.moves_used)
        self.assertEqual(decoded.core.next_block_value,
                         engine.state.next_block_value)
        self.assertEqual(decoded.level_id, level.id)

    def test_resume_keeps_generating_the_same_blocks(self):
        engine, level = self._engine(seed=77)
        raw = GameSnapshotCodec.encode(self._snapshot(engine, level))
        decoded = GameSnapshotCodec.decode(raw)
        resumed = GameEngine.restore(decoded.core, level.difficulty, level=level)
        self.assertEqual(resumed.state.next_block_value,
                         engine.state.next_block_value)

        # Both engines must now agree on the following value.
        self.assertEqual(resumed.generator.peek(), engine.generator.peek())

    def test_resume_can_continue_playing(self):
        engine, level = self._engine(seed=31)
        raw = GameSnapshotCodec.encode(self._snapshot(engine, level))
        decoded = GameSnapshotCodec.decode(raw)
        resumed = GameEngine.restore(decoded.core, level.difficulty, level=level)
        outcome = resumed.drop(0)
        self.assertTrue(outcome.accepted)
        self.assertEqual(resumed.state.moves_used,
                         engine.state.moves_used + 1)

    def test_corrupt_payloads_are_discarded_not_thrown(self):
        for payload in ("", "not json", "{}", "[]", "null", "123",
                        '{"v": 1}', '{"v": 99, "core": {}}',
                        '{"v":1,"mode":"level","core":{"board":{"rows":12,'
                        '"columns":6,"cells":[[0]]}}}'):
            self.assertIsNone(GameSnapshotCodec.decode(payload), payload[:40])

    def test_finished_game_is_not_resumable(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        for r in range(ROWS):
            for c in range(COLUMNS):
                grid[r][c] = 2 if (r + c) % 2 == 0 else 4
        board = board_from(ROWS, COLUMNS, grid)
        core = GameStateCore(board, 50, 2, __import__(
            "mergedrop.game_stats", fromlist=["GameStats"]).GameStats(), 0, 3, 1)
        snapshot = GameSnapshot(version=1, mode="level", level_id=1, core=core)
        self.assertIsNone(GameSnapshotCodec.decode(
            GameSnapshotCodec.encode(snapshot)))

    def test_future_versions_are_rejected(self):
        engine, level = self._engine()
        snapshot = self._snapshot(engine, level)
        future = snapshot.copy_with(version=CURRENT_VERSION + 1)
        raw = json.dumps({"v": future.version, "mode": "level",
                          "core": future.core.to_json()})
        self.assertIsNone(GameSnapshotCodec.decode(raw))

    @staticmethod
    def _core_of(state):
        return GameStateCore(state.board, state.next_block_id,
                             state.next_block_value, state.stats, state.score,
                             state.moves_used, state.rng_state)

    def test_undo_history_survives_a_save(self):
        engine, level = self._engine(seed=5)
        history = list(engine.state.undo_history)[-3:]
        snapshot = GameSnapshot(version=CURRENT_VERSION, mode="level",
                                level_id=level.id, core=engine.to_core(),
                                undo=[self._core_of(h) for h in history])
        decoded = GameSnapshotCodec.decode(GameSnapshotCodec.encode(snapshot))
        self.assertIsNotNone(decoded)
        self.assertEqual(len(decoded.undo), 3)
        self.assertEqual(values(decoded.undo[-1].board),
                         values(history[-1].board))


class TestDailySeed(unittest.TestCase):
    def test_key_is_zero_padded_iso_date(self):
        self.assertEqual(daily_key(2026, 10, 8), "2026-10-08")
        self.assertEqual(daily_key(2026, 1, 5), "2026-01-05")

    def test_seed_is_deterministic(self):
        self.assertEqual(daily_seed("2026-10-08"), daily_seed("2026-10-08"))
        self.assertEqual(daily_seed_for_date(2026, 10, 8),
                         daily_seed_for_date(2026, 10, 8))

    def test_seed_is_stable_across_calls_and_platforms(self):
        # FNV-1a is defined over bytes, so the value cannot drift between
        # devices or SDK versions.
        self.assertEqual(fnv1a32("mergedrop-daily-2026-10-08"),
                         daily_seed("2026-10-08"))
        self.assertGreater(daily_seed("2026-10-08"), 0)

    def test_different_days_give_different_seeds(self):
        seeds = {daily_seed_for_date(2026, 10, d) for d in range(1, 31)}
        self.assertEqual(len(seeds), 30)

    def test_same_puzzle_for_every_player(self):
        """Two 'devices' must build an identical daily level."""
        from mergedrop.level_generator import LevelGenerator
        seed_a = daily_seed_for_date(2026, 10, 8)
        seed_b = daily_seed_for_date(2026, 10, 8)
        gen_a = LevelGenerator(seed=seed_a)
        gen_b = LevelGenerator(seed=seed_b)
        self.assertEqual(gen_a.generate(137).to_json(), gen_b.generate(137).to_json())

    def test_different_days_give_different_puzzles(self):
        from mergedrop.level_generator import LevelGenerator
        a = LevelGenerator(seed=daily_seed_for_date(2026, 10, 8)).generate(137)
        b = LevelGenerator(seed=daily_seed_for_date(2026, 10, 9)).generate(137)
        self.assertNotEqual(a.to_json(), b.to_json())


if __name__ == "__main__":
    unittest.main(verbosity=2)
