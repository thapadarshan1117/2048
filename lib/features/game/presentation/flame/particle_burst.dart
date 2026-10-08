import 'dart:math' as math;

import 'package:flame/components.dart';
import 'dart:ui' as ui;

import '../../../../app/theme/app_colors.dart';

/// A burst of sparks emitted when blocks merge.
///
/// Particle count and speed scale with the merged value, so creating a 512 is
/// visibly more of an event than creating an 8.
///
/// The effect is drawn by this component directly rather than by a
/// `ParticleSystemComponent` so it owns its own lifetime and can never outlive
/// the merge it belongs to.
class MergeBurst extends PositionComponent {
  MergeBurst({
    required Vector2 position,
    required this.value,
    double cellSize = 40,
  })  : _cellSize = cellSize,
        super(position: position.clone(), anchor: Anchor.center);

  final int value;
  final double _cellSize;

  final List<_Spark> _sparks = <_Spark>[];
  final math.Random _rng = math.Random();
  double _age = 0;

  static const double _lifespan = 0.5;

  @override
  Future<void> onLoad() async {
    final count = math.min(24, 6 + (math.log(value) / math.ln2).round() * 2);
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = 90 + _rng.nextDouble() * 130;
      _sparks.add(_Spark(
        velocity: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
        radius: _cellSize * (0.045 + _rng.nextDouble() * 0.03),
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    for (final spark in _sparks) {
      spark.velocity.y += 420 * dt;
      spark.offset += spark.velocity * dt;
    }
    if (_age >= _lifespan) removeFromParent();
  }

  @override
  void render(ui.Canvas canvas) {
    final progress = (_age / _lifespan).clamp(0.0, 1.0);
    final base = AppColors.blockColor(value);
    for (final spark in _sparks) {
      final paint = ui.Paint()
        ..color =
            ui.Color.lerp(base, const ui.Color(0xFFFFFFFF), progress * 0.6)!
                .withValues(alpha: 1 - progress);
      canvas.drawCircle(
        spark.offset.toOffset(),
        spark.radius * (1 - progress * 0.5),
        paint,
      );
    }
  }
}

class _Spark {
  _Spark({required this.velocity, required this.radius});

  Vector2 velocity;
  final Vector2 offset = Vector2.zero();
  final double radius;
}

/// Floating "+N" text that rises from the merge point.
class ScorePopup extends PositionComponent {
  ScorePopup({
    required Vector2 position,
    required this.text,
    required this.color,
  }) : super(position: position.clone(), anchor: Anchor.center);

  final String text;
  final ui.Color color;

  double _t = 0;

  static const double _lifespan = 0.85;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    position.y -= 42 * dt;
    if (_t >= _lifespan) removeFromParent();
  }

  @override
  void render(ui.Canvas canvas) {
    final progress = (_t / _lifespan).clamp(0.0, 1.0);
    final opacity = 1 - progress;
    final scale = 1 + 0.25 * math.sin(math.pi * math.min(1, progress * 2));

    canvas.save();
    canvas.translate(position.x, position.y);
    canvas.scale(scale);

    final painter = ui.TextPainter(
      text: ui.TextSpan(
        text: text,
        style: ui.TextStyle(
          fontSize: 20,
          fontWeight: ui.FontWeight.w900,
          color: color.withValues(alpha: opacity),
          shadows: const <ui.Shadow>[
            ui.Shadow(color: ui.Color(0xAA000000), blurRadius: 6),
          ],
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
