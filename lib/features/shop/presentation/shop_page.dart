import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/widgets/coin_display.dart';
import '../../../core/widgets/game_button.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/widgets/icon_action_button.dart';
import '../../boosters/presentation/cubit/booster_inventory_cubit.dart';
import '../../boosters/presentation/widgets/booster_tile.dart';
import '../../game/domain/boosters/booster_registry.dart';

/// Booster shop and the remove-ads purchase.
///
/// Coins and booster charges come from [BoosterInventoryCubit], the same owner
/// the profile screen uses, so a purchase made here is visible everywhere the
/// moment the player navigates.
class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = ServiceLocator.instance.boosterInventoryCubit;

    return BlocProvider<BoosterInventoryCubit>.value(
      value: cubit,
      child: const _ShopView(),
    );
  }
}

class _ShopView extends StatelessWidget {
  const _ShopView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BoosterInventoryCubit, BoosterInventoryState>(
      listener: (context, state) {
        final key = state.messageKey;
        if (key == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.tr(key))),
        );
        context.read<BoosterInventoryCubit>().dismissMessage();
      },
      builder: (context, state) {
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
                child: CoinDisplay(coins: state.coins),
              ),
            ],
          ),
          child: ListView(
            children: <Widget>[
              _RemoveAdsCard(
                owned: state.removeAdsOwned,
                onBuy: () =>
                    context.read<BoosterInventoryCubit>().buyRemoveAds(),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(AppStrings.tr('shop_title'), style: AppTypography.title),
              const SizedBox(height: AppSpacing.md),
              ...BoosterRegistry.all.map(
                (booster) => BoosterTile(
                  booster: booster,
                  owned: state.countOf(booster.id),
                  coins: state.coins,
                  onBuy: () =>
                      context.read<BoosterInventoryCubit>().buy(booster.id),
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
                label: AppStrings.tr('shop_restore'),
                variant: GameButtonVariant.ghost,
                onPressed: () => context
                    .read<BoosterInventoryCubit>()
                    .restorePurchases(),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }
}

/// Remove-ads card. Rewarded ads stay opt-in even after the purchase, so the
/// copy says exactly that.
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
