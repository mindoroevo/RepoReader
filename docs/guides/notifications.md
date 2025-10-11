# Guide: Änderungs-Polling & Benachrichtigungen

## Überblick
RepoReader kann periodisch nach geänderten Dateien suchen und auf Wunsch System-Benachrichtigungen anzeigen.

## Komponenten
- Polling/Steuerung: `lib/screens/home_shell.dart`
- Erkennung/Details: `lib/services/change_tracker_service.dart`
- Benachrichtigungen: `lib/services/notification_service.dart`

## Funktionsweise
1. Basierend auf `pref:pollMinutes` (Default 5) wird ein Minutenticker gestartet.
2. Alle X Minuten wird `ChangeTrackerService.detectChanges()` aufgerufen.
3. Änderungen (Added/Modified/Removed) werden aggregiert; Diff ist zeilenbasiert (naiv).
4. Optional zeigt die App einen Dialog und/oder sendet eine System-Notification.

Backoff-Strategie:
- Keine Änderungen erkannt → interner Zähler erhöht sich
- Alle 5 Leerlaufzyklen verdoppelt sich das effektive Intervall (max. 8× des Basiswerts)

## Einstellungen
- `pref:pollMinutes`: 0 (aus), 5, 10, 30, 60 …
- `pref:notifyChanges`: true/false, steuert System-Benachrichtigungen
- `pref:showChangeDialog`: true/false, steuert Dialog beim Erkennen

## Plattform-Hinweise
- Android 13+: Laufzeitberechtigung für Notifications erforderlich (wird angefragt)
- iOS/macOS: Erlaubnisdialog via Plugin
- Web: System-Notification nicht verfügbar; in-App-Dialog weiterhin nutzbar

## Grenzen & Tipps
- Diff ist zeilenbasiert; Wort-Level-Diff ist auf der Roadmap
- Für sehr große Repos kann Polling ressourcenintensiv sein → Intervall erhöhen
- Snapshot/Cache beeinflusst Diff-Basis; bei inkonsistenten Ergebnissen Cache leeren

