import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/game_constants.dart';
import '../../../../core/services/ads_service.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/utils/daily_seed.dart';
import '../../../daily_challenge/data/daily_challenge_repository.dart';
import '../../../daily_challenge/domain/daily_challenge.dart';
import '../../../levels/domain/level.dart';
import '../../../progression/data/progress_repository.dart';
import '../../../progression/domain/milestone_tracker.dart';
import '../../../settings/data/settings_repository.dart';
import '../../../settings/domain/app_settings.dart';
import '../../data/game_save_repository.dart';
import '../../domain/boosters/booster.dart';
import '../../domain/boosters/booster_registry.dart';
import '../../domain/boosters/undo_booster.dart';
import '../../domain/drop_result.dart';
import '../../domain/game_board.dart';
import '../../domain/game_engine.dart';
import '../../domain/game_mode.dart';
import '../../domain/game_snapshot.dart';
import '../../domain/game_state.dart';
import '../../domain/merge_event.dart';
import 'game_session_state.dart';

/// Owns one play session: input, boosters, persistence and progression.
///
/// The cubit is the *only* thing that calls the engine. Widgets and Flame
/// components send intents here and observe [GameSessionState]; neither of them
/// ever mutates the board directly.
class GameSessionCubit extends Cubit<GameSessionState> {
  GameSessionCubit({
    required GameEngine engine,
    required this.progressRepository,
    required this.saveRepository,
    required this.dailyRepository,
    required this.settingsRepository,
    required this.audio,
    required this.haptics,
    required this.analytics,
    required this.ads,
    ProgressSnapshot progress = ProgressSnapshot.empty,
    AppSettings settings = AppSettings.defaults,
  })  : _engine = engine,
        _progress = progress,
        _settings = settings,
        super(GameSessionState(game: engine.state));

  GameEngine _engine;
  final ProgressRepository progressRepository;
  final GameSaveRepository saveRepository;
  final DailyChallengeRepository dailyRepository;
  final SettingsRepository settingsRepository;
  final AudioService audio;
  final HapticsService haptics;
  final AnalyticsService analytics;
  final AdsService ads;

  ProgressSnapshot _progress;
  AppSettings _settings;
  Timer? _autoSaveTimer;
  bool _closed = false;

  /// Coins paid by the most recently completed level, so a rewarded
  /// "double coins" offer can double the amount the player actually earned.
  int _lastCoinsEarned = 0;

  ProgressSnapshot get progress => _progress;

  AppSettings get settings => _settings;

  // ---------------------------------------------------------------- lifecycle

  /// Builds the opening board for [level]: the level's pre-filled blocks on an
  /// otherwise empty grid of the standard size.
  GameBoard _boardForLevel(Level level) => GameEngine.initialBoardForLevel(
        level,
        GameConstants.defaultRows,
        GameConstants.defaultColumns,
      );

  /// Starts [level] from the beginning.
  void startLevel(Level level) {
    _autoSaveTimer?.cancel();
    _progress = _progress.copyWithProgress(_progress.progress.unlock(level.id));

    final engine = GameEngine.start(
      board: _boardForLevel(level),
      profile: level.difficulty,
      level: level,
      mode: GameMode.level,
    );
    _engine = engine;

    emit(state.copyWith(
      game: engine.state,
      level: level,
      clearLevel: false,
      status: GameSessionStatus.playing,
      clearColumn: true,
      clearBlock: true,
      clearBooster: true,
      clearMessage: true,
      lastDropRejected: false,
      lastTransitions: const <BoardTransition>[],
      transitionId: state.transitionId + 1,
    ));

    analytics.logEvent(AnalyticsEvents.levelStarted, <String, Object>{
      'level': level.id,
      'chapter': level.chapter,
      'mode': 'level',
      'objective': level.objective.type.name,
      'move_limit': level.effectiveMoveLimit,
    });
    if (level.isCurated) {
      analytics.logEvent(
        AnalyticsEvents.tutorialStarted,
        <String, Object>{'step': level.tutorialStepKey ?? 'none'},
      );
    }

    _scheduleAutoSave();
  }

  /// Continues a persisted session.
  void resume(GameSnapshot snapshot, Level? level) {
    _autoSaveTimer?.cancel();
    final engine = GameEngine.restore(
      core: snapshot.core,
      profile: level?.difficulty ?? const DifficultyProfile(),
      level: level,
      mode: snapshot.mode,
      undoHistory: snapshot.undo
          .map((core) => GameStateFromCore.core(
                core,
                level: level,
                mode: snapshot.mode,
              ))
          .toList(),
    );
    _engine = engine;
    emit(state.copyWith(
      game: engine.state,
      level: level,
      clearLevel: false,
      status: GameSessionStatus.playing,
      clearColumn: true,
      clearBlock: true,
      clearBooster: true,
      clearMessage: true,
      lastTransitions: const <BoardTransition>[],
      transitionId: state.transitionId + 1,
    ));
    _scheduleAutoSave();
  }

