import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/block_state.dart';
import '../../domain/merge_event.dart';
import '../cubit/game_session_state.dart';
import 'block_component.dart';
import 'board_layout.dart';
import 'column_highlight.dart';
import 'particle_burst.dart';
import 'preview_block.dart';

/// Renders the board and plays back the transitions produced by the domain.
///
/// This component is a pure mirror: it never decides anything. Every frame it
/// reconciles itself against [GameSessionState.game], and the transitions tell
/// it *how* the board changed so it can animate instead of snapping.
class BoardComponent extends PositionComponent {
  BoardComponent({
    required this.state,
    required this.onColumnSelected,
    required this.onColumnCommitted,
    required this.onBlockTapped,
  });

  /// Latest session state; replaced by the game before every update.
  GameSessionState state;

  /// Called while the player drags.
  final void Function(int column) onColumnSelected;

  /// Called when the player lifts their finger.
  final void Function(int column) onColumnCommitted;

  /// Called when a block is tapped while a booster is armed.
  final void Function(int blockId) onBlockTapped;

  final Map<int, BlockComponent> _blocks = <int, BlockComponent>{};
  final List<BlockComponent> _fading = <BlockComponent>[];

  BoardLayout? _layout;
  Vector2? _layoutSize;

  /// Geometry for the current size. Recomputed whenever the component is
  /// resized, so the board stays correct on rotation and on window resize.
  BoardLayout get layout {
    if (_layout == null || _layoutSize != size) {
      _layout = BoardLayout.compute(size, _rows, _columns);
      _layoutSize = size.clone();
    }
    return _layout!;
  }

  ColumnHighlight? _highlight;
  PreviewBlock? _preview;

  List<BoardTransition> _pending = <BoardTransition>[];
  int _appliedTransitionId = -1;
  double _stepTimer = 0;

  static const double _stepDuration = 0.085;

  double _shake = 0;
  double _shakeTime = 0;

  int get _rows => state.game.board.rows;

  int get _columns => state.game.board.columns;

  @override
  Future<void> onLoad() async {
    _highlight = ColumnHighlight(
      cellSize: layout.cellSize,
      rows: _rows,
    );
    await add(_highlight!);

    _preview = PreviewBlock(
      value: state.game.nextBlockValue,
      cellSize: layout.cellSize,
      slotSize: Vector2(layout.cellSize.x, layout.cellSize.y),
      columns: _columns,
      column: 2,
    );
    _preview!.position =
        Vector2(layout.boardSize.x / 2, -layout.cellSize.y * 0.9);
    await add(_preview!);

    _reconcile();
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    if (newSize.x <= 0 || newSize.y <= 0) return;
    size = newSize;
    // Invalidate the geometry and the effects that were positioned with the old
    // one; both are rebuilt on the next frame from the new layout.
    _layout = null;
    _layoutSize = null;
    _highlight?.removeFromParent();
    _preview?.removeFromParent();
    _highlight = null;
    _preview = null;
    _repositionBlocks();
  }

