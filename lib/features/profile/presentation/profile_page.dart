import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/widgets/game_button.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/widgets/icon_action_button.dart';
import '../../progression/domain/milestone.dart';
import '../../progression/domain/player_progress.dart';
import '../../progression/presentation/cubit/progression_cubit.dart';
import '../../progression/presentation/cubit/progression_state.dart';
import 'widgets/stat_card.dart';

/// Lifetime statistics and achievements.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProgressionCubit>(
      create: (_) => ProgressionCubit(
        progressRepository: ServiceLocator.instance.progressRepository,
      )..load(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProgressionCubit, ProgressionState>(
      builder: (context, state) {
        final progress = state.progress;
        final stats = state.stats;

        return GradientScaffold(
          appBar: AppBar(
            leading: IconActionButton(
              icon: Icons.arrow_back_rounded,
              onPressed: () => context.pop(),
            ),
            title: Text(AppStrings.tr('profile_title')),
          ),
          child: ListView(
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  StatCard(
                    label: AppStrings.tr('profile_levels_completed'),
                    value: '${progress.levelsCompleted}',
                  ),
                  StatCard(
                    label: AppStrings.tr('profile_stars_earned'),
                    value: '${progress.starsEarned}',
                  ),
                  StatCard(
                    label: AppStrings.tr('profile_total_score'),
                    value: '${stats.highestScore}',
                  ),
                  StatCard(
                    label: AppStrings.tr('profile_highest_block'),
                    value: '${stats.highestBlock}',
                  ),
                  StatCard(
                    label: AppStrings.tr('profile_best_infinite'),
                    value: '${stats.infiniteBestScore}',
                  ),
                  StatCard(
                    label: AppStrings.tr('profile_daily_done'),
                    value: '${stats.dailyChallengesCompleted}',
                  ),
                  StatCard(
                    label: AppStrings.tr('profile_total_merges'),
                    value: '${stats.totalMerges}',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppStrings.tr('profile_milestones'),
                style: AppTypography.title,
              ),
              const SizedBox(height: AppSpacing.md),
              ...MilestoneCatalogue.all.map(
                (milestone) => _MilestoneRow(
                  milestone: milestone,
                  progress: progress,
                  stats: stats,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              GameButton(
                label: AppStrings.tr('nav_shop'),
                variant: GameButtonVariant.ghost,
                icon: Icons.storefront_rounded,
                onPressed: () => context.push('/shop'),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.progress,
    required this.stats,
  });

  final Milestone milestone;
  final PlayerProgress progress;
  final MilestoneStats stats;

  @override
  Widget build(BuildContext context) {
    final reached = milestone.isReached(progress, stats);
    final ratio = milestone.progressRatio(progress, stats);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: reached
            ? AppColors.success.withValues(alpha: 0.14)
            : AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: reached
            ? Border.all(color: AppColors.success.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            reached ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: reached ? AppColors.success : AppColors.textMuted,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.tr(milestone.nameKey),
                  style: AppTypography.bodyStrong,
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceDim,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      reached ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '${milestone.currentValue(progress, stats)}/${milestone.target}',
            style: AppTypography.label,
          ),
        ],
      ),
    );
  }
}
