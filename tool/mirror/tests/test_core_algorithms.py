"""Verifies the rules mirrored from lib/features/game/domain."""
import unittest

from helpers import (ROWS, COLUMNS, board_from, bottom_row_values, column_values,
                     empty_board, values)
from mergedrop.difficulty_profile import DifficultyProfile
from mergedrop.game_engine import DropRejection, GameEngine
from mergedrop.level_objective import (ComboCountObjective, CreateNumberObjective,
                                       LevelObjective, MergeCountObjective,
                                       ObjectiveType, ReachNumberObjective,
                                       ReachScoreObjective)
from mergedrop.level import Level
from mergedrop.merge_engine import MergeEngine
from mergedrop.block_state import BlockState
from mergedrop.game_stats import GameStats
from mergedrop.star_thresholds import StarThresholds


class TestBoard(unittest.TestCase):
    def test_landing_row_is_lowest_empty_cell(self):
        board = board_from(ROWS, COLUMNS, [
            [0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0],
            [2, 0, 0, 0, 0, 0],
        ])
        self.assertEqual(board.find_landing_row(0), ROWS - 2)
        self.assertEqual(board.find_landing_row(3), ROWS - 1)

    def test_full_column_rejects(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        for r in range(ROWS):
            grid[r][2] = 2
        board = board_from(ROWS, COLUMNS, grid)
        self.assertIsNone(board.find_landing_row(2))
        self.assertTrue(board.has_legal_drop)

    def test_neighbors_are_orthogonal_and_clamped(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[0][0] = 2
        grid[0][1] = 4
        grid[1][0] = 8
        board = board_from(ROWS, COLUMNS, grid)
        neighbours = board.get_neighbors(0, 0)
        self.assertEqual(sorted(b.value for b in neighbours), [4, 8])

    def test_clone_is_independent(self):
        board = empty_board().with_block(BlockState(1, 2, 11, 0))
        clone = board.clone()
        mutated = clone.with_block(BlockState(2, 4, 10, 0))
        self.assertEqual(board.block_count, 1)
        self.assertEqual(mutated.block_count, 2)

    def test_serialisation_round_trip(self):
        from mergedrop.game_board import GameBoard
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][0] = 2
        grid[ROWS - 2][0] = 4
        grid[ROWS - 1][5] = 8
        board = board_from(ROWS, COLUMNS, grid)
        restored = GameBoard.from_json(board.to_json())
        self.assertEqual(restored.rows, ROWS)
        self.assertEqual(restored.columns, COLUMNS)
        self.assertEqual(values(restored), values(board))

    def test_corrupt_payload_raises_not_silently_misreads(self):
        from mergedrop.game_board import GameBoard, FormatException_
        with self.assertRaises(FormatException_):
            GameBoard.from_json({"rows": 12, "columns": 6, "cells": [[0] * 6]})


class TestGravity(unittest.TestCase):
    def test_blocks_fall_to_the_floor(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[3][1] = 2
        grid[6][1] = 4
        board = board_from(ROWS, COLUMNS, grid)
        settled, moves = MergeEngine().apply_gravity(board)
        self.assertEqual(bottom_row_values(settled), [None, 4, None, None, None, None])
        self.assertEqual(settled.cells[ROWS - 2][1].value, 2)
        self.assertEqual(len(moves), 2)

    def test_stacked_column_is_stable(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        for r in range(ROWS - 3, ROWS):
            grid[r][0] = 2
        board = board_from(ROWS, COLUMNS, grid)
        settled, moves = MergeEngine().apply_gravity(board)
        self.assertEqual(moves, [])
        self.assertEqual(column_values(settled, 0), [None] * 9 + [2, 2, 2])


class TestMerge(unittest.TestCase):
    def test_two_twos_make_a_four(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][0] = 2
        grid[ROWS - 2][0] = 2
        board = board_from(ROWS, COLUMNS, grid)
        result = MergeEngine().resolve(board, next_block_id=100)
        self.assertEqual(bottom_row_values(result.board), [4, None, None, None, None, None])
        self.assertEqual(result.merge_count, 1)
        self.assertEqual(result.score_gained, 4)
        self.assertEqual(result.events[0].old_value, 2)
        self.assertEqual(result.events[0].new_value, 4)

    def test_four_fours_make_an_eight(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][0] = 4
        grid[ROWS - 2][0] = 4
        board = board_from(ROWS, COLUMNS, grid)
        result = MergeEngine().resolve(board, next_block_id=1)
        self.assertEqual(bottom_row_values(result.board), [8, None, None, None, None, None])
        self.assertEqual(result.score_gained, 8)

    def test_eight_eights_make_a_sixteen(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][0] = 8
        grid[ROWS - 2][0] = 8
        board = board_from(ROWS, COLUMNS, grid)
        result = MergeEngine().resolve(board, next_block_id=1)
        self.assertEqual(bottom_row_values(result.board), [16, None, None, None, None, None])

    def test_horizontal_merge(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][1] = 2
        grid[ROWS - 1][2] = 2
        board = board_from(ROWS, COLUMNS, grid)
        result = MergeEngine().resolve(board, next_block_id=1)
        row = bottom_row_values(result.board)
        self.assertEqual(row[1], 4)
        self.assertIsNone(row[2])

    def test_three_in_a_row_leaves_one_behind(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][0] = 2
        grid[ROWS - 1][1] = 2
        grid[ROWS - 1][2] = 2
        board = board_from(ROWS, COLUMNS, grid)
        result = MergeEngine().resolve(board, next_block_id=1)
        row = bottom_row_values(result.board)
        self.assertEqual(sorted(v for v in row if v is not None), [2, 4])
        self.assertEqual(result.merge_count, 1)

    def test_four_in_a_row_makes_two_merges(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        for c in range(4):
            grid[ROWS - 1][c] = 2
        board = board_from(ROWS, COLUMNS, grid)
        result = MergeEngine().resolve(board, next_block_id=1)
        row = bottom_row_values(result.board)
        self.assertEqual(sorted(v for v in row if v is not None), [4, 4])

    def test_no_merge_for_different_values(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][0] = 2
        grid[ROWS - 1][1] = 4
        board = board_from(ROWS, COLUMNS, grid)
        result = MergeEngine().resolve(board, next_block_id=1)
        self.assertEqual(result.merge_count, 0)
        self.assertEqual(result.score_gained, 0)
        self.assertEqual(bottom_row_values(result.board), [2, 4, None, None, None, None])

    def test_merge_events_carry_chain_step(self):
        # 4 over 2 over 2 -> the 2s merge into a 4 that then joins the 4.
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][0] = 4
        grid[ROWS - 2][0] = 2
        grid[ROWS - 3][0] = 2
        board = board_from(ROWS, COLUMNS, grid)
        result = MergeEngine().resolve(board, next_block_id=1)
        self.assertEqual(result.merge_count, 2)
        self.assertEqual(result.longest_chain, 2)
        self.assertEqual([e.chain_step for e in result.events], [0, 1])
        self.assertEqual([e.new_value for e in result.events], [4, 8])
        self.assertEqual(bottom_row_values(result.board), [8, None, None, None, None, None])

    def test_drop_triggered_merge_resolves_where_the_player_aimed(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][1] = 2
        board = board_from(ROWS, COLUMNS, grid)
        result = MergeEngine().resolve(
            board.with_block(BlockState(99, 2, ROWS - 1, 0)),
            next_block_id=1,
            preferred_anchor_block_id=99)
        # The merged 4 must land in column 0 - the column the player dropped into.
        self.assertEqual(bottom_row_values(result.board),
                         [4, None, None, None, None, None])

    def test_merge_without_preferred_anchor_uses_lowest_cell(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][1] = 2
        grid[ROWS - 1][2] = 2
        board = board_from(ROWS, COLUMNS, grid)
        result = MergeEngine().resolve(board, next_block_id=1)
        row = bottom_row_values(result.board)
        self.assertEqual(row[1], 4)
        self.assertIsNone(row[2])


class TestChainReaction(unittest.TestCase):
    def _staircase(self, values_from_bottom):
        """A column shaped like 8,4,2,2 (bottom first) that cascades."""
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        for i, v in enumerate(values_from_bottom):
            grid[ROWS - 1 - i][0] = v
        return board_from(ROWS, COLUMNS, grid)

    def test_two_step_cascade(self):
        board = self._staircase([4, 2, 2])
        result = MergeEngine().resolve(board, next_block_id=1)
        self.assertEqual(bottom_row_values(result.board),
                         [8, None, None, None, None, None])
        self.assertEqual(result.merge_count, 2)
        self.assertEqual(result.longest_chain, 2)
        self.assertEqual([e.chain_step for e in result.events], [0, 1])
        self.assertEqual([e.score_gained for e in result.events], [4, 12])
        self.assertEqual(result.score_gained, 16)

    def test_three_step_cascade(self):
        board = self._staircase([8, 4, 2, 2])
        result = MergeEngine().resolve(board, next_block_id=1)
        self.assertEqual(bottom_row_values(result.board),
                         [16, None, None, None, None, None])
        self.assertEqual(result.longest_chain, 3)
        self.assertEqual([e.score_gained for e in result.events], [4, 12, 32])
        self.assertEqual(result.score_gained, 48)

    def test_cascade_is_deterministic(self):
        board = self._staircase([8, 4, 2, 2])
        first = MergeEngine().resolve(board, next_block_id=1)
        second = MergeEngine().resolve(board, next_block_id=500)
        self.assertEqual(first.board.to_value_grid(), second.board.to_value_grid())
        self.assertEqual(first.score_gained, second.score_gained)
        self.assertEqual([e.new_value for e in first.events],
                         [e.new_value for e in second.events])

    def test_independent_pairs_merge_in_the_same_wave(self):
        """Two separate pairs are one combo wave, not a chain."""
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        grid[ROWS - 1][0] = 2
        grid[ROWS - 1][1] = 2
        grid[ROWS - 1][3] = 2
        grid[ROWS - 1][4] = 2
        board = board_from(ROWS, COLUMNS, grid)
        result = MergeEngine().resolve(board, next_block_id=1)
        self.assertEqual(result.merge_count, 2)
        self.assertEqual(result.longest_chain, 1)
        self.assertEqual([e.chain_step for e in result.events], [0, 0])
        self.assertEqual(result.score_gained, 8)

    def test_resolution_always_terminates(self):
        """Worst case: a full board of a single value collapses to one block."""
        grid = [[2] * COLUMNS for _ in range(ROWS)]
        board = board_from(ROWS, COLUMNS, grid)
        result = MergeEngine().resolve(board, next_block_id=1)
        # 72 identical blocks collapse to three 32s resting on three 16s.
        self.assertEqual(result.board.block_count, 6)
        self.assertEqual(bottom_row_values(result.board),
                         [32, None, 32, None, 32, None])
        # Merging conserves total value: 72 * 2 == 3 * 32 + 3 * 16.
        self.assertEqual(sum(b.value for b in result.board.blocks), 144)
        # Combo multipliers mean the score always exceeds raw value created.
        self.assertGreater(result.score_gained, 144)

    def test_merging_conserves_total_value(self):
        for stack in ([2, 2], [4, 2, 2], [8, 4, 2, 2], [16, 8, 4, 2, 2],
                      [2, 2, 2, 2, 2, 2, 2, 2]):
            grid = [[0] * COLUMNS for _ in range(ROWS)]
            for i, v in enumerate(stack):
                grid[ROWS - 1 - i][0] = v
            board = board_from(ROWS, COLUMNS, grid)
            result = MergeEngine().resolve(board, next_block_id=1)
            self.assertEqual(
                sum(b.value for b in result.board.blocks), sum(stack),
                "value not conserved for stack %s" % stack)

    def test_transitions_replay_to_the_final_board(self):
        board = self._staircase([8, 4, 2, 2])
        result = MergeEngine().resolve(board, next_block_id=1)
        self.assertGreater(len(result.transitions), 0)
        self.assertEqual(result.transitions[-1].board.to_value_grid(),
                         result.board.to_value_grid())


class TestDropSystem(unittest.TestCase):
    def _engine(self, level=None, seed=7):
        profile = level.difficulty if level else DifficultyProfile()
        return GameEngine.start(empty_board(), profile, seed=seed, level=level)

    def test_drop_lands_at_bottom(self):
        engine = self._engine()
        outcome = engine.drop(3)
        self.assertTrue(outcome.accepted)
        self.assertEqual(outcome.landing_row, ROWS - 1)
        self.assertEqual(bottom_row_values(outcome.state.board)[3],
                         outcome.dropped_block.value)
        self.assertEqual(outcome.state.moves_used, 1)

    def test_drop_stacks_on_existing_blocks(self):
        engine = self._engine()
        engine.drop(3)
        outcome = engine.drop(3)
        self.assertEqual(outcome.landing_row, ROWS - 2)

    def test_invalid_column_is_rejected(self):
        engine = self._engine()
        self.assertFalse(engine.drop(-1).accepted)
        self.assertFalse(engine.drop(99).accepted)
        self.assertEqual(engine.drop(-1).rejection, DropRejection.INVALID_COLUMN)

    def test_full_column_is_rejected(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        for r in range(ROWS):
            grid[r][0] = 2 if r % 2 == 0 else 4
        board = board_from(ROWS, COLUMNS, grid)
        from mergedrop.game_state import GameStateCore
        core = GameStateCore(board=board, next_block_id=100, next_block_value=2,
                             stats=GameStats(), score=0, moves_used=0, rng_state=1)
        engine = GameEngine.restore(core, DifficultyProfile())
        outcome = engine.drop(0)
        self.assertFalse(outcome.accepted)
        self.assertEqual(outcome.rejection, DropRejection.COLUMN_FULL)
        self.assertEqual(outcome.state.moves_used, 0)

    def test_restricted_columns_cannot_be_used(self):
        profile = DifficultyProfile(restriction=None)
        from mergedrop.difficulty_profile import RestrictedColumnsRestriction
        profile = DifficultyProfile(restriction=RestrictedColumnsRestriction({1, 2}))
        engine = GameEngine.start(empty_board(), profile, seed=5)
        self.assertFalse(engine.can_drop(1))
        self.assertFalse(engine.can_drop(2))
        self.assertTrue(engine.can_drop(0))

    def test_height_limit_blocks_upper_rows(self):
        from mergedrop.difficulty_profile import HeightLimitRestriction
        profile = DifficultyProfile(restriction=HeightLimitRestriction(ROWS - 4))
        engine = GameEngine.start(empty_board(), profile, seed=5)
        for _ in range(10):
            if engine.landing_row_for(0) is None:
                break
            engine.drop(0)
        # Never more than 4 blocks can rest in a height-limited column.
        self.assertLessEqual(
            sum(1 for r in range(ROWS) if engine.state.board.cells[r][0]), 4)


class TestGameOver(unittest.TestCase):
    @staticmethod
    def _full_checkerboard():
        """A completely full board with no two adjacent blocks equal."""
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        for r in range(ROWS):
            for c in range(COLUMNS):
                grid[r][c] = 2 if (r + c) % 2 == 0 else 4
        return board_from(ROWS, COLUMNS, grid)

    def test_full_board_ends_the_game(self):
        from mergedrop.game_state import GameStateCore
        core = GameStateCore(board=self._full_checkerboard(), next_block_id=100,
                             next_block_value=2, stats=GameStats(), score=0,
                             moves_used=0, rng_state=1)
        engine = GameEngine.restore(core, DifficultyProfile())
        self.assertTrue(engine.state.is_game_over)
        self.assertFalse(engine.state.board.has_legal_drop)

    def test_no_drop_is_accepted_after_game_over(self):
        from mergedrop.game_state import GameStateCore
        core = GameStateCore(board=self._full_checkerboard(), next_block_id=100,
                             next_block_value=2, stats=GameStats(), score=0,
                             moves_used=0, rng_state=1)
        engine = GameEngine.restore(core, DifficultyProfile())
        outcome = engine.drop(0)
        self.assertFalse(outcome.accepted)
        self.assertEqual(outcome.rejection, DropRejection.SESSION_OVER)

    def test_single_full_column_is_not_game_over(self):
        grid = [[0] * COLUMNS for _ in range(ROWS)]
        for r in range(ROWS):
            grid[r][0] = 2 if r % 2 == 0 else 4
        board = board_from(ROWS, COLUMNS, grid)
        from mergedrop.game_state import GameStateCore
        core = GameStateCore(board=board, next_block_id=100, next_block_value=2,
                             stats=GameStats(), score=0, moves_used=0, rng_state=1)
        engine = GameEngine.restore(core, DifficultyProfile())
        self.assertFalse(engine.state.is_game_over)
        outcome = engine.drop(0)
        self.assertFalse(outcome.accepted)
        self.assertEqual(outcome.rejection, DropRejection.COLUMN_FULL)
        self.assertTrue(engine.can_drop(1))

    def test_long_random_session_always_terminates(self):
        """A real session must end instead of looping forever."""
        profile = DifficultyProfile(spawn_weights={2: 50, 4: 30, 8: 15, 16: 5})
        engine = GameEngine.start(empty_board(), profile, seed=2024)
        moves = 0
        while not engine.state.is_game_over and moves < 5000:
            column = moves % COLUMNS
            if engine.can_drop(column):
                engine.drop(column)
            moves += 1
        self.assertTrue(engine.state.is_game_over,
                        "session did not terminate within 5000 drops")
        self.assertLess(moves, 5000)


class TestScore(unittest.TestCase):
    def test_score_is_centralised(self):
        from mergedrop.score_calculator import merge_score, combo_multiplier
        self.assertEqual(merge_score(4), 4)
        self.assertEqual(merge_score(8), 8)
        self.assertEqual(merge_score(16), 16)
        self.assertEqual(merge_score(4, 1), 6)
        self.assertEqual(merge_score(8, 2), 16)
        self.assertAlmostEqual(combo_multiplier(0), 1.0)
        self.assertAlmostEqual(combo_multiplier(3), 2.5)

    def test_score_never_computed_by_ui(self):
        # Dropping into an empty column must award nothing.
        engine = GameEngine.start(empty_board(), DifficultyProfile(), seed=9)
        outcome = engine.drop(2)
        self.assertEqual(outcome.score_gained, 0)
        self.assertEqual(outcome.state.score, 0)


class TestBlockGeneration(unittest.TestCase):
    def test_weights_are_respected(self):
        profile = DifficultyProfile(spawn_weights={2: 65, 4: 25, 8: 10})
        from mergedrop.block_generator import BlockGenerator
        gen = BlockGenerator(profile, seed=1234)
        dist = gen.sample_distribution(20000)
        self.assertAlmostEqual(dist.get(2, 0), 0.65, delta=0.03)
        self.assertAlmostEqual(dist.get(4, 0), 0.25, delta=0.03)
        self.assertAlmostEqual(dist.get(8, 0), 0.10, delta=0.03)

    def test_generator_is_seed_deterministic(self):
        from mergedrop.block_generator import BlockGenerator
        profile = DifficultyProfile()
        a = BlockGenerator(profile, seed=555).next_batch(50)
        b = BlockGenerator(profile, seed=555).next_batch(50)
        self.assertEqual(a, b)

    def test_max_spawn_value_is_enforced(self):
        from mergedrop.block_generator import BlockGenerator
        profile = DifficultyProfile(spawn_weights={2: 10, 4: 10, 8: 10, 16: 10},
                                    max_spawn_value=4)
        gen = BlockGenerator(profile, seed=77)
        self.assertTrue(all(v <= 4 for v in gen.next_batch(500)))

    def test_peek_does_not_consume(self):
        from mergedrop.block_generator import BlockGenerator
        gen = BlockGenerator(DifficultyProfile(), seed=31)
        peeked = gen.peek()
        self.assertEqual(gen.next(), peeked)


class TestObjectives(unittest.TestCase):
    def _stats(self, **kw):
        from mergedrop.game_stats import GameStats
        base = dict(score=0, merge_count=0, moves_used=0, highest_value_created=0,
                    highest_value_on_board=0, longest_combo=0)
        base.update(kw)
        return GameStats(**base)

    def test_reach_score(self):
        obj = ReachScoreObjective(500)
        self.assertFalse(obj.is_satisfied(self._stats(score=499)))
        self.assertTrue(obj.is_satisfied(self._stats(score=500)))
        self.assertAlmostEqual(obj.progress(self._stats(score=250)), 0.5)

    def test_create_number(self):
        obj = CreateNumberObjective(128)
        self.assertFalse(obj.is_satisfied(self._stats(highest_value_created=64)))
        self.assertTrue(obj.is_satisfied(self._stats(highest_value_created=128)))

    def test_merge_count(self):
        obj = MergeCountObjective(10)
        self.assertTrue(obj.is_satisfied(self._stats(merge_count=11)))

    def test_reach_number(self):
        obj = ReachNumberObjective(512)
        self.assertTrue(obj.is_satisfied(self._stats(highest_value_on_board=1024)))

    def test_combo_count(self):
        obj = ComboCountObjective(5)
        self.assertFalse(obj.is_satisfied(self._stats(longest_combo=4)))
        self.assertTrue(obj.is_satisfied(self._stats(longest_combo=5)))

    def test_complete_within_moves(self):
        from mergedrop.level_objective import CompleteWithinMovesObjective
        obj = CompleteWithinMovesObjective(80)
        self.assertTrue(obj.is_satisfied(self._stats(moves_used=80)))
        self.assertFalse(obj.is_satisfied(self._stats(moves_used=81)))

    def test_objective_json_round_trip(self):
        for obj in (ReachScoreObjective(500), CreateNumberObjective(128),
                    MergeCountObjective(10), ReachNumberObjective(512),
                    ComboCountObjective(5),
                    LevelObjective.decode({"type": "completeWithinMoves", "target": 80})):
            decoded = LevelObjective.decode(obj.to_json())
            self.assertEqual(decoded.type, obj.type)
            self.assertEqual(decoded.target, obj.target)


class TestStars(unittest.TestCase):
    def test_star_thresholds(self):
        stars = StarThresholds(500, 1200)
        self.assertEqual(stars.stars_for(100), 1)
        self.assertEqual(stars.stars_for(500), 2)
        self.assertEqual(stars.stars_for(1200), 3)
        self.assertEqual(stars.stars_for(5000), 3)

    def test_trivial_thresholds_give_one_star(self):
        stars = StarThresholds(0, 0)
        self.assertEqual(stars.stars_for(0), 1)


class TestLevelModel(unittest.TestCase):
    def test_level_json_round_trip(self):
        level = Level(
            id=7, chapter=1,
            objective=ReachScoreObjective(1000),
            difficulty=DifficultyProfile(spawn_weights={2: 70, 4: 30}),
            stars=StarThresholds(800, 1500),
            initial_blocks=[],
            move_limit=40,
            is_curated=True,
            tutorial_step_key="tut_drop")
        restored = Level.from_json(level.to_json())
        self.assertEqual(restored.id, 7)
        self.assertEqual(restored.objective.target, 1000)
        self.assertEqual(restored.stars.three_star_score, 1500)
        self.assertEqual(restored.move_limit, 40)
        self.assertEqual(restored.difficulty.spawn_weights, {2: 70, 4: 30})
        self.assertTrue(restored.is_curated)



class TestRestrictions(unittest.TestCase):
    def test_height_limit_allows_low_rows_only(self):
        from mergedrop.difficulty_profile import HeightLimitRestriction
        r = HeightLimitRestriction(9)
        self.assertTrue(r.allows(11, 0))
        self.assertTrue(r.allows(9, 0))
        self.assertFalse(r.allows(8, 0))

    def test_height_limited_board_is_still_playable(self):
        from mergedrop.difficulty_profile import HeightLimitRestriction
        from mergedrop.game_state import GameStateCore
        profile = DifficultyProfile(restriction=HeightLimitRestriction(9))
        engine = GameEngine.start(empty_board(), profile, seed=5)
        for _ in range(40):
            if engine.landing_row_for(0) is None:
                break
            engine.drop(0)
        # Only rows 9..11 (three cells) can ever be occupied in column 0.
        self.assertLessEqual(
            sum(1 for r in range(ROWS) if engine.state.board.cells[r][0]), 3)
        self.assertGreater(engine.state.score, 0)

    def test_restricted_columns_round_trip_through_json(self):
        from mergedrop.difficulty_profile import RestrictedColumnsRestriction
        profile = DifficultyProfile(
            restriction=RestrictedColumnsRestriction({1, 4}),
            spawn_weights={2: 70, 4: 30})
        restored = DifficultyProfile.from_json(profile.to_json())
        self.assertEqual(restored.restriction.kind, "restrictedColumns")
        self.assertEqual(restored.restriction.columns, {1, 4})
        self.assertTrue(restored.restriction.allows(0, 0))
        self.assertFalse(restored.restriction.allows(0, 1))

    def test_height_limit_round_trips_through_json(self):
        from mergedrop.difficulty_profile import HeightLimitRestriction
        profile = DifficultyProfile(restriction=HeightLimitRestriction(6))
        restored = DifficultyProfile.from_json(profile.to_json())
        self.assertEqual(restored.restriction.kind, "maxHeight")
        self.assertEqual(restored.restriction.top_row, 6)
        self.assertFalse(restored.restriction.allows(5, 0))

    def test_level_json_preserves_restrictions(self):
        from mergedrop.difficulty_profile import HeightLimitRestriction
        level = Level(101, ReachScoreObjective(1000),
                      DifficultyProfile(restriction=HeightLimitRestriction(7)),
                      stars=StarThresholds(400, 700))
        restored = Level.from_json(level.to_json())
        self.assertEqual(restored.difficulty.restriction.kind, "maxHeight")
        self.assertEqual(restored.difficulty.restriction.top_row, 7)

if __name__ == "__main__":
    unittest.main(verbosity=2)
