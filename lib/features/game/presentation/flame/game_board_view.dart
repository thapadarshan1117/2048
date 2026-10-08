import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../cubit/game_session_state.dart';
import 'merge_game.dart';

/// Embeds [MergeGame] in the widget tree.
///
/// The widget is intentionally dumb: it builds the game once, then feeds it new
/// state on every rebuild. All gameplay decisions live in the cubit.
class GameBoardView extends StatefulWidget {
  const GameBoardView({
    required this.state,
    required this.onColumnSelected,
    required this.onColumnCommitted,
    required this.onBlockTapped,
    super.key,
  });

  final GameSessionState state;
  final void Function(int column) onColumnSelected;
  final void Function(int column) onColumnCommitted;
  final void Function(int blockId) onBlockTapped;

  @override
  State<GameBoardView> createState() => _GameBoardViewState();
}

class _GameBoardViewState extends State<GameBoardView> {
  late final MergeGame _game = MergeGame(
    state: widget.state,
    onColumnSelected: widget.onColumnSelected,
    onColumnCommitted: widget.onColumnCommitted,
    onBlockTapped: widget.onBlockTapped,
  );

  @override
  void didUpdateWidget(GameBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _game.pushState(widget.state);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        child: GameWidget(game: _game),
      ),
    );
  }
}
