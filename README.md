<div align="center">

# 📚 RepoReader

_Multiplattform Flutter App (Android • iOS • Web • Windows • macOS • Linux) zum **Live-Lesen, Navigieren, Durchsuchen, Offline-Nutzen und Änderungs‑Erkennen** von Dokumentation & beliebigen Repository-Dateien (Text + ausgewählte Binärtypen) direkt über GitHub APIs – ohne eigenen Backend‑Server._

<p>
<img alt="Platforms" src="https://img.shields.io/badge/platform-android%20|%20ios%20|%20web%20|%20desktop-blue" />
<img alt="Dart" src="https://img.shields.io/badge/dart-%3E=3.7-informational" />
<img alt="Status" src="https://img.shields.io/badge/status-alpha-orange" />
<img alt="Offline" src="https://img.shields.io/badge/offline-snapshot-green" />
<img alt="License" src="https://img.shields.io/badge/license-restricted-critical" />
</p>

_TL;DR:_ README-/Dokunavigation • Alle Dateien (flach + Baum) • Universeller File Viewer • Offline Snapshot Mode • Änderungs-Badges + Diff • Volltext & erweiterte Suche • Favoriten • Token (PAT / Device Flow) • Caching • Markdown Preprocessing & Sanitizing.

</div>

---

## Inhaltsverzeichnis
1. [Quick Start](#quick-start)
2. [Warum? Ziele & Abgrenzung](#warum-ziele--abgrenzung)
3. [Feature Überblick (Kurz)](#feature-überblick-kurz)
4. [Feature Matrix (Detail)](#feature-matrix-detail)
5. [View Modi](#view-modi)
6. [Setup & Erststart](#setup--erststart)
7. [Konfigurationsquellen & Persistenz](#konfigurationsquellen--persistenz)
8. [Token / Auth (PAT & Device Flow)](#token--auth-pat--device-flow)
9. [Favoriten & Extension-Filter](#favoriten--extension-filter)
10. [Änderungserkennung & Diff](#änderungserkennung--diff)
11. [Suchsystem](#suchsystem)
12. [Datei-Typ Kategorisierung & Universal Reader](#datei-typ-kategorisierung--universal-reader)
13. [Markdown Preprocessing & Sanitizing](#markdown-preprocessing--sanitizing)
14. [Namenslogik & Titelableitung](#namenslogik--titelableitung)
15. [Offline Snapshot Mode](#offline-snapshot-mode)
16. [Caching Strategie](#caching-strategie)
17. [Architektur & Layering](#architektur--layering)
18. [Datenfluss (End-to-End)](#datenfluss-end-to-end)
19. [Theming & UX Prinzipien](#theming--ux-prinzipien)
20. [Public API / Funktionen (lib Verzeichnis)](#public-api--funktionen-lib-verzeichnis)
21. [Konfiguration (AppConfig)](#konfiguration-appconfig)
22. [Build & Run](#build--run)
23. [Tests & Qualitätssicherung](#tests--qualitätssicherung)
24. [Security & Privacy](#security--privacy)
25. [Performance & Skalierung](#performance--skalierung)
26. [Troubleshooting](#troubleshooting)
27. [FAQ](#faq)
28. [Roadmap](#roadmap)
29. [Contribution Richtlinien](#contribution-richtlinien)
30. [Lizenz](#lizenz)
31. [Credits](#credits)
32. [Internationalisierung (i18n)](#internationalisierung-i18n)
33. [Vorlese-Funktion (Text-to-Speech)](#vorlese-funktion-text-to-speech)

---

## Quick Start
```bash
flutter pub get
flutter run -d windows   # oder chrome / linux / macos / ios / android
```
Setup Screen erscheint (kein Default Repo). GitHub Repo URL einfügen → Speichern → Navigation lädt. Optional: PAT einfügen.

Minimaler Erststart:
1. URL (z.B. `https://github.com/OWNER/REPO`) einfügen
2. (Optional) PAT für private Repos / Rate Limit
3. Speichern → README / Dateien erscheinen
4. Extensions öffnen → zusätzliche Dateitypen auswählen

---

## Warum? Ziele & Abgrenzung
| Ziel | Beschreibung |
|------|--------------|
| Sofortiger Wissenszugriff | Kein Build / statischer Site Generator erforderlich |
| Einheitliche Darstellung | Konsistente UI über Plattformen & Repos hinweg |
| Minimale Vorannahmen | Funktioniert auch ohne dedizierten `docs/` Ordner (Root Mode) |
| Änderungs-Transparenz | Schneller Überblick: Was hat sich seit letztem Besuch geändert? |
| Universalität | Nicht nur README – auch Code, Config, Plaintext, Bilder |
| Offline Robustheit | Letzte Stände bleiben verfügbar |

Nicht Fokus (aktuell): Bearbeiten von Dateien, PR-Erstellung, Auth-Workflows über Write-Scopes.

---

## Feature Überblick (Kurz)
README-Gruppierung • Volltext Navigation • Explorer • Universeller Datei Viewer • Änderungs-Diff • Favoriten • Erweiterte Suche • Token Support • Caching • Preprocessing & Sanitizing • Theming.

---

## Feature Matrix (Detail)
| Kategorie | Funktionen | Hinweise |
|-----------|-----------|----------|
| Navigation | README basierte Ordner-Gruppen, Flat-All Liste, Explorer Baum | Zyklischer Toggle, persistiert |
| Titelableitung | Ordnertitel für README, Dateiname ohne Extension für andere | Numerische Präfixe optional entfernbar (geplant) |
| Dateien | Text, Bilder, einfache Binär-Erkennung | PDF/Archive Platzhalter |
| Suche | Markdown Volltext + Erweiterte Textdatei-Suche | Mehrstufiger Token AND Match |
| Diff | Added/Modified/Removed, Zeilen-Diff | Word-Level geplant |
| Änderungsbadge | Persistenter Signatur-Vergleich | Manuelles Acknowledge |
| Preprocessing | HTML→MD, Link & Image Rewriting, Sanitizing | Idempotent |
| Favoriten | Pfadbasierte Liste, persistiert | Schneller Zugriff |
| Extensions | Globaler Dialog, Kategorien & Suche | Aktiv beeinflusst Gruppenkarten |
| Caching | Versionierte Keys, Snapshot, Acknowledge | Kein globaler TTL aktuell |
| Auth | PAT optional | Fine-grained empfohlen |
| Theming | System / Hell / Dunkel Persistenz | Material 3 Basis |
| Plattform | Desktop, Mobile, Web PWA Icons | Fenster-/Seitentitel „RepoReader“ |

---

## View Modi
| Modus | Beschreibung | Typische Nutzung |
|-------|--------------|------------------|
| README | Gruppiert über README(-ähnliche) Dateien; zusätzliche Textdateien integriert | Dokumentation / Wissen |
| Alle Dateien (flach) | Linear alphabetisch / kategorisch sortierbar | Überblick viele Dateien |
| Explorer (Baum) | Verzeichnisstruktur, einklappbar | Entwicklung / Code-Kontext |

Umschaltung per Icon in der AppBar (rotierendes Symbol). Status persistiert in `pref:mainViewMode`.

---

## Setup & Erststart
| Schritt | Aktion | Ergebnis |
|--------|--------|----------|
| 1 | App starten | Setup Screen (leere Konfiguration) |
| 2 | Repo URL | Parser extrahiert owner / repo / branch / (optional) subdir |
| 3 | (Optional) PAT | Erhöht Rate Limit / private Repos |
| 4 | Speichern | Konfig + Clear alter Cache → Initialer Index Build |
| 5 | (Optional) Extensions wählen | Weitere Dateitypen sichtbar |

Unterstützte URL-Formate:
```
https://github.com/OWNER/REPO
https://github.com/OWNER/REPO/tree/BRANCH/path/to/dir
https://raw.githubusercontent.com/OWNER/REPO/BRANCH/path/to/file.md
```
Fallbacks: Branch → `main` (falls HEAD nicht explizit), Verzeichnis leer = Root.

---

## Konfigurationsquellen & Persistenz
Persistente Keys:
`cfg:owner`, `cfg:repo`, `cfg:branch`, `cfg:dir`, `cfg:token`, `pref:activeExtensions`, `pref:mainViewMode`, `fav:paths`, `snapshot:v1`, `changes:ackSignature`, `cache:v2:<path>`.

Priorität:
1. User Setup (SharedPreferences)
2. Dart-Define Token: `--dart-define=GITHUB_TOKEN=...`
3. Defaults (leer) → zwingt Setup

---

## Token / Auth (PAT & Device Flow)
| Zweck | Rechte | Bemerkung |
|-------|--------|-----------|
| Rate Limit Erhöhung | `Contents: Read` (fine-grained) | 60 → 5k Requests/h |
| Private Repos lesen | Gleiches wie oben | Keine Schreibrechte nötig |
| Classic Token (Fallback) | `repo` (breit) | Nur falls fine-grained nicht möglich |

Erstellung (Fine-grained): Developer Settings → Fine-grained Tokens → Repo auswählen → Permission `Contents: Read` → Ablaufdatum setzen.

Speicherung: Aktuell unverschlüsselt (SharedPreferences) → für höhere Sicherheitsanforderungen Secure Storage (Roadmap) oder nur Laufzeit.

Fehler / Symptome:
| Symptom | Ursache | Lösung |
|---------|---------|--------|
| 401 | Falsches / abgelaufenes Token | Neues Token erzeugen |
| 403 | Rate Limit ohne Token | PAT setzen / warten |
| 404 private Datei | Keine Permission | Fine-grained prüfen |
| Nur 60/h | Kein Token aktiv | Token Feld füllen |

Token entfernen: Feld leeren + Speichern.

---

## Favoriten & Extension-Filter
Favoriten: Toggle auf Datei-/Gruppenkarte → Eintrag in `fav:paths`.

Extension-Dialog:
1. Öffnen (⚙️ / Filter Icon)
2. Kategorien (Code / Config / Docs / Media / Archive / Other)
3. Suche nach Endung (z.B. `yaml`, `svg`)
4. Working Set anwenden → Persistenz `pref:activeExtensions`
5. README-Karten zeigen Badge mit Anzahl zusätzlicher Dateien im Scope

Warum global statt pro Gruppe? Einheitliche Sicht, reduzierte kognitive Last, einfache Persistenz.

---

## Änderungserkennung & Diff
Schritte:
1. Git Tree (recursive) → Map Pfad→SHA
2. Vergleich mit lokalem Snapshot (`snapshot:v1`)
3. Klassifikation: Added / Modified / Removed
4. Diff (Zeilen-basiert) nur für Modified (Textdateien)
5. Preview Snippets (sanitized) im Änderungsdialog
6. Aggregierte Signatur (Hash aller Paarungen) → Acknowledge Key

Limitierungen & Designentscheidungen:
| Bereich | Entscheidung | Begründung |
|---------|-------------|-----------|
| Zeilen-Diff | Kein Word-Level | Schnelligkeit / Einfachheit |
| Binärdateien | Kein Diff | Geringer Mehrwert, Performance |
| Snapshot Speicher | Plain JSON | Debuggbar & leicht resetbar |

---

## Suchsystem
Aktueller Algorithmus (Markdown Basis):
1. Alle relevanten Textdateien laden (Cache-first)
2. Query → Tokens (whitespace split, lowercase)
3. Filter: Datei enthält alle Tokens (substring)
4. Snippet: Erstes Match + Kontextfenster ±N Zeichen
5. Mehrere Tokens → zusätzliche Hervorhebungen

Erweiterte Suche: Inkl. Code/Config/Plain Texte + Dateinamen + Kategorie-Filter.

Geplant: Scoring (Heading > Body), Fuzzy Levenshtein bei kurzer Query, invertierter Index für O(k) Retrieval.

---

## Datei-Typ Kategorisierung & Universal Reader
Heuristiken: Extension Whitelist + einfache Binary Detection (unprintable ratio).

| Kategorie | Beispiele | Darstellung | Hinweis |
|-----------|-----------|-------------|---------|
| Dokumentation | .md .mdx .markdown .rst .adoc | Markdown Renderer | Preprocessing aktiv |
| Plain/Text | .txt .log .csv | Monospace Text | Wrap / Scroll |
| Code | .dart .js .ts .yaml .json .yml .py .java ... | Monospace | Syntax Highlighting geplant |
| Config | .env .ini .toml | Plain Text | 🔒 Vorsicht mit Secrets |
| Bilder | .png .jpg .jpeg .gif .svg .webp | Image Widget | Fallback Icon bei Fehler |
| Archive/Binär | .zip .tar .gz .exe .dll | Meta Info + Hinweis | Kein Download integriert |
| PDF | .pdf | Platzhalter | Viewer später |

---

## Markdown Preprocessing & Sanitizing
Pipeline (vereinfacht):
1. Normalisierung Zeilenenden (\r\n → \n)
2. HTML Headings `<h1..h6>` → `#` Syntax + `<!--anchor:slug-->`
3. Zentrierte Blöcke `<p align=center>` → H1 (Branding konform)
4. `<br>` → Zeilenumbruch (außerhalb Code Fences)
5. Absatz-Normalisierung `<p>` Blocks
6. Navigations-/Footer Muster entfernen (Regex Liste)
7. Relative Bildpfade → Raw GitHub URL
8. Inline HTML Konvertierung (`<strong>`, `<em>`, `<code>`, `<a>`, `<span>`, `<u>` etc.)
9. Leerzeilen Dedup
10. Sicherheits-Sanitizing für Diff Snippets (entfernt potenziell störende HTML Fragmente)

Idempotent entworfen: Mehrfachanwendung erzeugt keine doppelten Markierungen.

---

## Namenslogik & Titelableitung
Regeln:
| Fall | Titelquelle | Beispiel |
|------|-------------|----------|
| README / readme.* | Parent Ordnername | `docs/README.md` → `docs` |
| index.md / home.md | Parent Ordner | `guide/index.md` → `guide` |
| Andere Textdatei | Dateiname ohne Extension | `01-intro.md` → `01-intro` (num-prefix removal geplant) |
| Groß-/Kleinschreibung | Normalisiert (erste Buchstabe groß) | `utilities` → `Utilities` |

Geplante Verbesserung: Numerische Präfixe + Trenner (`01_`, `02-`) entfernen.

---

## Offline Snapshot Mode
Der Offline-Modus speichert einen vollständigen lokalen Snapshot aller Dateien im konfigurierten Verzeichnisbereich. Aktivierbar über Einstellungen.

Ziele:
* Vollständige Nutzung ohne Netzwerk (Lesen von Text & Binärdateien)
* Schneller Start & Navigation auch bei Ausfall / Rate Limit
* Reproduzierbare Stände (Zeitpunkt im Manifest)

Verzeichnisstruktur (App-Dokumente):
```
offline_snapshots/
	<owner>_<repo>_<branch>/
		meta.json
		files/<repoPath>
```
`meta.json` Beispiel (verkürzt):
```json
{
	"owner":"...",
	"repo":"...",
	"branch":"main",
	"created":1730000000,
	"dirPath":"docs",
	"files":[{"path":"docs/Intro.md","size":1234,"text":true}]
}
```

Erstellung: Settings → "Snapshot erstellen". Vorheriger Snapshot wird überschrieben.

Lade-Priorität (Text/Binär):
1. Offline Snapshot (wenn aktiviert)
2. Raw GitHub Content
3. Contents API (Base64)
4. Lokaler Cache (SharedPreferences)

Navigation Offline: Fällt Netzwerk weg, werden README-/Markdown-Einträge aus `meta.json` gefiltert (`.md`, `.mdx`, `.txt`, `.rst`, `.adoc`).

Grenzen / Trade-Offs:
| Bereich | Entscheidung | Grund |
|--------|--------------|-------|
| Update | Komplettes Neu-Schreiben | Einfachheit statt Diff |
| Speicher | Plain Files + Manifest | Debuggbar, transparent |
| Versionierung | Kein Multi-Snapshot | Reduzierte Komplexität |
| Konflikte | Kein Merge | Read-Only Konzept |

API (Auszug `OfflineSnapshotService`):
| Funktion | Beschreibung |
|----------|--------------|
| `isOfflineEnabled()` | Prüft Flag |
| `setOfflineEnabled(v)` | Aktiviert/deaktiviert Modus |
| `createSnapshot(onProgress)` | Baut Snapshot via Git Tree + Universal Reader |
| `hasSnapshot()` | Prüft Vorhandensein |
| `deleteSnapshot()` | Entfernt lokalen Snapshot |
| `readTextFileOffline(path)` | Liest Textdatei aus Snapshot |
| `readBinaryFileOffline(path)` | Liest Binärdatei |
| `listOfflineNavTextEntries()` | Filtert Navigationsrelevante Einträge |

## Caching Strategie
Persistente Keys:
| Key | Bedeutung |
|-----|-----------|
| `cache:v2:<path>` | Markdown Klartext (ungefiltert) |
| `universal_cache:v2:<path>` | Beliebige Datei (Text direkt / Binär Base64) |
| `tree:snapshot` | Letzter Git Tree (Markdown Pfade→SHA) |
| `tree:lastSig` | Aktuelle Signatur |
| `tree:ackSig` | Als gelesen markierte Signatur |
| `favorites:paths` | Favoritenliste |
| `pref:activeExtensions` | Aktivierte Extensions |
| `offline:enabled` | Offline Flag |

Invalidierung: Version-Bump (`cacheVersion` in `AppConfig`). Manuell: Einstellungen (geplant), oder Neuinstallation.

Fallback Reihenfolge (UniversalFileReader / WikiService): Offline → Raw → Contents API → Cache → Fehler.

---

## Architektur & Layering
```
lib/
	main.dart                     # App Bootstrap, Theme, Routing
	config.dart                   # Dynamische Laufzeit-Konfiguration
	theme.dart                    # Farbpaletten / ThemeMode Handling
	services/
		wiki_service.dart           # GitHub API (Contents/Raw/Tree), Listing, Cache Access
		change_tracker_service.dart # Snapshot + Diff + Signatur
		favorites_service.dart      # Favoritenpersistenz
		secure_token_store.dart     # (Platzhalter) Token Handling / Migration Pfad
		wiki_service.dart           # (Datei-Listing & Content) – zentral
	screens/
		home_shell.dart             # Hauptnavigation + View Mode Toggle + Gruppen / Listen / Baum
		search_screen.dart          # Markdown Volltextsuche
		universal_file_browser_screen.dart # Kategorie & Flat File Übersicht
		change_detail_screen.dart   # Diff / Render / Raw Tabs
		settings_screen.dart        # Theme & globale Optionen
		setup_screen.dart           # Erstkonfiguration (Repo + Token)
	widgets/
		markdown_view.dart          # Darstellung & (zukünftige) Erweiterungen
		universal_file_viewer.dart  # Content Rendering (Text, Bild, Binary Hinweis)
	utils/
		markdown_preprocess.dart    # Preprocessing Pipeline
		github_link_parser.dart     # URL Parsing / Normalisierung
		naming.dart                 # Titelableitung / Slug
		toc.dart                    # Anker & Table of Contents (Vorbereitung)
		wiki_links.dart             # Interne Link Auflösung
```

Layer Prinzip:
| Ebene | Verantwortung | Darf abhängen von |
|-------|---------------|-------------------|
| Screens | UI + Interaktion | Services, Widgets, Utils |
| Widgets | Präsentation | Utils |
| Services | Domain / Netzwerk / State | Utils, Config |
| Utils | Pure Functions | (keine) |
| Config | Globale Parameter | — |

Architekturziele: Testbarkeit, geringe Kopplung, klarer Datenfluss, Minimierung UI‑seitiger Nebenwirkungen.

---

## Datenfluss (End-to-End)
1. Setup → AppConfig konfigurieren
2. Home Shell lädt: a) Dateibaum (Tree API / Contents API) b) README Indizes
3. Nutzer wählt Ansicht (README / Flat / Explorer)
4. Beim Öffnen einer Datei: Cache Lookup → ggf. Netzwerk → Preprocessing → Anzeige
5. Periodisch / Benutzeraktion: Änderungserkennung (Tree Snapshot)
6. Diff Ergebnisse → Badge / Dialog → Acknowledge setzt Signatur
7. Suche: On-Demand Laden fehlender Inhalte → Tokenisierung → Match & Snippets

Fehlerpfade: Netzwerkfehler → Cache Fallback; 403 → Hinweis (RATE LIMIT) + Token Empfehlung.

---

## Theming & UX Prinzipien
| Prinzip | Umsetzung |
|---------|-----------|
| Konsistenz | Einheitliche Card / Badge Styles Material 3 |
| Geschwindigkeit | Lazy Content Fetch nur bei Öffnung |
| Rückmeldung | Badges / Snackbar / Diff Dialog |
| Orientierung | Klar getrennte Modi + eindeutige Icons |
| Lesbarkeit | Preprocessing entfernt Rauschen (Navigationsreste) |
| Zugänglichkeit | Hoher Kontrast in Dark Theme, skalierbarer Text (System) |

---

## Public API / Funktionen (lib Verzeichnis)
Vollständiger Überblick über zentrale Klassen & Methoden (Auszug – private/obvious UI Widgets ausgelassen). Parameter vereinfacht dargestellt.

### config.dart – AppConfig
| Element | Beschreibung |
|---------|--------------|
| `cacheVersion` | Globale Cache Versionsnummer |
| `configure({owner,repo,branch,dirPath,token})` | Setzt Laufzeit-Konfiguration + persistiert |
| `resetToDefaults()` | Leert aktuelle Konfiguration |
| `rawFile(rel)` | Raw URL für Datei |
| `gitTreeUri()` | Git Tree API URI (recursive) |
| `listDirUri(path)` | Contents API URI für Verzeichnis |

### services/universal_file_reader.dart – UniversalFileReader
| Methode | Zweck |
|---------|-------|
| `readFile(repoPath)` | Lädt Text/Binär + erkennt MIME + Caching + Offline |
| `isTextFile(path)` | Heuristik basierend auf Extension |
| `getMimeType(path)` | MIME Bestimmung |
| `listAllFilesRecursively(dir)` | Alle Dateien via Git Tree |
| `listFilesByType(dir,exts)` | Filter nach Extension Set |
| `listTextFiles(dir)` | Nur Text |
| `listBinaryFiles(dir)` | Nur Binär |
| `clearCache()` | Entfernt alle universal Cache Keys |

`FileReadResult` Eigenschaften: `content`, `fromCache`, `isText`, `mimeType`, Helper: `asText()`, `asBytes()`, `asBase64()`.
`UniversalRepoEntry`: Felder `name,path,type,extension,mimeType,isText,size`, Getter `formattedSize`, `category`.

### services/wiki_service.dart – WikiService
| Methode | Zweck |
|--------|------|
| `fetchMarkdownByRepoPath(path)` | Markdown (Offline→Raw→Contents→Cache) |
| `listMarkdownFiles(dir)` | Nicht rekursiv .md in Verzeichnis |
| `listReadmesRecursively(dir)` | Rekursive README Navigation |
| `listAllMarkdownFilesRecursively(dir)` | Für Suche / Index |
| `fetchAllReadmesWithContent(dir)` | Liste inkl. Inhalte |
| `fetchFileByPath(path)` | Delegiert an UniversalFileReader |
| `listAllFiles(dir)` | Alle Dateien |
| `listTextFiles(dir)` | Text subset |
| `listBinaryFiles(dir)` | Binär subset |
| `listFilesByCategory(dir)` | Gruppierung nach Kategorie |
| `listFilesByExtensions(dir,exts)` | Extension Filter |
| `listCodeFiles(dir)` | Code Extensions Set |
| `listDocumentationFiles(dir)` | Doku Extensions Set |
| `listConfigFiles(dir)` | Config Extensions Set |
| `listImageFiles(dir)` | Bild Extensions |
| `listPdfFiles(dir)` | PDFs |
| `fetchTextFile(path)` | Convenience Text |
| `fetchBinaryFile(path)` | Convenience Binär |
| `fileExists(path)` | HEAD Request Prüfung |
| `getFileMetadata(path)` | Metadaten Lookup |
| `clearAllCaches({keepConfig})` | Globale Cache Bereinigung |
| `ensureIndex()` (static) | README Normalisierungsindex erzeugen |
| `resolveExistingReadmePath(cand)` (static) | Pfad-Kanonisierung |

### services/offline_snapshot_service.dart – OfflineSnapshotService
| Methode | Zweck |
|--------|------|
| `isOfflineEnabled()` | Prüft Offline Flag |
| `setOfflineEnabled(v)` | Setzt Flag |
| `createSnapshot({onProgress})` | Baut Snapshot (Git Tree + Laden aller Dateien) |
| `hasSnapshot()` | Prüft Existenz |
| `deleteSnapshot()` | Löscht Snapshot |
| `readTextFileOffline(path)` | Text lesen |
| `readBinaryFileOffline(path)` | Binär lesen |
| `listSnapshotFiles()` | Manifest Datei-Liste |
| `listOfflineNavTextEntries()` | Navigationstaugliche Textdateien |
| `currentSnapshotRootPath()` | Basis-Pfad (z.B. für Bildlade-Widgets) |

### services/change_tracker_service.dart – ChangeTrackerService
| Methode | Zweck |
|--------|------|
| `detectChanges()` | Vergleicht aktuellen Tree mit altem Snapshot |
| `markRead(signature)` | Acknowledge eines Standes |
| `acknowledgedSignature()` | Letzt bestätigte Signatur |
| `lastCheckedAt()` | Zeitpunkt letzter Prüfung |
| `_diffLines(path,oldSha)` | (intern) Naiver Zeilen-Diff |
| `_fetchCurrentSnapshot()` | (intern) Git Tree Abzug |

`ChangeSummary`: Felder `files`, `newSignature`, `timestamp`.  
`ChangeFile`: `path,status,addedLines,removedLines,sample,diff`.  
`DiffLine`: `prefix('+','-',' ','➜')`, `text`.

### services/favorites_service.dart – FavoritesService
| Methode | Zweck |
|--------|------|
| `load()` | Lädt Favoriten Set |
| `save(favs)` | Persistiert sortiert |

### services/private_auth_service.dart – PrivateAuthService
| Methode | Zweck |
|--------|------|
| `loadToken()` | Token lesen (secure storage) |
| `saveToken(token)` | Speichern |
| `clearToken()` | Löschen |
| `startDeviceFlow(scopes)` | Device Flow Initiierung (user_code, verification_uri, interval, device_code) |
| `pollForDeviceToken(deviceCode, interval)` | Polling bis Access Token |

### services/notification_service.dart – NotificationService
| Methode | Zweck |
|--------|------|
| `init()` | Initialisiert Plugin + Channel |
| `showChangeNotification(count)` | Lokale Notification |
| `registerWebhookPlaceholder()` | Debug Placeholder |

### widgets/markdown_view.dart
Erweitertes Rendering von Markdown-Inhalten inkl. (vereinfacht):
* Image Loader (Offline-Pfade → lokale Dateien, sonst Netzwerk)
* Geplante: Syntax Highlighting, TOC Interaktion

### widgets/universal_file_viewer.dart
Rendert beliebige Dateiarten basierend auf `FileReadResult` (Heuristik: Text vs. Binär).

### utils/markdown_preprocess.dart
Mehrstufige Pipeline (Normalisierung, HTML → Markdown, Bildpfad-Rewriting, Sanitizing). Idempotent.

### utils/naming.dart
Titel-/Slug Ableitung für Navigationskarten & Anzeige.

### utils/wiki_links.dart / toc.dart
Interne Link-Auflösung & spätere Table-of-Contents Generierung.

### screens/* (Auszug)
| Screen | Kernfunktion |
|--------|--------------|
| `home_shell.dart` | Zentrale Navigation + Favoriten + Change Badges + Offline Fallback |
| `search_screen.dart` / `enhanced_search_screen.dart` | Volltext / Erweiterte Suche |
| `change_detail_screen.dart` | Diff Anzeige & Tabs |
| `settings_screen.dart` | Theme, Änderungsdialog, Offline, Polling, Snapshot |
| `setup_screen.dart` | Ersterfassung Repo/Token |
| `universal_file_browser_screen.dart` | Alle Dateien gruppiert/kategorisiert |
| `page_screen.dart` | Markdown Darstellung einzelner Datei |

## Konfiguration (AppConfig)
Auszug (vereinfachtes Beispiel – tatsächliche Datei für Details prüfen):
```dart
class AppConfig {
	static const cacheVersion = 2;
	static String _owner = '';
	static String _repo  = '';
	static String _branch = 'main';
	static String _dirPath = ''; // leer = root mode
	static String? _runtimeToken;

	static void configure({String? owner, String? repo, String? branch, String? dirPath, String? token}) { /* ... */ }
	static void resetToDefaults() { /* ... */ }
	static String rawFile(String rel) => 'https://raw.githubusercontent.com/$owner/$repo/$branch/$rel';
	static Uri gitTreeUri() => Uri.parse('https://api.github.com/repos/$owner/$repo/git/trees/$branch?recursive=1');
}
```

---

## Build & Run
Voraussetzungen: Flutter >= 3.7, Git installiert.

| Ziel | Beispiel |
|------|----------|
| Desktop Debug | `flutter run -d windows` |
| Web Debug | `flutter run -d chrome` |
| Android Release | `flutter build apk --release` |
| Web Release | `flutter build web --release` |
| Icons neu erzeugen | `dart run flutter_launcher_icons` |

Optionale Flags:
```bash
flutter run -d chrome --dart-define=GITHUB_TOKEN=xxxx
flutter run -d chrome --dart-define=FLUTTER_WEB_USE_SKIA=true
```

---

## Tests & Qualitätssicherung
Empfohlene Testbereiche:
| Bereich | Fokus |
|---------|-------|
| Preprocessing | HTML Fälle, Idempotenz |
| Diff | Edge Cases (Leerdatei, nur Add, nur Remove) |
| Suche | Multi-Term, Case, Nicht-Treffer |
| Naming | README vs. normal, numerische Präfixe |
| Services | 404 / 403 / Netzwerk Timeout Fallback |

CI (geplant):
1. `flutter analyze`
2. `flutter test --coverage`
3. (optional) Golden Tests UI

Lints: `analysis_options.yaml` kann verschärft werden (Pedantic / Lints Paket).

---

## Security & Privacy
| Aspekt | Status | Hinweis |
|--------|--------|--------|
| Token Storage | Plaintext SharedPreferences | Sicherer Storage geplant |
| Netzwerk | Direkte GitHub Endpunkte | Keine Dritt-Server |
| Telemetrie | Keine | Privacy by default |
| Berechtigungen | Nur READ Scope nötig | Geringe Angriffsfläche |
| HTML Sanitizing | Basis (Inline) | Erweiterung für komplexe Embeds geplant |
| Secrets Risiko | Anzeige von .env möglich | Nutzerverantwortung; Filteroption denkbar |

Empfehlungen: Kein breites Classic Token, regelmäßige Token Rotation.

---

## Performance & Skalierung
| Komponente | Ansatz | Optimierungspotential |
|-----------|-------|-----------------------|
| Listing | Tree API + Filter | Pagination / Lazy Expand (Baum) |
| Suche | Linear O(n * m) | Invertierter Index, Ranking Cache |
| Diff | Zeilenweise O(n) | Word-Level & Caching Diff Blöcke |
| Caching | Version Key | Expiry / LRU Strategie |
| Bilder | On-demand | Progressive / Low-Res Placeholder |

Geplante Maßnahmen: Parallel Prefetch ausgewählter Dateien nach Leerlauf; Persistenter Suchindex.

---

## Troubleshooting
| Problem | Ursache | Lösung |
|---------|---------|--------|
| 403 Rate Limit | Keine Auth | PAT setzen / warten |
| 401 Unauthorized | Falsches Token | Neues Token generieren |
| Weißer Inhalt | Datei leer oder Binary | Prüfen Kategorie / Raw öffnen |
| Fehlende Bilder | Pfade außerhalb Root | Root Mode nutzen oder Pfad anpassen |
| Kein Diff | Nur Add/Remove | Erwartet (kein Vergleich) |
| Suche langsam | Sehr großes Repo | Filter / Roadmap Index |
| Titel „README“ überall | Falsche Erkennung | Prüfe Preprocessing / Naming Regeln |

---

## FAQ
**Warum kein vorgegebenes Default Repo?** Intentionale Quelle, Datenschutz, klare Kontrolle.

**Unterstützt mehrere Repos gleichzeitig?** Aktuell Single-Context; Multi-Profile denkbar.

**Enterprise GitHub Instanzen?** Nicht direkt; API Basis-URL müsste konfigurierbar gemacht werden.

**Kann ich Dateien editieren?** Nein – reiner Reader (bewusst risikoarm).

**Warum wird mein Token nicht verschlüsselt?** Alpha-Phase; Priorität Funktionsumfang. Secure Storage geplant.

**Funktioniert das offline?** Nur bereits geladene (gecachete) Inhalte.

**Syntax Highlighting?** Auf Roadmap; aktuell Plain Monospace.

---

## Roadmap
| Priorität | Item | Status |
|----------|------|--------|
| Hoch | TOC Scroll / Jump | offen |
| Hoch | Word-Level Diff | offen |
| Hoch | Rate Limit UI (Header Auswertung) | offen |
| Mittel | Syntax Highlighting | offen |
| Mittel | Fuzzy & Ranking Suche | offen |
| Mittel | Secure Token Storage | offen |
| Niedrig | Offline Export (ZIP Cache) | offen |
| Niedrig | Numerische Präfix-Filter Titel | offen |
| Niedrig | PDF Inline Viewer | offen |

---

## Contribution Richtlinien
Interner Fokus – externe PRs ggf. eingeschränkt.
| Schritt | Richtlinie |
|--------|-----------|
| Branch | `feat/<kurz>`, `fix/<issue>`, `refactor/<bereich>` |
| Umfang | Kleine, fokussierte Änderungen |
| Tests | Für Kernlogik bevorzugt |
| Secrets | Keine Tokens / Keys commiten |
| Code Style | Kurze Funktionen, Services kapseln I/O, pure Utils |

Review Checkliste: Läuft `flutter analyze` clean? Keine Regression laut manueller Smoke Tests? README Abschnitt aktualisiert falls Verhalten geändert.

---

## Lizenz
Eingeschränkte interne / private Nutzung. Kein öffentlicher Fork, kein Vertrieb, keine Bereitstellung als SaaS ohne Zustimmung.

| Erlaubt | Verboten |
|---------|----------|
| Interne Nutzung | Öffentliche Mirrors |
| Anpassungen lokal | App Store Veröffentlichung |
| Test Deploys | Kommerzieller Verkauf |

Spätere Öffnung unter permissiver OSS Lizenz (z.B. MIT) denkbar – keine Garantie.

Kontakt für Lizenzanfragen: <mindoro.evolution@gmail.com>

---

## Credits
Autor: **Mindoro Evolution**

Dank an die Flutter / Dart & Open Source Communities. _Letzte Inhaltspflege: siehe Git History._

---

## Internationalisierung (i18n)

Die App ist vollständig internationalisiert. Englisch ist Default; zusätzlich existieren 10 weitere Sprachen (de, fr, es, it, pt, ru, nl, ja, ko, zh). Alle aktuell sichtbaren UI‑Strings – Navigation, Buttons, Dialoge, Fehlermeldungen, Setup, Erweiterte Suche, Dateityp-Dialog, Offline/Snapshot, Token & Device Flow – sind abgedeckt.

### 1. Ziele & Prinzipien
| Ziel | Umsetzung |
|------|-----------|
| Vollständige Abdeckung | Alle UI Strings in 11 Sprachen synchron gehalten |
| Typ‑Sicherheit | Generierter `AppLocalizations` Code (compile-time) |
| Sofortige Umschaltung | Kein Neustart, State bleibt erhalten |
| Persistenz | SharedPreferences (`pref:locale`) |
| Fallback | System → falls nicht unterstützt → `en` |
| Erweiterbarkeit | Neue `.arb` hinzufügen + `supportedLocales` erweitern |
| Minimierter Overhead | Lazy Load nur aktive Locale |

### 2. Status / Coverage
| Aspekt | Status |
|--------|--------|
| Sprachen | 11 (en + 10 weitere) |
| Laufzeit-Umschaltung | ✔ (Settings) |
| Interpolation | ✔ (`{dir}`, `{branch}`, `{count}`, `{code}` …) |
| Kategorien / Dateityp-Dialog | ✔ Vollständig lokalisiert |
| Setup Flow & Token / Device Flow | ✔ |
| Offline / Snapshot UI | ✔ |
| Fehlermeldungen & Netzwerkzustände | ✔ |
| Pluralisierung | Basis (einfache Zählstrings) – ICU Ausbau möglich |

### 3. Architektur Kurzübersicht
```
LanguageSwitcher  ─▶ LocalizationController ─▶ SharedPreferences
				│                          │
				▼                          ▼
		 MaterialApp ◀────────── AppLocalizations (flutter_gen)
```
* `LocalizationController` hält aktuelle `Locale` & benachrichtigt Listener.
* `MaterialApp` reagiert über `locale` + Delegates.
* UI holt Strings immer: `final l10n = AppLocalizations.of(context)!;`.

### 4. Wichtige Dateien
| Datei | Zweck |
|-------|-------|
| `l10n.yaml` | Konfiguration (`arb-dir`, `template-arb-file`, `output-class`) |
| `pubspec.yaml` | `flutter_localizations`, `intl`, `generate: true` |
| `lib/l10n/app_en.arb` | Template / Quelle aller Keys |
| `lib/l10n/app_<locale>.arb` | Übersetzungen | 
| `main.dart` | Delegates + Supported Locales Registrierung |
| Screen Dateien | Nutzung lokalisierter Strings statt Hardcodes |

### 5. Verwendung im Code
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Widget build(BuildContext context) {
	final l10n = AppLocalizations.of(context)!;
	return Text(l10n.appTitle); // Beispiel
}
```

### 6. Neue Sprache hinzufügen (How‑To)
1. `app_en.arb` kopieren zu `app_<locale>.arb` (Struktur beibehalten).
2. Werte übersetzen (Keys unverändert lassen).
3. Locale zu `supportedLocales` (und ggf. Language-Auswahl UI) hinzufügen.
4. `flutter pub get` oder `flutter run` zwecks Code-Generierung.
5. UI sichten (Layout-Stretch bei längeren Strings prüfen).

### 7. Qualität & Validierung
| Check | Ergebnis |
|-------|----------|
| Rest-Hardcodes Deutsch | Entfernt / neutralisiert |
| File-Type Dialog | Lokalisiert (Titel, Kategorien, Status) |
| Kategorie-Bezeichner intern | Neutrale Canonical Strings + Anzeige lokalisiert |
| Fehlende Keys Warnungen | 0 (letzter Build) |
| Konsistenz Platzhalter | Einheitliche `{placeholder}` Syntax |

Regelmäßige Sicherung: Suche (Regex) nach deutschen Begriffen (`grep -iE "Ä|Ö|Ü|ß|…"`).

### 8. Metriken & Pflege
Aktuelle String-Anzahl (UI-relevant, inklusive Setup & FileType Dialog): >70 Schlüssel synchronisiert in 11 Sprachen.

Pflegeprozess bei neuen Features:
1. Key in `app_en.arb` hinzufügen (alphabetisch oder thematisch gruppiert).
2. Kurz `flutter pub get` → Build schlägt Warnung bei fehlenden Übersetzungen für andere Locales (falls `untranslated-messages` konfiguriert) – dann übersetzen.
3. Review: Platzhalter konsistent? Satzzeichen? Kontextkommentar ggf. als `@`-Metadaten ergänzen (kann später hinzugefügt werden).

### 9. Geplante Erweiterungen
| Item | Nutzen |
|------|-------|
| ICU Pluralformen | Sprachspezifische Grammatik für counts |
| RTL (ar, he) | Globale Reichweite, Directionality Test |
| Datum/Zahl Formatierung | Locale-korrekte Darstellung (intl DateFormat) |
| Lokalisierte Kategorie-Tooltips | Feinere UX |
| Externer CSV/JSON Export | Einfaches Outsourcing von Übersetzungen |

### 10. FAQ (i18n-spezifisch)
| Frage | Antwort |
|-------|---------|
| Warum Englisch als Template? | Höchste Neutralität + internationale Reichweite |
| Was tun bei fehlender Übersetzung? | Fallback => Englisch, Build Warnung prüfen |
| Können Übersetzer ohne Flutter arbeiten? | Ja: Nur `.arb` bearbeiten, PR öffnen |
| Wann Pluralformen einführen? | Sobald mehrere count-sensitive Sätze entstehen |

### 11. Changelog (i18n)
| Datum | Änderung |
|-------|---------|
| Initial | Einführung Basis-Keys & 11 Sprachen |
| Setup Erweiterung | Token / Device Flow Strings hinzugefügt |
| FileType Dialog | Kategorien + Dialogschlüssel ergänzt |
| Konsolidierung | Separate i18n Markdown Dateien entfernt, README erweitert |

---

## Vorlese-Funktion (Text-to-Speech)

Die integrierte Vorlese-Funktion macht längere Dokumentationsabschnitte hörbar und unterstützt Fokus‑/Unterwegs‑Szenarien.

### 1. Ziele
| Ziel | Umsetzung |
|------|-----------|
| Schneller Einstieg | Ein Klick auf Play liest gesamtes Dokument (aktueller Tab) |
| Kontexttreue | Absatz-/Satzgrenzen bleiben erhalten (Chunking) |
| Feiner Start | Start-Slider erlaubt Versatz über Wortindex / Absatzzuordnung |
| Mehrsprachigkeit | Verwendet vorhandene Locale + auswählbare Stimmen |
| Geräuscharm | Kurze Sätze werden gemerged + minimale Pausen zwischen Chunks |
| Persistenz | Rate, Pitch, Modus, Sprache & Stimme werden gespeichert |

### 2. UI Elemente
| Element | Beschreibung |
|---------|--------------|
| Play (Start) | Startet Vorlesen ab Dokumentanfang oder gewähltem Wort |
| Stop | Sofortiger Abbruch & Reset Status |
| Sprache / Stimme Dropdown | Gefilterte Liste verfügbarer Engine-Sprachen & Voices (Favoriten / Flaggen) |
| Speed Slider | Anpassung der Sprechgeschwindigkeit (persistiert) |
| Pitch Slider | Stimmhöhe (persistiert) |
| Modus (intern) | Chunking-Modi: Wörter, Sätze, Blöcke (Absätze) |
| Start bei Wort Slider | Definiert Wortindex; für Sätze/Blöcke wird automatisch an Anfang des entsprechenden Satzes / Absatzes gesprungen |
| Absatz-Vorschau | Zeigt Textauszug des Absatzes, der beim aktuellen Slider‑Wert vorgelesen wird |

### 3. Chunking Modi
| Modus | Strategien | Einsatz |
|-------|------------|--------|
| words | Gruppen von 20 Wörtern (konstante Länge) | Präziser Wiedereinstieg / Debug |
| sentences | Regex Split an Satzendzeichen, sehr kurze Sätze werden mit folgendem kombiniert (<25 Zeichen) | Natürliche Prosodie |
| blocks | Absatzbasiert (Doppel‑Newlines). Lange Absätze werden weich an Wortgrenzen gesplittet (~200–220 Zeichen) | Dokumentationskapitel |

### 4. Startversatz & Absatzlogik
Der Slider berechnet zunächst einen Wortindex im bereinigten Plaintext. Für words wird exakt ab diesem Wort begonnen; für sentences/blocks wird der Chunk ermittelt, der das Wort enthält – der Chunk wird vollständig vorgelesen (kein abgeschnittener Satz / Absatz). Dadurch wirkt der Einstieg natürlicher.

### 5. Persistenz Keys
| Key | Bedeutung |
|-----|-----------|
| `tts:rate` | Sprechgeschwindigkeit |
| `tts:pitch` | Stimmlage |
| `tts:mode` | Ausgewählter Chunk-Modus (Index) |
| `tts:lang` | Letzte Sprache (Locale) |
| `tts:voice` | Letzte ausgewählte Stimme |

### 6. Audio Qualität (Knacken Minimierung)
| Maßnahme | Wirkung |
|----------|--------|
| Merging kurzer Sätze | Weniger harte Engine-Re-Initialisierungen |
| 60ms Delay zwischen Chunks | Weichere Übergänge, reduziert Knackgeräusche |
| Konsistente Gruppengröße (words) | Gleichmäßiger Ausgabefluss |

Geplant: Adaptive Pausen basierend auf Satzlänge, optional SSML (sofern Engine unterstützt), einstellbares Zwischen-Silence.

### 7. Grenzen & Edge Cases
| Fall | Verhalten |
|------|-----------|
| Inline Code / Backticks | Vorlesen entfernt Formatierung (bereinigt) |
| Große Tabellen | Linearisiert als Text (evtl. monotone Aufzählung) |
| Emojis | Entfernt / ersetzt (kein TTS Name Call) |
| Sprachwechsel im Dokument | Kein automatischer Locale Switch pro Abschnitt |

### 8. Erweiterungsideen (Roadmap Ergänzung)
| Idee | Nutzen |
|------|-------|
| Wort-Highlighting im Scrolltext | Visueller Sync beim Hören |
| Fortschritts-Sprungmarken (Absatzliste) | Kapitelnavigation auditiv |
| Export als Audio (lokal) | Offline Hörversionen |
| Dynamik-Anpassung (AGC) | Lautstärke-Konsistenz |
| Satz-/Absatz-Zähler Overlay | Orientierung bei langen Dokus |

### 9. Entwickler Hinweise
Zentrale Implementierung: `TtsService` (`lib/services/tts_service.dart`).
| Methode / Feld | Zweck |
|----------------|------|
| `start(fullText, startWord, overrideMode)` | Baut Chunks + initialisiert Wiedergabe |
| `_buildChunks()` | Chunking Strategie je Modus |
| `_cleanText()` | Entfernt Markdown / Inline Artefakte für robustes TTS |
| `currentChunk` / `currentWord` (ValueNotifier) | UI Bindings für Fortschritt / Highlight |

Fehlertoleranz: Sprache / Voice werden beim Init re-gesetzt; wenn nicht verfügbar -> Engine default (kann stumm wirken falls keine passende Stimme). Geplant: Fallback-Kaskade (z.B. de-DE → de → en-US).

### 10. Nutzung Quick Demo
1. Dokument öffnen.
2. Play drücken → gesamter Inhalt ab Anfang.
3. Für späteren Einstieg: Dialog öffnen → Slider bewegen → „Ab hier vorlesen“ (Dialog schließt automatisch).
4. Geschwindigkeit & Pitch anpassen → Werte werden sofort persistiert.

---


