import 'package:go_router/go_router.dart';

import '../about/about_page.dart';
import '../home/home_page.dart';
import '../splash/splash_page.dart';

class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const about = '/about';
  static const search = '/search';
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: AppRoutes.about,
      builder: (context, state) => const AboutPage(),
    ),
    GoRoute(
      path: AppRoutes.search,
      builder: (context, state) => const AboutPage(),
    ),
  ],
);

