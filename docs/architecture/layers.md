# Architekturschichten (Detail)

## Übersicht
RepoReader folgt einem vereinfachten Schichtenmodell zur Trennung von Darstellung, Logik und Infrastruktur.

| Schicht | Inhalt | Beispiele | Änderungsauswirkung |
|---------|--------|-----------|---------------------|
| UI / Presentation | Screens, Widgets, Dialoge | TTS Dialog, Markdown Ansicht | UI Refactor selten Einfluss auf Services |
| Domain / Services | Geschäftslogik, Aggregation | TTS Service, Snapshot Manager | Änderung kann UI Verhalten ändern |
| Data / Integrationen | GitHub API Calls, Storage | HTTP Client, SharedPreferences | Anpassung kann Caching / Performance beeinflussen |
| Utils / Helpers | Parsing, Normalisierung | Markdown Preprocessor | Breite Wiederverwendung |

## Verantwortlichkeiten
- UI: Zustandsanzeige + Eingabe
- Service: Orchestrierung (z.B. TTS Chunking, Offline Snapshot Erzeugung)
- Data: Reine Zugriffe (fetch, store)
- Utils: Pure Functions, deterministisch

## Abhängigkeiten
```
UI → Services → Data → (HTTP / Storage)
           ↘ Utils ↗
```

## Vorteile
- Testbarkeit: Services isolierbar
- Austauschbarkeit: GitHub API Layer später erweiterbar für GitLab
- Weniger Seiteneffekte durch funktionale Utils

## Anti-Pattern Vermeidung
- Kein direkter HTTP Zugriff in Widgets
- Kein State-Leak von Services nach außen (nur klar definierte Methoden)

## Erweiterungsszenarien
| Ziel | Änderungsscope | Risiko |
|------|----------------|-------|
| GitLab Support | Neue Data Provider + Konfig Layer | Mittel |
| Secure Storage | Austausch Token Storage Backend | Niedrig |
| Multi-Snapshot | Snapshot Manager Erweiterung | Mittel |

## Testfokus (Empfehlung)
- Unit: Markdown Preprocessing, TTS Chunking
- Integration: Repo Laden + Rendern
- Smoke: Start App, Öffne Datei, Starte TTS

