import 'package:equatable/equatable.dart';

import '../../../levels/domain/level.dart';
import '../../domain/game_state.dart';
import '../../domain/game_mode.dart';
import '../../domain/merge_event.dart';

/// What the player is currently allowed to do.
enum GameSessionStatus { playing, paused, won, lost }

/// The state of an in-progress session, as the UI and the renderer see it.
///
/// This is the *only* thing the presentation layer reads. The authoritative
/// board lives in [GameState]; nothing here can change it.
class GameSessionState extends Equatable {
  const GameSessionState({
    required this.game,
    this.level,
    this.status = GameSessionStatus.playing,
    this.selectedColumn,
    this.selectedBlockId,
    this.activeBoosterId,
    this.inventory = const <String, int>{},
    this.coins = 0,
    this.lastTransitions = const <BoardTransition>[],
    this.transitionId = 0,
    this.messageKey,
    this.lastDropRejected = false,
  });

  /// The immutable domain state.
  final GameState game;

  /// Level being played, or `null` in infinite / daily mode.
  final Level? level;

  final GameSessionStatus status;

  /// Column the player is aiming at (tap or drag).
  final int? selectedColumn;

  /// Block the player has targeted with a booster.
  final int? selectedBlockId;

  /// Booster currently in targeting mode, if any.
  final String? activeBoosterId;

  /// Owned booster counts.
  final Map<String, int> inventory;

  final int coins;

  /// Transitions the renderer should animate.
  ///
  /// The Flame layer replays these; it never derives its own board from them.
  final List<BoardTransition> lastTransitions;

  /// Increments on every drop so the renderer can tell a new transition from a
  /// rebuilt one.
  final int transitionId;

  /// Localisation key of a transient message ("column full", "no undo left").
  final String? messageKey;

  /// `true` when the last drop was refused, used for a short shake on the
  /// targeted column.
  final bool lastDropRejected;

  bool get isPlaying => status == GameSessionStatus.playing;

  bool get isBusy => status == GameSessionStatus.paused ||
      status == GameSessionStatus.won ||
      status == GameSessionStatus.lost;

  GameSessionState copyWith({
    GameState? game,
    Level? level,
    bool clearLevel = false,
    GameSessionStatus? status,
    int? selectedColumn,
    bool clearColumn = false,
    int? selectedBlockId,
    bool clearBlock = false,
    String? activeBoosterId,
    bool clearBooster = false,
    Map<String, int>? inventory,
    int? coins,
    List<BoardTransition>? lastTransitions,
    int? transitionId,
    String? messageKey,
    bool clearMessage = false,
    bool? lastDropRejected,
  }) {
    return GameSessionState(
      game: game ?? this.game,
      level: clearLevel ? null : (level ?? this.level),
      status: status ?? this.status,
      selectedColumn: clearColumn ? null : (selectedColumn ?? this.selectedColumn),
      selectedBlockId:
          clearBlock ? null : (selectedBlockId ?? this.selectedBlockId),
      activeBoosterId:
          clearBooster ? null : (activeBoosterId ?? this.activeBoosterId),
      inventory: inventory ?? this.inventory,
      coins: coins ?? this.coins,
      lastTransitions: lastTransitions ?? this.lastTransitions,
      transitionId: transitionId ?? this.transitionId,
      messageKey: clearMessage ? null : (messageKey ?? this.messageKey),
      lastDropRejected: lastDropRejected ?? this.lastDropRejected,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        game,
        level,
        status,
        selectedColumn,
        selectedBlockId,
        activeBoosterId,
        inventory,
        coins,
        transitionId,
        messageKey,
        lastDropRejected,
      ];
}
