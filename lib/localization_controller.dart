import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LocalizationController
/// ======================
/// Verwaltet die aktuelle Sprache der App und persistiert die Auswahl.
/// Ähnlich wie ThemeController, aber für Lokalisierung.
class LocalizationController extends ChangeNotifier {
  LocalizationController(this._locale, this._prefs);
  
  Locale _locale;
  final SharedPreferences _prefs;
  
  Locale get locale => _locale;
  
  /// Unterstützte Sprachen
  static const supportedLocales = [
    Locale('en'), // English (default)
    Locale('de'), // German
    Locale('fr'), // French
    Locale('es'), // Spanish
    Locale('it'), // Italian
    Locale('pt'), // Portuguese
    Locale('ru'), // Russian
    Locale('ja'), // Japanese
    Locale('zh'), // Chinese
    Locale('ko'), // Korean
    Locale('nl'), // Dutch
  ];
  
  /// Sprache ändern und persistieren
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    await _prefs.setString('pref:locale', locale.languageCode);
  }
  
  /// Sprachname für die UI
  String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en': return 'English';
      case 'de': return 'Deutsch';
      case 'fr': return 'Français';
      case 'es': return 'Español';
      case 'it': return 'Italiano';
      case 'pt': return 'Português';
      case 'ru': return 'Русский';
      case 'ja': return '日本語';
      case 'zh': return '中文';
      case 'ko': return '한국어';
      case 'nl': return 'Nederlands';
      default: return locale.languageCode.toUpperCase();
    }
  }
}

/// LocalizationProvider
/// ====================
/// InheritedNotifier Wrapper um den LocalizationController global verfügbar zu machen.
class LocalizationProvider extends InheritedNotifier<LocalizationController> {
  const LocalizationProvider({
    super.key,
    required LocalizationController controller,
    required super.child,
  }) : super(notifier: controller);
  
  static LocalizationController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocalizationProvider>()!.notifier!;
}

/// LanguageSwitcher
/// ================
/// Dropdown Widget zum Wechseln der Sprache
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});
  
  @override
  Widget build(BuildContext context) {
    final controller = LocalizationProvider.of(context);
    
    return DropdownButton<Locale>(
      value: controller.locale,
      onChanged: (locale) {
        if (locale != null) {
          controller.setLocale(locale);
        }
      },
      items: LocalizationController.supportedLocales.map((locale) {
        return DropdownMenuItem<Locale>(
          value: locale,
          child: Text(controller.getLanguageName(locale)),
        );
      }).toList(),
    );
  }
}