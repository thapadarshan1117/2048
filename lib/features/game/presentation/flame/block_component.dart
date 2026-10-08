import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/block_state.dart';

/// The visual projection of one [BlockState].
///
/// Holds no gameplay data of its own: position is driven by the domain and the
/// component only owns transient animation state (spawn punch, merge scale).
/// Nothing here can change the rules.
class BlockComponent extends PositionComponent {
  BlockComponent({
    required this.block,
    required this.cellSize,
    this.onAnimationComplete,
  }) : super(size: cellSize.clone(), anchor: Anchor.topLeft);

  /// The block this component mirrors. Replaced (never mutated) on merge.
  BlockState block;

  final Vector2 cellSize;

  /// Called when a spawn animation finishes.
  final void Function(BlockComponent component)? onAnimationComplete;

  double _spawnT = 1;
  double _punchT = 0;
  double _fadeT = 1;

  /// Where the component is currently sliding to. `null` means "stay".
  Vector2? targetPosition;

  /// Opacity used by the preview-style fade-out (0..1).
  double opacity = 1;

  bool get isSpawning => _spawnT < 1;

  bool get isPunching => _punchT > 0;

  bool get isFading => _fadeT < 1;

  /// Plays the drop-in animation.
  void playSpawn() {
    _spawnT = 0;
    _fadeT = 1;
  }

  /// Plays the scale punch used when the value doubles.
  void playPunch() {
    _punchT = 1;
  }

  /// Fades the component out (used for merged-away source blocks).
  void playFade() => _fadeT = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (_spawnT < 1) {
      _spawnT = math.min(1, _spawnT + dt * 5.5);
      if (_spawnT >= 1) onAnimationComplete?.call(this);
    }
    if (_punchT > 0) {
      _punchT = math.max(0, _punchT - dt * 3.2);
    }
    if (_fadeT < 1) {
      _fadeT = math.min(1, _fadeT + dt * 6);
    }

    final target = targetPosition;
    if (target != null) {
      final t = math.min(1, dt * 13);
      position.setValues(
        position.x + (target.x - position.x) * t,
        position.y + (target.y - position.y) * t,
      );
      if ((target - position).length < 0.4) {
        position.setFrom(target);
        targetPosition = null;
      }
    }
  }

  @override
  void render(ui.Canvas canvas) {
    final value = block.value;
    final colors = AppColors.blockGradient(value);
    final rect = size.toRect();
    final radius = math.min(size.x, size.y) * 0.22;

    final spawnScale = _spawnT >= 1 ? 1.0 : 0.4 + 0.6 * _spawnT;
    final punch = _punchT > 0 ? 1 + 0.18 * math.sin(_punchT * math.pi) : 1.0;
    final scale = spawnScale * punch;

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(scale);
    canvas.translate(-size.x / 2, -size.y / 2);

    // Drop shadow.
    final shadow = ui.Paint()
      ..color = const ui.Color(0x55000000)
      ..maskFilter =
          const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(radius)),
      shadow,
    );

    // Body gradient.
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

    // Glossy highlight along the top edge.
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

    // Outline.
    final border = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const ui.Color(0x33FFFFFF);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(radius)),
      border,
    );

    // Number.
    final painter = ui.TextPainter(
      text: ui.TextSpan(
        text: '$value',
        style: ui.TextStyle(
          fontSize: math.min(size.x, size.y) * (value >= 1024 ? 0.26 : 0.34),
          fontWeight: ui.FontWeight.w800,
          color: const ui.Color(0xFF1A1030),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      ui.Offset(
        (size.x - painter.width) / 2,
        (size.y - painter.height) / 2,
      ),
    );

    canvas.restore();

    if (_fadeT < 1) {
      final fade = ui.Paint()
        ..color = ui.Color.fromRGBO(255, 255, 255, 1 - _fadeT);
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(radius)),
        fade,
      );
    }
  }
}
