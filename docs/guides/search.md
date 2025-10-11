# Guide: Suche (Basis + Erweitert)

## Überblick
RepoReader bietet zwei Sucherlebnisse:
- Basis-Volltextsuche über Markdown-Dateien
- Erweiterte Suche über ALLE Dateien (Inhalt + Dateiname/Pfad, mit Kategorie-Filtern)

## Basis-Suche (Markdown)
- Screen/Datei: `lib/screens/search_screen.dart`
- Umfang: Nur Markdown-Dateien (`.md`, rekursiv im gewählten Wurzelpfad)
- Logik: Multi-Term AND (alle eingegebenen Terme müssen im Dokument vorkommen)
- Snippet: Fenster um die erste Trefferposition, Markierung mit « »
- Performance: O(n·m); n = Anzahl Markdown-Dateien, m = Terme

So verwendest du die Basis-Suche:
1. In der App die Suche öffnen (Lupe-Symbol)
2. Suchbegriffe mit Leerzeichen trennen (z. B. „offline snapshot“)
3. Treffer antippen, um die Seite zu öffnen

## Erweiterte Suche (Alle Dateien)
- Screen/Datei: `lib/screens/enhanced_search_screen.dart`
- Umfang: Alle Repository-Dateien; Inhalte werden nur bei Textdateien geladen
- Filter:
  - Inhalt (Textdateien) und/oder Dateiname/Pfad
  - Kategorie (z. B. Documentation, Source Code, Images …)
  - Nur-Text-Dateien
- Snippets: Kontextfenster mit Markierung, Rendering als RichText
- Progress: Ergebnisse werden in Batches aktualisiert; Eingaben brechen laufende Suchen ab

Tipps:
- Wenn du Begriffe im Dateipfad erwartest (z. B. „README“), Dateiname/Pfad-Filter aktivieren
- Für große Repos zunächst Kategorie einschränken
- „Nur Text“-Filter beschleunigt die Suche und reduziert Downloads

## Datenquellen
- Dateien: `WikiService.listAllFiles(..)` und `UniversalFileReader`
- Inhalte (Text): `WikiService.fetchFileByPath(..)` mit Caching & Offline-Fallback

## Grenzen & Roadmap
- Kein Ranking/Scoring; Treffer sind ungeordnet
- Für sehr große Repos ist indexing (Snapshot-basiert) in Planung
- Synonym/Fuzzy-Suche ist aktuell nicht enthalten

