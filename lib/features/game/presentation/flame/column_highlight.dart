import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../../../../app/theme/app_colors.dart';

/// Translucent overlay showing which column the player is aiming at.
class ColumnHighlight extends PositionComponent {
  ColumnHighlight({required this.cellSize, required this.rows})
      : super(size: Vector2(cellSize.x, cellSize.y * rows), anchor: Anchor.topLeft);

  final Vector2 cellSize;
  final int rows;

  /// `0..1` - fades in and out with the aim.
  double opacity = 0;

  bool get visible => opacity > 0.01;

  @override
  void render(ui.Canvas canvas) {
    if (!visible) return;
    final paint = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset.zero,
        ui.Offset(0, size.y),
        <ui.Color>[
          AppColors.columnFeedback.withValues(alpha: 0.30 * opacity),
          AppColors.columnFeedback.withValues(alpha: 0.02 * opacity),
        ],
        const <double>[0, 1],
      );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(size.toRect(), ui.Radius.circular(cellSize.x * 0.22)),
      paint,
    );
  }
}
