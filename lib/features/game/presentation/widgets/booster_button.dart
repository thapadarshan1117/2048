import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';

/// A booster slot in the in-game toolbar.
///
/// Shows owned count and disabled state; the disabled state is the only
/// feedback the player needs when a booster cannot be used on the current
/// board.
class BoosterButton extends StatelessWidget {
  const BoosterButton({
    required this.label,
    required this.icon,
    required this.count,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
    super.key,
  });

  final String label;
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final usable = enabled && count > 0;
    return GestureDetector(
      onTap: usable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.22)
              : AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.surfaceElevated,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 22,
              color: usable ? AppColors.textPrimary : AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: usable ? AppColors.textSecondary : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: AppTypography.label.copyWith(
                color: usable ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
