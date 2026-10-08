import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_durations.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/star_rating.dart';
import '../../../progression/domain/level_progress.dart';

/// A single level button on the level map.
///
/// Locked levels are visible but not tappable, which is what gives the map its
/// sense of progress.
class LevelNode extends StatefulWidget {
  const LevelNode({
    required this.levelId,
    required this.progress,
    required this.unlocked,
    this.isCurrent = false,
    this.onTap,
    super.key,
  });

  final int levelId;
  final LevelProgress progress;
  final bool unlocked;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  State<LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<LevelNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.slower,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.chapterTheme(
      ((widget.levelId - 1) ~/ GameConstantsLevels.perChapter) + 1,
    );
    final borderColor = widget.unlocked ? theme.first : AppColors.surface;
    final fill = widget.unlocked
        ? theme
        : <Color>[AppColors.surfaceDim, AppColors.surfaceDim];

    return GestureDetector(
      onTap: widget.unlocked ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = widget.isCurrent
              ? 1 + 0.04 * _controller.value
              : 1.0;
          return Transform.scale(scale: pulse, child: child);
        },
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: fill,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: borderColor,
                    width: widget.isCurrent ? 2.5 : 1.5,
                  ),
                  boxShadow: widget.unlocked
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: widget.unlocked
                      ? Text(
                          '${widget.levelId}',
                          style: AppTypography.number(18)
                              .copyWith(color: AppColors.textOnAccent),
                        )
                      : Icon(
                          Icons.lock_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (widget.unlocked)
                StarRating(stars: widget.progress.stars, size: 13, animate: false)
              else
                const SizedBox(height: 13),
            ],
          ),
        ),
      ),
    );
  }
}

/// Local constant holder so the widget does not import the whole game layer.
abstract final class GameConstantsLevels {
  const GameConstantsLevels._();

  static const int perChapter = 25;
}
