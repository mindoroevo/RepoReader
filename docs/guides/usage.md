# Guide: Grundbenutzung

## Start
1. App öffnen – Startbildschirm zeigt Eingabemöglichkeiten für Repository.
2. Öffentliches Repo: Owner/Name eingeben (z.B. `flutter/flutter`).
3. Privates Repo: Optional Token zuvor in Einstellungen hinterlegen.

## Dateien Anzeigen
- Navigiere im Dateibaum
- Tippe eine Markdown-/Text-Datei an → gerenderte Ansicht
- Zurück über Navigation / System-Back

## Suche
- Suchfeld öffnen (Symbol in der Toolbar)
- Teilstring eingeben
- Treffer werden markiert (geplant: Liste aller Vorkommen)

## TTS Starten
1. In Datei-Ansicht TTS Button öffnen
2. Modus wählen (Wörter / Sätze / Blöcke)
3. Start-Slider bewegen → Vorschau des Absatzes
4. "Ab hier vorlesen" → Dialog schließt, Wiedergabe startet
5. Stop / Pause über Steuerung

## Offline Snapshot
- Menü → "Offline Snapshot" erstellen
- App speichert relevante Textdateien lokal
- Später ohne Netz Zugriff möglich
- Entfernen über Einstellungen / Snapshot Verwaltung

## Token Verwalten
- Einstellungen öffnen
- Token einfügen (nur Lese-Scope empfohlen)
- Speichern → zukünftige Requests nutzen Authorization Header
- Entfernen: Feld leeren / Button "Token löschen"

## Einstellungen
- Theme (Hell / Dunkel / System)
- Sprache UI (sofern verfügbar)
- TTS Rate / Pitch / Stimme

## Fehlerbehandlung
- "Rate Limit" Hinweis → Token setzen oder abwarten
- 404 → Prüfe Schreibweise / Zugriffsrechte
- Ungültiger Token → Entfernen & neuen generieren

## Tipps
- Kurze Test-Repos nutzen für erste Offline Funktion
- TTS optimal mit mittlerer Rate starten, dann anpassen
- Token niemals mit Vollzugriff nutzen – minimaler Scope!
