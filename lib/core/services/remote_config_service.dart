/// Remote configuration abstraction.
///
/// The MVP ships local defaults; the interface is shaped so Firebase Remote
/// Config can be dropped in later without touching a single call site.
///
/// ```text
/// interstitial_frequency
/// reward_ad_coin_multiplier
/// daily_reward
/// booster_prices
/// spawn_weights
/// difficulty
/// max_level
/// ```
abstract interface class RemoteConfigService {
  Future<void> initialize();

  /// Fetches and activates new values. Safe to call when offline.
  Future<void> fetchAndActivate();

  int getInt(String key, int fallback);

  double getDouble(String key, double fallback);

  bool getBool(String key, bool fallback);

  String getString(String key, String fallback);
}

/// Local defaults only.
class LocalRemoteConfigService implements RemoteConfigService {
  const LocalRemoteConfigService();

  static const Map<String, Object> _defaults = <String, Object>{
    'interstitial_frequency': 4,
    'reward_ad_coin_multiplier': 2.0,
    'daily_reward_day7': 200,
    'booster_price_undo': 60,
    'booster_price_hammer': 90,
    'booster_price_shuffle': 120,
    'difficulty_scale': 1.0,
    'max_level': 500,
    'spawn_weight_2': 65,
    'spawn_weight_4': 25,
    'spawn_weight_8': 10,
  };

  @override
  Future<void> initialize() async {}

  @override
  Future<void> fetchAndActivate() async {}

  @override
  int getInt(String key, int fallback) {
    final value = _defaults[key];
    return value is int ? value : fallback;
  }

  @override
  double getDouble(String key, double fallback) {
    final value = _defaults[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return fallback;
  }

  @override
  bool getBool(String key, bool fallback) {
    final value = _defaults[key];
    return value is bool ? value : fallback;
  }

  @override
  String getString(String key, String fallback) {
    final value = _defaults[key];
    return value is String ? value : fallback;
  }
}
