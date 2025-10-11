# Guide: Universeller Datei-Browser

## Überblick
Der Datei-Browser zeigt ALLE Dateien eines Repositories – Text und Binär – mit Such- und Filteroptionen.

## Funktionen
- Kategorien-Gruppierung oder flache Liste
- Suche nach Name und Pfad (case-insensitive)
- „Nur Text“-Filter
- Inline-Vorschau (Dialog) und vollständige Detailansicht
- MIME-Typ und formatierte Größe

## Komponenten
- Screen: `lib/screens/universal_file_browser_screen.dart`
- Viewer: `lib/widgets/universal_file_viewer.dart`
- Listing/Typisierung: `lib/services/universal_file_reader.dart` und `WikiService`

## Bedienung
1. Browser öffnen (Menü/Navigation)
2. Optional Kategorie wählen (z. B. Documentation, Source Code, Images)
3. Suchfeld nutzen, um Treffer zu filtern
4. Datei antippen → Detailansicht; „Auge“-Symbol für schnelle Vorschau

## Hinweise
- Große Binärdateien werden nicht als Inhalt gerendert; Hex-/Base64-Infos stehen bereit
- PDF: Platzhalterhinweis und Download/Kopie-Funktion
- Syntax-Highlighting für Code ist auf der Roadmap

## Offline
- Bei aktivem Offline-Snapshot versucht die App, Dateien lokal zu laden
- Kennzeichnung „fromCache“/Status ist je nach UI sichtbar

