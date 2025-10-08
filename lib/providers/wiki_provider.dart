// ============================================================================
// RepoReader
// File: wiki_provider.dart
// Author: Mindoro Evolution
// Description: ChangeNotifier für (optionale) Sidebar-Navigation.
// ============================================================================
import 'package:flutter/material.dart';
/// Provider (ChangeNotifier) für eine klassische Wiki-Sidebar-Struktur.
///
/// Dieser Ansatz zielte ursprünglich auf GitHub Wiki-ähnliche Navigation
/// (Seitenliste aus einer speziellen Sidebar-Datei). Im aktuellen UI setzen
/// wir primär auf rekursive README-Gruppierung; die Sidebar-Mechanik kann
/// optional wiederbelebt oder entfernt werden.
///
/// Aufgaben:
///  * Laden der definierten Sidebar Markdown-Datei (`AppConfig.sidebar`)
///  * Extraktion lokaler Links → `pages` (Fallback auf Home, falls Fehler)
///  * Benachrichtigung der UI über `notifyListeners()` nach Abschluss
///
/// Nicht-Ziele:
///  * Kein Caching (übernimmt `WikiService` / SharedPreferences an anderer Stelle)
///  * Keine Live-Change-Erkennung für Sidebar
///  * Kein Ranking / Sortierlogik: Reihenfolge entspricht Linkreihenfolge im Markdown
///
/// Erweiterungsideen:
///  * Beobachtung/Invalidierung bei Änderungen (Snapshot + Hash)
///  * Mehrere Sidebar-Dateien zu Sektionen aggregieren
///  * Metadaten pro Seite (z.B. Icon) über Spezial-Syntax `[Icon:book]` ergänzen
import '../config.dart';
import '../models/wiki_page.dart';
import '../services/wiki_service.dart';
import '../utils/wiki_links.dart';

class WikiProvider extends ChangeNotifier {
  final _service = WikiService();
  List<WikiPageLink> pages = [];
  bool ready = false;

  /// Lädt die Sidebar Markdown-Datei und füllt `pages`.
  /// Fallback: Einzelner Home-Eintrag falls Datei fehlt oder Fehler.
  Future<void> loadSidebar() async {
    try {
      final (txt, _) = await _service.fetchMarkdownByRepoPath('${AppConfig.dirPath}/${AppConfig.sidebar}');
      pages = extractSidebarLinks(txt);
    } catch (_) {
      pages = [WikiPageLink(title: 'Home', path: '${AppConfig.dirPath}/${AppConfig.homePage}')];
    } finally {
      ready = true;
      notifyListeners();
    }
  }
}