  /// Starts endless mode.
  void startInfinite() {
    _autoSaveTimer?.cancel();
    final engine = GameEngine.start(
      board: GameBoard.empty(
        rows: GameConstants.defaultRows,
        columns: GameConstants.defaultColumns,
      ),
      profile: const DifficultyProfile(),
      mode: GameMode.infinite,
    );
    _engine = engine;
    emit(state.copyWith(
      game: engine.state,
      clearLevel: true,
      status: GameSessionStatus.playing,
      clearColumn: true,
      clearBlock: true,
      clearBooster: true,
      clearMessage: true,
      lastDropRejected: false,
      lastTransitions: const <BoardTransition>[],
      transitionId: state.transitionId + 1,
    ));
    analytics.logEvent(AnalyticsEvents.infiniteStarted);
    _scheduleAutoSave();
  }

  /// Starts the deterministic daily challenge.
  void startDaily(DailyChallenge challenge) {
    _autoSaveTimer?.cancel();
    final level = challenge.level;
    final engine = GameEngine.start(
      board: _boardForLevel(level),
      profile: level.difficulty,
      seed: challenge.seed,
      level: level,
      mode: GameMode.daily,
    );
    _engine = engine;
    emit(state.copyWith(
      game: engine.state,
      level: level,
      clearLevel: false,
      status: GameSessionStatus.playing,
      clearColumn: true,
      clearBlock: true,
      clearBooster: true,
      clearMessage: true,
      lastDropRejected: false,
      lastTransitions: const <BoardTransition>[],
      transitionId: state.transitionId + 1,
    ));
    analytics.logEvent(AnalyticsEvents.dailyChallengeStarted, <String, Object>{
      'date': challenge.key,
      'level': level.id,
    });
    _scheduleAutoSave();
  }

  /// Restarts the current session.
  void restart() {
    final level = state.level;
    if (level == null) {
      startInfinite();
      return;
    }
    analytics.logEvent(AnalyticsEvents.levelReplayed, <String, Object>{
      'level': level.id,
    });
    startLevel(level);
  }

  // ------------------------------------------------------------------- input

  /// Aims at [column]. Ignored while a booster is waiting for a block target.
  void selectColumn(int column) {
    if (state.isBusy) return;
    if (column < 0 || column >= state.game.board.columns) return;
    if (state.activeBoosterId != null) return;
    emit(state.copyWith(selectedColumn: column, clearMessage: true));
  }

  /// Clears the column aim.
  void clearColumn() => emit(state.copyWith(clearColumn: true));

  /// Targets a block for a booster that needs one.
  void selectBlock(int blockId) {
    if (state.activeBoosterId == null) return;
    emit(state.copyWith(selectedBlockId: blockId));
  }

  /// Enters targeting mode for [boosterId].
  void armBooster(String boosterId) {
    if (state.isBusy) return;
    final booster = BoosterRegistry.byId(boosterId);
    if (booster == null) return;
    if (state.level != null && !state.level!.allowsBooster(boosterId)) {
      emit(state.copyWith(messageKey: 'booster_reject_not_allowed'));
      return;
    }
    if (inventoryOf(boosterId) <= 0) {
      emit(state.copyWith(messageKey: 'booster_reject_none_left'));
      return;
    }
    if (!booster.canUse(_context())) {
      emit(state.copyWith(
        messageKey: booster is UndoBooster
            ? BoosterOutcome.rejectionNoUndo
            : BoosterOutcome.rejectionNoTarget,
      ));
      return;
    }
    emit(state.copyWith(
      activeBoosterId: boosterId,
      clearBlock: true,
      clearColumn: true,
      clearMessage: true,
    ));
    analytics.logEvent(AnalyticsEvents.boosterOpened, <String, Object>{
      'booster': boosterId,
      'level': state.level?.id ?? 0,
    });
  }

  /// Leaves targeting mode.
  void disarmBooster() => emit(
        state.copyWith(clearBooster: true, clearBlock: true, clearColumn: true),
      );

