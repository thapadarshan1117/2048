/// Compile-time configuration.
///
/// Everything that differs between a local dev build and a shipped build is a
/// `--dart-define`, so no secrets live in source control and the app can run
/// out of the box.
///
/// ```bash
/// flutter run --dart-define=ENABLE_FIREBASE=true \
///             --dart-define=ADMOB_APP_ID=ca-app-pub-xxx~yyy \
///             --dart-define=ADS_ENABLED=true
/// ```
abstract final class AppConfig {
  const AppConfig._();

  /// Enables Firebase Analytics / Crashlytics.
  ///
  /// Off by default: turning it on also requires `google-services.json` /
  /// `GoogleService-Info.plist` and the matching Gradle plugin, which are
  /// deliberately not committed.
  static const bool enableFirebase =
      bool.fromEnvironment('ENABLE_FIREBASE', defaultValue: false);

  /// Enables Google Mobile Ads.
  static const bool adsEnabled =
      bool.fromEnvironment('ADS_ENABLED', defaultValue: false);

  /// Enables in-app purchases (needs store configuration).
  static const bool purchasesEnabled =
      bool.fromEnvironment('PURCHASES_ENABLED', defaultValue: false);

  /// Google Mobile Ads application id. Defaults to Google's public test app.
  static const String admobAppId = String.fromEnvironment(
    'ADMOB_APP_ID',
    defaultValue: 'ca-app-pub-3940256099942544~3347511713',
  );

  /// Rewarded ad unit used for "continue / double coins / free booster".
  static const String rewardedAdUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );

  /// Interstitial ad unit shown between levels.
  static const String interstitialAdUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );

  /// Product id of the "remove ads" purchase.
  static const String removeAdsProductId = String.fromEnvironment(
    'REMOVE_ADS_PRODUCT_ID',
    defaultValue: 'remove_ads',
  );

  /// Unlocks the debug panel and the dev-only simulator entry points.
  static const bool debugTools =
      bool.fromEnvironment('DEBUG_TOOLS', defaultValue: false);

  /// `true` in release builds - used to keep debug-only UI out of production.
  static bool get isRelease {
    var release = true;
    assert(() {
      release = false;
      return true;
    }());
    return release;
  }

  /// The debug panel is only ever available in debug/profile builds *and* when
  /// explicitly enabled.
  static bool get showDebugTools => debugTools && !isRelease;
}
