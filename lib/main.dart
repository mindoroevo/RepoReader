// ============================================================================
// RepoReader
// File: main.dart
// Author: Mindoro Evolution
// Description: App Einstieg – Initialisierung von Theme & SharedPreferences.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
/// main.dart – App Einstieg
/// ========================
/// Initialisiert SharedPreferences & ThemeMode, injiziert ThemeController.
///
/// Reihenfolge:
///  1. `WidgetsFlutterBinding.ensureInitialized()` – benötigt für async prefs
///  2. Laden gespeicherten Theme-Strings (light/dark/system)
///  3. Start `runApp` mit injiziertem [ThemeController]
///
/// Fehlerfälle: Scheitert das Lesen der Preferences (selten), fällt es implizit auf System-Mode zurück.
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'screens/home_shell.dart';
import 'localization_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  // Theme Mode laden
  final stored = prefs.getString('pref:themeMode');
  final mode = switch (stored) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  
  // Locale laden (Standard: Englisch)
  final storedLocale = prefs.getString('pref:locale') ?? 'en';
  final locale = Locale(storedLocale);
  
  runApp(WikiApp(initialMode: mode, initialLocale: locale, prefs: prefs));
}

/// Verwaltet aktuellen ThemeMode und persistiert Änderungen.
///
/// Gründe für eigenständigen Controller statt direkten Riverpod / Provider:
///  * Minimale Abhängigkeiten – kein zusätzliches Paket
///  * Notifier genügt, da nur eine Handvoll Umschaltungen erwartet
///
/// Persistenz-Key: `pref:themeMode`
class ThemeController extends ChangeNotifier {
  ThemeController(this._mode, this._prefs);
  ThemeMode _mode; final SharedPreferences _prefs;
  ThemeMode get mode => _mode;
  Future<void> setMode(ThemeMode m) async {
    _mode = m; notifyListeners();
    final v = switch (m) { ThemeMode.light => 'light', ThemeMode.dark => 'dark', ThemeMode.system => 'system' };
    await _prefs.setString('pref:themeMode', v);
  }
}

/// Einfacher InheritedNotifier Wrapper um den [ThemeController] global verfügbar zu machen.
/// Alternative: `ValueListenableBuilder` pro Zugriff, hier aber globale Struktur + Abhängigkeitserkennung.
class ThemeProvider extends InheritedNotifier<ThemeController> {
  const ThemeProvider({super.key, required ThemeController controller, required super.child}) : super(notifier: controller);
  static ThemeController of(BuildContext ctx) => ctx.dependOnInheritedWidgetOfExactType<ThemeProvider>()!.notifier!;
}

/// Root-Widget der Applikation (MaterialApp). Enthält keine Business-Logik.
///
/// ThemeMode und Locale werden über [AnimatedBuilder] reaktiv eingebunden.
class WikiApp extends StatelessWidget {
  const WikiApp({
    super.key,
    required this.initialMode,
    required this.initialLocale,
    required this.prefs,
  });
  final ThemeMode initialMode;
  final Locale initialLocale;
  final SharedPreferences prefs;
  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController(initialMode, prefs);
    final localizationController = LocalizationController(initialLocale, prefs);
    
    return ThemeProvider(
      controller: themeController,
      child: LocalizationProvider(
        controller: localizationController,
        child: AnimatedBuilder(
          animation: Listenable.merge([themeController, localizationController]),
          builder: (context, _) => MaterialApp(
            title: 'RepoReader',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeController.mode,
            home: const HomeShell(),
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LocalizationController.supportedLocales,
            locale: localizationController.locale,
          ),
        ),
      ),
    );
  }
}
