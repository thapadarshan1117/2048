import 'package:flame/game.dart';
import 'package:flame/components.dart';

import '../cubit/game_session_state.dart';
import 'board_component.dart';

/// The Flame game that renders the playfield.
///
/// It owns no game state: [BoardComponent] mirrors whatever
/// [GameSessionCubit] last emitted, and every input event is forwarded to the
/// cubit as an intent. This is what keeps the domain testable without Flame.
class MergeGame extends FlameGame {
  MergeGame({
    required this.state,
    required this.onColumnSelected,
    required this.onColumnCommitted,
    required this.onBlockTapped,
  });

  /// Current session state. The hosting widget keeps this in sync.
  GameSessionState state;

  final void Function(int column) onColumnSelected;
  final void Function(int column) onColumnCommitted;
  final void Function(int blockId) onBlockTapped;

  late final BoardComponent _board;

  @override
  Future<void> onLoad() async {
    _board = BoardComponent(
      state: state,
      onColumnSelected: onColumnSelected,
      onColumnCommitted: onColumnCommitted,
      onBlockTapped: onBlockTapped,
    );
    await add(_board);
  }

  @override
  void update(double dt) {
    // The board reads the live state object, which the hosting widget mutates
    // in place before calling `updateTree`. Mutating in place (rather than
    // rebuilding the component) keeps the block identity map stable, which is
    // what lets the animation layer follow a block across a merge.
    _board.state = state;
    super.update(dt);
  }

  /// Called by the hosting widget when the session state changes.
  void pushState(GameSessionState next) {
    state = next;
  }

  /// Exposed for the debug overlay.
  int get renderedBlockCount => _board.children.length;
}
