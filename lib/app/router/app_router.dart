import 'package:go_router/go_router.dart';

import '../../features/daily_challenge/presentation/daily_page.dart';
import '../../features/game/presentation/pages/game_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/levels/presentation/pages/levels_page.dart';
import '../../features/shop/presentation/shop_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/settings/presentation/settings_page.dart';

/// Route names and paths.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String home = '/';
  static const String levels = '/levels';
  static const String game = '/game';
  static const String daily = '/daily';
  static const String shop = '/shop';
  static const String settings = '/settings';
  static const String profile = '/profile';
}

/// Application navigation.
///
/// `go_router` keeps deep links and the browser back button working for free,
/// and keeps every screen addressable, which is what makes integration tests
/// straightforward.
class AppRouter {
  const AppRouter._();

  static GoRouter create() => GoRouter(
        initialLocation: AppRoutes.home,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: AppRoutes.levels,
            name: 'levels',
            builder: (context, state) => const LevelsPage(),
          ),
          GoRoute(
            path: AppRoutes.game,
            name: 'game',
            builder: (context, state) => GamePage(args: state.extra),
          ),
          GoRoute(
            path: AppRoutes.daily,
            name: 'daily',
            builder: (context, state) => const DailyPage(),
          ),
          GoRoute(
            path: AppRoutes.shop,
            name: 'shop',
            builder: (context, state) => const ShopPage(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      );
}
