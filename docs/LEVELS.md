# Levels

## Catalogue shape

```text
500 levels
 20 chapters of 25
 Chapter 1  = levels 1-25
 Chapter 2  = levels 26-50
 ...
 Chapter 20 = levels 476-500

One JSON file per chapter: assets/levels/chapter_01.json ... chapter_20.json
Total size: ~344 KB
```

There is **no** `level_1.dart` ... `level_500.dart`. Levels are data, loaded at
runtime, with a generator as a fallback if an asset is missing or corrupt.

## JSON shape

```json
{
  "chapter": 1,
  "theme": "theme_1",
  "nameKey": "chapter_1",
  "startLevel": 1,
  "endLevel": 25,
  "levels": [
    {
      "id": 1,
      "chapter": 1,
      "objective": { "type": "reachScore", "target": 20 },
      "moveLimit": null,
      "initialBlocks": [],
      "allowedBoosters": ["undo", "hammer", "shuffle"],
      "difficulty": {
        "spawnWeights": { "2": 65, "4": 25, "8": 10 },
        "spawnProbability": 1.0,
        "maxSpawnValue": 8,
        "chainBonusMultiplier": 1.0,
        "restriction": "none"
      },
      "stars": { "twoStar": 100, "threeStar": 500 },
      "isCurated": true,
      "tutorialStepKey": "tut_drop"
    }
  ]
}
```

Restrictions carry their payload (`restrictionTopRow` for `maxHeight`,
`restrictedColumns` for `restrictedColumns`). Persisting the kind alone would
silently turn a restricted level into an unrestricted one on reload.

## Objectives

| Type | Meaning | Satisfied when |
| --- | --- | --- |
| `reachScore` | Reach a total score | `stats.score >= target` |
| `createNumber` | Produce a block of at least N | `stats.highestValueCreated >= target` |
| `reachNumber` | Have a block of at least N on the board | `stats.highestValueOnBoard >= target` |
| `mergeCount` | Perform N merges | `stats.mergeCount >= target` |
| `comboCount` | Trigger an N-merge chain from one drop | `stats.longestCombo >= target` |
| `completeWithinMoves` | Finish within N moves | `stats.movesUsed <= target` |

## Stars

```text
1 star  the level's objective is met
2 stars score >= twoStarScore
3 stars score >= threeStarScore
```

The best result is always kept, so a level can be replayed to improve its rating.

## Difficulty pacing

```dart
difficultyOf(levelId, totalLevels) =
    clamp(0.85 * progress + 0.10 * sin(id * 0.55) + 0.05 * sin(id * 1.9), 0.02, 1.0)

progress = (levelId - 1) / (totalLevels - 1)
```

The sine terms break the monotonic ramp so the difficulty curve breathes instead
of climbing like a staircase.

## The value curve

Measured with the simulator (a greedy bot that favours consolidating value):

| Move budget | Typical highest block |
| --- | --- |
| 120 | 128 |
| 250 | 256 |
| 400 | 512 |
| 800 | 1024 |
| 3000 | 4096 |

This drives `calibrationBudgetFor`: a value objective is measured with
`clamp(round(120 * target / 128), 60, 520)` moves, capped by the level's own
move limit. 1024 / 2048 / 4096 are endless-mode milestones, not level targets.

## How levels are calibrated

`tool/mirror/generate_levels.py` runs three phases.

**Phase 1 - draft.** Each level gets an initial objective, difficulty profile,
initial blocks and a move limit from its difficulty.

**Phase 2 - calibrate.** The simulator plays the level several times at a
generous budget. Then, in two separate passes:

* `_set_objective` sets the objective target from the measured averages
  (score objectives use 85% of the average for unlimited levels and 70% for
  move-limited ones; value objectives use 90% of the average highest block,
  capped by the value ceiling; merge/combo counts use 80%; the move limit is
  1.4x the average move count, minimum 15).
* `_calibrate` sets the star thresholds **at the objective's own budget** -
  35% and 55% of the average score for generated levels.

