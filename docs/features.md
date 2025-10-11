# Features

Überblick über die wichtigsten Funktionen von RepoReader.

## Kernfunktionen
- Repository-Browser (öffentliche & private Repos*)
- README‑Navigation, flache Liste, Explorer (Baum)
- Universeller Datei‑Browser (alle Dateitypen, Kategorien, Vorschau)
- Suche: Basis (Markdown) und Erweiterte (alle Dateien, Inhalt + Dateiname)
- Offline Snapshot + Caching
- Text‑to‑Speech (Wort / Satz / Block) inkl. Startversatz
- Änderungs‑Erkennung (Added/Modified/Removed) mit zeilenbasiertem Diff
- Benachrichtigungen bei Änderungen (optional)
- Einstellungen: Theme, Sprache, TTS‑Parameter, Polling/Notifications
- Token‑Integration (PAT) & Device Flow Login

(*) Private Repos nur bei freiwilliger Eingabe eines Personal Access Token.

## TTS (Vorlese-Funktion)
- Mehrere Modi (Wörter, Sätze, Blöcke)
- Automatisches Zusammenführen ultrakurzer Sätze zur Reduktion von Audio-Knacksern
- Interne Chunk-Pipeline mit regulierbarer Geschwindigkeit & Stimme
- Persistente Speicherung von Sprache, Stimme, Rate, Pitch

## Offline Snapshot
- Vollständiger Snapshot im App‑Dokumentenordner (inkl. Metadaten)
- Lesen ohne Netz, Bildpfade werden lokal aufgelöst
- Snapshot erstellen/neu erstellen/löschen aus den Einstellungen

## Performance / UX
- Lazy Laden von Dateien
- Vereinheitlichte Markdown Vorverarbeitung (bereinigt Anker, leere Überschriften)
- UI Fokus auf Lesbarkeit – kein ablenkendes UI Clutter

## Sicherheit & Datenschutz
- Kein Tracking, keine Analytics SDKs
- Token lokal; Secure Storage für private Tokens (Service vorhanden)
- Keine Server, direkter GitHub API Zugriff

## Geplante Erweiterungen
- Persistenter Index für schnelle Suche
- Word‑Level‑Diff & visuelles Inline‑Diffing
- SSML Unterstützung / feinere Pausensteuerung
- Syntax‑Highlighting für Code
- Snapshot‑Manager mit Größe, Selektion, Delta‑Updates
