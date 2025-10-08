# Guide: Offline Snapshot & Caching

## Ziel
Ermöglicht das Lesen von Repository-Inhalten ohne aktive Internetverbindung.

## Was wird gespeichert?
- Markdown / Text-Dateien
- Evtl. Metadaten (Hashes, Zeitstempel)
- Keine Binär-Ressourcen großer Größe (geplant: Filter / Auswahl)

## Erstellung
1. Repository laden
2. Menü → "Offline Snapshot erstellen"
3. App iteriert durch definierte Dateitypen (z.B. .md, .txt)
4. Dateien werden lokal persistiert

## Nutzung
- Im Offline-Modus App öffnen → Snapshot Inhalte erscheinen
- Kennzeichnung (Geplant): "(Offline)" Badge

## Aktualisieren
- Erneut Snapshot erstellen überschreibt / aktualisiert Inhalte
- Geplant: Delta Prüfung via Hash / Commit SHAs

## Löschen
- Einstellungen → Offline Snapshot entfernen
- Löscht alle gespeicherten Dateien des Repos

## Geplante Erweiterungen
- Mehrere Snapshots verwalten
- Speicherverbrauch Anzeige
- Selektive Aufnahme (Ordner / Dateitypen)
- Diff Ansicht: Was hat sich geändert?

## Best Practices
- Nur benötigte Repos offline nehmen → Speicher sparen
- Regelmäßig aktualisieren bei aktiven Projekten
- Sensible private Repos nach Nutzung wieder entfernen
