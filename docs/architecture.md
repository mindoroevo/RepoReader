# Architektur

Dieser Abschnitt beschreibt die grobe Architektur von RepoReader.

## Übersicht
RepoReader ist eine Flutter App ohne eigenes Backend. Alle externen Aufrufe gehen direkt gegen GitHub Endpunkte.

```
+-------------+        HTTPS         +-------------------+
|  App (UI)   +--------------------->+  GitHub API       |
|             |<---------------------+  (public/private) |
+------+------+                      +-------------------+
       |
       | Markdown / Text
       v
+-------------+
|  TTS Engine | (lokal, Plattform)
+-------------+
```

## Hauptschichten
1. UI / Screens: Anzeige, Interaktion
2. Services: TTS Service, Repo Fetching, Caching
3. Utils: Markdown Vorverarbeitung, Parsing
4. Persistence: SharedPreferences (Einstellungen, Token)
5. (Geplant) Secure Storage für sensible Werte

## Datenfluss (Beispiel Abruf)
1. Nutzer wählt Repository
2. App lädt Dateibaum via GitHub API
3. Nutzer öffnet Datei → Inhalt wird geladen & optional in Cache
4. Markdown wird vorverarbeitet & gerendert
5. Optional: TTS Service segmentiert Text & spielt vor

## Markdown Vorverarbeitung
- Entfernung von HTML Ankern
- Normalisierung von Überschriften
- Entfernen leerer heading Container
- Relative Bilder (geplant: Umwandlung in absolute URLs)

## TTS Pipeline (vereinfacht)
1. Rohtext aus gerendertem Markdown extrahieren
2. Normalisierung / Cleaning (Whitespace, kurze Sätze zusammenfassen)
3. Chunking basierend auf Modus
4. Sequenzielle Wiedergabe über `flutter_tts`

## Token Nutzung
- Nur bei Eingabe durch Nutzer
- Verwendet für Authorization Header bei privaten Repos
- Lokal persistiert, nicht gesendet außer an GitHub Endpunkte

## Offline Snapshot
- Speicherung strukturierter Dateien im App Speicher
- Referenzierung über Repository Identifier + Pfad
- Geplant: Delta Updates / Diff Anzeige

## Fehler- & Edge Cases
- Rate Limit → Anzeige / Hinweis Token nutzen
- Netzwerkverlust → Fallback auf Offline Snapshot
- Ungültiger Token → Lokales Entfernen + Meldung

## Erweiterbarkeit
- Services modular gehalten
- Künftige Plattform-Spezifika (Desktop / Web) isolierbar
- Potenzial: Plugin-Schicht für alternative Quellen (GitLab, Codeberg)

## Sicherheit
- Kein eigener Netzwerk Proxy
- HTTPS Only
- Kein stilles Senden von Telemetrie

## Bekannte Grenzen
- Kein Syntax Highlighting für alle exotischen Formate
- Keine parallele Multi-Repo Indexierung (noch) 
- Keine differenzielle Delta Synchronisation
