# Testing and verification

## What is verified by execution, and what is not

This repository was built in an environment **without a Dart/Flutter toolchain**
(`pub.dev` and the Flutter SDK download hosts are unreachable). That constraint
is real and it shapes what can honestly be claimed.

### Verified by execution

**`tool/mirror/` - an executable Python mirror of the pure-Dart domain.**

Every algorithm that decides *what happens* in the game is mirrored in Python
and executed by a test suite. `python3 tool/mirror/run_tests.py` currently runs
**113 tests, all passing**:

| File | Tests | Covers |
| --- | --- | --- |
| `test_core_algorithms.py` | 56 | board, gravity, merge waves, chain reactions, score, combo multipliers, game-over detection, RNG determinism, block-generation distribution, snapshot round-trip |
| `test_boosters.py` | 17 | undo history, hammer targeting, shuffle value conservation and determinism, wildcard, upgrade, rejection keys |
| `test_save_and_daily.py` | 13 | snapshot encode/decode, corrupt-payload rejection, version rejection, undo persistence, daily seed determinism and uniqueness |
| `test_levels_and_simulator.py` | 27 | level generation, objective/star round-trips, validator rules, simulator determinism and aggregation |

The mirror is not a mock: it is a line-by-line port of the same rules, so a bug
in the algorithm shows up in both implementations and the tests catch it there.

**The 500-level catalogue is validated by execution.**

```bash
python3 tool/mirror/generate_levels.py --levels 500
# 500 levels, 20 chapters, 343.6 KB
# validation: 500 levels, 0 with errors, 0 with warnings

python3 tool/mirror/validate_levels.py --games 6
# loads the exported JSON (no regeneration) and re-checks every level
# 0 errors, 0 warnings
```

**The audio assets are validated by execution.**

`python3 tool/generate_audio.py` synthesises 9 sound effects and 2 music loops as
original WAV files. Each file is verified to be a readable, non-silent 44.1 kHz
16-bit mono WAV.

**`tool/check_sources.py` is executed on every change.**

It checks balanced delimiters, that every relative import resolves, that no
domain file references Flutter or Flame, and that no banned token
(`UnimplementedError`, `TODO`, bare `dynamic`) is present.

```bash
python3 tool/check_sources.py
# checked 95 Dart files under lib/
# no structural problems found
```

### NOT verified by execution

* **`flutter analyze` has never been run.** The lint configuration in
  `analysis_options.yaml` is deliberate and the sources are structured to
  satisfy it, but the analyzer has not executed.
* **`flutter test` has never been run.** The Dart test suite is written and
  structurally checked, but the Dart tests have not been executed.
* **The app has never been built, installed or run.** No Android SDK, no Xcode.
  No frame has been rendered, no input handled on a device.
* **Flame rendering has never been seen.** `MergeGame`, `BoardComponent`,
  `BlockComponent`, `MergeBurst` and `ScorePopup` are written against the Flame
  1.x API and are structurally consistent, but they have not been executed.

Run these locally before shipping:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## The Dart test suite

| File | Covers |
| --- | --- |
| `test/features/game/domain/merge_engine_test.dart` | merge waves, chain reactions, anchor selection, value conservation, id allocation, stability |
| `test/features/game/domain/game_board_test.dart` | landing rows, full boards, restrictions, JSON round-trip |
| `test/features/game/domain/game_engine_test.dart` | drops, refusals, game over, objectives, move limits, undo, determinism, restore, clone |
| `test/features/game/domain/score_calculator_test.dart` | score scaling, chain multiplier, chain-step cap, event payload |
| `test/features/game/domain/boosters_test.dart` | registry, undo, hammer, shuffle, `BoosterSupport.settle` |
| `test/features/game/data/game_snapshot_test.dart` | codec round-trip, corrupt rejection, version rejection, non-resumable boards |
| `test/features/game/presentation/game_session_test.dart` | cubit intents, column aiming, rejections, pause, restart, boosters, inventory, game over |
| `test/features/levels/domain/level_test.dart` | every objective type, star thresholds, restrictions round-trip, chapters |
| `test/features/levels/data/level_generator_test.dart` | generation, curated band, difficulty pacing, validation seeds, calibration budget, validator rules |
| `test/features/levels/data/level_repository_test.dart` | the shipped catalogue: 500 levels, 20 chapters, contiguous ids, objective mix, no dead ends, fallback generation |
| `test/features/progression/domain/progression_test.dart` | level progress, unlocking, monotonic bests, daily ladder, grace days, milestones, FNV-1a vectors |
| `test/app/app_test.dart` | localisation keys, design system, `AppConfig` defaults, debug panel compiled out |

## Integration tests

`test/features/levels/data/level_repository_test.dart` loads the shipped
catalogue through `rootBundle` exactly the way the app does, so a broken asset
bundle fails in CI rather than on a player's phone. It asserts the level count,
chapter sizes, id contiguity, objective mix, star ordering, that no level seals
every column, that every level round-trips through JSON, and that the repository
falls back to generation when an asset is missing.

## The balance loop

```text
generate_levels.py
   |
   +-- draft every level
   +-- measure with GameSimulator (deterministic greedy bot, fixed seeds)
   +-- _set_objective   (pass 1: objective target)
   +-- _calibrate       (pass 2: star thresholds, at the objective's own budget)
   +-- validate with LevelValidator
   +-- export assets/levels/chapter_NN.json

validate_levels.py
   |
   +-- load the exported JSON (no regeneration)
   +-- re-simulate and re-check every level
```

The two-pass calibration exists because measuring star thresholds in the same
pass as the objective target produced ~75 `unreachable_three_star` warnings:
value objectives get a much longer measurement window (up to 520 moves) than the
budget they are finally judged at, so a threshold measured at 520 moves looked
impossible at 240.

The bot itself needed work. A merge-maximising bot plateaus at a highest block
of ~128, which made every value-based level look impossible. The heuristic now
rewards *concentrating* value into fewer, larger blocks
(`+350 * log2(maxValue)`, `-22 * distinctValues`, `-16 * blockCount`,
`+45 * emptyCells`), which is what a strong human does, and reaches 2048-4096 in
long sessions.

## Known limitations

* `GameStateCore` persists board values only; block ids are regenerated on load.
  Ids must never be used as identity across sessions.
* Cross-session undo is supported through the snapshot's `undo` cores, but the
  restored history is capped at `GameEngine.maxUndoDepth`.
* Firebase, Ads and IAP implementations are behind interfaces and default to
  no-op. They have not been exercised against a real project or store account.
