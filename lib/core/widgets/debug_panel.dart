import 'package:flutter/material.dart';

import '../constants/app_config.dart';
import '../../app/localization/app_strings.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../constants/game_constants.dart';
import '../di/service_locator.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import '../services/purchase_service.dart';
import '../services/remote_config_service.dart';

/// Developer-only overlay.
///
/// Compiled out of release builds entirely - [AppConfig.showDebugTools] is
/// `false` there, so the entry point never renders. This is what keeps debug
/// affordances out of production.
class DebugPanel extends StatelessWidget {
  const DebugPanel({super.key});

  /// Whether the debug entry point should be shown at all.
  static bool get available => AppConfig.showDebugTools;

  static Future<void> open(BuildContext context) async {
    if (!available) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => const _DebugSheet(),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _DebugSheet extends StatelessWidget {
  const _DebugSheet();

  @override
  Widget build(BuildContext context) {
    final locator = ServiceLocator.instance;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(AppStrings.tr('debug_title'), style: AppTypography.headline),
            const SizedBox(height: AppSpacing.lg),
            _Row(label: 'Levels loaded', value: '${locator.levelRepository.count}'),
            _Row(
              label: 'Firebase',
              value: AppConfig.enableFirebase ? 'on' : 'off',
            ),
            _Row(label: 'Ads', value: AppConfig.adsEnabled ? 'on' : 'off'),
            _Row(
              label: 'Purchases',
              value: AppConfig.purchasesEnabled ? 'on' : 'off',
            ),
            _Row(
              label: 'Remove ads owned',
              value: locator.purchases.removeAdsPurchased ? 'yes' : 'no',
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _Action(
                  label: AppStrings.tr('debug_grant_coins'),
                  onTap: () {
                    final progress = locator.progressRepository.read();
                    locator.progressRepository.write(
                      progress.copyWithCoins(progress.coins + 1000),
                    );
                    Navigator.of(context).pop();
                  },
                ),
                _Action(
                  label: AppStrings.tr('debug_clear_save'),
                  onTap: () async {
                    await locator.progressRepository.reset();
                    await locator.saveRepository.clearActive();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
                _Action(
                  label: AppStrings.tr('debug_simulate'),
                  onTap: () => Navigator.of(context).pop(),
                ),
                _Action(
                  label: AppStrings.tr('debug_validate'),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: AppTypography.body),
          Text(value, style: AppTypography.bodyStrong),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

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
          color: AppColors.surfaceDim,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label, style: AppTypography.label),
      ),
    );
  }
}

/// Compile-time guard so the debug panel cannot silently ship.
///
/// `true` exactly when the panel is unavailable, which is the case in every
/// release build. `test/app/app_test.dart` asserts this.
bool get debugToolsCompiledOut => !AppConfig.showDebugTools;
