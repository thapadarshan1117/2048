import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_strings.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/widgets/game_button.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/widgets/icon_action_button.dart';
import '../../../core/widgets/star_rating.dart';
import '../../progression/domain/daily_reward_state.dart';
import '../domain/daily_challenge.dart';
import 'daily_labels.dart';

/// Daily challenge entry point.
///
/// Shows the deterministic puzzle for today, the streak ladder and the best
/// result the player has achieved on it.
class DailyPage extends StatelessWidget {
  const DailyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final locator = ServiceLocator.instance;
    final challenge = DailyChallenge.forDate(DateTime.now());
    final attempt = locator.dailyRepository.attemptFor(challenge.key);
    final progress = locator.progressRepository.read();

    return GradientScaffold(
      appBar: AppBar(
        leading: IconActionButton(
          icon: Icons.arrow_back_rounded,
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.tr('daily_title')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(challenge.key, style: AppTypography.label),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppColors.surfaceElevated, AppColors.surface],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(AppStrings.tr('daily_today'), style: AppTypography.title),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  DailyLabels.objectiveText(challenge),
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Text(AppStrings.tr('result_best'), style: AppTypography.label),
                    const SizedBox(width: AppSpacing.sm),
                    Text('${attempt?.score ?? 0}', style: AppTypography.title),
                    const Spacer(),
                    StarRating(
                      stars: attempt?.stars ?? 0,
                      size: 20,
                      animate: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppStrings.tr('daily_streak',
                <String, Object?>{'day': progress.dailyReward.streakDay + 1}),
            style: AppTypography.bodyStrong,
          ),
          const SizedBox(height: AppSpacing.md),
          _RewardLadder(nextDay: progress.dailyReward.streakDay + 1),
          const Spacer(),
          PrimaryButton(
            label: attempt?.completed == true
                ? AppStrings.tr('daily_completed')
                : AppStrings.tr('daily_play'),
            icon: Icons.play_arrow_rounded,
            onPressed: () => context.push(
              AppRoutes.game,
              extra: <String, Object?>{'mode': 'daily'},
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// The 7-rung daily reward ladder.
class _RewardLadder extends StatelessWidget {
  const _RewardLadder({required this.nextDay});

  final int nextDay;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(DailyRewardState.ladderLength, (index) {
        final day = index + 1;
        final reached = day < nextDay;
        final isNext = day == nextDay;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: isNext
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : reached
                      ? AppColors.success.withValues(alpha: 0.16)
                      : AppColors.surfaceDim,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isNext ? AppColors.primary : Colors.transparent,
              ),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  '$day',
                  style: AppTypography.label.copyWith(
                    color: isNext ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DailyRewardState.rewardFor(day)}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
