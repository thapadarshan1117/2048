import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';

/// Analytics abstraction.
///
/// The game talks to this interface only, so analytics never leaks into a
/// widget and the app runs fully offline with the no-op implementation.
///
/// No personally identifying information is ever sent: every event carries
/// gameplay parameters only (level, score, mode, block value, booster).
abstract interface class AnalyticsService {
  Future<void> initialize();

  void logEvent(String name, [Map<String, Object>? parameters]);

  void setUserProperty(String name, String? value);

  void logScreenView(String screenName);

  Future<void> dispose();
}

/// Firebase Analytics implementation.
///
/// Only constructed when [AppConfig.enableFirebase] is true, which also
/// requires `google-services.json` / `GoogleService-Info.plist` to be present.
class FirebaseAnalyticsService implements AnalyticsService {
  const FirebaseAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> initialize() async {}

  @override
  void logEvent(String name, [Map<String, Object>? parameters]) {
    // Analytics must never break gameplay: a failed event is swallowed.
    unawaited(_analytics.logEvent(
      name: name,
      parameters: parameters?.map(
        (key, value) => MapEntry(key, value is num ? value : value.toString()),
      ),
    ));
  }

  @override
  void setUserProperty(String name, String? value) {
    unawaited(_analytics.setUserProperty(name: name, value: value));
  }

  @override
  void logScreenView(String screenName) {
    unawaited(_analytics.logScreenView(screenName: screenName));
  }

  @override
  Future<void> dispose() async {}
}

/// No-op implementation - the default, so the game works offline.
class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> initialize() async {}

  @override
  void logEvent(String name, [Map<String, Object>? parameters]) {}

  @override
  void setUserProperty(String name, String? value) {}

  @override
  void logScreenView(String screenName) {}

  @override
  Future<void> dispose() async {}
}

/// The complete set of analytics events the game emits.
///
/// Keeping the names in one place is what keeps the analytics documentation
/// true.
abstract final class AnalyticsEvents {
  const AnalyticsEvents._();

  static const String appOpen = 'app_open';
  static const String tutorialStarted = 'tutorial_started';
  static const String tutorialCompleted = 'tutorial_completed';

  static const String levelStarted = 'level_started';
  static const String levelCompleted = 'level_completed';
  static const String levelFailed = 'level_failed';
  static const String levelReplayed = 'level_replayed';

  static const String blockDropped = 'block_dropped';
  static const String blockMerged = 'block_merged';

  static const String boosterOpened = 'booster_opened';
  static const String boosterUsed = 'booster_used';

  static const String rewardAdOffered = 'reward_ad_offered';
  static const String rewardAdStarted = 'reward_ad_started';
  static const String rewardAdCompleted = 'reward_ad_completed';

  static const String interstitialShown = 'interstitial_shown';

  static const String dailyChallengeStarted = 'daily_challenge_started';
  static const String dailyChallengeCompleted = 'daily_challenge_completed';

  static const String infiniteStarted = 'infinite_started';
  static const String infiniteGameOver = 'infinite_game_over';

  static const String purchaseStarted = 'purchase_started';
  static const String purchaseCompleted = 'purchase_completed';

  static const String dailyRewardClaimed = 'daily_reward_claimed';
  static const String milestoneReached = 'milestone_reached';
}
