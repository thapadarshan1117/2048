import 'package:flutter_test/flutter_test.dart';
import 'package:merge_drop/features/daily_challenge/data/daily_challenge_repository.dart';
import 'package:merge_drop/features/game/data/game_save_repository.dart';
import 'package:merge_drop/features/game/domain/game_board.dart';
import 'package:merge_drop/features/game/domain/game_engine.dart';
import 'package:merge_drop/features/game/domain/game_mode.dart';
import 'package:merge_drop/features/game/presentation/cubit/game_session_cubit.dart';
import 'package:merge_drop/features/game/presentation/cubit/game_session_state.dart';
import 'package:merge_drop/features/levels/domain/difficulty_profile.dart';
import 'package:merge_drop/features/progression/data/progress_repository.dart';
import 'package:merge_drop/features/settings/data/settings_repository.dart';
import 'package:merge_drop/features/settings/domain/app_settings.dart';
import 'package:merge_drop/core/services/ads_service.dart';
import 'package:merge_drop/core/services/analytics_service.dart';
import 'package:merge_drop/core/services/audio_service.dart';
import 'package:merge_drop/core/services/haptics_service.dart';
import 'package:merge_drop/features/levels/domain/level.dart';
import 'package:merge_drop/features/levels/domain/level_objective.dart';
import 'package:merge_drop/features/levels/domain/star_thresholds.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory doubles so the cubit can be tested without a device.
class _FakeSaveRepository implements GameSaveRepository {
  GameSnapshot? active;
  Map<String, int> inventory = const <String, int>{};

  @override
  GameSnapshot? readActive() => active;

  @override
  Future<void> writeActive(GameSnapshot snapshot) async => active = snapshot;

  @override
  Future<void> clearActive() async => active = null;

  @override
  Map<String, int> readInventory() => inventory;

  @override
  Future<void> writeInventory(Map<String, int> value) async => inventory = value;
}

const DifficultyProfile _profile = DifficultyProfile();

Level _level({int id = 1, int? moveLimit}) => Level(
      id: id,
      chapter: 1,
      objective: LevelObjective.reachScore(50),
      moveLimit: moveLimit,
      initialBlocks: const <BlockSpawn>[],
      allowedBoosters: const <String>['undo', 'hammer', 'shuffle'],
      difficulty: _profile,
      stars: const StarThresholds(twoStarScore: 50, threeStarScore: 150),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameSessionCubit', () {
    late _FakeSaveRepository saveRepository;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      saveRepository = _FakeSaveRepository();
    });

    GameSessionCubit _cubit({Level? level}) {
      final engine = GameEngine.start(
        board: GameBoard.empty(rows: 12, columns: 6),
        profile: level?.difficulty ?? _profile,
        level: level,
      );
      return GameSessionCubit(
        engine: engine,
        progressRepository: _NoopProgressRepository(),
        saveRepository: saveRepository,
        dailyRepository: _NoopDailyRepository(),
        settingsRepository: _NoopSettingsRepository(),
        audio: _NoopAudio(),
        haptics: _NoopHaptics(),
        analytics: _NoopAnalytics(),
        ads: _NoopAds(),
      );
    }

    test('starts a level in the playing state', () {
      final cubit = _cubit();
      cubit.startLevel(_level());
      expect(cubit.state.status, GameSessionStatus.playing);
      expect(cubit.state.level?.id, 1);
      expect(cubit.state.game.board.blockCount, 0);
      expect(cubit.state.game.mode, GameMode.level);
    });

    test('a drop moves a block onto the board and bumps the revision', () {
      final cubit = _cubit();
      cubit.startLevel(_level());
      final before = cubit.state.transitionId;
      cubit.drop(2);
      expect(cubit.state.game.board.blockCount, 1);
      expect(cubit.state.transitionId, greaterThan(before));
      expect(cubit.state.lastTransitions, isNotEmpty);
    });

    test('selecting a column then dropping uses the aimed column', () {
      final cubit = _cubit();
      cubit.startLevel(_level());
      cubit.selectColumn(4);
      expect(cubit.state.selectedColumn, 4);
      cubit.drop(4);
      expect(cubit.state.game.board.cells[11][4], isNotNull);
      expect(cubit.state.selectedColumn, isNull,
          reason: 'the aim clears once the drop is committed');
    });

    test('a full column is refused and reported', () {
      final cubit = _cubit();
      cubit.startLevel(_level());
      for (var i = 0; i < 12; i++) {
        cubit.drop(0);
      }
      expect(cubit.state.game.board.isCompletelyFull, isFalse);
      final before = cubit.state.game;
      cubit.drop(0);
      expect(cubit.state.lastDropRejected, isTrue);
      expect(cubit.state.messageKey, 'drop_error_column_full');
      expect(cubit.state.game.board, before.board);
    });

    test('an out-of-range column is ignored', () {
      final cubit = _cubit();
      cubit.startLevel(_level());
      cubit.selectColumn(99);
      expect(cubit.state.selectedColumn, isNull);
      cubit.drop(-3);
      expect(cubit.state.game.board.blockCount, 0);
    });

    test('pause blocks input until the session is resumed', () {
      final cubit = _cubit();
      cubit.startLevel(_level());
      cubit.pause();
      expect(cubit.state.status, GameSessionStatus.paused);
      cubit.drop(1);
      expect(cubit.state.game.board.blockCount, 0);
      cubit.resumeSession();
      expect(cubit.state.status, GameSessionStatus.playing);
      cubit.drop(1);
      expect(cubit.state.game.board.blockCount, 1);
    });

    test('restart clears the board', () {
      final cubit = _cubit();
      cubit.startLevel(_level());
      cubit.drop(0);
      cubit.drop(1);
      expect(cubit.state.game.board.blockCount, 2);
      cubit.restart();
      expect(cubit.state.game.board.blockCount, 0);
      expect(cubit.state.game.score, 0);
      expect(cubit.state.status, GameSessionStatus.playing);
    });

    test('infinite mode starts with no level', () {
      final cubit = _cubit();
      cubit.startInfinite();
      expect(cubit.state.level, isNull);
      expect(cubit.state.game.mode, GameMode.infinite);
      expect(cubit.state.game.board.rows, 12);
    });

    test('a level that disallows a booster refuses to arm it', () {
      final cubit = _cubit();
      cubit.startLevel(_level());
      cubit.armBooster('wildcard');
      expect(cubit.state.activeBoosterId, isNull);
      expect(cubit.state.messageKey, 'booster_reject_not_allowed');
    });

    test('undo walks the session back to the previous board', () {
      final cubit = _cubit();
      cubit.startLevel(_level());
      cubit.drop(0);
      expect(cubit.state.game.board.blockCount, 1);
      cubit.armBooster('undo');
      expect(cubit.state.activeBoosterId, 'undo');
      cubit.useBooster('undo');
      expect(cubit.state.game.board.blockCount, 0);
      expect(cubit.state.inventory['undo'], 2,
          reason: 'one of the three starting charges was spent');
    });

    test('the hammer removes the targeted block', () {
      final cubit = _cubit();
      cubit.startLevel(_level());
      cubit.drop(3);
      final target = cubit.state.game.board.cells[11][3]!;
      cubit.armBooster('hammer');
      cubit.selectBlock(target.id);
      expect(cubit.state.selectedBlockId, target.id);
      cubit.useBooster('hammer');
      expect(cubit.state.game.board.blockById(target.id), isNull);
      expect(cubit.state.inventory['hammer'], 0);
    });

    test('a move limit is enforced by the engine', () {
      final cubit = _cubit();
      cubit.startLevel(_level(moveLimit: 2));
      cubit.drop(0);
      cubit.drop(1);
      expect(cubit.state.game.remainingMoves, 0);
    });

    test('filling the board ends the session as a loss', () {
      final cubit = _cubit();
      cubit.startLevel(_level());
      for (var column = 0; column < 6; column++) {
        for (var i = 0; i < 12; i++) {
          cubit.drop(column);
        }
      }
      expect(cubit.state.game.isGameOver, isTrue);
      expect(cubit.state.status, GameSessionStatus.lost);
    });

    test('exit clears the saved game', () {
      final cubit = _cubit();
      cubit.startLevel(_level());
      cubit.drop(0);
      cubit.exit();
      expect(saveRepository.active, isNull);
    });
  });
}

