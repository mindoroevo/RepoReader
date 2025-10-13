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
  // Warm, soft background and crisp cards
  surface: const Color(0xFFF7F6FB),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: const Color(0xFFFCFBFE),
  surfaceContainer: const Color(0xFFF2F1F7),
  primary: const Color(0xFF4958F0), // a touch more saturated for accents
  secondary: const Color(0xFF5E6B8C),
  onPrimary: Colors.white,
  onSurface: const Color(0xFF14151A),
  onSurfaceVariant: const Color(0xFF535666),
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
  scaffoldBackgroundColor: const Color(0xFFF6F5FA),
  textTheme: Typography.englishLike2021.apply(
    bodyColor: const Color(0xFF14151A),
    displayColor: const Color(0xFF14151A),
  ),
  cardTheme: CardTheme(
    color: Colors.white,
    elevation: 2,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withAlpha(28),
    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: const Color(0xFF1F254033).withAlpha(28)),
    ),
  ),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 3,
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF14151A),
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
  ),
  iconTheme: const IconThemeData(color: Color(0xFF4A4E60)),
  dividerTheme: const DividerThemeData(
    thickness: 1,
    color: Color(0x14000000), // subtle
    space: 24,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: const Color(0xFF4958F0),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF4958F0),
      side: const BorderSide(color: Color(0x334958F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFF2F1F7),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0x14000000)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0x14000000)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF4958F0)),
    ),
  ),
  listTileTheme: const ListTileThemeData(
    iconColor: Color(0xFF4A4E60),
    textColor: Color(0xFF14151A),
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    dense: false,
  ),
  chipTheme: ChipThemeData(
    labelStyle: const TextStyle(color: Color(0xFF4A4E60), fontWeight: FontWeight.w600),
    backgroundColor: const Color(0xFFF2F1F7),
    selectedColor: const Color(0x334958F0),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0x14000000))),
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