Both passes measure with `move_limit = None` so the measurement window is not
truncated by the limit being calibrated.

**Phase 3 - validate.** `LevelValidator` re-simulates every finished level and
reports:

| Severity | Code | Meaning |
| --- | --- | --- |
| error | `impossible_level` | fewer than 15% of games complete the objective |
| error | `dead_end_start` | no column can accept a drop |
| error | `initial_block_out_of_bounds` / `duplicate_initial_block` / `invalid_block_value` | malformed level data |
| error | `invalid_objective` / `move_limit_too_small` / `empty_spawn_weights` | unplayable configuration |
| warning | `trivial_level` | >99.5% completion with an average score 2.5x the 3-star bar |
| warning | `unreachable_two_star` / `unreachable_three_star` | the best simulated score never reaches the threshold |
| warning | `flat_star_thresholds` | 2-star bar is not below the 3-star bar |
| info | `no_boosters` | the level allows no boosters |

Levels 1-3 are exempt from `trivial_level` - the opening tutorial is *meant* to
be trivial, and flagging it would just train designers to ignore the warning.

## The curated tutorial band (levels 1-20)

Levels 1-20 are hand-authored. Their pedagogical targets are deliberate, so the
calibration pipeline returns their draft untouched: the objective target, move
limit and initial blocks are never rewritten and the value ceiling never applies
to them. Only their star thresholds may be clamped, so a hand-set bar that no
human could reach is lowered rather than shipped.

| Level | Objective | 2-star / 3-star | Note |
| --- | --- | --- | --- |
| 1 | reachScore 20 | 100 / 500 | `tut_drop` |
| 2 | reachScore 60 | 150 / 800 | `tut_merge` |
| 3 | reachScore 150 | 250 / 1200 | `tut_merge_again` |
| 4 | reachScore 300 | 400 / 1546 | `tut_chain` |
| 5 | reachScore 500 | | |
| 6 | reachScore 900 | | |
| 7 | reachScore 1400 | | |
| 8 | reachScore 1200 | | |
| 9 | comboCount 2 | | |
| 10 | mergeCount 25 | | `tut_boosters` |
| 11 | reachScore 1600 | | |
| 12 | reachScore 600, move limit 60 | | |
| 13 | createNumber 32 | | |
| 14 | comboCount 3 | | |
| 15 | reachScore 2200 | | 4 initial blocks |
| 16 | createNumber 64 | | |
| 17 | createNumber 128 | | |
| 18 | comboCount 4 | | |
| 19 | createNumber 256 | 2000 / 4422 | |
| 20 | createNumber 512 | 6000 / 14169 | 3 initial blocks |

The tutorial teaches by interaction: each level's `tutorialStepKey` drives a
single short hint shown once, at the moment the player needs it. There are no
text walls.

## Regenerating the catalogue

```bash
python3 tool/mirror/generate_levels.py --levels 500 --games 6
python3 tool/mirror/validate_levels.py --levels 500 --games 6   # independent re-check
```

Current output:

```text
500 levels, 20 chapters, 343.6 KB
validation: 500 levels, 0 with errors, 0 with warnings
```

Objective mix: `reachScore` 171, `createNumber` 85, `comboCount` 83,
`mergeCount` 81, `reachNumber` 80. 81 levels are move-limited, 379 have initial
blocks, 13 use `restrictedColumns` and 13 use `maxHeight`.

## Runtime loading

`AssetLevelRepository` loads `assets/levels/chapter_NN.json`. If a file is
missing, unreadable or contains no usable level, the repository **generates**
that chapter with `LevelGenerator` instead. A broken asset bundle degrades into
"slightly different levels" rather than "the game will not start".

The Dart `LevelGenerator` in `lib/features/levels/data/level_generator.dart` is
a port of the Python generator (same calibration rules, same curated table, same
validation seeds). It is the runtime fallback and is covered by unit tests; the
Python mirror is the tool that produced the shipped JSON.