class _NoopProgressRepository implements ProgressRepository {
  @override
  ProgressSnapshot read() => ProgressSnapshot.empty;

  @override
  Future<void> write(ProgressSnapshot snapshot) async {}

  @override
  Future<void> reset() async {}
}

class _NoopDailyRepository implements DailyChallengeRepository {
  @override
  DailyAttempt? attemptFor(String key) => null;

  @override
  Future<void> recordAttempt(DailyAttempt attempt) async {}

  @override
  int completedCount() => 0;
}

class _NoopSettingsRepository implements SettingsRepository {
  @override
  AppSettings read() => AppSettings.defaults;

  @override
  Future<void> write(AppSettings settings) async {}

  @override
  Future<void> reset() async {}
}

class _NoopAudio implements AudioService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> play(SoundEffect effect) async {}

  @override
  Future<void> playMusic(MusicTrack track) async {}

  @override
  Future<void> stopMusic() async {}

  @override
  void setSoundEnabled(bool enabled) {}

  @override
  void setMusicEnabled(bool enabled) {}

  @override
  Future<void> dispose() async {}
}

class _NoopHaptics implements HapticsService {
  @override
  void setEnabled(bool enabled) {}

  @override
  void trigger(HapticKind kind) {}
}

class _NoopAnalytics implements AnalyticsService {
  @override
  Future<void> initialize() async {}

  @override
  void logEvent(String name, [Map<String, Object>? parameters]) {}

  @override
  void setUserProperty(String name, String? value) {}

  @override
  void logScreenView(String screenName) {}

  @override
  Future<void> dispose() async {}
}

class _NoopAds implements AdsService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> preloadInterstitial() async {}

  @override
  Future<void> maybeShowInterstitial({required int completedLevels}) async {}

  @override
  Future<RewardAdResult> showRewarded({required RewardKind kind}) async =>
      RewardAdResult.notAvailable;

  @override
  void setAdsRemoved(bool removed) {}

  @override
  Future<void> dispose() async {}
}
