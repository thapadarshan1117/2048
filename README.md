# MERGE DROP

An original number merge / drop puzzle game for phones, built with **Flutter** and
**Flame**.

Genre inspiration only: 2048-style merge games and "M2 Blocks"-style drop
puzzles. Every name, logo, colour, sound, animation, screen and line of text in
this repository is original work written for this project. No third-party
artwork, audio, fonts or copy are used anywhere.

```text
Drop a numbered block into a column.
It falls to the lowest free cell.
Adjacent equal blocks merge, doubling in value.
Chains resolve automatically.
Score is awarded.
The level ends when the objective is met - or when the board fills up.
```

---

## Running the game

```bash
flutter pub get
flutter run
```

The game runs with no configuration: no API keys, no account, no network. All
progress is stored on the device.

### Optional build flags

```bash
flutter run \
  --dart-define=ENABLE_FIREBASE=true \   # Analytics + Crashlytics
  --dart-define=ADS_ENABLED=true \       # Google Mobile Ads
  --dart-define=PURCHASES_ENABLED=true \ # in-app purchases
  --dart-define=ADMOB_APP_ID=ca-app-pub-xxx~yyy \
  --dart-define=DEBUG_TOOLS=true         # debug panel (debug builds only)
```

Firebase additionally needs `google-services.json` (Android) /
`GoogleService-Info.plist` (iOS) and the matching Gradle plugin. Those files are
deliberately not committed.

See `docs/ARCHITECTURE.md` for the full architecture, `docs/LEVELS.md` for the
level catalogue, `docs/ANALYTICS.md` for the event list and `docs/TESTING.md`
for the verification story.

---

## What is in the box

| Area | Status |
| --- | --- |
| Pure-Dart merge engine (gravity, chains, game over) | Complete |
| Centralised score calculator with combo multipliers | Complete |
| Seeded weighted block generator (2: 65% / 4: 25% / 8: 10%) | Complete |
| 500-level data-driven catalogue in 20 chapters of 25 | Complete |
| `LevelValidator` + `GameSimulator` balance tooling | Complete |
| 20 hand-curated tutorial levels that teach by interaction | Complete |
| Flame rendering layer (blocks, preview, particles, screen shake) | Complete |
| Tap + horizontal-drag input with column feedback | Complete |
| Boosters: Undo, Hammer, Shuffle (+ Wildcard, Upgrade) | Complete |
| Coin economy, daily reward ladder, achievements | Complete |
| Deterministic daily challenge seeded from `YYYY-MM-DD` | Complete |
| Endless mode | Complete |
| Offline save / resume behind a repository abstraction | Complete |
| Settings (sound, music, vibration, notifications, language, privacy) | Complete |
| Ads abstraction (interstitial every 4 levels, rewarded opt-in) | Complete |
| Remove-ads IAP abstraction | Complete |
| Analytics + Crashlytics abstractions with local defaults | Complete |
| Localisation-ready architecture, English MVP | Complete |
| Reusable component library + centralised design system | Complete |
| Unit + integration tests | Complete |
| Dev-only debug panel, compiled out of release builds | Complete |

---

## Architecture at a glance

```text
lib/
  app/                  app shell: theme, router, localisation
    theme/              colours, spacing, radius, durations, typography, shadows
    router/             go_router routes
    localization/       localisation keys + English values
  core/
    constants/          AppConfig (dart-defines), GameConstants
    di/                 composition root
    errors/ extensions/ services/ utils/ widgets/
  features/
    game/               the play session
      domain/           PURE Dart - no Flutter, no Flame, fully testable
      data/             snapshot codec
      presentation/
        cubit/          GameSessionCubit - the only writer of game state
        flame/          MergeGame, BoardComponent, BlockComponent, effects
        pages/ widgets/ HUD, boosters, result dialog
    levels/             level catalogue, generator, validator, simulator
    progression/        stars, progress, coins, daily rewards, achievements
    home/ levels/ daily_challenge/ infinite/ settings/ shop/ profile/ monetization/
```

