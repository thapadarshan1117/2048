"""Booster behaviour, mirrored from lib/features/game/domain/boosters."""
import unittest

from helpers import ROWS, COLUMNS, board_from, bottom_row_values, empty_board, values
from mergedrop.boosters import (BoosterContext, BoosterSupport, HammerBooster,
                                ShuffleBooster, UndoBooster, UpgradeBooster,
                                WildcardBooster, by_id, by_id_or_default)
from mergedrop.difficulty_profile import DifficultyProfile
from mergedrop.game_engine import GameEngine
from mergedrop.game_stats import GameStats
from mergedrop.merge_engine import MergeEngine
from mergedrop.level import Level
from mergedrop.level_objective import ReachScoreObjective
from mergedrop.star_thresholds import StarThresholds


class TestBoosterRegistry(unittest.TestCase):
    def test_all_boosters_are_addressable(self):
        for booster_id in ("undo", "hammer", "shuffle", "wildcard", "upgrade"):
            self.assertIsNotNone(by_id(booster_id), booster_id)
        self.assertIsNone(by_id("nope"))
        self.assertEqual(by_id_or_default("nope").id, "undo")

    def test_boosters_have_localised_copy_and_a_price(self):
        for booster in (UndoBooster(), HammerBooster(), ShuffleBooster(),
                        WildcardBooster(), UpgradeBooster()):
            self.assertTrue(booster.name_key.startswith("booster_"), booster.id)
            self.assertTrue(booster.description_key.startswith("booster_"), booster.id)
            self.assertGreater(booster.price, 0, booster.id)

    def test_target_boosters_declare_their_requirement(self):
        self.assertFalse(UndoBooster().requires_target_block)
        self.assertFalse(ShuffleBooster().requires_target_block)
        self.assertTrue(HammerBooster().requires_target_block)
        self.assertTrue(WildcardBooster().requires_target_block)
        self.assertTrue(UpgradeBooster().requires_target_block)


class TestUndoBooster(unittest.TestCase):
    def _played_engine(self, seed=3):
        level = Level(1, ReachScoreObjective(1000), DifficultyProfile(),
                      stars=StarThresholds(500, 900))
        engine = GameEngine.start(empty_board(), level.difficulty, seed=seed,
                                  level=level)
        for _ in range(6):
            engine.drop(1)
            engine.drop(3)
        return engine

    def test_undo_restores_the_previous_board(self):
        engine = self._played_engine()
        before = engine.state
        engine.drop(0)
        after = engine.state
        self.assertNotEqual(values(before.board), values(after.board))

        outcome = UndoBooster().apply(BoosterContext(state=engine.state))
        self.assertTrue(outcome.applied)
        self.assertEqual(values(outcome.state.board), values(before.board))
        self.assertEqual(outcome.state.score, before.score)
        self.assertEqual(outcome.state.moves_used, before.moves_used)

    def test_undo_without_history_is_refused(self):
        engine = self._played_engine(seed=8)
        fresh = GameEngine.start(empty_board(), DifficultyProfile(), seed=8)
        outcome = UndoBooster().apply(BoosterContext(state=fresh.state))
        self.assertFalse(outcome.applied)
        self.assertEqual(outcome.rejection_key, "booster_reject_no_undo")

    def test_repeated_undo_walks_back_the_history(self):
        engine = self._played_engine(seed=4)
        history_depth = len(engine.state.undo_history)
        state = engine.state
        for _ in range(history_depth):
            state = UndoBooster().apply(BoosterContext(state=state)).state
        self.assertEqual(state.moves_used, 0)
        self.assertEqual(state.board.block_count, 0)
        self.assertFalse(state.can_undo)

    def test_undo_clears_game_over(self):
        from mergedrop.game_state import GameStateCore
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        for r in range(ROWS):
            for c in range(COLUMNS):
                grid[r][c] = 2 if (r + c) % 2 == 0 else 4
        board = board_from(ROWS, COLUMNS, grid)
        core = GameStateCore(board, 100, 2, GameStats(), 0, 5, 1)
        engine = GameEngine.restore(core, DifficultyProfile())
        self.assertTrue(engine.state.is_game_over)
        state = engine.state.copy_with(
            undo_history=[engine.state.copy_with(is_game_over=False)])
        outcome = UndoBooster().apply(BoosterContext(state=state))
        self.assertTrue(outcome.applied)
        self.assertFalse(outcome.state.is_game_over)


