# Architecture

## 1. Layers

```text
+-------------------------------------------------------------+
| Flutter application UI                                      |
|   pages/  widgets/  cubit/                                  |
|   Renders GameSessionState, sends intents to the cubit.     |
+-----------------------------+-------------------------------+
                              | GameSessionState (immutable)
+-----------------------------v-------------------------------+
| Flame rendering / animation                                 |
|   MergeGame  BoardComponent  BlockComponent  PreviewBlock   |
|   MergeBurst  ScorePopup  ColumnHighlight                    |
|   Mirrors the board; animates the transitions it is handed.  |
+-----------------------------+-------------------------------+
                              | GameState / BoardTransition
+-----------------------------v-------------------------------+
| Game domain logic (pure Dart)                               |
|   GameEngine  MergeEngine  ScoreCalculator  BlockGenerator   |
|   GameBoard  BlockState  GameStats  Boosters  Objectives     |
|   No Flutter. No Flame. No widgets. Fully unit-testable.     |
+-------------------------------------------------------------+
```

### Why the domain is pure

* The rules are the thing most likely to be wrong, and the thing cheapest to
  test. A pure domain can be tested in milliseconds without a device, an
  emulator, a golden image or a widget tree.
* Rendering can be rewritten (different engine, different art direction) without
  touching a rule.
* The same engine drives the level simulator, the balance tooling and the game.

`tool/check_sources.py` enforces the boundary: any file under
`lib/features/*/domain/` that mentions `flutter`, `flame`, `BuildContext`,
`Widget`, `Canvas`, `PositionComponent`, `flutter_bloc` or `go_router` fails the
check.

## 2. State ownership

```text
GameSessionCubit  (the ONLY writer)
        |
        +-- owns a GameEngine
        +-- owns PlayerProgress / coins / booster inventory
        +-- writes saves through GameSaveRepository
        |
        v
   GameSessionState  (immutable, Equatable)
        |
        +--> Flutter widgets rebuild
        +--> Flame BoardComponent reconciles
```

`GameSessionState` carries:

| Field | Purpose |
| --- | --- |
| `game` | the immutable domain `GameState` |
| `level` | the level being played (`null` in endless mode) |
| `status` | playing / paused / won / lost |
| `selectedColumn` | the column the player is aiming at |
| `selectedBlockId` | block targeted by a booster |
| `activeBoosterId` | booster in targeting mode |
| `inventory` | owned booster counts |
| `coins` | coin balance |
| `lastTransitions` | `BoardTransition`s for the renderer to replay |
| `transitionId` | increments per drop so the renderer can tell new work from a rebuild |
| `messageKey` | localisation key of a transient message |

Nothing downstream can mutate the board. The Flame layer holds a
`Map<int, BlockComponent>` keyed by block id purely so it can follow a block
across a drop, a gravity shift and a merge - it is a cache, not a model.

## 3. The drop pipeline

```text
tap / drag release
      |
      v
GameSessionCubit.drop(column)
      |
      v
GameEngine.canDrop(column)  ------------------> reject: DropRejection.columnFull
      |
      v
GameEngine.drop(column)
      |
      +-- landingRowFor(column)          (honours board restrictions)
      +-- board.withBlock(dropped)
      +-- MergeEngine.resolve(...)       (gravity -> merges -> repeat)
      |     +-- emits one BoardTransition per wave
      |     +-- each carries BlockMove[] + MergeEvent[]
      +-- GameStats.applyDrop(...)       (score, merges, chain, highest)
      +-- BlockGenerator.next()          (deterministic, seeded)
      +-- isGameOver = !board.hasLegalDrop
      |
      v
DropOutcome { accepted, state, droppedBlock, landingRow, resolution, ... }
      |
      v
cubit: audio, haptics, analytics, progression, coins, status
      |
      v
emit(GameSessionState)  -->  widgets rebuild, Flame animates
```

## 4. The merge algorithm

```text
loop:
  1. apply gravity (blocks fall to the lowest free cell)
  2. find connected same-value components of size >= 2
  3. pair them deterministically:
       - pool sorted by (-row, column)   [lowest, then left-most first]
       - each block pairs with its closest group-mate, preferring an
         orthogonally adjacent one
       - an odd block is left over for the next wave
  4. the pair produces one block of value x 2 at the anchor cell
       anchor = preferredAnchorBlockId's cell, else the lower row, else the
                smaller column
  5. repeat until a pass produces no merges
```

Each iteration emits a `BoardTransition`. `MergeEvent` carries everything the
animation layer needs: source ids, target id, old/new value, cell, chain step and
score awarded. `MergeResolution` carries the whole cascade.

**Merging conserves total board value.** This is asserted in
`test/features/game/domain/merge_engine_test.dart`.

**Game over** is exactly `GameBoard.hasLegalDrop == false`.

## 5. Board restrictions

Levels can restrict the board. Restrictions live on `DifficultyProfile` and are
applied by `GameEngine.landingRowFor`, which scans from the floor upwards and
stops at the first row the restriction forbids:

```dart
for (var row = board.rows - 1; row >= 0; row--) {
  if (!restriction.allows(row, column)) return null;
  if (board.cells[row][column] == null) return row;
}
```

