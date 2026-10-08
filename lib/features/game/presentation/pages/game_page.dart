import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_strings.dart';
import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_durations.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/game_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/ads_service.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/widgets/game_button.dart';
import '../../../../core/widgets/game_dialog.dart';
import '../../../../core/widgets/score_display.dart';
import '../../../../core/widgets/star_rating.dart';
import '../../../daily_challenge/domain/daily_challenge.dart';
import '../../../levels/domain/level.dart';
import '../../domain/game_board.dart';
import '../../domain/game_engine.dart';
import '../../domain/game_mode.dart';
import '../cubit/game_session_cubit.dart';
import '../cubit/game_session_state.dart';
import '../flame/game_board_view.dart';
import '../widgets/booster_button.dart';

/// How a session should start.
enum GameLaunchMode {
  /// Play [levelId] from the beginning.
  level,

  /// Continue the persisted session.
  resume,

  /// Endless mode.
  infinite,

  /// Today's deterministic daily puzzle.
  daily,
}

/// Arguments handed to [GamePage] by the router.
class GamePageArgs {
  const GamePageArgs({this.levelId, this.mode = 'level'});

  final int? levelId;
  final String mode;

  GameLaunchMode get launchMode => switch (mode) {
        'infinite' => GameLaunchMode.infinite,
        'daily' => GameLaunchMode.daily,
        'resume' => GameLaunchMode.resume,
        _ => GameLaunchMode.level,
      };

  /// Parses the `extra` payload pushed by callers. Falls back to a fresh level
  /// so a malformed deep link still opens a playable game.
  factory GamePageArgs.fromExtra(Object? extra) {
    if (extra is! Map) return const GamePageArgs();
    final levelId = extra['levelId'];
    final mode = extra['mode'];
    return GamePageArgs(
      levelId: levelId is int ? levelId : int.tryParse('$levelId'),
      mode: mode is String ? mode : 'level',
    );
  }
}

/// The play screen.
///
/// All state lives in [GameSessionCubit]; this page only renders it and
/// forwards intents. The board is a Flame widget, but the HUD, boosters and
/// result dialog are ordinary Flutter widgets.
class GamePage extends StatelessWidget {
  GamePage({Object? args, super.key})
      : _args = GamePageArgs.fromExtra(args);

  final GamePageArgs _args;

  @override
  Widget build(BuildContext context) {
    final locator = ServiceLocator.instance;
    // A resumed session must be judged against the level it was started on,
    // not against whatever the caller happened to pass.
    final saved = _args.launchMode == GameLaunchMode.resume
        ? locator.saveRepository.readActive()
        : null;
    final levelId = saved?.levelId ?? _args.levelId;
    final level =
        levelId == null ? null : locator.levelRepository.levelById(levelId);

    return BlocProvider<GameSessionCubit>(
      create: (_) {
        // The engine needs *some* starting point before the cubit's start*
        // method runs; for a resumed session the saved core is used instead.
        final engine = saved == null
            ? GameEngine.start(
                board: level == null
                    ? GameBoard.empty(
                        rows: GameConstants.defaultRows,
                        columns: GameConstants.defaultColumns,
                      )
                    : GameEngine.initialBoardForLevel(
                        level,
                        GameConstants.defaultRows,
                        GameConstants.defaultColumns,
                      ),
                profile: level?.difficulty ?? const DifficultyProfile(),
                level: level,
                mode: _args.launchMode == GameLaunchMode.daily
                    ? GameMode.daily
                    : GameMode.level,
                seed: _args.launchMode == GameLaunchMode.daily
                    ? DailyChallenge.forDate(DateTime.now()).seed
                    : null,
              )
            : GameEngine.restore(
                core: saved.core,
                profile: level?.difficulty ?? const DifficultyProfile(),
                level: level,
                mode: saved.mode,
              );

        final cubit = GameSessionCubit(
          engine: engine,
          progressRepository: locator.progressRepository,
          saveRepository: locator.saveRepository,
          dailyRepository: locator.dailyRepository,
          settingsRepository: locator.settingsRepository,
          audio: locator.audio,
          haptics: locator.haptics,
          analytics: locator.analytics,
          ads: locator.ads,
          progress: locator.progressRepository.read(),
          settings: locator.settingsRepository.read(),
        );

        switch (_args.launchMode) {
          case GameLaunchMode.infinite:
            cubit.startInfinite();
          case GameLaunchMode.daily:
            cubit.startDaily(DailyChallenge.forDate(DateTime.now()));
          case GameLaunchMode.resume when saved != null:
            cubit.resume(saved, level);
          case GameLaunchMode.level when level != null:
            cubit.startLevel(level);
          case GameLaunchMode.level:
          case GameLaunchMode.resume:
            cubit.startInfinite();
        }
        return cubit;
      },
      child: const _GameView(),
    );
  }
}

