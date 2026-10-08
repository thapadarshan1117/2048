import 'milestone.dart';
import 'player_progress.dart';

/// Detects achievements that have just been reached.
///
/// Kept separate from the repository so the "which milestones are new?" question
/// is a pure function that can be unit-tested, and so the caller decides when to
/// pay out (rather than paying twice for the same milestone).
abstract final class MilestoneTracker {
  const MilestoneTracker._();

  /// Milestones reached by [progress] + [stats] whose reward has not yet been
  /// claimed.
  static List<Milestone> newlyReached(
    PlayerProgress progress,
    MilestoneStats stats,
    Set<String> claimed,
  ) {
    return MilestoneCatalogue.all
        .where((milestone) => !claimed.contains(milestone.id))
        .where((milestone) => milestone.isReached(progress, stats))
        .toList();
  }

  /// Coins owed for [milestones].
  static int coinsFor(List<Milestone> milestones) =>
      milestones.fold<int>(0, (sum, m) => sum + m.coinReward);
}
