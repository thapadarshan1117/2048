import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// The coin balance chip shown in the top bar of every screen.
class CoinDisplay extends StatelessWidget {
  const CoinDisplay({
    required this.coins,
    this.onTap,
    super.key,
  });

  final int coins;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.coin.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[AppColors.coin, AppColors.coinDark],
                ),
              ),
              child: const Center(
                child: Text(
                  '\$',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textOnAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('$coins', style: AppTypography.bodyStrong),
            if (onTap != null) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.add_circle,
                  size: 16, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}
