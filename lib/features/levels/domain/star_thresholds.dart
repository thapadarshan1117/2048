/// Star thresholds for a level.
///
/// ```text
/// 1 star  level completed
/// 2 stars score >= twoStarScore
/// 3 stars score >= threeStarScore
/// ```
///
/// The player's *best* result is always kept, so levels can be replayed to
/// improve a star rating.
class StarThresholds {
  const StarThresholds({
    required this.twoStarScore,
    required this.threeStarScore,
  });

  const StarThresholds.trivial()
      : twoStarScore = 0,
        threeStarScore = 0;

  final int twoStarScore;
  final int threeStarScore;

  /// Stars earned for [score]. A level is never worth zero stars once the
  /// objectives are met - callers only ask for stars on success.
  int starsFor(int score) {
    if (score >= threeStarScore && threeStarScore > 0) return 3;
    if (score >= twoStarScore && twoStarScore > 0) return 2;
    return 1;
  }

  /// Progress towards the next star in `0..1`, used by the result screen bar.
  double progressToNextStar(int score, int currentStars) {
    if (currentStars >= 3) return 1;
    final goal = currentStars >= 2 ? threeStarScore : twoStarScore;
    if (goal <= 0) return 1;
    return (score / goal).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'twoStar': twoStarScore,
        'threeStar': threeStarScore,
      };

  factory StarThresholds.fromJson(Map<String, dynamic> json) => StarThresholds(
        twoStarScore: (json['twoStar'] as num? ?? 0).toInt(),
        threeStarScore: (json['threeStar'] as num? ?? 0).toInt(),
      );
}
