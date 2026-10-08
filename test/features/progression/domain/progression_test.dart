import 'package:flutter_test/flutter_test.dart';
import 'package:merge_drop/features/progression/domain/daily_reward_state.dart';
import 'package:merge_drop/features/progression/domain/level_progress.dart';
import 'package:merge_drop/features/progression/domain/milestone.dart';
import 'package:merge_drop/features/progression/domain/player_progress.dart';
import 'package:merge_drop/core/utils/daily_seed.dart';

void main() {
  group('LevelProgress', () {
    test('stars and best score are monotonic', () {
      const progress = LevelProgress(stars: 2, bestScore: 300, completed: true);
      final worse = progress.applyRun(stars: 1, score: 100, completed: false);
      expect(worse.stars, 2);
      expect(worse.bestScore, 300);
      expect(worse.completed, isTrue);
      expect(worse.attempts, 1);

      final better = progress.applyRun(stars: 3, score: 900, completed: true);
      expect(better.stars, 3);
      expect(better.bestScore, 900);
      expect(better.attempts, 1);
    });

    test('round-trips through JSON', () {
      const progress = LevelProgress(stars: 3, bestScore: 1234, completed: true, attempts: 4);
      expect(LevelProgress.fromJson(progress.toJson()), progress);
    });
  });

  group('PlayerProgress', () {
    test('starts locked to level 1', () {
      const progress = PlayerProgress.empty;
      expect(progress.currentLevel, 1);
      expect(progress.highestUnlockedLevel, 1);
      expect(progress.isUnlocked(1), isTrue);
      expect(progress.isUnlocked(2), isFalse);
    });

    test('completing a level unlocks the next one', () {
      final progress = PlayerProgress.empty.applyRun(
        levelId: 1,
        stars: 2,
        score: 400,
        completed: true,
      );
      expect(progress.currentLevel, 2);
      expect(progress.highestUnlockedLevel, 2);
      expect(progress.isUnlocked(2), isTrue);
      expect(progress.levelsCompleted, 1);
      expect(progress.starsEarned, 2);
    });

    test('failing a level does not unlock the next one', () {
      final progress = PlayerProgress.empty.applyRun(
        levelId: 1,
        stars: 1,
        score: 50,
        completed: false,
      );
      expect(progress.currentLevel, 1);
      expect(progress.highestUnlockedLevel, 1);
      expect(progress.isUnlocked(2), isFalse);
    });

    test('replaying a level never lowers the best result', () {
      var progress = PlayerProgress.empty.applyRun(
        levelId: 1,
        stars: 3,
        score: 900,
        completed: true,
      );
      progress = progress.applyRun(
        levelId: 1,
        stars: 1,
        score: 100,
        completed: true,
      );
      expect(progress.progressFor(1).stars, 3);
      expect(progress.progressFor(1).bestScore, 900);
      expect(progress.progressFor(1).attempts, 2);
    });

    test('unlock never lowers the unlocked level', () {
      const progress = PlayerProgress(highestUnlockedLevel: 20, currentLevel: 21);
      expect(progress.unlock(5).highestUnlockedLevel, 20);
      expect(progress.unlock(40).highestUnlockedLevel, 40);
    });

    test('round-trips through JSON', () {
      final progress = PlayerProgress.empty
          .applyRun(levelId: 1, stars: 2, score: 400, completed: true)
          .applyRun(levelId: 2, stars: 1, score: 120, completed: true);
      final restored = PlayerProgress.fromJson(progress.toJson());
      expect(restored.currentLevel, progress.currentLevel);
      expect(restored.highestUnlockedLevel, progress.highestUnlockedLevel);
      expect(restored.progressFor(2).bestScore, 400 - 280);
      expect(restored.starsEarned, progress.starsEarned);
    });

    test('a corrupt payload falls back to level 1 rather than throwing', () {
      final restored = PlayerProgress.fromJson(<String, dynamic>{
        'levels': 'not a map',
        'currentLevel': 'nope',
      });
      expect(restored.currentLevel, greaterThanOrEqualTo(1));
      expect(restored.highestUnlockedLevel, greaterThanOrEqualTo(1));
    });
  });

  group('DailyRewardState', () {
    test('day 1 pays 20 coins and the ladder climbs to day 7', () {
      expect(DailyRewardState.rewardFor(1), 20);
      expect(DailyRewardState.rewardFor(2), 30);
      expect(DailyRewardState.rewardFor(7), 200);
      expect(DailyRewardState.rewardFor(7),
          greaterThan(DailyRewardState.rewardFor(6)));
    });

    test('a first claim is always available', () {
      const state = DailyRewardState.empty;
      expect(state.canClaim('2026-10-08'), isTrue);
      final claimed = state.claim('2026-10-08');
      expect(claimed.streakDay, 1);
      expect(claimed.canClaim('2026-10-08'), isFalse);
    });

    test('the streak survives one skipped day', () {
      var state = DailyRewardState.empty.claim('2026-10-01');
      expect(state.streakDay, 1);
      state = state.tick('2026-10-03');
      expect(state.streakDay, 1, reason: 'one grace day keeps the rung');
      expect(state.canClaim('2026-10-03'), isTrue);
    });

    test('two skipped days reset the ladder', () {
      var state = DailyRewardState.empty
          .claim('2026-10-01')
          .claim('2026-10-02')
          .claim('2026-10-03');
      expect(state.streakDay, 3);
      state = state.tick('2026-10-07');
      expect(state.streakDay, 0);
      expect(state.canClaim('2026-10-07'), isTrue);
    });

    test('the ladder wraps back to day 1 after day 7', () {
      var state = const DailyRewardState.empty;
      for (var day = 1; day <= 8; day++) {
        state = state.claim('2026-10-${day.toString().padLeft(2, '0')}');
      }
      expect(state.streakDay, 1);
    });

    test('round-trips through JSON', () {
      const state = DailyRewardState(lastClaimKey: '2026-10-08', streakDay: 3);
      expect(DailyRewardState.fromJson(state.toJson()), state);
    });
  });

  group('Milestones', () {
    test('every milestone has a unique id and a reward', () {
      final ids = MilestoneCatalogue.all.map((m) => m.id).toSet();
      expect(ids.length, MilestoneCatalogue.all.length);
      for (final milestone in MilestoneCatalogue.all) {
        expect(milestone.target, greaterThan(0));
        expect(milestone.coinReward, greaterThan(0));
        expect(milestone.nameKey.startsWith('milestone_'), isTrue);
      }
    });

    test('progress is derived from the right metric', () {
      const mergeCount = Milestone(
        id: 'test_merges',
        metric: MilestoneMetric.totalMerges,
        target: 10,
        nameKey: 'milestone_first_merge',
        coinReward: 10,
      );
      const progress = PlayerProgress(highestUnlockedLevel: 5);
      const none = MilestoneStats.empty;
      expect(mergeCount.currentValue(progress, none), 0);
      expect(mergeCount.isReached(progress, none), isFalse);

      const some = MilestoneStats(totalMerges: 5);
      expect(mergeCount.currentValue(progress, some), 5);
      expect(mergeCount.progressRatio(progress, some), 0.5);

      const enough = MilestoneStats(totalMerges: 25);
      expect(mergeCount.isReached(progress, enough), isTrue);
      expect(mergeCount.progressRatio(progress, enough), 1.0);
    });

    test('level-count milestones read the progress object', () {
      const milestone = Milestone(
        id: 'test_levels',
        metric: MilestoneMetric.levelsCompleted,
        target: 3,
        nameKey: 'milestone_complete_10_levels',
        coinReward: 10,
      );
      var progress = PlayerProgress.empty;
      for (var id = 1; id <= 2; id++) {
        progress = progress.applyRun(
          levelId: id,
          stars: 1,
          score: 10,
          completed: true,
        );
      }
      expect(milestone.isReached(progress, MilestoneStats.empty), isFalse);
      progress = progress.applyRun(
        levelId: 3,
        stars: 1,
        score: 10,
        completed: true,
      );
      expect(milestone.isReached(progress, MilestoneStats.empty), isTrue);
    });

    test('stats round-trip through JSON', () {
      const stats = MilestoneStats(
        highestBlock: 512,
        highestScore: 9000,
        infiniteBestScore: 12000,
        dailyChallengesCompleted: 4,
        totalMerges: 250,
      );
      expect(MilestoneStats.fromJson(stats.toJson()), stats);
    });
  });

  group('MilestoneTracker', () {
    const tracker = MilestoneTracker();

    test('reports only milestones that have not been claimed', () {
      const progress = PlayerProgress(highestUnlockedLevel: 3);
      const stats = MilestoneStats(totalMerges: 40);
      final all = tracker.newlyReached(progress, stats, const <String>{});
      expect(all.map((m) => m.id), contains('first_merge'));

      final afterClaim = tracker.newlyReached(
        progress,
        stats,
        <String>{'first_merge'},
      );
      expect(afterClaim.map((m) => m.id), isNot(contains('first_merge')));
    });

    test('coins are summed across the newly reached set', () {
      const reached = <Milestone>[
        Milestone(
          id: 'a',
          metric: MilestoneMetric.totalMerges,
          target: 1,
          nameKey: 'milestone_first_merge',
          coinReward: 10,
        ),
        Milestone(
          id: 'b',
          metric: MilestoneMetric.totalMerges,
          target: 2,
          nameKey: 'milestone_reach_128',
          coinReward: 25,
        ),
      ];
      expect(MilestoneTracker.coinsFor(reached), 35);
      expect(MilestoneTracker.coinsFor(const <Milestone>[]), 0);
    });

    test('a fresh player has no milestones', () {
      expect(
        tracker.newlyReached(
          PlayerProgress.empty,
          MilestoneStats.empty,
          const <String>{},
        ),
        isEmpty,
      );
    });
  });

  group('DailySeed', () {
    test('the same date always produces the same key and seed', () {
      final a = DateTime.utc(2026, 10, 8, 3, 14);
      final b = DateTime.utc(2026, 10, 8, 22, 59);
      expect(DailySeed.keyFor(a), '2026-10-08');
      expect(DailySeed.keyFor(b), '2026-10-08');
      expect(DailySeed.seedForDate(a), DailySeed.seedForDate(b));
    });

    test('different dates produce different seeds', () {
      final seeds = <int>{};
      for (var day = 1; day <= 60; day++) {
        seeds.add(DailySeed.seedForDate(DateTime.utc(2026, 1, day)));
      }
      expect(seeds.length, 60, reason: 'daily seeds must be unique per day');
    });

    test('fnv1a32 matches the reference vectors', () {
      // FNV-1a 32-bit of the empty string is the offset basis.
      expect(DailySeed.fnv1a32(''), 0x811C9DC5);
      // "a" is the canonical published test vector.
      expect(DailySeed.fnv1a32('a'), 0xE40C292C);
    });
  });
}
