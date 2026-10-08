import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Three stars with a staggered pop-in animation.
///
/// Used on the result screen and the level map, so the celebration moment is
/// identical everywhere.
class StarRating extends StatefulWidget {
  const StarRating({
    required this.stars,
    this.size = 32,
    this.animate = true,
    super.key,
  });

  final int stars;
  final double size;
  final bool animate;

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers = List<AnimationController>.generate(
    3,
    (index) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    ),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _play();
    } else {
      for (final controller in _controllers) {
        controller.value = 1;
      }
    }
  }

  void _play() {
    for (var i = 0; i < widget.stars && i < _controllers.length; i++) {
      Future<void>.delayed(Duration(milliseconds: 180 * i), () {
        if (!mounted) return;
        _controllers[i].forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(StarRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && oldWidget.stars != widget.stars) {
      for (final controller in _controllers) {
        controller.value = 0;
      }
      _play();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(3, (index) {
        final filled = index < widget.stars;
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            final t = Curves.elasticOut.transform(_controllers[index].value);
            return Transform.scale(
              scale: filled ? 0.4 + 0.6 * t : 1,
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: widget.size,
              color: filled ? AppColors.starFilled : AppColors.starEmpty,
            ),
          ),
        );
      }),
    );
  }
}