  /// Drops the queued block into [column].
  void drop(int column) {
    if (state.isBusy) return;
    if (!_engine.canDrop(column)) {
      emit(state.copyWith(
        lastDropRejected: true,
        messageKey: 'drop_error_column_full',
      ));
      return;
    }

    final previous = _engine.state;
    final outcome = _engine.drop(column);
    if (!outcome.accepted) {
      emit(state.copyWith(
        lastDropRejected: true,
        messageKey: outcome.rejection.messageKey,
      ));
      return;
    }

    _afterDrop(previous, outcome);
  }

  /// Applies [boosterId], consuming one charge.
  void useBooster(String boosterId) {
    if (state.isBusy) return;
    final booster = BoosterRegistry.byId(boosterId);
    if (booster == null) return;
    if (inventoryOf(boosterId) <= 0) {
      emit(state.copyWith(messageKey: 'booster_reject_none_left'));
      return;
    }

    final context = BoosterContext(
      state: _engine.state,
      selectedBlockId: state.selectedBlockId,
      selectedColumn: state.selectedColumn,
    );
    if (!booster.canUse(context)) {
      emit(state.copyWith(
        messageKey: booster is UndoBooster
            ? BoosterOutcome.rejectionNoUndo
            : BoosterOutcome.rejectionNoTarget,
      ));
      return;
    }

    final result = booster.apply(context);
    if (!result.applied) {
      emit(state.copyWith(messageKey: result.rejectionKey));
      return;
    }

    _engine.replaceState(result.state);
    _consumeBooster(boosterId);

    audio.play(SoundEffect.booster);
    haptics.trigger(HapticKind.booster);
    analytics.logEvent(AnalyticsEvents.boosterUsed, <String, Object>{
      'booster': boosterId,
      'level': state.level?.id ?? 0,
      'mode': result.state.mode.name,
    });

    final status = result.state.isGameOver
        ? (result.state.objectivesComplete
            ? GameSessionStatus.won
            : GameSessionStatus.lost)
        : GameSessionStatus.playing;

    emit(state.copyWith(
      game: result.state,
      status: status,
      inventory: _readInventory(),
      coins: _progress.coins,
      lastTransitions: result.transitions,
      transitionId: state.transitionId + 1,
      clearBooster: true,
      clearBlock: true,
      clearColumn: true,
      clearMessage: true,
      lastDropRejected: false,
    ));

    _scheduleAutoSave();
  }

  /// Buys one charge of [boosterId] with coins.
  void buyBooster(String boosterId) {
    final booster = BoosterRegistry.byId(boosterId);
    if (booster == null) return;
    if (_progress.coins < booster.price) {
      emit(state.copyWith(messageKey: 'shop_reject_not_enough_coins'));
      return;
    }
    _setCoins(_progress.coins - booster.price);
    final inventory = Map<String, int>.from(_progress.boosterInventory);
    inventory[boosterId] = (inventory[boosterId] ?? 0) + 1;
    _setInventory(inventory);
  }

  /// Pays out a completed rewarded ad.
  void grantReward(RewardKind kind) {
    switch (kind) {
      case RewardKind.continueGame:
        final revived = _engine.state.copyWith(isGameOver: false);
        _engine.replaceState(revived);
        emit(state.copyWith(game: revived, status: GameSessionStatus.playing));
      case RewardKind.doubleCoins:
        // Doubles what the level actually paid, not a fixed amount.
        _setCoins(_progress.coins + _lastCoinsEarned);
      case RewardKind.freeBooster:
        final inventory = Map<String, int>.from(_progress.boosterInventory);
        inventory['hammer'] = (inventory['hammer'] ?? 0) + 1;
        _setInventory(inventory);
      case RewardKind.extraMoves:
        break;
    }
    audio.play(SoundEffect.reward);
  }

  // -------------------------------------------------------- session controls

  /// Pauses and persists the session.
  void pause() {
    if (state.status != GameSessionStatus.playing) return;
    emit(state.copyWith(status: GameSessionStatus.paused, clearColumn: true));
    _persistActive();
  }

  /// Resumes a paused session.
  void resumeSession() {
    if (state.status != GameSessionStatus.paused) return;
    emit(state.copyWith(status: GameSessionStatus.playing));
  }

  /// Ends the session and clears the saved game.
  void exit() {
    _autoSaveTimer?.cancel();
    saveRepository.clearActive();
    emit(state.copyWith(status: GameSessionStatus.paused, clearColumn: true));
  }

  /// Clears the transient message.
  void dismissMessage() => emit(state.copyWith(clearMessage: true));

