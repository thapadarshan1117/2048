import 'package:equatable/equatable.dart';

import 'player_progress.dart';

/// What an achievement measures.
enum MilestoneMetric {
  highestBlock,
  highestScore,
  levelsCompleted,
  starsEarned,
  infiniteBestScore,
  dailyChallengesCompleted,
  totalMerges;

  String get analyticsName => name;
}

/// A single achievement.
///
/// Achievements are data, so new ones can be added without touching the
/// statistics screen.
class Milestone extends Equatable {
  const Milestone({
    required this.id,
    required this.metric,
    required this.target,
    required this.nameKey,
    required this.coinReward,
  });

  final String id;
  final MilestoneMetric metric;
  final int target;

  /// Localisation key of the achievement name.
  final String nameKey;

  /// Coins paid the first time the milestone is reached.
  final int coinReward;

  bool isReached(PlayerProgress progress, MilestoneStats stats) =>
      currentValue(progress, stats) >= target;

  int currentValue(PlayerProgress progress, MilestoneStats stats) {
    return switch (metric) {
      MilestoneMetric.highestBlock => stats.highestBlock,
      MilestoneMetric.highestScore => stats.highestScore,
      MilestoneMetric.levelsCompleted => progress.levelsCompleted,
      MilestoneMetric.starsEarned => progress.starsEarned,
      MilestoneMetric.infiniteBestScore => stats.infiniteBestScore,
      MilestoneMetric.dailyChallengesCompleted => stats.dailyChallengesCompleted,
      MilestoneMetric.totalMerges => stats.totalMerges,
    };
  }

  double progressRatio(PlayerProgress progress, MilestoneStats stats) {
    if (target <= 0) return 1;
    return (currentValue(progress, stats) / target).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'metric': metric.name,
        'target': target,
        'nameKey': nameKey,
        'coins': coinReward,
      };

  @override
  List<Object?> get props => <Object?>[id, metric, target, coinReward];
}

/// Lifetime statistics the achievements read from.
class MilestoneStats extends Equatable {
  const MilestoneStats({
    this.highestBlock = 0,
    this.highestScore = 0,
    this.infiniteBestScore = 0,
    this.dailyChallengesCompleted = 0,
    this.totalMerges = 0,
  });

  final int highestBlock;
  final int highestScore;
  final int infiniteBestScore;
  final int dailyChallengesCompleted;
  final int totalMerges;

  static const MilestoneStats empty = MilestoneStats();

  MilestoneStats copyWith({
    int? highestBlock,
    int? highestScore,
    int? infiniteBestScore,
    int? dailyChallengesCompleted,
    int? totalMerges,
  }) {
    return MilestoneStats(
      highestBlock: highestBlock ?? this.highestBlock,
      highestScore: highestScore ?? this.highestScore,
      infiniteBestScore: infiniteBestScore ?? this.infiniteBestScore,
      dailyChallengesCompleted:
          dailyChallengesCompleted ?? this.dailyChallengesCompleted,
      totalMerges: totalMerges ?? this.totalMerges,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'highestBlock': highestBlock,
        'highestScore': highestScore,
        'infiniteBest': infiniteBestScore,
        'dailyDone': dailyChallengesCompleted,
        'merges': totalMerges,
      };

  static MilestoneStats fromJson(Map<String, dynamic> json) => MilestoneStats(
        highestBlock: (json['highestBlock'] as num? ?? 0).toInt(),
        highestScore: (json['highestScore'] as num? ?? 0).toInt(),
        infiniteBestScore: (json['infiniteBest'] as num? ?? 0).toInt(),
        dailyChallengesCompleted: (json['dailyDone'] as num? ?? 0).toInt(),
        totalMerges: (json['merges'] as num? ?? 0).toInt(),
      );

  @override
  List<Object?> get props => <Object?>[
        highestBlock,
        highestScore,
        infiniteBestScore,
        dailyChallengesCompleted,
        totalMerges,
      ];
}

/// The shipped achievement list.
abstract final class MilestoneCatalogue {
  const MilestoneCatalogue._();

  static const List<Milestone> all = <Milestone>[
    Milestone(
      id: 'first_merge',
      metric: MilestoneMetric.totalMerges,
      target: 1,
      nameKey: 'milestone_first_merge',
      coinReward: 10,
    ),
    Milestone(
      id: 'reach_128',
      metric: MilestoneMetric.highestBlock,
      target: 128,
      nameKey: 'milestone_reach_128',
      coinReward: 25,
    ),
    Milestone(
      id: 'reach_512',
      metric: MilestoneMetric.highestBlock,
      target: 512,
      nameKey: 'milestone_reach_512',
      coinReward: 60,
    ),
    Milestone(
      id: 'reach_2048',
      metric: MilestoneMetric.highestBlock,
      target: 2048,
      nameKey: 'milestone_reach_2048',
      coinReward: 150,
    ),
    Milestone(
      id: 'reach_4096',
      metric: MilestoneMetric.highestBlock,
      target: 4096,
      nameKey: 'milestone_reach_4096',
      coinReward: 300,
    ),
    Milestone(
      id: 'complete_10_levels',
      metric: MilestoneMetric.levelsCompleted,
      target: 10,
      nameKey: 'milestone_complete_10_levels',
      coinReward: 40,
    ),
    Milestone(
      id: 'complete_50_levels',
      metric: MilestoneMetric.levelsCompleted,
      target: 50,
      nameKey: 'milestone_complete_50_levels',
      coinReward: 120,
    ),
    Milestone(
      id: 'complete_100_levels',
      metric: MilestoneMetric.levelsCompleted,
      target: 100,
      nameKey: 'milestone_complete_100_levels',
      coinReward: 250,
    ),
    Milestone(
      id: 'earn_100_stars',
      metric: MilestoneMetric.starsEarned,
      target: 100,
      nameKey: 'milestone_earn_100_stars',
      coinReward: 100,
    ),
    Milestone(
      id: 'earn_500_stars',
      metric: MilestoneMetric.starsEarned,
      target: 500,
      nameKey: 'milestone_earn_500_stars',
      coinReward: 400,
    ),
    Milestone(
      id: 'infinite_10000',
      metric: MilestoneMetric.infiniteBestScore,
      target: 10000,
      nameKey: 'milestone_infinite_10000',
      coinReward: 80,
    ),
    Milestone(
      id: 'daily_7',
      metric: MilestoneMetric.dailyChallengesCompleted,
      target: 7,
      nameKey: 'milestone_daily_7',
      coinReward: 90,
    ),
  ];
}
