import 'package:go_router/go_router.dart';

import '../about/about_page.dart';
import '../home/home_page.dart';

class AppRoutes {
  static const home = '/';
  static const about = '/about';
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: AppRoutes.about,
      builder: (context, state) => const AboutPage(),
    ),
  ],
);