  /// Applies settings that affect playback.
  void applySettings(AppSettings settings) {
    _settings = settings;
    audio.setSoundEnabled(settings.soundEnabled);
    audio.setMusicEnabled(settings.musicEnabled);
    haptics.setEnabled(settings.vibrationEnabled);
    ads.setAdsRemoved(settings.removeAdsPurchased);
    unawaited(settingsRepository.write(settings));
    emit(state.copyWith());
  }

  int inventoryOf(String boosterId) => state.inventory[boosterId] ?? 0;

  // ---------------------------------------------------------------- internals

  void _afterDrop(GameState previous, DropOutcome outcome) {
    final next = outcome.state;
    final level = state.level;
    final bigMerge = outcome.mergeEvents
        .any((event) => event.newValue >= 128 || event.chainStep >= 2);

    if (outcome.hadMerges) {
      audio.play(bigMerge ? SoundEffect.bigMerge : SoundEffect.merge);
      haptics.trigger(bigMerge ? HapticKind.bigMerge : HapticKind.merge);
    } else {
      audio.play(SoundEffect.drop);
      haptics.trigger(HapticKind.drop);
    }

    analytics.logEvent(AnalyticsEvents.blockDropped, <String, Object>{
      'column': outcome.landingRow ?? -1,
      'value': previous.nextBlockValue,
      'level': level?.id ?? 0,
      'mode': next.mode.name,
    });

    if (outcome.hadMerges) {
      final biggest = outcome.mergeEvents
          .map((event) => event.newValue)
          .fold<int>(0, (max, value) => value > max ? value : max);
      final chain = outcome.mergeEvents.fold<int>(
        0,
        (max, event) => event.chainStep > max ? event.chainStep : max,
      );
      analytics.logEvent(AnalyticsEvents.blockMerged, <String, Object>{
        'value': biggest,
        'level': level?.id ?? 0,
        'mode': next.mode.name,
        'chain': chain,
      });
    }

    var status = GameSessionStatus.playing;
    if (next.objectivesComplete && level != null) {
      status = GameSessionStatus.won;
      if (level.isCurated) {
        analytics.logEvent(
          AnalyticsEvents.tutorialCompleted,
          <String, Object>{'step': level.tutorialStepKey ?? 'none'},
        );
      }
      _lastCoinsEarned = _coinsFor(next, level);
      _setCoins(_progress.coins + _lastCoinsEarned);
      _recordCompletion(level, next);
      audio.play(SoundEffect.levelComplete);
      haptics.trigger(HapticKind.levelComplete);
      analytics.logEvent(AnalyticsEvents.levelCompleted, <String, Object>{
        'level': level.id,
        'score': next.score,
        'stars': next.stars,
        'moves': next.movesUsed,
        'block_value': next.stats.highestValueCreated,
      });
      if (next.mode == GameMode.daily) {
        final key = DailySeed.keyFor(DateTime.now());
        unawaited(dailyRepository.recordAttempt(DailyAttempt(
          key: key,
          score: next.score,
          stars: next.stars,
          completed: true,
        )));
        analytics.logEvent(
          AnalyticsEvents.dailyChallengeCompleted,
          <String, Object>{
            'date': key,
            'score': next.score,
            'stars': next.stars,
          },
        );
      }
      if (AppConfig.adsEnabled &&
          level.id % GameConstants.interstitialEveryNLevels == 0) {
        unawaited(ads.maybeShowInterstitial(
          completedLevels: _progress.levelsCompleted,
        ));
      }
    } else if (next.isGameOver) {
      status = GameSessionStatus.lost;
      audio.play(SoundEffect.levelFailed);
      haptics.trigger(HapticKind.levelFailed);
      if (level != null) {
        analytics.logEvent(AnalyticsEvents.levelFailed, <String, Object>{
          'level': level.id,
          'score': next.score,
          'reason': 'board_full',
        });
      } else {
        analytics.logEvent(AnalyticsEvents.infiniteGameOver, <String, Object>{
          'score': next.score,
          'highest_block': next.stats.highestValueCreated,
          'moves': next.movesUsed,
        });
        _recordInfiniteBest(next.score);
      }
    }

    emit(state.copyWith(
      game: next,
      status: status,
      coins: _progress.coins,
      inventory: _readInventory(),
      lastTransitions: outcome.resolution?.transitions ?? const <BoardTransition>[],
      transitionId: state.transitionId + 1,
      clearColumn: true,
      clearBlock: true,
      clearBooster: true,
      clearMessage: true,
      lastDropRejected: false,
    ));

    _scheduleAutoSave();
  }

  int _coinsFor(GameState game, Level level) =>
      20 + level.id + game.stars * 15;

