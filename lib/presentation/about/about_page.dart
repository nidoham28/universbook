import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universbook/genarated/l10n/app_localizations.dart';

import '../routes/app_routes.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.aboutMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(l10n.backToHome),
            ),
          ],
        ),
      ),
    );
  }
}
