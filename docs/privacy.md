# Datenschutz (Kurzüberblick)

Ausführliche Fassung: Siehe `PRIVACY_POLICY_DE.md` im Repository.

## Kernpunkte
- Keine Analytics / kein Tracking / keine Werbung
- Kein eigenes Backend – direkte GitHub API Nutzung
- Token nur lokal, freiwillig, jederzeit entfernbar
- Offline Snapshots jederzeit löschbar
- TTS lokal über Geräte-Engine

## Datenfluss Minimalprinzip
```
Nutzer Aktion → Direkter GitHub Abruf → Lokale Anzeige / Cache → (optional) Offline Snapshot / TTS
```

## Empfohlene Token-Nutzung
- Nur Fine-grained mit Read Scope
- Nicht wiederverwenden in anderen Tools
- Regelmäßig rotieren

## Rechte
- Kontrolle durch lokale Löschung / Deinstallation

## Geplant
- Secure Storage
- Erweiterter Offline Manager
