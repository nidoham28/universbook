import 'package:go_router/go_router.dart';
import 'package:universbook/presentation/stories/stories_page.dart';
import 'package:universbook/presentation/stories/upload_stories.dart';

import '../about/about_page.dart';
import '../home/home_page.dart';
import '../splash/splash_page.dart';
import '../stories/page_view.dart';

class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const about = '/about';
  static const search = '/search';
  static const uploadStory = '/uploadStory';
  static const myStories = '/myStories';
  static const settings = '/settings';
  static const pageView = '/pageView';
  static String pageViewPath(String storyId) => '$pageView/$storyId';
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
    GoRoute(
      path: AppRoutes.uploadStory,
      builder: (context, state) => const UploadStories(),
    ),
    GoRoute(
      path: AppRoutes.myStories,
      builder: (context, state) => const StoriesPage(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const AboutPage(),
    ),
    GoRoute(
      path: '${AppRoutes.pageView}/:storyId',
      builder: (context, state) {
        final storyId = state.pathParameters['storyId']!;
        return PageViewScreen(storyId: storyId);
      },
),
  ],
);

