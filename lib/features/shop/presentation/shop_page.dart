import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/purchase_service.dart';
import '../../../core/widgets/coin_display.dart';
import '../../../core/widgets/game_button.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/widgets/icon_action_button.dart';
import '../../game/domain/boosters/booster_registry.dart';
import '../../monetization/domain/entitlements.dart';
import '../../progression/data/progress_repository.dart';


/// Booster shop and the remove-ads purchase.
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  ProgressSnapshot _progress = ProgressSnapshot.empty;
  bool _removeAdsOwned = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final locator = ServiceLocator.instance;
    setState(() {
      _progress = locator.progressRepository.read();
      _removeAdsOwned = locator.purchases.removeAdsPurchased ||
          locator.settingsRepository.read().removeAdsPurchased;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        leading: IconActionButton(
          icon: Icons.arrow_back_rounded,
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.tr('shop_title')),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: CoinDisplay(coins: _progress.coins),
          ),
        ],
      ),
      child: ListView(
        children: <Widget>[
          _RemoveAdsCard(owned: _removeAdsOwned, onBuy: _buyRemoveAds),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.tr('shop_title'), style: AppTypography.title),
          const SizedBox(height: AppSpacing.md),
          ...BoosterRegistry.all.map(
            (booster) => _BoosterRow(
              name: AppStrings.tr(booster.nameKey),
              description: AppStrings.tr(booster.descriptionKey),
              price: booster.price,
              onBuy: () => _buyBooster(booster.id, booster.price),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.tr('shop_coin_packs'), style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.tr('shop_coin_packs_soon'),
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          GameButton(
            label: AppStrings.tr('settings_restore'),
            variant: GameButtonVariant.ghost,
            onPressed: _restore,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  void _buyBooster(String boosterId, int price) {
    final locator = ServiceLocator.instance;
    if (_progress.coins < price) {
      _showMessage(AppStrings.tr('shop_not_enough_coins'));
      return;
    }
    final inventory = Map<String, int>.from(_progress.boosterInventory);
    inventory[boosterId] = (inventory[boosterId] ?? 0) + 1;
    final updated = _progress
        .copyWithCoins(_progress.coins - price)
        .copyWithBoosterInventory(inventory);
    locator.progressRepository.write(updated);
    _reload();
  }

  Future<void> _buyRemoveAds() async {
    final locator = ServiceLocator.instance;
    locator.analytics.logEvent(AnalyticsEvents.purchaseStarted,
        <String, Object>{'product_id': 'remove_ads'});
    final result = await locator.purchases.buy(ProductCatalogue.removeAds);
    if (result == PurchaseResult.success) {
      locator.analytics.logEvent(AnalyticsEvents.purchaseCompleted,
          <String, Object>{'product_id': 'remove_ads'});
      final settings = locator.settingsRepository.read();
      final updated = settings.copyWith(removeAdsPurchased: true);
      locator.settingsRepository.write(updated);
      locator.ads.setAdsRemoved(true);
      _reload();
    }
  }

  Future<void> _restore() async {
    await ServiceLocator.instance.purchases.restorePurchases();
    _reload();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _RemoveAdsCard extends StatelessWidget {
  const _RemoveAdsCard({required this.owned, required this.onBuy});

  final bool owned;
  final Future<void> Function() onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.20),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(AppStrings.tr('shop_remove_ads'), style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.tr('shop_remove_ads_desc'),
            style: AppTypography.body,
          ),
          const SizedBox(height: AppSpacing.md),
          GameButton(
            label: owned
                ? AppStrings.tr('shop_remove_ads_owned')
                : AppStrings.tr('shop_buy'),
            height: 44,
            onPressed: owned ? null : onBuy,
          ),
        ],
      ),
    );
  }
}

class _BoosterRow extends StatelessWidget {
  const _BoosterRow({
    required this.name,
    required this.description,
    required this.price,
    required this.onBuy,
  });

  final String name;
  final String description;
  final int price;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: AppTypography.bodyStrong),
                const SizedBox(height: 2),
                Text(description, style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GameButton(
            label: '$price',
            height: 38,
            width: 74,
            onPressed: onBuy,
          ),
        ],
      ),
    );
  }
}