  /// Snaps every block to its cell in the new layout.
  void _repositionBlocks() {
    for (final component in _blocks.values) {
      component.targetPosition = null;
      component.position =
          layout.cellPosition(component.block.row, component.block.column);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncFromState();
    _advancePlayback(dt);
    _updateShake(dt);
  }

  /// Pulls new work out of the session state.
  void _syncFromState() {
    final next = state;

    // The column highlight and preview are rebuilt after a resize; creating
    // them lazily here keeps them alive for the whole session.
    if (_highlight == null) {
      _highlight = ColumnHighlight(
        cellSize: layout.cellSize,
        rows: _rows,
      );
      add(_highlight!);
    }
    if (_preview == null) {
      _preview = PreviewBlock(
        value: next.game.nextBlockValue,
        cellSize: layout.cellSize,
        slotSize: Vector2(layout.cellSize.x, layout.cellSize.y),
        columns: _columns,
        column: next.selectedColumn ?? 2,
      );
      _preview!.position =
          Vector2(layout.boardSize.x / 2, -layout.cellSize.y * 0.9);
      add(_preview!);
    }

    if (_appliedTransitionId != next.transitionId) {
      _appliedTransitionId = next.transitionId;
      _pending = List<BoardTransition>.from(next.lastTransitions);
    }

    final highlight = _highlight;
    if (highlight != null) {
      final column = next.selectedColumn;
      if (column == null) {
        highlight.opacity = 0;
      } else {
        highlight.opacity = 1;
        highlight.position = layout.cellPosition(0, column);
      }
    }

    final preview = _preview;
    if (preview != null) {
      preview.value = next.game.nextBlockValue;
      preview.setColumn(next.selectedColumn ?? 2);
      preview.opacity = next.activeBoosterId != null ? 0.35 : 1;
    }
  }

  void _advancePlayback(double dt) {
    if (_stepTimer > 0) {
      _stepTimer -= dt;
      if (_stepTimer > 0) return;
    }
    if (_pending.isEmpty) {
      _reconcile();
      return;
    }

    final transition = _pending.removeAt(0);
    _applyTransition(transition);
    _stepTimer = _stepDuration;
  }

  void _applyTransition(BoardTransition transition) {
    for (final move in transition.moves) {
      final component = _blocks[move.blockId];
      if (component == null) continue;
      component.targetPosition = layout.cellPosition(move.toRow, move.toColumn);
    }

    for (final merge in transition.merges) {
      for (final sourceId in merge.sourceBlockIds) {
        final source = _blocks.remove(sourceId);
        if (source != null) {
          source.playFade();
          _fading.add(source);
        }
      }

      final target = _blocks[merge.targetBlockId];
      if (target != null) {
        target.block = BlockState(
          id: merge.targetBlockId,
          value: merge.newValue,
          row: merge.row,
          column: merge.column,
        );
        target.position = layout.cellPosition(merge.row, merge.column);
        target.targetPosition = target.position.clone();
        target.playPunch();
      }

      final center = layout.cellCenter(merge.row, merge.column);
      if (merge.scoreGained > 0) {
        _addEffect(ScorePopup(
          position: center.clone(),
          text: '+${merge.scoreGained}',
          color: AppColors.blockColor(merge.newValue),
        ));
      }
      _addEffect(MergeBurst(
        position: center.clone(),
        value: merge.newValue,
        cellSize: layout.cellSize.x,
      ));

      if (merge.newValue >= 128 || merge.chainStep >= 2) {
        _shake = math.min(1, _shake + 0.35 + merge.chainStep * 0.08);
        _shakeTime = 0;
      }
    }
  }

  /// Creates or destroys components until the visual board matches the domain.
  void _reconcile() {
    final board = state.game.board;
    final live = <int>{};

    for (final block in board.blocks) {
      live.add(block.id);
      final existing = _blocks[block.id];
      if (existing == null) {
        final component = BlockComponent(
          block: block,
          cellSize: layout.cellSize,
        );
        component.position = layout.cellPosition(block.row, block.column);
        component.targetPosition = component.position.clone();
        _blocks[block.id] = component;
        add(component);
        component.playSpawn();
      } else if (existing.block != block) {
        existing.block = block;
        existing.targetPosition = layout.cellPosition(block.row, block.column);
      } else if (existing.targetPosition == null) {
        existing.targetPosition = layout.cellPosition(block.row, block.column);
      }
    }

    // Anything not on the board any more is either mid-merge (already fading)
    // or stale: remove it so the renderer never shows a phantom block.
    final stale = _blocks.keys.where((id) => !live.contains(id)).toList();
    for (final id in stale) {
      final component = _blocks.remove(id);
      if (component != null) {
        component.playFade();
        _fading.add(component);
      }
    }
  }

  void _addEffect(Component effect) {
    if (children.length > 240) return;
    add(effect);
  }

  void _updateShake(double dt) {
    if (_shake <= 0) return;
    _shakeTime += dt;
    _shake = math.max(0, _shake - dt * 3.4);
    final magnitude = _shake * 6;
    position = Vector2(
      math.sin(_shakeTime * 47) * magnitude,
      math.cos(_shakeTime * 61) * magnitude,
    );
  }

  // -------------------------------------------------------------------- input

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final column = layout.columnAt(event.canvasPosition.x);
    if (column != null) onColumnSelected(column);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    final column =
        layout.columnAt(event.canvasPosition.x) ?? state.selectedColumn;
    if (column != null) onColumnCommitted(column);
  }

  @override
  void onTapDown(TapDownEvent event) {
    final column = layout.columnAt(event.canvasPosition.x);
    if (column == null) return;

    if (state.activeBoosterId != null) {
      final block = _blockAt(event.canvasPosition);
      if (block != null) onBlockTapped(block.id);
      return;
    }
    onColumnSelected(column);
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (state.activeBoosterId != null) return;
    final column = layout.columnAt(event.canvasPosition.x);
    if (column != null) onColumnCommitted(column);
  }

  BlockComponent? _blockAt(Vector2 point) {
    for (final component in _blocks.values) {
      final left = component.position.x;
      final top = component.position.y;
      final rect = ui.Rect.fromLTWH(
        left,
        top,
        component.size.x,
        component.size.y,
      );
      if (rect.contains(point.toOffset())) return component;
    }
    return null;
  }

  @override
  void render(ui.Canvas canvas) {
    // Board backdrop.
    final backdrop = ui.Paint()..color = AppColors.boardBackground;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        size.toRect(),
        ui.Radius.circular(math.min(size.x, size.y) * 0.04),
      ),
      backdrop,
    );

    // Cell wells.
    final well = ui.Paint()..color = AppColors.cellBackground;
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _columns; c++) {
        final cell = layout.cellPosition(r, c);
        final rect = ui.Rect.fromLTWH(
          cell.x,
          cell.y,
          layout.cellSize.x,
          layout.cellSize.y,
        );
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            rect,
            ui.Radius.circular(layout.cellSize.x * 0.22),
          ),
          well,
        );
      }
    }

    super.render(canvas);
  }

  @override
  void onRemove() {
    for (final component in _fading) {
      component.removeFromParent();
    }
    _fading.clear();
    _blocks.clear();
    super.onRemove();
  }
}

/// Local conversion helpers so the component does not need vector_math
/// extensions under confusing names.
extension on Vector2 {
  ui.Rect toRect() =>
      ui.Rect.fromLTWH(x, y, this.toRect().width, this.toRect().height);

  ui.Offset toOffset() => ui.Offset(x, y);
}
