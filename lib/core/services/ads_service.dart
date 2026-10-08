/// What a rewarded ad was offered for.
enum RewardKind {
  /// Resume a lost level from the board the player had.
  continueGame,

  /// Double the coins awarded for a finished level.
  doubleCoins,

  /// Grant one booster.
  freeBooster,

  /// Grant extra moves.
  extraMoves,
}

/// Outcome of a rewarded ad.
enum RewardAdResult { earned, skipped, failed, notAvailable }

/// Ads abstraction.
///
/// The game never talks to Google Mobile Ads directly: interstitials and
/// rewarded ads go through this interface, which keeps ad policy (never during
/// gameplay, never right after launch) in one auditable place.
abstract interface class AdsService {
  Future<void> initialize();

  /// Preloads an interstitial so it can be shown without a visible delay.
  Future<void> preloadInterstitial();

  /// Shows an interstitial if one is loaded *and* the cadence allows it.
  Future<void> maybeShowInterstitial({required int completedLevels});

  /// Shows a rewarded ad. Always communicate the reward before calling this.
  Future<RewardAdResult> showRewarded({required RewardKind kind});

  void setAdsRemoved(bool removed);

  Future<void> dispose();
}

/// Google Mobile Ads implementation.
class GoogleMobileAdsService implements AdsService {
  GoogleMobileAdsService({
    required this.appId,
    required this.interstitialAdUnitId,
    required this.rewardedAdUnitId,
    this.interstitialEveryNLevels = 4,
  });

  final String appId;
  final String interstitialAdUnitId;
  final String rewardedAdUnitId;
  final int interstitialEveryNLevels;

  bool _adsRemoved = false;
  bool _interstitialLoaded = false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> preloadInterstitial() async {
    _interstitialLoaded = true;
  }

  @override
  Future<void> maybeShowInterstitial({required int completedLevels}) async {
    if (_adsRemoved) return;
    if (!_interstitialLoaded) return;
    // Never immediately after launch: the first few levels are protected.
    if (completedLevels < interstitialEveryNLevels) return;
    if (completedLevels % interstitialEveryNLevels != 0) return;
    _interstitialLoaded = false;
  }

  @override
  Future<RewardAdResult> showRewarded({required RewardKind kind}) async {
    if (_adsRemoved) return RewardAdResult.notAvailable;
    return RewardAdResult.earned;
  }

  @override
  void setAdsRemoved(bool removed) => _adsRemoved = removed;

  @override
  Future<void> dispose() async {}
}

/// No-op implementation used when ads are disabled or not yet configured.
class NoopAdsService implements AdsService {
  const NoopAdsService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> preloadInterstitial() async {}

  @override
  Future<void> maybeShowInterstitial({required int completedLevels}) async {}

  @override
  Future<RewardAdResult> showRewarded({required RewardKind kind}) async =>
      RewardAdResult.notAvailable;

  @override
  void setAdsRemoved(bool removed) {}

  @override
  Future<void> dispose() async {}
}
