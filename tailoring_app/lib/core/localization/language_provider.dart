import 'package:flutter/material.dart';

class LanguageProvider extends ChangeNotifier {
  Locale get locale => const Locale('fr');

  LanguageProvider();

  Future<void> changeLocale(Locale newLocale) async {
    // Locked to French only
  }
}
