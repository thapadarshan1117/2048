/// Centralised score rules.
///
/// Every point in the game is awarded here - UI widgets, Flame components and
/// boosters must never compute score themselves.
///
/// ```text
/// merge 2  -> 4    +4
/// merge 4  -> 8    +8
/// merge 8  -> 16   +16
/// ```
///
/// Chain reactions (multiple merge waves produced by a single drop) apply a
/// growing combo multiplier so that long cascades feel rewarding.
class ScoreCalculator {
  const ScoreCalculator._();

  /// Chain step at which the combo multiplier stops growing.
  static const int maxComboStep = 9;

  /// Base reward for producing [newValue] with no combo.
  static int mergeScore({required int newValue, int chainStep = 0}) {
    if (newValue <= 0) return 0;
    final step = chainStep.clamp(0, maxComboStep);
    return (newValue * comboMultiplier(step)).round();
  }

  /// `1.0` for a plain merge, `1.5` for the second wave of a chain, etc.
  static double comboMultiplier(int chainStep) {
    final step = chainStep.clamp(0, maxComboStep);
    return 1.0 + 0.5 * step;
  }

  /// Reward for a very large merge, layered on top of the merge score so big
  /// numbers feel meaningfully better without breaking the doubling rhythm.
  static int bigMergeBonus(int newValue) {
    if (newValue >= 2048) return 2048;
    if (newValue >= 1024) return 1024;
    if (newValue >= 512) return 512;
    if (newValue >= 256) return 256;
    if (newValue >= 128) return 128;
    return 0;
  }

  /// Score awarded for surviving a drop without merging - deliberately 0 so
  /// that score always reflects real progress.
  static const int dropScore = 0;

  /// Coins awarded for completing a level, before star bonuses.
  static int levelCompletionCoins({required int stars}) {
    return switch (stars) {
      3 => 30,
      2 => 20,
      1 => 10,
      _ => 0,
    };
  }

  /// Extra coins for each star beyond the first.
  static int starBonusCoins({required int stars}) => (stars - 1).clamp(0, 2) * 15;

  /// Coins granted by the daily reward ladder.
  static int dailyRewardCoins({required int day}) {
    if (day <= 0) return 20;
    if (day >= 7) return 200;
    return 20 + (day - 1) * 30;
  }
}
