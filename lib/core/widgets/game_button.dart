import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_durations.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';

/// Visual style of a [GameButton].
enum GameButtonVariant { primary, secondary, ghost, danger }

/// The single button used across the whole game.
///
/// Provides the press-in scale animation, gradient fill and disabled state that
/// every call-to-action needs, so no screen builds its own button.
class GameButton extends StatefulWidget {
  const GameButton({
    required this.label,
    required this.onPressed,
    this.variant = GameButtonVariant.primary,
    this.icon,
    this.height = 52,
    this.width,
    this.expand = false,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final GameButtonVariant variant;
  final IconData? icon;
  final double height;
  final double? width;
  final bool expand;
  final bool enabled;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  List<Color> get _gradient => switch (widget.variant) {
        GameButtonVariant.primary => const <Color>[
            AppColors.primaryLight,
            AppColors.primary,
            AppColors.primaryDark,
          ],
        GameButtonVariant.secondary => const <Color>[
            AppColors.secondary,
            AppColors.secondaryDark,
          ],
        GameButtonVariant.danger => const <Color>[
            Color(0xFFFF8A8A),
            AppColors.danger,
          ],
        GameButtonVariant.ghost => <Color>[
            AppColors.surfaceElevated,
            AppColors.surface,
          ],
      };

  Color get _textColor => switch (widget.variant) {
        GameButtonVariant.primary => AppColors.textOnAccent,
        GameButtonVariant.secondary => AppColors.textOnAccent,
        GameButtonVariant.danger => Colors.white,
        GameButtonVariant.ghost => AppColors.textPrimary,
      };

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = widget.enabled && widget.onPressed != null;
    final content = AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: AppDurations.fast,
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        height: widget.height,
        width: widget.expand ? double.infinity : widget.width,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: effectiveEnabled
                ? _gradient
                : <Color>[AppColors.surface, AppColors.surfaceDim],
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: effectiveEnabled
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (widget.icon != null) ...<Widget>[
              Icon(
                widget.icon,
                size: 20,
                color: effectiveEnabled
                    ? _textColor
                    : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title.copyWith(
                  color: effectiveEnabled ? _textColor : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTapDown: effectiveEnabled
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: effectiveEnabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel:
          effectiveEnabled ? () => setState(() => _pressed = false) : null,
      onTap: effectiveEnabled ? widget.onPressed : null,
      child: content,
    );
  }
}

/// The main call-to-action.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) => GameButton(
        label: label,
        onPressed: onPressed,
        icon: icon,
        expand: expand,
        variant: GameButtonVariant.primary,
      );
}

/// A quieter alternative action.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) => GameButton(
        label: label,
        onPressed: onPressed,
        icon: icon,
        expand: expand,
        variant: GameButtonVariant.secondary,
      );
}

/// A square icon-only button (back, pause, sound toggle).
class IconActionButton extends StatelessWidget {
  const IconActionButton({
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.variant = GameButtonVariant.ghost,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final GameButtonVariant variant;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: GameButton(
          label: '',
          onPressed: onPressed,
          icon: icon,
          variant: variant,
          height: size,
          width: size,
        ),
      );
}
