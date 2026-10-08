import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_durations.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import 'game_button.dart';

/// Every dialog in the game.
///
/// Replaces the stock Material dialog so the result, pause, settings and shop
/// overlays all share the same frame, entrance animation and spacing.
class GameDialog extends StatelessWidget {
  const GameDialog({
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
    this.dismissible = true,
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool dismissible;

  /// Shows [GameDialog] with a scale-and-fade entrance.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    List<Widget> actions = const <Widget>[],
    bool dismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: 'dialog',
      barrierColor: Colors.black.withValues(alpha: 0.66),
      transitionDuration: AppDurations.normal,
      pageBuilder: (context, _, __) => GameDialog(
        title: title,
        actions: actions,
        dismissible: dismissible,
        child: child,
      ),
      transitionBuilder: (context, animation, _, dialog) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(curve),
          child: FadeTransition(
            opacity: animation,
            child: dialog,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: dismissible,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[AppColors.surfaceElevated, AppColors.surface],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 40,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTypography.headline,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Flexible(child: child),
                    if (actions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xl),
                      ...actions.map(
                        (action) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: action,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirmation dialog with a destructive and a neutral action.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    super.key,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final String cancelLabel;
  final bool destructive;

  /// Shows a confirmation dialog and invokes [onConfirm] when accepted.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) {
    return GameDialog.show<void>(
      context,
      title: title,
      dismissible: true,
      actions: <Widget>[
        GameButton(
          label: cancelLabel,
          variant: GameButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        GameButton(
          label: confirmLabel,
          variant: destructive
              ? GameButtonVariant.danger
              : GameButtonVariant.primary,
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
        ),
      ],
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTypography.body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