  void _recordCompletion(Level level, GameState game) {
    _progress = _progress.copyWithProgress(_progress.progress.applyRun(
      levelId: level.id,
      stars: game.stars,
      score: game.score,
      completed: true,
    ));
    _progress = _progress.copyWithStats(
      _progress.stats.copyWith(
        highestScore: game.score > _progress.stats.highestScore
            ? game.score
            : _progress.stats.highestScore,
        highestBlock: game.stats.highestValueCreated > _progress.stats.highestBlock
            ? game.stats.highestValueCreated
            : _progress.stats.highestBlock,
        totalMerges: _progress.stats.totalMerges + game.stats.mergeCount,
      ),
    );
    _writeProgress();
    saveRepository.clearActive();
    _payMilestones(level, game);
  }

  /// Pays any achievement the run just unlocked, exactly once.
  void _payMilestones(Level level, GameState game) {
    final reached = MilestoneTracker.newlyReached(
      _progress.progress,
      _progress.stats,
      _progress.claimedMilestones,
    );
    if (reached.isEmpty) return;

    final claimed = Set<String>.from(_progress.claimedMilestones)
      ..addAll(reached.map((m) => m.id));
    _progress = _progress.copyWithClaimedMilestones(claimed);
    _progress = _progress.copyWithCoins(
      _progress.coins + MilestoneTracker.coinsFor(reached),
    );
    _writeProgress();

    audio.play(SoundEffect.reward);
    for (final milestone in reached) {
      analytics.logEvent(
        AnalyticsEvents.milestoneReached,
        <String, Object>{'milestone_id': milestone.id, 'coins': milestone.coinReward},
      );
    }
    emit(state.copyWith(coins: _progress.coins));
  }

  void _setCoins(int value) {
    _progress = _progress.copyWithCoins(value);
    _writeProgress();
    emit(state.copyWith(coins: value));
  }

  void _setInventory(Map<String, int> value) {
    _progress = _progress.copyWithBoosterInventory(value);
    _writeProgress();
    emit(state.copyWith(inventory: _readInventory()));
  }

  void _recordInfiniteBest(int score) {
    if (score <= _progress.stats.infiniteBestScore) return;
    _progress = _progress.copyWithStats(
      _progress.stats.copyWith(infiniteBestScore: score),
    );
    _writeProgress();
  }

  void _writeProgress() => unawaited(progressRepository.write(_progress));

  Map<String, int> _readInventory() {
    final inventory = Map<String, int>.from(_progress.boosterInventory);
    for (final entry in GameConstants.startingBoosters.entries) {
      inventory.putIfAbsent(entry.key, () => entry.value);
    }
    return inventory;
  }

  void _consumeBooster(String boosterId) {
    final inventory = Map<String, int>.from(_progress.boosterInventory);
    final current = inventory[boosterId] ?? 0;
    if (current > 0) inventory[boosterId] = current - 1;
    _progress = _progress.copyWithBoosterInventory(inventory);
    _writeProgress();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(
      const Duration(seconds: GameConstants.autoSaveSeconds),
      _persistActive,
    );
  }

  void _persistActive() {
    if (_closed) return;
    if (state.status != GameSessionStatus.playing) return;
    if (state.game.isGameOver) return;
    unawaited(saveRepository.writeActive(GameSnapshot(
      version: GameSnapshot.currentVersion,
      mode: state.game.mode,
      levelId: state.level?.id,
      core: _engine.toCore(),
      undo: _engine.state.undoHistory.map(_coreOf).toList(),
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
    )));
  }

  static GameStateCoreOf _coreOf(GameState state) =>
      GameStateCoreOf.from(state);

  BoosterContext _context() => BoosterContext(
        state: _engine.state,
        selectedBlockId: state.selectedBlockId,
        selectedColumn: state.selectedColumn,
      );

  @override
  Future<void> close() {
    _closed = true;
    _autoSaveTimer?.cancel();
    return super.close();
  }
}

/// Rebuilds a live state from a persisted core.
abstract final class GameStateFromCore {
  const GameStateFromCore._();

  static GameState core(
    GameStateCore core, {
    Level? level,
    GameMode mode = GameMode.level,
  }) =>
      GameState.fromCore(core, level: level, mode: mode);
}

/// Serialises a live state into a persisted core.
abstract final class GameStateCoreOf {
  const GameStateCoreOf._();

  static GameStateCore from(GameState state) => GameStateCore(
        board: state.board,
        nextBlockId: state.nextBlockId,
        nextBlockValue: state.nextBlockValue,
        stats: state.stats,
        score: state.score,
        movesUsed: state.movesUsed,
        rngState: state.rngState,
      );
}
