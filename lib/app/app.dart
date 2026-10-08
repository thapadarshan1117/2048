import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget.
class MergeDropApp extends StatelessWidget {
  const MergeDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MERGE DROP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      routerConfig: AppRouter.create(),
      builder: (context, child) => _AppReadyScope(child: child),
    );
  }
}

/// Waits for the composition root before showing the first screen, so no
/// screen ever has to handle "dependencies are not ready yet".
class _AppReadyScope extends StatefulWidget {
  const _AppReadyScope({required this.child});

  final Widget? child;

  @override
  State<_AppReadyScope> createState() => _AppReadyScopeState();
}

class _AppReadyScopeState extends State<_AppReadyScope> {
  late final Future<void> _ready = ServiceLocator.instance.initialize();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SplashScreen();
        }
        if (snapshot.hasError) {
          return _StartupErrorScreen(error: snapshot.error);
        }
        return widget.child ?? const SizedBox.shrink();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF1B1035), Color(0xFF2D1B4E)],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 42,
          height: 42,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB020)),
          ),
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF1B1035), Color(0xFF2D1B4E)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Something went wrong while starting the game.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
