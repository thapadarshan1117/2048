import 'package:equatable/equatable.dart';

/// State of the daily-reward ladder.
///
/// ```text
/// Day 1 -> 20 coins
/// Day 2 -> 30
/// ...
/// Day 7 -> large reward
/// ```
///
/// Missed days are handled by a configurable rule: by default a single missed
/// day keeps the streak (people are busy), two or more reset it to day 1.
class DailyRewardState extends Equatable {
  const DailyRewardState({
    this.lastClaimKey,
    this.streakDay = 0,
    this.graceDaysUsed = 0,
  });

  /// `YYYY-MM-DD` of the last claim, or `null` when never claimed.
  final String? lastClaimKey;

  /// Which rung of the ladder the next claim will pay out (1-7).
  final int streakDay;

  /// Consecutive days the player has been allowed to skip without losing the
  /// streak. Reset whenever a claim happens on time.
  final int graceDaysUsed;

  static const DailyRewardState empty = DailyRewardState();

  /// Ladder length before it wraps back to day 1.
  static const int ladderLength = 7;

  /// Coins paid by rung [day] (1-based).
  static int rewardFor(int day) {
    if (day <= 0) return 20;
    if (day >= ladderLength) return 200;
    return 20 + (day - 1) * 30;
  }

  /// Missed days tolerated before the streak resets.
  static const int maxGraceDays = 1;

  /// Rung the next claim will pay out (1-based), wrapping back to day 1 once
  /// the ladder is complete.
  ///
  /// Every caller must go through this rather than doing `streakDay + 1`
  /// itself: without the wrap, a player sitting on rung 7 would be shown a
  /// 200-coin reward and then paid the 20-coin rung-one reward.
  int get nextRung => streakDay >= ladderLength ? 1 : streakDay + 1;

  /// Coins the next claim will pay out.
  int get nextReward => rewardFor(nextRung);

  bool canClaim(String todayKey) {
    if (lastClaimKey == null) return true;
    if (lastClaimKey == todayKey) return false;
    final gap = _daysBetween(lastClaimKey!, todayKey);
    return gap >= 1 && gap <= maxGraceDays + 1;
  }

  /// Records a claim made on [todayKey].
  DailyRewardState claim(String todayKey) {
    final nextDay = streakDay >= ladderLength ? 1 : streakDay + 1;
    return DailyRewardState(
      lastClaimKey: todayKey,
      streakDay: nextDay,
      graceDaysUsed: 0,
    );
  }

  /// Applies the grace/reset rule for a day that was skipped.
  DailyRewardState tick(String todayKey) {
    if (lastClaimKey == null) return this;
    final gap = _daysBetween(lastClaimKey!, todayKey);
    if (gap <= 0) return this;
    if (gap > maxGraceDays + 1) {
      return const DailyRewardState();
    }
    return DailyRewardState(
      lastClaimKey: lastClaimKey,
      streakDay: streakDay,
      graceDaysUsed: graceDaysUsed + (gap - 1),
    );
  }

  static int _daysBetween(String fromKey, String toKey) {
    final from = DateTime.tryParse(fromKey);
    final to = DateTime.tryParse(toKey);
    if (from == null || to == null) return 0;
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lastClaim': lastClaimKey,
        'streakDay': streakDay,
        'grace': graceDaysUsed,
      };

  static DailyRewardState fromJson(Map<String, dynamic> json) => DailyRewardState(
        lastClaimKey: json['lastClaim'] as String?,
        streakDay: (json['streakDay'] as num? ?? 0).toInt().clamp(0, 7),
        graceDaysUsed: (json['grace'] as num? ?? 0).toInt(),
      );

  @override
  List<Object?> get props => <Object?>[lastClaimKey, streakDay, graceDaysUsed];
}