class TestHammerBooster(unittest.TestCase):
    def test_hammer_removes_the_target_block(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][2] = 8
        board = board_from(ROWS, COLUMNS, grid)
        engine = GameEngine.start(board, DifficultyProfile(), seed=1)
        target = engine.state.board.cells[ROWS - 1][2].id
        outcome = HammerBooster().apply(
            BoosterContext(state=engine.state, selected_block_id=target))
        self.assertTrue(outcome.applied)
        self.assertIsNone(outcome.state.board.block_by_id(target))
        self.assertEqual(outcome.effect, "remove")

    def test_hammer_triggers_a_cascade(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][0] = 4
        grid[ROWS - 2][0] = 2
        grid[ROWS - 3][0] = 2
        board = board_from(ROWS, COLUMNS, grid)
        engine = GameEngine.start(board, DifficultyProfile(), seed=1)
        target = engine.state.board.cells[ROWS - 1][0].id
        outcome = HammerBooster().apply(
            BoosterContext(state=engine.state, selected_block_id=target))
        self.assertTrue(outcome.applied)
        # Removing the 4 lets 2+2 merge into a 4, which then has nothing to
        # merge with - so exactly one merge is awarded.
        self.assertEqual(outcome.state.stats.merge_count, 1)
        self.assertGreater(outcome.state.score, 0)

    def test_hammer_without_a_target_is_refused(self):
        engine = GameEngine.start(empty_board(), DifficultyProfile(), seed=1)
        outcome = HammerBooster().apply(BoosterContext(state=engine.state))
        self.assertFalse(outcome.applied)
        self.assertEqual(outcome.rejection_key, "booster_reject_no_target")

    def test_hammer_does_not_consume_a_move(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][2] = 8
        board = board_from(ROWS, COLUMNS, grid)
        engine = GameEngine.start(board, DifficultyProfile(), seed=1)
        moves = engine.state.moves_used
        target = engine.state.board.cells[ROWS - 1][2].id
        outcome = HammerBooster().apply(
            BoosterContext(state=engine.state, selected_block_id=target))
        self.assertEqual(outcome.state.moves_used, moves)


class TestShuffleBooster(unittest.TestCase):
    def test_shuffle_conserves_value_and_leaves_a_stable_board(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        for i, v in enumerate([2, 4, 2, 8, 4, 2]):
            grid[ROWS - 1 - i][0] = v
        board = board_from(ROWS, COLUMNS, grid)
        engine = GameEngine.start(board, DifficultyProfile(), seed=1)
        before_value = sum(b.value for b in engine.state.board.blocks)
        before_count = engine.state.board.block_count
        outcome = ShuffleBooster().apply(BoosterContext(state=engine.state))
        self.assertTrue(outcome.applied)
        # Shuffle may set up merges (that is part of its value), so blocks can
        # only disappear - never appear - and total value is conserved.
        self.assertLessEqual(outcome.state.board.block_count, before_count)
        self.assertEqual(sum(b.value for b in outcome.state.board.blocks),
                         before_value)
        self.assertFalse(MergeEngine().find_merge_groups(outcome.state.board))

    def test_shuffle_is_deterministic_for_a_given_state(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        for i, v in enumerate([2, 4, 2, 8, 4, 2]):
            grid[ROWS - 1 - i][0] = v
        board = board_from(ROWS, COLUMNS, grid)
        engine = GameEngine.start(board, DifficultyProfile(), seed=1)
        first = ShuffleBooster().apply(BoosterContext(state=engine.state))
        second = ShuffleBooster().apply(BoosterContext(state=engine.state))
        self.assertEqual(values(first.state.board), values(second.state.board))

    def test_shuffle_refuses_an_almost_empty_board(self):
        engine = GameEngine.start(empty_board(), DifficultyProfile(), seed=1)
        engine.drop(2)
        outcome = ShuffleBooster().apply(BoosterContext(state=engine.state))
        self.assertFalse(outcome.applied)
        self.assertEqual(outcome.rejection_key, "booster_reject_too_few_blocks")


class TestWildcardAndUpgrade(unittest.TestCase):
    def test_wildcard_makes_the_target_mergeable(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][0] = 4
        grid[ROWS - 1][1] = 2
        board = board_from(ROWS, COLUMNS, grid)
        engine = GameEngine.start(board, DifficultyProfile(), seed=1)
        target = engine.state.board.cells[ROWS - 1][1].id
        outcome = WildcardBooster().apply(
            BoosterContext(state=engine.state, selected_block_id=target))
        self.assertTrue(outcome.applied)
        # The 2 becomes a 4 and merges with its neighbour.
        self.assertEqual(outcome.state.stats.merge_count, 1)
        self.assertEqual(bottom_row_values(outcome.state.board)[0], 8)

    def test_upgrade_doubles_the_target(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][3] = 8
        board = board_from(ROWS, COLUMNS, grid)
        engine = GameEngine.start(board, DifficultyProfile(), seed=1)
        target = engine.state.board.cells[ROWS - 1][3].id
        outcome = UpgradeBooster().apply(
            BoosterContext(state=engine.state, selected_block_id=target))
        self.assertTrue(outcome.applied)
        self.assertEqual(bottom_row_values(outcome.state.board)[3], 16)


class TestBoosterSupport(unittest.TestCase):
    def test_settle_resolves_and_scores(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][0] = 2
        grid[ROWS - 2][0] = 2
        board = board_from(ROWS, COLUMNS, grid)
        engine = GameEngine.start(board, DifficultyProfile(), seed=1)
        state = engine.state
        settled, transitions = BoosterSupport.settle(state)
        self.assertEqual(settled.stats.merge_count, 1)
        self.assertEqual(settled.score, 4)
        self.assertEqual(settled.moves_used, state.moves_used)
        self.assertGreater(len(transitions), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
