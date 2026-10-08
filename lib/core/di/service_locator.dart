import 'package:shared_preferences/shared_preferences.dart';

import '../../features/daily_challenge/data/daily_challenge_repository.dart';
import '../../features/game/data/game_save_repository.dart';
import '../../features/levels/data/level_repository.dart';
import '../../features/progression/data/progress_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../services/ads_service.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/crash_reporting_service.dart';
import '../services/haptics_service.dart';
import '../services/preferences_service.dart';
import '../services/purchase_service.dart';
import '../services/remote_config_service.dart';
import '../constants/app_config.dart';

/// Composition root.
///
/// The app builds every dependency here once and injects it downwards, so no
/// widget ever reaches for a singleton. Swapping an implementation (for tests,
/// or when Firebase becomes available) is a one-line change.
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  late final PreferencesService preferences;
  late final LevelRepository levelRepository;
  late final ProgressRepository progressRepository;
  late final SettingsRepository settingsRepository;
  late final GameSaveRepository saveRepository;
  late final DailyChallengeRepository dailyRepository;
  late final AudioService audio;
  late final HapticsService haptics;
  late final AnalyticsService analytics;
  late final CrashReportingService crashReporting;
  late final AdsService ads;
  late final PurchaseService purchases;
  late final RemoteConfigService remoteConfig;

  bool _ready = false;

  /// Builds the object graph. Safe to call more than once.
  Future<void> initialize() async {
    if (_ready) return;

    final prefs = await PreferencesService.create();
    preferences = prefs;

    levelRepository = AssetLevelRepository();
    await levelRepository.load();

    progressRepository = LocalProgressRepository(prefs);
    settingsRepository = LocalSettingsRepository(prefs);
    saveRepository = LocalGameSaveRepository(prefs);
    dailyRepository = LocalDailyChallengeRepository(prefs.sharedPreferences);

    audio = FlameAudioService();
    await audio.initialize();

    haptics = FlutterHapticsService();

    // Firebase-backed services are only constructed when the build is
    // configured for them; otherwise the no-op implementations keep the game
    // fully functional offline. Initialisation is attempted in a try/catch so a
    // missing or malformed google-services.json degrades to no-op telemetry
    // instead of a crash on launch.
    if (AppConfig.enableFirebase) {
      try {
        await Firebase.initializeApp();
        analytics = FirebaseAnalyticsService(FirebaseAnalytics.instance);
        crashReporting =
            FirebaseCrashReportingService(FirebaseCrashlytics.instance);
      } on Object {
        analytics = const NoopAnalyticsService();
        crashReporting = const NoopCrashReportingService();
      }
    } else {
      analytics = const NoopAnalyticsService();
      crashReporting = const NoopCrashReportingService();
    }

    if (AppConfig.adsEnabled) {
      ads = GoogleMobileAdsService(
        appId: AppConfig.admobAppId,
        interstitialAdUnitId: AppConfig.interstitialAdUnitId,
        rewardedAdUnitId: AppConfig.rewardedAdUnitId,
      );
      await ads.initialize();
    } else {
      ads = const NoopAdsService();
    }

    if (AppConfig.purchasesEnabled) {
      purchases = StorePurchaseService(
        removeAdsProductId: AppConfig.removeAdsProductId,
      );
      await purchases.initialize();
    } else {
      purchases = const NoopPurchaseService();
    }

    remoteConfig = const LocalRemoteConfigService();
    await remoteConfig.initialize();

    _ready = true;
  }

  bool get isReady => _ready;
}
