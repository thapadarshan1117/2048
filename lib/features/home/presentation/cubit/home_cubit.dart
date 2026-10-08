import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../app/localization/app_strings.dart';
import '../../../levels/data/level_repository.dart';
import '../../../progression/data/progress_repository.dart';
import '../../../progression/domain/daily_reward_state.dart';

/// Everything the home screen needs to draw itself.
class HomeState extends Equatable {
  const HomeState({
    this.progress = ProgressSnapshot.empty,
    this.totalLevels = 0,
    this.dailyRewardCoins = 0,
    this.hasResumableGame = false,
    this.currentObjectiveText = '',
  });

  final ProgressSnapshot progress;

  /// Levels in the shipped catalogue.
  final int totalLevels;

  /// Coins the daily ladder will pay on the next claim (0 when not claimable).
  final int dailyRewardCoins;

  /// `true` when a saved game can be continued.
  final bool hasResumableGame;

  /// Localised text of the objective on the next unplayed level.
  final String currentObjectiveText;

  int get currentLevel => progress.progress.currentLevel;

  int get starsEarned => progress.progress.starsEarned;

  int get coins => progress.coins;

  bool get dailyRewardReady => dailyRewardCoins > 0;

  @override
  List<Object?> get props => <Object?>[
        progress,
        totalLevels,
        dailyRewardCoins,
        hasResumableGame,
        currentObjectiveText,
      ];
}

/// Loads the summary the home screen shows.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required ProgressRepository progressRepository,
    required LevelRepository levelRepository,
    required this.todayKey,
  })  : _progressRepository = progressRepository,
        _levelRepository = levelRepository,
        super(const HomeState());

  final ProgressRepository _progressRepository;
  final LevelRepository _levelRepository;

  /// `YYYY-MM-DD` for the local calendar day.
  final String todayKey;

  Future<void> load({bool resumable = false}) async {
    final progress = _progressRepository.read();
    final daily = progress.dailyReward;
    final canClaim = daily.canClaim(todayKey);
    final nextDay = daily.lastClaimKey == null ? 1 : daily.streakDay + 1;

    emit(HomeState(
      progress: progress,
      totalLevels: _levelRepository.count,
      dailyRewardCoins:
          canClaim ? DailyRewardState.rewardFor(nextDay.clamp(1, 7)) : 0,
      hasResumableGame: resumable,
      currentObjectiveText: _objectiveText(progress),
    ));
  }

  String _objectiveText(ProgressSnapshot progress) {
    final level = _levelRepository.levelById(progress.progress.currentLevel);
    if (level == null) return '';
    return AppStrings.tr(
      level.objective.localizationKey,
      <String, Object?>{'target': level.objective.target},
    );
  }
}

/// Formats a `DateTime` as the canonical `YYYY-MM-DD` daily key.
String formatDailyKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
