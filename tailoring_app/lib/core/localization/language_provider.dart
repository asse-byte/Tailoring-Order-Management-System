import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _prefsKey = 'selected_language_code';
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  LanguageProvider() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? savedCode = prefs.getString(_prefsKey);
      if (savedCode != null) {
        _locale = Locale(savedCode);
      } else {
        final String deviceLang =
            PlatformDispatcher.instance.locale.languageCode;
        if (deviceLang == 'fr') {
          _locale = const Locale('fr');
        } else {
          _locale = const Locale('en');
        }
      }
      notifyListeners();
    } catch (_) {
      // Fallback in case shared_preferences fails
    }
  }

  Future<void> changeLocale(Locale newLocale) async {
    if (newLocale.languageCode == _locale.languageCode) return;
    _locale = newLocale;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, newLocale.languageCode);
    } catch (_) {
      // ignore
    }
  }
}
