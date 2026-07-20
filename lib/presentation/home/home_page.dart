import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universbook/genarated/l10n/app_localizations.dart';

import '../routes/app_routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.welcomeMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.about),
              child: Text(l10n.goToAbout),
            ),
          ],
        ),
      ),
    );
  }
}
