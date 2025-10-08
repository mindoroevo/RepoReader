import '../models/wiki_page.dart';

/// Hilfsfunktionen für Link-Normalisierung im (Legacy) Wiki-/Sidebar-Kontext.
///
/// Herkunft: Frühere Sidebar-/GitHub-Wiki-Struktur (derzeit nur begrenzt aktiv im UI).
/// Perspektive: Kann bei endgültigem Verzicht auf klassische Sidebar entfallen.
///
/// Funktionen:
///  * [normalizeWikiFile] – erzwingt '.md' und ersetzt Whitespaces durch '-'
///  * [extractSidebarLinks] – extrahiert Markdown-Links (lokal) als `WikiPageLink`
///  * [isExternalUrl] – einfache Heuristik für absolute externe URLs
///
/// Einschränkungen:
///  * Keine Auflösung relativer Pfade / Verzeichnisse (nur Datei-Ebene)
///  * Keine Anker (#...) Verarbeitung
///  * Entfernt nicht URL-Sonderzeichen außer Whitespace → '-'
///
/// Mögliche Erweiterungen:
///  * Slug-Normalisierung (Umlaute → ae/oe/ue)
///  * Unterstützung für Anker (Rückgabe Struktur mit anchor-Feld)
///  * Filter auf bestimmte Link-Sektionen (Sidebar nur innerhalb definierter Bereiche)

/// Erzwingt '.md' Endung und ersetzt wiederholte Whitespaces durch '-'.
/// Beispiel: "Meine Seite" -> "Meine-Seite.md".
String normalizeWikiFile(String s) {
  final withMd = s.endsWith('.md') ? s : '$s.md';
  return withMd.replaceAll(RegExp(r'\s+'), '-');
}

/// Extrahiert Markdown-Link-Paare `[Titel](pfad)` aus Roh-Markdown.
/// Externe Links (http/https) werden ignoriert.
/// Gibt mindestens einen Eintrag zurück (Fallback: Home.md), falls nichts gefunden.
List<WikiPageLink> extractSidebarLinks(String md) {
  final regex = RegExp(r'\[(.*?)\]\((.*?)\)');
  final matches = regex.allMatches(md);
  final out = <WikiPageLink>[];
  for (final m in matches) {
    final title = m.group(1)!.trim();
    final raw = m.group(2)!.trim();
    if (raw.startsWith('http')) continue;
    out.add(WikiPageLink(title: title, path: normalizeWikiFile(raw)));
  }
  return out.isEmpty ? [WikiPageLink(title: 'Home', path: 'Home.md')] : out;
}

/// Sehr einfache Prüf-Funktion für externe URLs.
bool isExternalUrl(String url) => url.startsWith('http://') || url.startsWith('https://');
