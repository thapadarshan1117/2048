import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Every screen's background: a soft vertical gradient with safe-area padding
/// already applied, so no screen has to repeat either.
class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    required this.child,
    this.appBar,
    this.bottomBar,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.lg,
    ),
    super.key,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomBar;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.backgroundTop, AppColors.backgroundBottom],
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(top: media.padding.top),
          child: Column(
            children: <Widget>[
              if (appBar != null) appBar!,
              Expanded(
                child: Padding(padding: padding, child: child),
              ),
              if (bottomBar != null) bottomBar!,
              SizedBox(height: media.padding.bottom),
            ],
          ),
        ),
      ),
    );
  }
}
