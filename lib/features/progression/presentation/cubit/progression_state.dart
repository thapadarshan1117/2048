import 'package:equatable/equatable.dart';

import '../../data/progress_repository.dart';
import '../../domain/milestone.dart';
import '../../domain/milestone_tracker.dart';
import '../../domain/player_progress.dart';

/// Everything the profile screen renders.
class ProgressionState extends Equatable {
  const ProgressionState({
    this.progress = PlayerProgress.empty,
    this.stats = MilestoneStats.empty,
    this.claimedMilestones = const <String>{},
    this.loaded = false,
  });

  static const ProgressionState empty = ProgressionState();

  final PlayerProgress progress;
  final MilestoneStats stats;

  /// Milestone ids whose coin reward has already been paid.
  final Set<String> claimedMilestones;

  /// `false` until the first read from storage has completed.
  final bool loaded;

  /// Milestones the player has reached but not yet been paid for.
  ///
  /// Paying them is [GameSessionCubit]'s job when a run finishes, so this list
  /// is normally empty; it exists so a milestone reached outside a session (a
  /// daily challenge, an endless run) is never silently lost.
  List<Milestone> get pendingMilestones => MilestoneTracker.newlyReached(
        progress,
        stats,
        claimedMilestones,
      );

  ProgressionState copyWith({
    PlayerProgress? progress,
    MilestoneStats? stats,
    Set<String>? claimedMilestones,
    bool? loaded,
  }) {
    return ProgressionState(
      progress: progress ?? this.progress,
      stats: stats ?? this.stats,
      claimedMilestones: claimedMilestones ?? this.claimedMilestones,
      loaded: loaded ?? this.loaded,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[progress, stats, claimedMilestones, loaded];
}
