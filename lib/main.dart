import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universbook/core/theme/app_themes.dart';
import 'package:universbook/core/theme/theme_controller.dart';
import 'package:universbook/genarated/l10n/app_localizations.dart';
import 'package:universbook/presentation/routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Universbook',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeController.themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}
