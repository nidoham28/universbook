import 'package:go_router/go_router.dart';
import 'package:universbook/presentation/stories/stories_page.dart';
import 'package:universbook/presentation/stories/upload_stories.dart';

import '../about/about_page.dart';
import '../home/home_page.dart';
import '../splash/splash_page.dart';
import '../stories/page_view.dart';
import '../stories/edit_page.dart';

class AppRoutes {
  static const splash = '/';
  static const home = '/home';
  static const about = '/about';
  static const search = '/search';
  static const uploadStory = '/uploadStory';
  static const myStories = '/myStories';
  static const settings = '/settings';
  static const pageView = '/pageView';
  static const editPage = '/editPage';

  static String pageViewPath(String storyId) => '$pageView/$storyId';

  /// pageIndex omitted (or null) means "create a new page"; otherwise it's
  /// the index of the existing page to edit.
  static String editPagePath(String storyId, {int? pageIndex}) {
    final path = '$editPage/$storyId';
    return pageIndex == null ? path : '$path?pageIndex=$pageIndex';
  }
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
      // UploadStories() with no arg → internally uses StoryRepository()
      builder: (context, state) => const UploadStories(),
    ),
    GoRoute(
      path: AppRoutes.myStories,
      // StoriesPage() with no arg → internally uses StoryRepository()
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
        // PageViewScreen with no repo arg → internally uses StoryRepository()
        return PageViewScreen(storyId: storyId);
      },
    ),
    GoRoute(
      path: '${AppRoutes.editPage}/:storyId',
      builder: (context, state) {
        final storyId = state.pathParameters['storyId']!;
        final pageIndexParam = state.uri.queryParameters['pageIndex'];
        final pageIndex =
        pageIndexParam != null ? int.tryParse(pageIndexParam) : null;
        // EditPageScreen with no repo arg → internally uses PageRepository()
        return EditPageScreen(storyId: storyId, pageNo: pageIndex);
      },
    ),
  ],
);