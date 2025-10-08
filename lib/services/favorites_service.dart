import 'package:shared_preferences/shared_preferences.dart';

/// Favoriten-Service
/// =================
/// Verwaltung gemerkter Dokument-/Datei-Pfade (Favoriten) mittels `SharedPreferences`.
///
/// Ziele:
/// * Minimalistische API (`load`, `save`)
/// * Stabile, sortierte Persistenz = deterministische UI + klarer Diff im Storage
/// * Einfache Austauschbarkeit durch spätere Persistenzlayer (Hive / SQLite)
///
/// Nicht-Ziele:
/// * Kein In-Memory Cache (geringe Datenmenge)
/// * Keine Event-Streams – UI pollt / lädt beim Start
///
/// Nebenläufigkeit: SharedPreferences ist effektiv sequenziell genug; Race Conditions bei schneller Folge-Aufrufen sind hier tolerierbar.
class FavoritesService {
  static const _key = 'favorites:paths';

  /// Lädt alle gespeicherten Favoriten als Set.
  /// Gibt ein leeres Set zurück falls noch nichts persistiert wurde.
  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    return list.toSet();
  }

  /// Persistiert die übergebenen Favoriten. Sortiert sie für stabile Anzeige.
  ///
  /// [favs] Menge von Repo-Pfaden (z.B. `docs/intro/README.md`).
  static Future<void> save(Set<String> favs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, favs.toList()..sort());
  }
}