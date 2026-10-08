import 'package:bloc/bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/services/ads_service.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../core/utils/daily_seed.dart';
import '../../../game/domain/boosters/booster_registry.dart';
import '../../../monetization/domain/entitlements.dart';
import '../../../progression/data/progress_repository.dart';
import '../../../settings/data/settings_repository.dart';
import '../../../settings/domain/app_settings.dart';
import 'booster_inventory_state.dart';

/// Owns the coin balance and the booster inventory for every screen that is
/// not a play session: the shop, the profile and the pre-game booster picker.
///
/// A running [GameSessionCubit] keeps its own copy of the same snapshot. Both
/// write through the same [ProgressRepository], and this cubit reloads whenever
/// a screen that shows it is entered, so the two can never disagree on screen.
class BoosterInventoryCubit extends Cubit<BoosterInventoryState> {
  BoosterInventoryCubit({
    required ProgressRepository progressRepository,
    required PurchaseService purchases,
    required AnalyticsService analytics,
    required SettingsRepository settingsRepository,
    required AdsService ads,
  })  : _progressRepository = progressRepository,
        _purchases = purchases,
        _analytics = analytics,
        _settingsRepository = settingsRepository,
        _ads = ads,
        super(const BoosterInventoryState.empty());

  final ProgressRepository _progressRepository;
  final PurchaseService _purchases;
  final AnalyticsService _analytics;
  final SettingsRepository _settingsRepository;
  final AdsService _ads;

  /// Reads the persisted snapshot. Called from `initState` of every screen that
  /// shows coins or booster charges.
  void load() {
    final snapshot = _progressRepository.read();
    emit(state.copyWith(
      coins: snapshot.coins,
      inventory: Map<String, int>.from(snapshot.boosterInventory),
      removeAdsOwned: _purchases.removeAdsPurchased,
      clearMessage: true,
    ));
  }

  /// Buys one charge of [boosterId] with coins.
  void buy(String boosterId) {
    final booster = BoosterRegistry.byId(boosterId);
    if (booster == null) return;
    if (!state.canAfford(booster.price)) {
      emit(state.copyWith(messageKey: 'shop_reject_not_enough_coins'));
      return;
    }

    final snapshot = _progressRepository.read();
    final inventory = Map<String, int>.from(snapshot.boosterInventory);
    inventory[boosterId] = (inventory[boosterId] ?? 0) + 1;
    final updated = snapshot
        .copyWithCoins(snapshot.coins - booster.price)
        .copyWithBoosterInventory(inventory);
    _commit(updated);

    _analytics.logEvent('booster_purchased', <String, Object>{
      'booster': boosterId,
      'price': booster.price,
      'source': 'shop',
    });
  }

  /// Adds [amount] coins (level rewards, milestone payouts, rewarded ads).
  void addCoins(int amount) {
    if (amount == 0) return;
    final snapshot = _progressRepository.read();
    _commit(snapshot.copyWithCoins(snapshot.coins + amount));
  }

  /// Removes [amount] coins, refusing to go negative.
  bool spendCoins(int amount) {
    final snapshot = _progressRepository.read();
    if (snapshot.coins < amount) {
      emit(state.copyWith(messageKey: 'shop_reject_not_enough_coins'));
      return false;
    }
    _commit(snapshot.copyWithCoins(snapshot.coins - amount));
    return true;
  }

  /// Grants [amount] free charges of [boosterId] (daily reward, rewarded ad).
  void grant(String boosterId, int amount) {
    final snapshot = _progressRepository.read();
    final inventory = Map<String, int>.from(snapshot.boosterInventory);
    inventory[boosterId] = (inventory[boosterId] ?? 0) + amount;
    _commit(snapshot.copyWithBoosterInventory(inventory));
  }

  /// Starts the remove-ads purchase and applies the entitlement on success.
  ///
  /// The purchase itself removes interstitials only; rewarded ads stay opt-in,
  /// which is what the shop copy promises.
  Future<void> buyRemoveAds() async {
    _analytics.logEvent(
      'purchase_started',
      <String, Object>{'product_id': ProductCatalogue.removeAds},
    );
    final result = await _purchases.buy(ProductCatalogue.removeAds);
    if (result == PurchaseResult.success) {
      await _applyRemoveAds();
    } else if (result == PurchaseResult.failed) {
      _analytics.logEvent(
        'purchase_failed',
        <String, Object>{'product_id': ProductCatalogue.removeAds},
      );
    }
    load();
  }

  /// Re-runs the store's purchase restoration.
  Future<void> restorePurchases() async {
    await _purchases.restorePurchases();
    if (_purchases.removeAdsPurchased) {
      await _applyRemoveAds();
    }
    load();
  }

  Future<void> _applyRemoveAds() async {
    _analytics.logEvent(
      'purchase_completed',
      <String, Object>{'product_id': ProductCatalogue.removeAds},
    );
    final settings = _settingsRepository.read();
    if (settings.removeAdsPurchased) return;
    await _settingsRepository.write(
      settings.copyWith(removeAdsPurchased: true),
    );
    _ads.setAdsRemoved(true);
  }

  /// Pays out the daily reward ladder, returning the coins granted.
  ///
  /// `tick` first applies the grace/reset rule for a day that was skipped, so a
  /// player who missed one day keeps their streak and one who missed two starts
  /// again at rung one.
  int claimDailyReward() {
    final todayKey = DailySeed.keyFor(DateTime.now());
    final snapshot = _progressRepository.read();
    final daily = snapshot.dailyReward.tick(todayKey);
    if (!daily.canClaim(todayKey)) {
      emit(state.copyWith(messageKey: 'daily_already_claimed'));
      return 0;
    }
    final coins = daily.nextReward;
    _commit(snapshot
        .copyWithDailyReward(daily.claim(todayKey))
        .copyWithCoins(snapshot.coins + coins));
    return coins;
  }

  void dismissMessage() => emit(state.copyWith(clearMessage: true));

  void _commit(ProgressSnapshot snapshot) {
    _progressRepository.write(snapshot);
    emit(state.copyWith(
      coins: snapshot.coins,
      inventory: Map<String, int>.from(snapshot.boosterInventory),
      removeAdsOwned: _purchases.removeAdsPurchased,
      clearMessage: true,
    ));
  }
}

/// Resolves the cubit for screens that only need to read it.
extension BoosterInventoryCubitLocator on ServiceLocator {
  BoosterInventoryCubit get boosterInventory => boosterInventoryCubit;
}