/// The visual layout of a running session.
class _GameView extends StatelessWidget {
  const _GameView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameSessionCubit, GameSessionState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == GameSessionStatus.won) {
          _showResult(context, won: true);
        } else if (state.status == GameSessionStatus.lost) {
          _showResult(context, won: false);
        }
      },
      builder: (context, state) {
        final cubit = context.read<GameSessionCubit>();
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[AppColors.backgroundTop, AppColors.backgroundBottom],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  _TopBar(state: state, cubit: cubit),
                  const SizedBox(height: AppSpacing.sm),
                  _ObjectiveBar(state: state),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: GameBoardView(
                        state: state,
                        onColumnSelected: cubit.selectColumn,
                        onColumnCommitted: cubit.drop,
                        onBlockTapped: cubit.selectBlock,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _BoosterBar(state: state, cubit: cubit),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showResult(BuildContext context, {required bool won}) {
    final cubit = context.read<GameSessionCubit>();
    final state = cubit.state;
    final level = state.level;
    final analytics = ServiceLocator.instance.analytics;
    if (!won) {
      // The reward is always communicated before the ad is offered.
      analytics.logEvent(
        AnalyticsEvents.rewardAdOffered,
        <String, Object>{'placement': 'continue_level'},
      );
    }
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, _, __) => ResultOverlay(
        won: won,
        score: state.game.score,
        stars: state.game.stars,
        bestScore: level == null
            ? 0
            : cubit.progress.progress.progressFor(level.id).bestScore,
        objectiveText: level == null
            ? ''
            : AppStrings.tr(
                level.objective.localizationKey,
                <String, Object?>{'target': level.objective.target},
              ),
        isDaily: state.game.mode == GameMode.daily,
        onNext: () {
          Navigator.of(context).pop();
          if (level != null) {
            context.pushReplacement(AppRoutes.game,
                extra: <String, Object?>{
                  'levelId': level.id + 1,
                  'mode': 'level',
                });
          } else {
            cubit.restart();
          }
        },
        onRetry: () {
          Navigator.of(context).pop();
          cubit.restart();
        },
        onMenu: () {
          Navigator.of(context).pop();
          context.go(AppRoutes.home);
        },
        onRewarded: () {
          Navigator.of(context).pop();
          analytics.logEvent(
            AnalyticsEvents.rewardAdStarted,
            <String, Object>{'placement': 'continue_level'},
          );
          cubit.grantReward(RewardKind.continueGame);
          analytics.logEvent(
            AnalyticsEvents.rewardAdCompleted,
            <String, Object>{'placement': 'continue_level', 'reward': 'continue'},
          );
        },
      ),
      transitionBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
}

/// Score, moves, best and the pause button.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.cubit});

  final GameSessionState state;
  final GameSessionCubit cubit;

  @override
  Widget build(BuildContext context) {
    final level = state.level;
    final remaining = state.game.remainingMoves;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconActionButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => _confirmQuit(context),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ScoreDisplay(
              score: state.game.score,
              label: AppStrings.tr('hud_score'),
              fontSize: 26,
            ),
          ),
          if (level != null && level.effectiveMoveLimit > 0)
            _StatChip(
              label: AppStrings.tr('hud_moves'),
              value: '$remaining',
              highlight: remaining <= 5,
            ),
          if (level != null && level.effectiveMoveLimit == 0)
            _StatChip(
              label: AppStrings.tr('hud_best'),
              value: '${cubit.progress.progress.progressFor(level.id).bestScore}',
            ),
          const SizedBox(width: AppSpacing.sm),
          IconActionButton(
            icon: Icons.pause_rounded,
            onPressed: cubit.pause,
          ),
        ],
      ),
    );
  }

  void _confirmQuit(BuildContext context) {
    ConfirmDialog.show(
      context,
      title: AppStrings.tr('hud_quit'),
      message: AppStrings.tr('hud_quit_confirm'),
      confirmLabel: AppStrings.tr('hud_quit'),
      cancelLabel: AppStrings.tr('hud_resume'),
      destructive: true,
      onConfirm: () {
        cubit.exit();
        context.go(AppRoutes.home);
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.danger.withValues(alpha: 0.18)
            : AppColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: highlight ? AppColors.danger : AppColors.surfaceElevated,
        ),
      ),
      child: Column(
        children: <Widget>[
          Text(label, style: AppTypography.label),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.number(16).copyWith(
              color: highlight ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Objective text and progress.
class _ObjectiveBar extends StatelessWidget {
  const _ObjectiveBar({required this.state});

  final GameSessionState state;

  @override
  Widget build(BuildContext context) {
    final level = state.level;
    if (level == null) {
      return Text(
        AppStrings.tr('objective_in_progress'),
        style: AppTypography.label,
      );
    }
    final progress = state.game.objectiveProgress.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          Text(
            AppStrings.tr(
              level.objective.localizationKey,
              <String, Object?>{'target': level.objective.target},
            ),
            style: AppTypography.bodyStrong,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilderCore(
              value: (progress * 100).round(),
              builder: (value) => LinearProgressIndicator(
                value: value / 100,
                minHeight: 8,
                backgroundColor: AppColors.surfaceDim,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The booster toolbar.
class _BoosterBar extends StatelessWidget {
  const _BoosterBar({required this.state, required this.cubit});

  final GameSessionState state;
  final GameSessionCubit cubit;

  static const List<({String id, String label, IconData icon})> _slots =
      <({String id, String label, IconData icon})>[
    (id: 'undo', label: 'Undo', icon: Icons.undo_rounded),
    (id: 'hammer', label: 'Hammer', icon: Icons.hardware_rounded),
    (id: 'shuffle', label: 'Shuffle', icon: Icons.shuffle_rounded),
    (id: 'wildcard', label: 'Wild', icon: Icons.auto_awesome_rounded),
    (id: 'upgrade', label: 'Upgrade', icon: Icons.arrow_circle_up_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final allowed = state.level?.allowedBoosters;
    final visible = _slots
        .where((slot) => allowed == null || allowed.contains(slot.id))
        .toList();

    return Column(
      children: <Widget>[
        if (state.activeBoosterId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              AppStrings.tr('booster_select_block'),
              style: AppTypography.label.copyWith(color: AppColors.primary),
            ),
          ),
        if (state.messageKey != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              AppStrings.tr(state.messageKey!),
              style: AppTypography.caption.copyWith(color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: visible.map((slot) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: BoosterButton(
                label: slot.label,
                icon: slot.icon,
                count: cubit.inventoryOf(slot.id),
                selected: state.activeBoosterId == slot.id,
                enabled: cubit.inventoryOf(slot.id) > 0,
                onTap: () {
                  if (state.activeBoosterId == slot.id) {
                    cubit.disarmBooster();
                  } else {
                    cubit.armBooster(slot.id);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Result dialog shown when a session ends.
class ResultOverlay extends StatelessWidget {
  const ResultOverlay({
    required this.won,
    required this.score,
    required this.stars,
    required this.bestScore,
    required this.objectiveText,
    required this.isDaily,
    required this.onNext,
    required this.onRetry,
    required this.onMenu,
    required this.onRewarded,
    super.key,
  });

  final bool won;
  final int score;
  final int stars;
  final int bestScore;
  final String objectiveText;
  final bool isDaily;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  final VoidCallback onRewarded;

  @override
  Widget build(BuildContext context) {
    return GameDialog(
      title: won
          ? AppStrings.tr('result_level_complete')
          : AppStrings.tr('result_level_failed'),
      dismissible: false,
      actions: <Widget>[
        if (won && !isDaily)
          PrimaryButton(label: AppStrings.tr('result_next'), onPressed: onNext),
        if (won && isDaily)
          PrimaryButton(label: AppStrings.tr('daily_completed'), onPressed: onMenu),
        if (!won) ...<Widget>[
          PrimaryButton(
            label: AppStrings.tr('result_retry'),
            onPressed: onRetry,
          ),
          GameButton(
            label: AppStrings.tr('result_continue_ad'),
            variant: GameButtonVariant.secondary,
            onPressed: onRewarded,
          ),
        ],
        GameButton(
          label: AppStrings.tr('result_menu'),
          variant: GameButtonVariant.ghost,
          onPressed: onMenu,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StarRating(stars: stars, size: 44),
          const SizedBox(height: AppSpacing.lg),
          ScoreDisplay(score: score, label: AppStrings.tr('result_score')),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${AppStrings.tr('result_best')}: $bestScore',
            style: AppTypography.label,
          ),
          if (!won) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(objectiveText, style: AppTypography.caption),
          ],
        ],
      ),
    );
  }
}
