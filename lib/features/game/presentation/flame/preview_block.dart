import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/block_state.dart';

/// The moving "next block" preview.
///
/// It slides horizontally with the player's aim and bobs gently, so the next
/// drop is always legible while the player is still deciding.
class PreviewBlock extends PositionComponent {
  PreviewBlock({
    required this.value,
    required Vector2 cellSize,
    required Vector2 slotSize,
    required int columns,
    this.column = 2,
  })  : _cellSize = cellSize.clone(),
        _slotSize = slotSize.clone(),
        _columns = columns,
        super(size: slotSize.clone(), anchor: Anchor.center);

  int value;
  int column;

  final Vector2 _cellSize;
  final Vector2 _slotSize;
  final int _columns;

  double _bob = 0;

  /// `0..1` - dimmed while a booster is armed.
  double opacity = 1;

  /// Horizontal target position, computed by the board component.
  double targetX = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _bob += dt * 3.4;
    final target = _slotCenter(column);
    position.x += (target.x - position.x) * math.min(1, dt * 14);
    position.y = target.y + math.sin(_bob) * 3;
  }

  Vector2 _slotCenter(int c) {
    final step = _slotSize.x;
    final left = -(_slotSize.x * _columns) / 2 + step / 2;
    return Vector2(left + c * step, 0);
  }

  void setColumn(int c) {
    if (c < 0 || c >= _columns) return;
    column = c;
  }

  @override
  void render(ui.Canvas canvas) {
    if (opacity <= 0.01) return;
    final scale = math.min(_cellSize.x, _cellSize.y) / math.max(_slotSize.x, _slotSize.y);
    final drawSize = _slotSize * (0.72 + 0.05 * math.sin(_bob * 1.3));
    final colors = AppColors.blockGradient(value);
    final rect = drawSize.toRect()
      ..translate(-drawSize.x / 2, -drawSize.y / 2);
    final radius = math.min(drawSize.x, drawSize.y) * 0.22;
    final scaleFactor = scale.clamp(0.5, 1.4);

    canvas.save();
    canvas.scale(scaleFactor);
    if (opacity < 1) canvas.scale(1, 1);

    final shadow = ui.Paint()
      ..color = const ui.Color(0x55000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(radius)),
      shadow,
    );

    final body = ui.Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        colors,
        const <double>[0, 0.55, 1],
      );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(radius)),
      body,
    );

    final gloss = ui.Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        ui.Offset(rect.center.dx, rect.top + rect.height * 0.45),
        const <ui.Color>[ui.Color(0x55FFFFFF), ui.Color(0x00FFFFFF)],
        const <double>[0, 1],
      );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.5),
        ui.Radius.circular(radius),
      ),
      gloss,
    );

    final painter = ui.TextPainter(
      text: ui.TextSpan(
        text: '$value',
        style: ui.TextStyle(
          fontSize: math.min(drawSize.x, drawSize.y) * 0.34,
          fontWeight: ui.FontWeight.w800,
          color: const ui.Color(0xFF1A1030),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      ui.Offset(-painter.width / 2, -painter.height / 2),
    );

    canvas.restore();
  }
}
