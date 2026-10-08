# Analytics, telemetry and monetisation

## Event list

All names live in `lib/core/services/analytics_service.dart` (`AnalyticsEvents`).
Every event carries gameplay parameters only - level, score, mode, block value,
booster. **No personally identifying information is ever sent.**

| Event | Parameters | Fired when |
| --- | --- | --- |
| `app_open` | - | the app starts |
| `tutorial_started` | `step` | a curated tutorial level is entered |
| `tutorial_completed` | `step` | a curated tutorial level is completed |
| `level_started` | `level`, `chapter`, `mode`, `objective`, `move_limit` | a level begins |
| `level_completed` | `level`, `score`, `stars`, `moves`, `block_value` | the objective is met |
| `level_failed` | `level`, `score`, `reason` | the board fills up or moves run out |
| `level_replayed` | `level` | the player retries a level |
| `block_dropped` | `column`, `value`, `level`, `mode` | a block is dropped |
| `block_merged` | `value`, `level`, `mode`, `chain` | a merge completes |
| `booster_opened` | `booster`, `level` | a booster enters targeting mode |
| `booster_used` | `booster`, `level`, `mode` | a booster is applied |
| `reward_ad_offered` | `placement` | a rewarded ad is offered |
| `reward_ad_started` | `placement` | the player starts a rewarded ad |
| `reward_ad_completed` | `placement`, `reward` | the player earns the reward |
| `interstitial_shown` | `level` | an interstitial is displayed |
| `daily_challenge_started` | `date`, `level` | the daily puzzle is started |
| `daily_challenge_completed` | `date`, `score`, `stars` | the daily puzzle is completed |
| `infinite_started` | - | endless mode is started |
| `infinite_game_over` | `score`, `highest_block`, `moves` | endless mode ends |
| `purchase_started` | `product_id` | a purchase flow opens |
| `purchase_completed` | `product_id`, `price` | a purchase succeeds |
| `daily_reward_claimed` | `day`, `coins` | the daily ladder is claimed |
| `milestone_reached` | `milestone_id` | an achievement is unlocked |

### User properties

| Property | Values |
| --- | --- |
| `highest_level` | highest level id reached |
| `total_stars` | stars earned |
| `remove_ads` | `true` / `false` |
| `language` | language code |

## Crashlytics

`CrashReportingService` attaches non-fatal context so a report can be
reproduced:

| Key | Example |
| --- | --- |
| `mode` | `level`, `daily`, `infinite` |
| `level` | `137` |
| `score` | `4820` |
| `moves_used` | `63` |
| `board_blocks` | `41` |
| `highest_block` | `256` |

No save data, no device identifiers and no user input are ever logged.

## Ads

`AdsService` is the only thing that talks to Google Mobile Ads.

| Rule | Value |
| --- | --- |
| Interstitial cadence | every `interstitialEveryNLevels = 4` completed levels |
| Protected window | the first 4 completed levels never see an interstitial |
| During gameplay | never |
| Rewarded ads | always opt-in, reward stated before the ad is shown |
| After `remove_ads` | interstitials disabled, rewarded ads stay optional |
| Test ids | Google public test ids by default, overridable by dart-define |

Remote-configurable: `interstitial_frequency`.

## Purchases

`PurchaseService` wraps `in_app_purchase`. The only product in the MVP is
`remove_ads`.

* Store logic lives behind the interface, so the game never imports
  `in_app_purchase` directly.
* Purchases are verified by the store; the client records the entitlement only
  after a successful transaction.
* `restorePurchases()` is exposed on both the shop and the settings screen, as
  both stores require.
* No secrets, API keys or licence checks live in the client.

## Remote config

`RemoteConfigService` ships local defaults; the interface is shaped so Firebase
Remote Config can be dropped in later without touching a call site.

| Key | Default |
| --- | --- |
| `interstitial_frequency` | `4` |
| `reward_ad_coin_multiplier` | `2.0` |
| `daily_reward_day7` | `200` |
| `booster_price_undo` | `60` |
| `booster_price_hammer` | `90` |
| `booster_price_shuffle` | `120` |
| `difficulty_scale` | `1.0` |
| `max_level` | `500` |
| `spawn_weight_2` | `65` |
| `spawn_weight_4` | `25` |
| `spawn_weight_8` | `10` |

## Privacy

* No account, no login, no backend. The core game works fully offline.
* All progress is stored on the device.
* Analytics and Crashlytics are off by default and must be enabled with a
  dart-define.
* No third-party SDK that collects advertising identifiers is initialised unless
  `ADS_ENABLED=true`.
