import 'package:flutter/material.dart';

import '../../../../app/localization/app_strings.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../game/domain/boosters/booster.dart';
import 'booster_catalogue.dart';

/// One booster as a purchasable row: name, explanation, price and charge count.
///
/// Used by the shop. The in-game toolbar uses `BoosterButton` instead, because
/// there the button doubles as the targeting toggle.
class BoosterTile extends StatelessWidget {
  const BoosterTile({
    required this.booster,
    required this.owned,
    required this.coins,
    required this.onBuy,
    super.key,
  });

  final Booster booster;

  /// Charges the player already owns.
  final int owned;

  final int coins;

  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final affordable = coins >= booster.price;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceDim),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              BoosterCatalogue.iconFor(booster.id),
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.tr(booster.nameKey),
                  style: AppTypography.bodyStrong,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.tr(booster.descriptionKey),
                  style: AppTypography.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (owned > 0) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${AppStrings.tr('shop_owned')}: $owned',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _PriceChip(price: booster.price, affordable: affordable),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: affordable ? onBuy : null,
                child: Text(AppStrings.tr('shop_buy')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Coin cost of one booster charge, dimmed when the player cannot afford it.
class _PriceChip extends StatelessWidget {
  const _PriceChip({required this.price, required this.affordable});

  final int price;
  final bool affordable;

  @override
  Widget build(BuildContext context) {
    final colour = affordable ? AppColors.coin : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(shape: BoxShape.circle, color: colour),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$price',
            style: AppTypography.label.copyWith(color: colour),
          ),
        ],
      ),
    );
  }
}
