// ============================================================================
// RepoReader
// File: theme.dart
// Author: Mindoro Evolution
// Description: Zentrales Light/Dark Theme Tuning für konsistente Doku UI.
// ============================================================================
import 'package:flutter/material.dart';
/// theme.dart – Zentrale Theme-Definition
/// =====================================
/// Light & Dark Theme mit Feinabstimmungen für ruhige Dokumentations-UI.
///
/// Ziele:
///  * Klare, ruhige Oberfläche – leicht erhöhte Karten ohne dominante Tints
///  * Reduzierte Farbsättigung für neutrale Dokumentations-Anmutung
///  * Konsistente Oberflächenabstufungen (surface, surfaceContainerLowest)
///  * Lesbarkeit für Monospace-Pfade / Diff-Snippets
///
/// Anpassungen:
///  * `surfaceContainerLowest` gezielt überschrieben für Karten-Hintergründe
///  * Outline / Schatten leicht moduliert für weichere Kontraste
///  * Light: Heller leicht warmer Grundton (#F8F7FB) statt reines Weiß → geringere Blendwirkung
///  * Dark: Dunkle neutrale Grautöne (#15161A / #1E2025) für sanfte Differenzierung
///
/// Erweiterungsideen:
///  * Typografie-Feintuning (z.B. eigene Code-TextTheme Variante)
///  * High-Contrast Modus (AA / AAA Fokus)
///  * Dynamische Seed-Farbe aus Branding-Konfiguration
///  * Anpassbare Lesebreite durch Layout-Wrapper
///
/// Entscheidungen:
///  * Kein globales MaterialColor Swizzling – SeedColor Indigo ausreichend
///  * Kein ThemeMode State hier (liegt in `main.dart` / ThemeController)
///
/// Hinweis: Einzelne Widgets (z.B. Diff-Markierung) setzen Inline-Farben für semantische Signalwerte.

ColorScheme _tuneLight(ColorScheme base) => base.copyWith(
  surface: const Color(0xFFF8F7FB),
  surfaceContainerLowest: Colors.white,
  primary: base.primary,
  onPrimary: Colors.white,
  onSurface: const Color(0xFF14151A),
  outlineVariant: base.outlineVariant.withAlpha(140),
);

ColorScheme _tuneDark(ColorScheme base) => base.copyWith(
  surface: const Color(0xFF15161A),
  surfaceContainerLowest: const Color(0xFF1E2025),
  onSurface: const Color(0xFFE9EAED),
  outlineVariant: base.outlineVariant.withAlpha(90),
);

final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: _tuneLight(ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light)),
  scaffoldBackgroundColor: const Color(0xFFF5F4F8),
  textTheme: Typography.englishLike2021.apply(
    bodyColor: const Color(0xFF14151A),
    displayColor: const Color(0xFF14151A),
  ),
  cardTheme: CardTheme(
    color: Colors.white,
    elevation: 1.5,
    surfaceTintColor: Colors.white,
    shadowColor: Colors.black.withAlpha(25),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 2,
    shadowColor: Colors.black26,
  ),
  dividerColor: Colors.black12,
  shadowColor: Colors.black.withAlpha(40),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: _tuneDark(ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark)),
  scaffoldBackgroundColor: const Color(0xFF101114),
  textTheme: Typography.englishLike2021.apply(
    bodyColor: const Color(0xFFE9EAED),
    displayColor: const Color(0xFFE9EAED),
  ),
  cardTheme: CardTheme(
    color: const Color(0xFF1E2025),
    elevation: 1.5,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withAlpha(120),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 2,
  ),
  dividerColor: Colors.white10,
  shadowColor: Colors.black.withAlpha(160),
);
