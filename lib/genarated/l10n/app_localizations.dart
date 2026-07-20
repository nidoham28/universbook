import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('bn'),
  ];

  String get appTitle => locale.languageCode == 'bn' ? 'ইউনিভার্সবুক' : 'Universbook';
  String get homeTitle => locale.languageCode == 'bn' ? 'ইউনিভার্সবুক হোম' : 'Universbook Home';
  String get welcomeMessage => locale.languageCode == 'bn' ? 'ইউনিভার্সবুকে স্বাগতম' : 'Welcome to Universbook';
  String get goToAbout => locale.languageCode == 'bn' ? 'এবাউট এ যান' : 'Go to About';
  String get aboutTitle => locale.languageCode == 'bn' ? 'সম্পর্কে' : 'About';
  String get aboutMessage => locale.languageCode == 'bn' ? 'ইউনিভার্সবুক সম্পর্কে' : 'About Universbook';
  String get backToHome => locale.languageCode == 'bn' ? 'হোমে ফিরে যান' : 'Back to Home';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'bn'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
