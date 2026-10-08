"""Level generation, validation and simulation."""
import unittest

from mergedrop.block_generator import BlockGenerator
from mergedrop.difficulty_profile import DifficultyProfile
from mergedrop.game_simulator import GameSimulator
from mergedrop.level import BlockSpawn, Level
from mergedrop.level_generator import (LEVELS_PER_CHAPTER, LevelGenerator,
                                       _nice, _pow2_down, difficulty_of)
from mergedrop.level_objective import LevelObjective
from mergedrop.level_validator import ERROR, INFO, WARNING, LevelValidator
from mergedrop.star_thresholds import StarThresholds


class TestBlockGenerationDistribution(unittest.TestCase):
    def test_documented_weights_hold(self):
        profile = DifficultyProfile(spawn_weights={2: 65, 4: 25, 8: 10})
        distribution = BlockGenerator(profile, seed=4242).sample_distribution(40000)
        self.assertAlmostEqual(distribution[2], 0.65, delta=0.02)
        self.assertAlmostEqual(distribution[4], 0.25, delta=0.02)
        self.assertAlmostEqual(distribution[8], 0.10, delta=0.02)

    def test_spawn_probability_forces_the_minimum(self):
        profile = DifficultyProfile(spawn_weights={2: 10, 8: 90},
                                    spawn_probability=0.0)
        values = BlockGenerator(profile, seed=9).next_batch(200)
        self.assertEqual(set(values), {2})

    def test_degenerate_weights_fall_back_to_the_minimum(self):
        profile = DifficultyProfile(spawn_weights={})
        self.assertEqual(BlockGenerator(profile, seed=1).next(), 2)


class TestLevelGeneration(unittest.TestCase):
    def test_first_twenty_levels_are_curated(self):
        generator = LevelGenerator()
        for level_id in range(1, 21):
            self.assertTrue(generator.generate(level_id).is_curated,
                            "level %d should be curated" % level_id)

    def test_later_levels_are_generated(self):
        generator = LevelGenerator()
        for level_id in (21, 100, 250, 500):
            self.assertFalse(generator.generate(level_id).is_curated)

    def test_catalogue_is_complete_and_unique(self):
        generator = LevelGenerator(total_levels=500)
        levels = generator.generate_all(calibrate=False)
        self.assertEqual(len(levels), 500)
        self.assertEqual([l.id for l in levels], list(range(1, 501)))

    def test_chapters_are_contiguous(self):
        generator = LevelGenerator(total_levels=500)
        for chapter in range(1, 21):
            start, end = generator.chapter_range(chapter)
            self.assertEqual(start, (chapter - 1) * LEVELS_PER_CHAPTER + 1)
            self.assertEqual(end - start + 1, LEVELS_PER_CHAPTER)
            for level_id in range(start, end + 1):
                self.assertEqual(generator.generate(level_id, calibrate=False).chapter,
                                 chapter)

    def test_difficulty_rises_overall_but_dips_for_pacing(self):
        values = [difficulty_of(n) for n in range(1, 501)]
        self.assertLess(values[0], values[-1])
        dips = sum(1 for i in range(1, len(values)) if values[i] < values[i - 1])
        self.assertGreater(dips, 40, "the curve should breathe, not climb linearly")

    def test_objectives_cover_every_type(self):
        generator = LevelGenerator(total_levels=500)
        kinds = {l.objective.type for l in generator.generate_all(calibrate=False)}
        for expected in ("reachScore", "createNumber", "mergeCount",
                         "reachNumber", "comboCount"):
            self.assertIn(expected, kinds)

    def test_no_duplicate_initial_cells(self):
        generator = LevelGenerator(total_levels=500, seed=7)
        for level in generator.generate_all(calibrate=False):
            cells = [(b.row, b.column) for b in level.initial_blocks]
            self.assertEqual(len(cells), len(set(cells)),
                             "level %d has duplicate initial cells" % level.id)

    def test_every_level_starts_playable(self):
        from mergedrop.game_board import GameBoard
        from mergedrop.block_state import BlockState
        generator = LevelGenerator(total_levels=500, seed=7)
        for level in generator.generate_all(calibrate=False):
            grid = [[None] * 6 for _ in range(12)]
            for i, spawn in enumerate(level.initial_blocks):
                grid[spawn.row][spawn.column] = BlockState(i + 1, spawn.value,
                                                           spawn.row, spawn.column)
            self.assertTrue(GameBoard.from_cells(12, 6, grid).has_legal_drop,
                            "level %d is a dead end at the start" % level.id)

    def test_nice_rounding(self):
        self.assertEqual(_nice(0), 0)
        self.assertEqual(_nice(7), 10)
        self.assertEqual(_nice(1337), 1300)
        self.assertEqual(_nice(98765), 100000)

    def test_pow2_down(self):
        self.assertEqual(_pow2_down(2), 2)
        self.assertEqual(_pow2_down(3), 2)
        self.assertEqual(_pow2_down(1000), 512)
        self.assertEqual(_pow2_down(2048), 2048)


