import 'package:flutter/material.dart';

import '../../app/theme/app_typography.dart';

/// Animated score readout.
///
/// The displayed value rolls towards [score] instead of snapping, which makes a
/// big merge feel like it paid out rather than teleported.
class ScoreDisplay extends StatelessWidget {
  const ScoreDisplay({
    required this.score,
    this.label,
    this.fontSize = 28,
    this.alignment = CrossAxisAlignment.center,
    super.key,
  });

  final int score;
  final String? label;
  final double fontSize;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      value: score,
      builder: (value) => Column(
        crossAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (label != null) ...<Widget>[
            Text(label!, style: AppTypography.label),
            const SizedBox(height: 2),
          ],
          Text(
            '$value',
            style: AppTypography.number(fontSize).copyWith(
              shadows: const <Shadow>[
                Shadow(color: Color(0x66000000), blurRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal tween builder that avoids pulling in an extra dependency.
class TweenAnimationBuilder extends StatelessWidget {
  const TweenAnimationBuilder({
    required this.value,
    required this.builder,
    super.key,
  });

  final int value;
  final Widget Function(int value) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilderCore(
        value: value,
        builder: builder,
      );
}

class TweenAnimationBuilderCore extends StatefulWidget {
  const TweenAnimationBuilderCore({
    required this.value,
    required this.builder,
    super.key,
  });

  final int value;
  final Widget Function(int value) builder;

  @override
  State<TweenAnimationBuilderCore> createState() =>
      _TweenAnimationBuilderCoreState();
}

class _TweenAnimationBuilderCoreState extends State<TweenAnimationBuilderCore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late int _displayed = widget.value;
  int _from = widget.value;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
  }

  void _onTick() {
    final t = Curves.easeOutCubic.transform(_controller.value);
    final next = (_from + (widget.value - _from) * t).round();
    if (next != _displayed) {
      setState(() => _displayed = next);
    }
  }

  @override
  void didUpdateWidget(TweenAnimationBuilderCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _from = _displayed;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_displayed);
}