Two rules follow from this and both are load-bearing:

* `canDrop` must **never** probe `restriction.allows(0, column)` - a height
  restriction forbids rows, not columns, so a row-0 probe rejects every column
  of a height-limited board.
* Restrictions must be **serialised with their payload** (`restrictionTopRow`,
  `restrictedColumns`). Persisting only the kind silently converts a restricted
  level into an unrestricted one on reload.

## 6. Boosters

```text
Booster (interface)
  String get id / nameKey / descriptionKey / price
  bool get requiresTargetBlock
  bool canUse(BoosterContext)
  BoosterOutcome apply(BoosterContext)

BoosterOutcome { state, effect, transitions, affectedBlockIds, applied, rejectionKey }
```

Boosters are pure use cases. They receive a `BoosterContext` (state plus the
targeted block/column) and return a brand new `GameState`. They never touch
widgets, navigation, analytics or storage.

`BoosterSupport.settle` is shared by every booster that changes the board: it
re-runs the same `MergeEngine` and the same `GameStats.applyDrop` path as a
normal drop, so score, combo and undo history stay consistent.

Adding a booster = one class + one line in `BoosterRegistry`.

## 7. Persistence

Everything is local. Three repositories, all behind interfaces:

| Repository | Stores |
| --- | --- |
| `ProgressRepository` | per-level stars / best score / completion, coins, daily reward state, lifetime stats, claimed milestones, booster inventory |
| `SettingsRepository` | sound, music, vibration, notifications, language, remove-ads |
| `GameSaveRepository` | the resumable `GameSnapshot` and the booster inventory |

`GameSnapshot` (v1) stores mode, level id, a `GameStateCore` and an undo
history. The core persists **board values only** - block ids are regenerated on
load, so ids are never used as identity across sessions.

Decoding is total: `GameSnapshotCodec.decode` returns `null` for any malformed
payload, rejects future versions and rejects boards that cannot accept a single
drop (a finished game is not a resumable one). A corrupt save is discarded while
the rest of the player's progress is preserved.

## 8. Services

Every platform capability sits behind an interface in `lib/core/services` with a
no-op default, so the app runs with nothing configured:

| Service | Default | Real implementation |
| --- | --- | --- |
| `AudioService` | `FlameAudioService` | Flame Audio (WAV assets) |
| `HapticsService` | `FlutterHapticsService` | `HapticFeedback` |
| `AnalyticsService` | `NoopAnalyticsService` | `FirebaseAnalyticsService` |
| `CrashReportingService` | `NoopCrashReportingService` | `FirebaseCrashReportingService` |
| `AdsService` | `NoopAdsService` | `GoogleMobileAdsService` |
| `PurchaseService` | `NoopPurchaseService` | `StorePurchaseService` |
| `RemoteConfigService` | `LocalRemoteConfigService` | local defaults |

`ServiceLocator` is the composition root. It builds the graph once and injects
downwards; no widget reaches for a singleton.

### Ads policy

* Never during gameplay.
* Never immediately after launch - the first `interstitialEveryNLevels` (4)
  completed levels are protected.
* Interstitials fire only on `completedLevels % 4 == 0`.
* Rewarded ads are always opt-in and always optional; the reward is stated
  before the ad is shown.
* `remove_ads` disables interstitials entirely; rewarded ads remain available.

## 9. Design system

`lib/app/theme/` owns every visual decision:

| File | Contents |
| --- | --- |
| `app_colors.dart` | palette, 13-step block ramp, 20 chapter themes |
| `app_spacing.dart` | 4-point spacing scale |
| `app_radius.dart` | corner radius scale |
| `app_durations.dart` | animation durations |
| `app_typography.dart` | type scale |
| `app_shadows.dart` | shadow presets |
| `app_theme.dart` | the single `ThemeData` |

No screen declares its own colour, padding, radius or duration. No font files
are shipped - the platform default renders every supported language correctly.

### Reusable components

`lib/core/widgets/`: `GradientScaffold`, `GameButton` (`PrimaryButton`,
`SecondaryButton`, `IconActionButton`), `StarRating`, `ScoreDisplay`,
`CoinDisplay`, `GameDialog`, `ConfirmDialog`, `DebugPanel`.
`lib/features/levels/presentation/widgets/`: `LevelNode`.
`lib/features/game/presentation/widgets/`: `BoosterButton`.
`lib/features/profile/presentation/widgets/`: `StatCard`.

## 10. Responsiveness

* No hardcoded widths or heights anywhere.
* `BoardLayout.compute(boardSize, rows, columns)` derives the cell size from the
  area it is given, keeps blocks square, and centres the board.
* `GradientScaffold` applies safe-area insets once, so no screen repeats it.
* Level maps use `Wrap`; long screens use `ListView`; the HUD uses `Row` with
  `Expanded`/`Spacer`.

## 11. Debug tools

`DebugPanel` is gated by `AppConfig.showDebugTools`, which requires **both**
`DEBUG_TOOLS=true` and a debug/profile build. In release it is compiled out and
`DebugPanel.available` is `false`, so no debug affordance can appear in
production. `test/app/app_test.dart` asserts this.