class TestLevelValidator(unittest.TestCase):
    def _level(self, **kw):
        base = dict(id=1, objective=LevelObjective.decode(
            {"type": "reachScore", "target": 500}),
            difficulty=DifficultyProfile(),
            stars=StarThresholds(200, 400))
        base.update(kw)
        return Level(**base)

    def test_valid_level_passes(self):
        report = LevelValidator().validate(self._level())
        self.assertTrue(report.ok, report.summary())

    def test_out_of_bounds_initial_block_is_an_error(self):
        level = self._level(initial_blocks=[BlockSpawn(2, 99, 0)])
        report = LevelValidator().validate(level)
        self.assertFalse(report.ok)
        self.assertIn("initial_block_out_of_bounds",
                      [i.code for i in report.errors])

    def test_duplicate_initial_block_is_an_error(self):
        level = self._level(initial_blocks=[BlockSpawn(2, 11, 0),
                                            BlockSpawn(4, 11, 0)])
        report = LevelValidator().validate(level)
        self.assertFalse(report.ok)
        self.assertIn("duplicate_initial_block", [i.code for i in report.errors])

    def test_invalid_block_value_is_an_error(self):
        level = self._level(initial_blocks=[BlockSpawn(6, 11, 0)])
        report = LevelValidator().validate(level)
        self.assertFalse(report.ok)
        self.assertIn("invalid_block_value", [i.code for i in report.errors])

    def test_dead_end_start_is_an_error(self):
        blocks = [BlockSpawn(2 if r % 2 == 0 else 4, r, c)
                  for r in range(12) for c in range(6)]
        report = LevelValidator().validate(self._level(initial_blocks=blocks))
        self.assertFalse(report.ok)
        self.assertIn("dead_end_start", [i.code for i in report.errors])

    def test_zero_target_is_an_error(self):
        # `decode` already repairs a non-positive target, so build the broken
        # objective directly to prove the validator still catches it.
        from mergedrop.level_objective import ReachScoreObjective
        level = self._level(objective=ReachScoreObjective(0))
        report = LevelValidator().validate(level)
        self.assertFalse(report.ok)
        self.assertIn("invalid_objective", [i.code for i in report.errors])

    def test_tiny_move_limit_is_an_error(self):
        report = LevelValidator().validate(self._level(move_limit=3))
        self.assertFalse(report.ok)
        self.assertIn("move_limit_too_small", [i.code for i in report.errors])

    def test_flat_star_thresholds_are_a_warning(self):
        report = LevelValidator().validate(
            self._level(stars=StarThresholds(300, 300)))
        self.assertTrue(report.ok)
        self.assertIn("flat_star_thresholds", [i.code for i in report.warnings])

    def test_impossible_objective_is_an_error(self):
        level = self._level(objective=LevelObjective.decode(
            {"type": "createNumber", "target": 8192}))
        simulator = GameSimulator(skill=0.8, max_moves=60)
        report = LevelValidator(simulator=simulator, games=3).validate(level)
        self.assertFalse(report.ok)
        self.assertIn("impossible_level", [i.code for i in report.errors])

    def test_trivial_level_is_a_warning(self):
        level = self._level(stars=StarThresholds(10, 20))
        simulator = GameSimulator(skill=0.9, max_moves=200)
        report = LevelValidator(simulator=simulator, games=3).validate(level)
        self.assertTrue(report.ok)
        self.assertIn("trivial_level", [i.code for i in report.warnings])


class TestGameSimulator(unittest.TestCase):
    def test_report_aggregates(self):
        level = Level(1, LevelObjective.decode({"type": "reachScore", "target": 50}),
                      DifficultyProfile(), stars=StarThresholds(10, 20))
        report = GameSimulator(max_moves=80).simulate(level, games=3, seed=1)
        self.assertEqual(report.games, 3)
        self.assertEqual(len(report.scores), 3)
        self.assertGreaterEqual(report.completion_rate, 0.0)
        self.assertLessEqual(report.completion_rate, 1.0)
        self.assertGreater(report.average_moves, 0)

    def test_simulation_is_deterministic(self):
        level = Level(2, LevelObjective.decode({"type": "reachScore", "target": 50}),
                      DifficultyProfile(), stars=StarThresholds(10, 20))
        first = GameSimulator(max_moves=60).simulate(level, games=2, seed=5)
        second = GameSimulator(max_moves=60).simulate(level, games=2, seed=5)
        self.assertEqual(first.scores, second.scores)
        self.assertEqual(first.average_moves, second.average_moves)

    def test_bot_reaches_high_values_in_long_sessions(self):
        level = Level(3, LevelObjective.decode({"type": "reachScore", "target": 50}),
                      DifficultyProfile(), stars=StarThresholds(10, 20))
        report = GameSimulator(max_moves=800).simulate(level, games=1, seed=3)
        self.assertGreaterEqual(report.average_highest_value, 512)

    def test_skill_changes_outcomes(self):
        level = Level(4, LevelObjective.decode({"type": "reachScore", "target": 50}),
                      DifficultyProfile(), stars=StarThresholds(10, 20))
        strong = GameSimulator(max_moves=120, skill=1.0).simulate(level, games=2, seed=1)
        weak = GameSimulator(max_moves=120, skill=0.0).simulate(level, games=2, seed=1)
        self.assertGreaterEqual(strong.average_score, weak.average_score)


if __name__ == "__main__":
    unittest.main(verbosity=2)
