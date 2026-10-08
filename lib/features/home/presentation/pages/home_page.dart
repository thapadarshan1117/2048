import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_strings.dart';
import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_durations.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/widgets/coin_display.dart';
import '../../../../core/widgets/game_button.dart';
import '../../../../core/widgets/gradient_scaffold.dart';
import '../../../../core/widgets/star_rating.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../game/domain/game_snapshot.dart';
import '../../../progression/domain/daily_reward_state.dart';
import '../cubit/home_cubit.dart';

/// The first screen the player sees.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeCubit _cubit;
  GameSnapshot? _resumable;

  @override
  void initState() {
    super.initState();
    _cubit = HomeCubit(
      progressRepository: ServiceLocator.instance.progressRepository,
      levelRepository: ServiceLocator.instance.levelRepository,
      todayKey: formatDailyKey(DateTime.now()),
    );
    _load();
  }

  String _todayKey() => formatDailyKey(DateTime.now());

  Future<void> _load() async {
    _resumable = ServiceLocator.instance.saveRepository.readActive();
    await _cubit.load(resumable: _resumable != null);
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: StreamBuilder<HomeState>(
        stream: _cubit.stream,
        initialData: _cubit.state,
        builder: (context, snapshot) {
          final state = snapshot.data ?? _cubit.state;
          return _buildContent(context, state);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, HomeState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                AppStrings.tr('app_name'),
                style: AppTypography.displayMedium,
              ),
            ),
            CoinDisplay(
              coins: state.progress.coins,
              onTap: () => context.push(AppRoutes.shop),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _ObjectiveCard(state: state),
                const SizedBox(height: AppSpacing.lg),
                if (state.dailyRewardCoins > 0) ...<Widget>[
                  _DailyRewardCard(
                    coins: state.dailyRewardCoins,
                    onClaim: _claimDailyReward,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                PrimaryButton(
                  label: state.hasResumableGame
                      ? AppStrings.tr('home_continue')
                      : AppStrings.tr('home_play'),
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => context.push(
                    AppRoutes.game,
                    extra: <String, Object?>{
                      if (_resumable != null)
                        'mode': 'resume',
                        'levelId':
                            _resumable?.levelId ?? state.currentLevel,
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(
                  label: AppStrings.tr('home_levels'),
                  icon: Icons.grid_view_rounded,
                  onPressed: () => context.push(AppRoutes.levels),
                ),
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(
                  label: AppStrings.tr('home_daily'),
                  icon: Icons.calendar_today_rounded,
                  onPressed: () => context.push(AppRoutes.daily),
                ),
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(
                  label: AppStrings.tr('home_infinite'),
                  icon: Icons.all_inclusive_rounded,
                  onPressed: () => context.push(
                    AppRoutes.game,
                    extra: <String, Object?>{'mode': 'infinite'},
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: GameButton(
                        label: AppStrings.tr('nav_shop'),
                        variant: GameButtonVariant.ghost,
                        icon: Icons.storefront_rounded,
                        onPressed: () => context.push(AppRoutes.shop),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: GameButton(
                        label: AppStrings.tr('nav_settings'),
                        variant: GameButtonVariant.ghost,
                        icon: Icons.settings_rounded,
                        onPressed: () => context.push(AppRoutes.settings),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _claimDailyReward() {
    final progress = _cubit.state.progress;
    final daily = progress.dailyReward;
    final today = formatDailyKey(DateTime.now());
    final nextDay = daily.lastClaimKey == null ? 1 : daily.streakDay + 1;
    final reward = DailyRewardState.rewardFor(nextDay.clamp(1, 7));

    final updated = ServiceLocator.instance.progressRepository.read();
    ServiceLocator.instance.progressRepository.write(
      updated.copyWithCoins(updated.coins + reward).copyWithDailyReward(
            daily.claim(today),
          ),
    );
    ServiceLocator.instance.analytics.logEvent(
      AnalyticsEvents.dailyRewardClaimed,
      <String, Object>{'day': nextDay.clamp(1, 7), 'coins': reward},
    );
    _load();
  }
}

/// Shows the level the player should play next.
class _ObjectiveCard extends StatelessWidget {
  const _ObjectiveCard({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.progress.progress;
    final levelProgress = progress.progressFor(progress.currentLevel);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.surfaceElevated, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  '${progress.currentLevel}',
                  style: AppTypography.number(20)
                      .copyWith(color: AppColors.textOnAccent),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(AppStrings.tr('home_level_label'),
                        style: AppTypography.label),
                    const SizedBox(height: 2),
                    StarRating(stars: levelProgress.stars, size: 18, animate: false),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(AppStrings.tr('home_stars_label'),
                      style: AppTypography.label),
                  const SizedBox(height: 2),
                  Text('${state.starsEarned}',
                      style: AppTypography.title),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            state.currentObjectiveText,
            style: AppTypography.body,
          ),
        ],
      ),
    );
  }
}

/// Daily reward call to action.
class _DailyRewardCard extends StatelessWidget {
  const _DailyRewardCard({required this.coins, required this.onClaim});

  final int coins;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.22),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.card_giftcard_rounded,
              color: AppColors.primary, size: 30),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              AppStrings.tr('daily_reward_ready', <String, Object?>{'count': coins}),
              style: AppTypography.bodyStrong,
            ),
          ),
          AnimatedContainer(
            duration: AppDurations.normal,
            child: GameButton(
              label: AppStrings.tr('daily_reward'),
              height: 40,
              onPressed: onClaim,
            ),
          ),
        ],
      ),
    );
  }
}