### The three-layer rule

1. **Game domain logic** (`lib/features/*/domain`) is pure Dart. It does not
   import `flutter`, `flame`, `BuildContext`, `Widget`, `Canvas` or
   `PositionComponent`, and it can be unit-tested without a device. The
   logical board is the single source of truth.
2. **Flame rendering / animation** (`presentation/flame`) mirrors the domain and
   animates the transitions it is handed. It never decides anything.
3. **Flutter application UI** (`presentation/pages`, `presentation/widgets`,
   `presentation/cubit`) renders state and sends intents to the cubit.

`GameSessionCubit` is the only component that can call `GameEngine`. Flame
components and widgets emit intents and observe `GameSessionState`.

`tool/check_sources.py` enforces this mechanically - it fails the build if a
domain file references Flutter or Flame:

```bash
python3 tool/check_sources.py
```

---

## The game rules

* **Board** - 12 rows x 6 columns (configurable per level).
* **Drop** - the block lands on the lowest free cell of the chosen column.
* **Merge** - horizontally or vertically adjacent blocks of equal value merge
  into one block of double the value. Every available pair resolves in the same
  wave; a chain reaction then runs until the board is stable.
* **Score** - `(newValue x (1 + 0.5 x chainStep)).round()`, `chainStep` capped
  at 9, plus a big-merge bonus from 128 upwards.
* **Game over** - no column can accept a block.
* **Objectives** - ReachScore, CreateNumber, MergeCount, ReachNumber,
  CompleteWithinMoves, ComboCount.
* **Stars** - 1 for completing, 2 at `twoStarScore`, 3 at `threeStarScore`. Best
  result is always kept.

Merging conserves the total value on the board. This is asserted in the test
suite.

---

## Levels

500 levels, 20 chapters of 25. One JSON file per chapter under
`assets/levels/`.

Levels 1-20 are hand-curated: their objectives, move limits and initial blocks
are authored for teaching, and the calibration pipeline is forbidden from
rewriting them. Levels 21-500 are generated and then **measured** by
`GameSimulator` - a deterministic greedy bot - so objective targets and star
thresholds are set from real play rather than guesswork. `LevelValidator` then
rejects anything impossible, trivial, unreachable or dead-ended.

The catalogue currently ships with **0 errors and 0 warnings**:

```text
reachScore 171 | createNumber 85 | comboCount 83 | mergeCount 81 | reachNumber 80
81 move-limited | 379 with initial blocks
13 restrictedColumns | 13 maxHeight | 20 curated
```

See `docs/LEVELS.md`.

---

## Tooling

```bash
python3 tool/check_sources.py                       # structural lint of lib/
python3 tool/mirror/run_tests.py                    # 113 domain algorithm tests
python3 tool/generate_audio.py --out assets         # synthesise SFX + music
python3 tool/mirror/generate_levels.py --levels 500 # regenerate the catalogue
python3 tool/mirror/validate_levels.py --games 6    # validate an exported catalogue
```

`tool/mirror/` is an executable Python mirror of the pure-Dart domain. It exists
because the Dart toolchain is not available in every environment: the mirror
runs the *same* algorithms (merge engine, gravity, scoring, game over, boosters,
objectives, stars, generator, validator, simulator, daily seed, snapshot codec)
so those algorithms are genuinely executed and covered by tests rather than only
written. `docs/TESTING.md` explains exactly what is and is not verified.

---

## Testing

```bash
flutter test
```

Unit tests cover the merge engine, board, engine, score calculator, boosters,
objectives, stars, level generator, validator, simulator, snapshot codec,
progression, daily seed and reward ladder, design system and localisation.
Integration tests load the shipped 500-level catalogue and validate it.

See `docs/TESTING.md` for the current verification status.

---

## Licence / attribution

Original work. No third-party assets, code or copy.
