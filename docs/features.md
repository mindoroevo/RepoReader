# Features

Überblick über die wichtigsten Funktionen von RepoReader.

## Kernfunktionen
- Repository-Browser (öffentliche & private Repos*)
- Dateibaum & Markdown Rendering
- Volltextsuche (lokal, im geladenen Kontext)
- Offline Snapshot Speicherung
- Text-to-Speech (Wort / Satz / Block Modus)
- Startpunkt-Auswahl beim Vorlesen
- Einstellungen: Theme, Sprache, TTS-Parameter
- Token-Integration für private Repos / Rate Limit Erhöhung

(*) Private Repos nur bei freiwilliger Eingabe eines Personal Access Token.

## TTS (Vorlese-Funktion)
- Mehrere Modi (Wörter, Sätze, Blöcke)
- Automatisches Zusammenführen ultrakurzer Sätze zur Reduktion von Audio-Knacksern
- Interne Chunk-Pipeline mit regulierbarer Geschwindigkeit & Stimme
- Persistente Speicherung von Sprache, Stimme, Rate, Pitch

## Offline Snapshot
- Lokale Kopie relevanter Dateien
- Hash-/SHA Tracking für Änderungsanzeige (geplant)
- Manuelles Entfernen jederzeit möglich

## Performance / UX
- Lazy Laden von Dateien
- Vereinheitlichte Markdown Vorverarbeitung (bereinigt Anker, leere Überschriften)
- UI Fokus auf Lesbarkeit – kein ablenkendes UI Clutter

## Sicherheit & Datenschutz
- Kein Tracking, keine Analytics SDKs
- Token bleibt lokal (SharedPreferences; Secure Storage geplant)
- Keine Server, direkter GitHub API Zugriff

## Geplante Erweiterungen
- Erweiterter Offline Snapshot Manager
- Diff Ansicht / Änderungsindikatoren
- Besseres Voice-Fallback Handling
- SSML Unterstützung / Atempausen
- Mehr Formatierungsoptionen für Codeblöcke
