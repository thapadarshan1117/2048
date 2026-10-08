import 'package:bloc/bloc.dart';

import '../../data/progress_repository.dart';
import '../../domain/milestone_tracker.dart';
import 'progression_state.dart';

/// Owns the lifetime-progress snapshot the profile screen shows.
///
/// A running [GameSessionCubit] keeps its own copy of the same snapshot and
/// writes through the same [ProgressRepository]. This cubit is what every
/// *non-session* screen reads, and it reloads when such a screen is entered, so
/// the two can never disagree on screen.
class ProgressionCubit extends Cubit<ProgressionState> {
  ProgressionCubit({required ProgressRepository progressRepository})
      : _progressRepository = progressRepository,
        super(const ProgressionState.empty());

  final ProgressRepository _progressRepository;

  /// Reads the persisted snapshot. Called from `initState` of every screen that
  /// shows lifetime progress.
  void load() {
    final snapshot = _progressRepository.read();
    emit(ProgressionState(
      progress: snapshot.progress,
      stats: snapshot.stats,
      claimedMilestones: snapshot.claimedMilestones,
      loaded: true,
    ));
  }

  /// Pays any milestone that is reached but not yet claimed, returning the coins
  /// granted.
  ///
  /// Milestones are normally paid by [GameSessionCubit] when a run ends; this
  /// covers the ones reached outside a session.
  int claimPendingMilestones() {
    final pending = state.pendingMilestones;
    if (pending.isEmpty) return 0;

    final snapshot = _progressRepository.read();
    final coins = MilestoneTracker.coinsFor(pending);
    _progressRepository.write(snapshot
        .copyWithClaimedMilestones(
          <String>{...snapshot.claimedMilestones, ...pending.map((m) => m.id)},
        )
        .copyWithCoins(snapshot.coins + coins));
    load();
    return coins;
  }
}
