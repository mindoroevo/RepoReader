<div align="center">

# 📚 RepoReader

_Multi-platform Flutter app (Android • iOS • Web • Windows • macOS • Linux) for **live reading, navigating, searching, offline using and change detection** of documentation & arbitrary repository files (text + selected binary types) directly via GitHub APIs – without a custom backend server._

<p>
<img alt="Platforms" src="https://img.shields.io/badge/platform-android%20|%20ios%20|%20web%20|%20desktop-blue" />
<img alt="Dart" src="https://img.shields.io/badge/dart-%3E=3.7-informational" />
<img alt="Status" src="https://img.shields.io/badge/status-alpha-orange" />
<img alt="Offline" src="https://img.shields.io/badge/offline-snapshot-green" />
<img alt="License" src="https://img.shields.io/badge/license-restricted-critical" />
</p>

_TL;DR:_ README / documentation navigation • All files (flat + tree) • Universal file viewer • Offline snapshot mode • Change badges + diff • Full text & advanced search • Favorites • Token (PAT / Device Flow) • Caching • Markdown preprocessing & sanitizing.

</div>

---

## Table of Contents
1. [Quick Start](#quick-start)
2. [Why? Goals & Scope](#why-goals--scope)
3. [Feature Overview (Short)](#feature-overview-short)
4. [Feature Matrix (Detailed)](#feature-matrix-detailed)
5. [View Modes](#view-modes)
6. [Setup & First Run](#setup--first-run)
7. [Configuration Sources & Persistence](#configuration-sources--persistence)
8. [Token / Auth (PAT & Device Flow)](#token--auth-pat--device-flow)
9. [Favorites & Extension Filter](#favorites--extension-filter)
10. [Change Detection & Diff](#change-detection--diff)
11. [Search System](#search-system)
12. [File Type Categorization & Universal Reader](#file-type-categorization--universal-reader)
13. [Markdown Preprocessing & Sanitizing](#markdown-preprocessing--sanitizing)
14. [Naming Logic & Title Derivation](#naming-logic--title-derivation)
15. [Offline Snapshot Mode](#offline-snapshot-mode)
16. [Caching Strategy](#caching-strategy)
17. [Architecture & Layering](#architecture--layering)
18. [Data Flow (End-to-End)](#data-flow-end-to-end)
19. [Theming & UX Principles](#theming--ux-principles)
20. [Public API / Functions (lib directory)](#public-api--functions-lib-directory)
21. [Configuration (AppConfig)](#configuration-appconfig)
22. [Build & Run](#build--run)
23. [Testing & Quality Assurance](#testing--quality-assurance)
24. [Security & Privacy](#security--privacy)
25. [Performance & Scaling](#performance--scaling)
26. [Troubleshooting](#troubleshooting)
27. [FAQ](#faq)
28. [Roadmap](#roadmap)
29. [Contribution Guidelines](#contribution-guidelines)
30. [License](#license)
31. [Credits](#credits)
32. [Internationalization (i18n)](#internationalization-i18n)
33. [Tips & Onboarding](#tips--onboarding)
34. [Universal File Browser](#universal-file-browser)
35. [Advanced Search (Details)](#advanced-search-details)
36. [Change Polling & Notifications](#change-polling--notifications)
37. [Device Flow (GitHub Login)](#device-flow-github-login)

---

## Quick Start
```bash
flutter pub get
flutter run -d windows   # or chrome / linux / macos / ios / android
```
Setup screen appears (no default repo). Paste GitHub repo URL → Save → Navigation loads. Optional: add PAT.

Minimal first run:
1. Paste URL (e.g. `https://github.com/OWNER/REPO`)
2. (Optional) PAT for private repos / rate limit
3. Save → README / files appear
4. Open extension dialog → enable additional file types

---

## Why? Goals & Scope
| Goal | Description |
|------|-------------|
| Instant knowledge access | No build / static site generator required |
| Unified presentation | Consistent UI across platforms & repos |
| Minimal assumptions | Works without dedicated `docs/` folder (root mode) |
| Change transparency | Quick overview: what changed since last visit? |
| Universality | Not only README – also code, config, plaintext, images |
| Offline robustness | Last known state remains usable |

Out of scope (currently): editing files, PR creation, write-scope auth flows.

---

## Feature Overview (Short)
README grouping • Fulltext navigation • Explorer • Universal file viewer • Change diff • Favorites • Advanced search • Token support • Caching • Preprocessing & sanitizing • Theming.

---

## Feature Matrix (Detailed)
| Category | Features | Notes |
|----------|----------|-------|
| Navigation | README based group cards, flat all list, explorer tree | Cyclic toggle, persisted |
| Title derivation | README folder name, file name fallback | Numeric prefix stripping planned |
| Files | Text, images, basic binary detection | PDF / archive placeholders |
| Search | Markdown fulltext + extended text file search | Multi token AND logic |
| Diff | Added/Modified/Removed, line diff | Word-level planned |
| Change badge | Persistent signature comparison | Manual acknowledge |
| Preprocessing | HTML→MD, link & image rewrite, sanitizing | Idempotent |
| Favorites | Path list, persisted | Quick access |
| Extensions | Global dialog, categories & search | Affects grouping cards |
| Caching | Versioned keys, snapshot, acknowledge | No global TTL yet |
| Auth | Optional PAT | Fine-grained recommended |
| Theming | System / Light / Dark | Material 3 |
| Platforms | Desktop, Mobile, Web PWA | Window / page title “RepoReader” |

---

## View Modes
| Mode | Description | Typical use |
|------|-------------|-------------|
| README | Grouped via README-like files; additional text integrated | Documentation / knowledge |
| All files (flat) | Linear, alphabetical / category sorting | Large overview |
| Explorer (tree) | Directory structure, collapsible | Development / context |

Toggle via rotating AppBar icon. State persisted in `pref:mainViewMode`.

---

## Setup & First Run
| Step | Action | Result |
|------|--------|--------|
| 1 | Launch app | Setup screen (empty config) |
| 2 | Repo URL | Parser extracts owner / repo / branch / optional subdir |
| 3 | (Optional) PAT | Raises rate limit / private repos |
| 4 | Save | Config persisted + clears old cache → initial index build |
| 5 | (Optional) Extensions | More file types visible |

Supported URL patterns:
```
https://github.com/OWNER/REPO
https://github.com/OWNER/REPO/tree/BRANCH/path/to/dir
https://raw.githubusercontent.com/OWNER/REPO/BRANCH/path/to/file.md
```
Fallbacks: Branch → `main` if not explicit; empty directory = root.

---

## Configuration Sources & Persistence
Persistent keys: `cfg:owner`, `cfg:repo`, `cfg:branch`, `cfg:dir`, `cfg:token`, `pref:activeExtensions`, `pref:mainViewMode`, `fav:paths`, `snapshot:v1`, `changes:ackSignature`, `cache:v2:<path>`.

Priority:
1. User setup (SharedPreferences)
2. Dart-define token: `--dart-define=GITHUB_TOKEN=...`
3. Defaults (empty) → forces setup

---

## Token / Auth (PAT & Device Flow)
| Purpose | Permission | Note |
|---------|------------|------|
| Raise rate limit | Fine-grained `contents:read` | 60 → 5k req/h |
| Private repo access | Same | No write needed |
| Classic fallback | `repo` (broad) | Only if fine-grained impossible |

Creation (fine-grained): Settings → Developer settings → Fine-grained tokens → Choose repo → Permission `contents:read` → expiry → generate.

Storage: Currently plaintext (SharedPreferences) – secure storage on roadmap.

Errors / symptoms:
| Symptom | Cause | Fix |
|---------|-------|-----|
| 401 | Invalid/expired token | Generate new token |
| 403 | Rate limit no token | Add PAT / wait |
| 404 private file | Missing permission | Adjust token scope |
| Only 60/h | No token active | Provide PAT |

Remove: Clear field + save.

---

## Favorites & Extension Filter
Favorites: Toggle on file / group card → persisted under `fav:paths`.

Extension dialog:
1. Open (filter/tune icon)
2. Category chips (Code / Config / Docs / Media / Archive / Other)
3. Search by extension (`yaml`, `svg` ...)
4. Apply selection → persisted `pref:activeExtensions`
5. README cards badge counts extra files in scope

Rationale: global = simpler mental model & persistence.

---

## Change Detection & Diff
Process:
1. Git tree (recursive) → map path→SHA
2. Compare with local snapshot (`snapshot:v1`)
3. Classify: Added / Modified / Removed
4. Line diff for modified text files
5. Snippets (sanitized) in change dialog
6. Aggregate signature (hash) → acknowledge key

Design decisions:
| Area | Decision | Reason |
|------|----------|-------|
| Line diff granularity | No word-level yet | Simplicity / speed |
| Binary files | No diff | Low value |
| Snapshot storage | Plain JSON | Debuggable |

---

## Search System
Markdown search algorithm:
1. Load relevant text files (cache-first)
2. Query → tokens (whitespace, lowercase)
3. File passes if contains all tokens (substring)
4. Snippet = first match ± window
5. Multi token → additional highlights

Extended search: Adds code / config / plain text & filename + category filters.

Planned: scoring (heading > body), fuzzy (Levenshtein), inverted index.

---

## File Type Categorization & Universal Reader
Heuristics: extension allowlist + simple binary detection (unprintable ratio).

| Category | Examples | Display | Note |
|----------|----------|---------|------|
| Documentation | .md .mdx .markdown .rst .adoc | Markdown renderer | Preprocess enabled |
| Plain/Text | .txt .log .csv | Monospace | Wrap / scroll |
| Code | .dart .js .ts .yaml .json .yml .py .java ... | Monospace | Syntax highlighting planned |
| Config | .env .ini .toml | Plain text | 🔒 watch secrets |
| Images | .png .jpg .jpeg .gif .svg .webp | Image widget | Fallback icon if error |
| Archive/Binary | .zip .tar .gz .exe .dll | Meta info only | No download builtin |
| PDF | .pdf | Placeholder | Viewer later |

---

## Markdown Preprocessing & Sanitizing
Pipeline (simplified): normalize EOL → convert structural HTML to MD → center block handling → `<br>` line breaks (outside code) → paragraph normalization → remove nav/footer fragments → rewrite relative image paths → inline HTML conversions → blank line dedup → sanitizing for diff snippets. Designed to be idempotent.

---

## Naming Logic & Title Derivation
| Case | Source | Example |
|------|--------|---------|
| README / readme.* | Parent directory | `docs/README.md` → `docs` |
| index.md / home.md | Parent directory | `guide/index.md` → `guide` |
| Other text file | Filename w/o extension | `01-intro.md` → `01-intro` (numeric prefix stripping planned) |
| Casing | Capitalize first letter | `utilities` → `Utilities` |

---

## Offline Snapshot Mode
Stores a full local snapshot of files inside configured directory scope. Goals: offline reading (text + binary), faster startup, reproducible state.

Directory layout (app documents):
```
offline_snapshots/
  <owner>_<repo>_<branch>/
    meta.json
    files/<repoPath>
```
`meta.json` example (short):
```json
{"owner":"…","repo":"…","branch":"main","created":1730000000,"dirPath":"docs","files":[{"path":"docs/Intro.md","size":1234,"text":true}]}
```
Creation: Settings → "Create snapshot" (overwrites). Priority order (text/binary): Offline → Raw → Contents API → Cache → Error.

---

## Caching Strategy
Keys:
| Key | Meaning |
|-----|---------|
| `cache:v2:<path>` | Markdown plaintext (unfiltered) |
| `universal_cache:v2:<path>` | Any file (text or base64 binary) |
| `tree:snapshot` | Last git tree (markdown path→SHA) |
| `tree:lastSig` | Current signature |
| `tree:ackSig` | Acknowledged signature |
| `favorites:paths` | Favorite list |
| `pref:activeExtensions` | Enabled extensions |
| `offline:enabled` | Offline flag |

Invalidation: version bump (`cacheVersion`). Manual: (planned UI) or reinstall.

---

## Architecture & Layering
```
lib/
  main.dart                 # App bootstrap, theme, routing
  config.dart               # Runtime configuration
  theme.dart                # Color palettes / ThemeMode
  services/
    wiki_service.dart       # GitHub API (Contents/Raw/Tree) + listing + cache
    change_tracker_service.dart
    favorites_service.dart
    private_auth_service.dart
    offline_snapshot_service.dart
    universal_file_reader.dart
  screens/ (home_shell, search, enhanced_search, setup, settings, etc.)
  widgets/ (markdown_view, universal_file_viewer ...)
  utils/ (markdown_preprocess, naming, toc, link parsing)
```
Layer goals: testability, low coupling, clear data flow.

---

## Data Flow (End-to-End)
1. Setup → configure AppConfig
2. HomeShell loads: tree + README index
3. User selects view (README / Flat / Explorer)
4. Opening file: cache lookup → network fallback → preprocess → display
5. Change detection (manual / periodic)
6. Diff results → badge/dialog → acknowledge
7. Search: load content on-demand → tokenization → match & snippets

---

## Theming & UX Principles
| Principle | Implementation |
|-----------|----------------|
| Consistency | Unified cards / badges (Material 3) |
| Speed | Lazy fetch per open |
| Feedback | Badges / snackbar / diff dialog |
| Orientation | Clear separated modes + icons |
| Readability | Preprocessing removes noise |
| Accessibility | High contrast dark theme, system text scaling |

---

## Public API / Functions (lib directory)
Full overview of central classes & key methods (subset – obvious private UI widgets omitted). Parameter lists simplified.

### config.dart – AppConfig
| Element | Description |
|---------|-------------|
| `cacheVersion` | Global cache version number |
| `configure({owner,repo,branch,dirPath,token})` | Sets runtime configuration + persists |
| `resetToDefaults()` | Clears current configuration |
| `rawFile(rel)` | Raw URL for file |
| `gitTreeUri()` | Git Tree API URI (recursive) |
| `listDirUri(path)` | Contents API URI for directory |

### services/universal_file_reader.dart – UniversalFileReader
| Method | Purpose |
|--------|---------|
| `readFile(repoPath)` | Loads text/binary + MIME detection + caching + offline |
| `isTextFile(path)` | Heuristic based on extension |
| `getMimeType(path)` | MIME determination |
| `listAllFilesRecursively(dir)` | All files via Git tree |
| `listFilesByType(dir,exts)` | Filter by extension set |
| `listTextFiles(dir)` | Text only |
| `listBinaryFiles(dir)` | Binary only |
| `clearCache()` | Purges universal cache keys |

`FileReadResult` props: `content`, `fromCache`, `isText`, `mimeType`; helpers: `asText()`, `asBytes()`, `asBase64()`.  
`UniversalRepoEntry`: `name,path,type,extension,mimeType,isText,size`; getters `formattedSize`, `category`.

### services/wiki_service.dart – WikiService
| Method | Purpose |
|--------|---------|
| `fetchMarkdownByRepoPath(path)` | Markdown (Offline → Raw → Contents → Cache) |
| `listMarkdownFiles(dir)` | Non-recursive `.md` in directory |
| `listReadmesRecursively(dir)` | Recursive README navigation |
| `listAllMarkdownFilesRecursively(dir)` | For search / index |
| `fetchAllReadmesWithContent(dir)` | List including contents |
| `fetchFileByPath(path)` | Delegates to UniversalFileReader |
| `listAllFiles(dir)` | All files |
| `listTextFiles(dir)` | Text subset |
| `listBinaryFiles(dir)` | Binary subset |
| `listFilesByCategory(dir)` | Group by category |
| `listFilesByExtensions(dir,exts)` | Extension filter |
| `listCodeFiles(dir)` | Code extension set |
| `listDocumentationFiles(dir)` | Documentation set |
| `listConfigFiles(dir)` | Config set |
| `listImageFiles(dir)` | Image set |
| `listPdfFiles(dir)` | PDFs |
| `fetchTextFile(path)` | Convenience text |
| `fetchBinaryFile(path)` | Convenience binary |
| `fileExists(path)` | HEAD existence check |
| `getFileMetadata(path)` | Metadata lookup |
| `clearAllCaches({keepConfig})` | Global cache purge |
| `ensureIndex()` (static) | README normalization index |
| `resolveExistingReadmePath(cand)` (static) | Canonical path resolution |

### services/offline_snapshot_service.dart – OfflineSnapshotService
| Method | Purpose |
|--------|---------|
| `isOfflineEnabled()` | Checks offline flag |
| `setOfflineEnabled(v)` | Toggle flag |
| `createSnapshot({onProgress})` | Build snapshot (tree + fetch all) |
| `hasSnapshot()` | Snapshot exists |
| `deleteSnapshot()` | Remove snapshot |
| `readTextFileOffline(path)` | Read text |
| `readBinaryFileOffline(path)` | Read binary |
| `listSnapshotFiles()` | Manifest file list |
| `listOfflineNavTextEntries()` | Navigation-relevant text entries |
| `currentSnapshotRootPath()` | Base path (e.g. for images) |

### services/change_tracker_service.dart – ChangeTrackerService
| Method | Purpose |
|--------|---------|
| `detectChanges()` | Compare current tree vs. previous snapshot |
| `markRead(signature)` | Acknowledge a state |
| `acknowledgedSignature()` | Last acknowledged signature |
| `lastCheckedAt()` | Timestamp of last check |
| `_diffLines(path,oldSha)` | (internal) naive line diff |
| `_fetchCurrentSnapshot()` | (internal) Git tree acquisition |

`ChangeSummary`: fields `files,newSignature,timestamp`.  
`ChangeFile`: `path,status,addedLines,removedLines,sample,diff`.  
`DiffLine`: `prefix('+','-',' ','➜')`, `text`.

### services/favorites_service.dart – FavoritesService
| Method | Purpose |
|--------|---------|
| `load()` | Load favorites set |
| `save(favs)` | Persist favorites (sorted) |

### services/private_auth_service.dart – PrivateAuthService
| Method | Purpose |
|--------|---------|
| `loadToken()` | Read token |
| `saveToken(token)` | Persist |
| `clearToken()` | Delete |
| `startDeviceFlow(scopes)` | Device flow start (user_code, verification_uri, interval, device_code) |
| `pollForDeviceToken(deviceCode, interval)` | Poll until access token |

### services/notification_service.dart – NotificationService
| Method | Purpose |
|--------|---------|
| `init()` | Initialize plugin + channel |
| `showChangeNotification(count)` | Local notification |
| `registerWebhookPlaceholder()` | Debug placeholder |

### widgets/markdown_view.dart
Extended Markdown rendering (images offline fallback, future: syntax highlighting, TOC interaction).

### widgets/universal_file_viewer.dart
Renders any file kind via `FileReadResult` (text vs binary heuristics + basic binary preview metadata).

### utils/markdown_preprocess.dart
Multi-stage pipeline (normalization, HTML→MD, image path rewriting, sanitizing). Idempotent by design.

### utils/naming.dart
Title / slug derivation for navigation cards & display.

### utils/wiki_links.dart / toc.dart
Internal link resolution & upcoming table-of-contents generation.

---

## Configuration (AppConfig)
Simplified excerpt:
```dart
class AppConfig {
  static const cacheVersion = 2;
  // configure(), resetToDefaults(), rawFile(), gitTreeUri() etc.
}
```

---

## Build & Run
Requirements: Flutter >= 3.7, Git.

| Target | Example |
|--------|---------|
| Desktop debug | `flutter run -d windows` |
| Web debug | `flutter run -d chrome` |
| Android release | `flutter build apk --release` |
| Web release | `flutter build web --release` |
| Regenerate icons | `dart run flutter_launcher_icons` |

Optional:
```bash
flutter run -d chrome --dart-define=GITHUB_TOKEN=xxxx
flutter run -d chrome --dart-define=FLUTTER_WEB_USE_SKIA=true
```

---

## Testing & Quality Assurance
Focus areas: preprocessing, diff edge cases, search multi-term & casing, naming logic, service fallbacks (404/403/network), offline snapshot integrity.

Planned CI: `flutter analyze`, `flutter test --coverage`, optional golden tests.

---

## Security & Privacy
| Aspect | Status | Note |
|--------|--------|------|
| Token storage | Plaintext SharedPreferences | Secure storage planned |
| Network | Direct GitHub endpoints | No third-party servers |
| Telemetry | None | Privacy by default |
| Permissions | READ only | Low attack surface |
| HTML sanitizing | Basic inline | Extendable |
| Secrets risk | .env can be displayed | User responsibility (filter option later) |

---

## Performance & Scaling
| Component | Approach | Potential |
|-----------|----------|-----------|
| Listing | Tree API + filter | Pagination / lazy expand |
| Search | Linear O(n*m) | Inverted index, ranking |
| Diff | Line-based O(n) | Word-level caching |
| Caching | Version key | Expiry / LRU |
| Images | On-demand | Progressive preview |

---

## Troubleshooting
| Problem | Cause | Fix |
|---------|-------|-----|
| 403 Rate limit | No auth | Add PAT / wait |
| 401 Unauthorized | Invalid token | Regenerate |
| White content | Empty or binary | Check category / open raw |
| Missing images | Paths outside root | Use root mode or adjust path |
| No diff | Only add/remove | Expected |
| Slow search | Huge repo | Filter / upcoming index |
| README titles everywhere | Detection issue | Check preprocessing / naming |

---

## FAQ
**Why no default repo?** Intentional source, privacy, explicit control.

**Multiple repos simultaneously?** Currently single-context; profiles possible later.

**Enterprise GitHub instances?** Not yet; base URL would need to be configurable.

**File editing?** Read-only by design.

**Why plaintext token?** Alpha focus on functionality; secure storage planned.

**Offline?** Snapshot or cached content only.

**Syntax highlighting?** On the roadmap.

---

## Roadmap
The full roadmap is maintained in `docs/roadmap.md`. This section highlights the top priorities:

- TOC scroll/jump
- Word-level diff
- Rate-limit UI (parse/display GitHub headers)
- Syntax highlighting for code
- Advanced search (fuzzy/ranking)

Details and status: see docs/roadmap.md.
| Priority | Item | Status |
|----------|------|--------|
| High | TOC scroll / jump | open |
| High | Word-level diff | open |
| High | Rate limit UI (header parsing) | open |
| Medium | Syntax highlighting | open |
| Medium | Fuzzy + ranking search | open |
| Medium | Secure token storage | open |
| Low | Offline export (ZIP cache) | open |
| Low | Numeric prefix title filter | open |
| Low | PDF inline viewer | open |

---

## Contribution Guidelines
Internal focus – external PRs limited.
| Step | Guideline |
|------|-----------|
| Branch naming | `feat/<short>`, `fix/<issue>`, `refactor/<area>` |
| Scope | Small focused changes |
| Tests | Core logic preferred |
| Secrets | No tokens / keys committed |
| Code style | Short functions, services encapsulate I/O, pure utils |

Review checklist: `flutter analyze` clean? Manual smoke tests pass? README updated if behavior changes.

---

## License
Restricted internal / private use. No public fork, distribution, SaaS offering without approval.

| Allowed | Forbidden |
|---------|----------|
| Internal use | Public mirrors |
| Local modifications | App store publishing |
| Test deployments | Commercial resale |

Potential future open-source (e.g. MIT) – not guaranteed.

Contact: <mindoro.evolution@gmail.com>

---

## Credits
Author: **Mindoro Evolution** – thanks to the Flutter / Dart and broader OSS communities. _Last content maintenance: see Git history._

---

## Internationalization (i18n)
The app is fully localized: English (default) + 10 additional languages (de, fr, es, it, pt, ru, nl, ja, ko, zh). All visible UI strings (navigation, dialogs, errors, setup flow, extended search, file type dialog, offline/snapshot, token & device flow) are translated.

### Overview
| Aspect | Status |
|--------|--------|
| Languages | 11 total |
| Runtime switch | Yes (Settings → Language) |
| Persistence | SharedPreferences (`pref:locale`) |
| Fallback | en |
| Placeholders / interpolation | Yes (`{dir}`, `{branch}`, `{count}`, `{code}` …) |
| New keys | Auto code-gen via `flutter_gen` |
| System locale auto detect | Partial (fallback to en) |
| Pluralization (ICU) | Basic; expansion possible |

### Key Files
| File | Purpose |
|------|---------|
| `l10n.yaml` | Flutter localization config |
| `lib/l10n/app_*.arb` | Translation resources (template: `app_en.arb`) |
| `pubspec.yaml` | Enables `generate: true`, dependencies |
| `main.dart` | Delegates & supported locales |
| Screens | Use `AppLocalizations` instead of hardcoded strings |

### Usage
```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.appTitle);
```

### Add a New Language
1. Copy `app_en.arb` to `app_<locale>.arb`.
2. Translate all values.
3. Add locale to `supportedLocales` and language selector.
4. Run `flutter pub get`.
5. Verify layout with longer strings.

### Quality & Completeness
Hard-coded German remnants removed; category labels normalized to canonical English internally & localized at render time. File type dialog fully localized (title, search hint, status bar, categories, apply/none/all). Synchronization key (e.g. `reset`) added across all locales.

### Future Enhancements
- ICU plural forms for all count-based strings
- RTL locales (ar, he)
- Date/number formatting by locale (intl DateFormat)
- External translation export pipeline

### Architecture
```
LanguageSwitcher  ─▶ LocalizationController ─▶ SharedPreferences
  │                          │
  ▼                          ▼
     MaterialApp ◀────────── AppLocalizations (flutter_gen)
```
* `LocalizationController` holds current locale & notifies listeners.
* `MaterialApp` rebuilds with new `locale`.
* All widgets fetch strings through `AppLocalizations.of(context)!`.

### Metrics
| Component Group | Localized Strings | Languages |
|-----------------|------------------|-----------|
| Core navigation | 20+ | 11 |
| File operations | 10+ | 11 |
| Setup & token flow | 30+ | 11 |
| Extended search | 15+ | 11 |
| File type dialog | 10+ | 11 |
| Misc / status / errors |  -  | 11 |
| **Total** | **>70** | **11** |

### Quality & Validation
| Check | Result |
|-------|--------|
| Remaining hard‑coded German strings | Removed / neutral canonical values |
| Missing key warnings (build) | 0 |
| Consistent placeholder syntax | Yes (`{placeholder}`) |
| File type dialog coverage | Complete (title, search hint, categories, status, actions) |
| Setup flow completeness | All steps & token/device statuses localized |

### Maintenance Workflow
1. Add key to `app_en.arb` (template).  
2. Run `flutter pub get` (code-gen).  
3. Add translations to all other `app_<locale>.arb`.  
4. Build; ensure no untranslated warnings.  
5. If introducing counts, evaluate ICU plural form early.  
6. Commit with message `i18n: add <feature> keys`.

### FAQ (i18n-specific)
| Question | Answer |
|----------|--------|
| Why English template? | Neutral & widely understood |
| What if translation missing? | Fallback to English, build warns |
| How to involve translators? | Provide `.arb` only; no Dart knowledge required |
| When to introduce plural rules? | Once multiple count-sensitive variants emerge |

### Changelog (i18n)
| Stage | Description |
|-------|-------------|
| Initial | Base keys + 11 locales added |
| Setup expansion | Added token & device flow strings |
| File type dialog | Added dialog + category keys |
| Consolidation | Removed separate i18n docs; merged into README |

---

## Tips & Onboarding

Short one-time tips make features discoverable without cluttering the UI.

- Components
  - `lib/widgets/tips_overlay.dart`: semi-transparent overlay tour with target highlight and Skip/Next/Done.
  - `lib/services/tips_service.dart`: persistence of shown tips (`pref:tips:<key>`).
  - Integrated in `home_shell.dart` (home tips), `page_screen.dart` (page tips), `setup_screen.dart` (setup tips).
- Onboarding
  - One-time welcome flow (`pref:onboardingSeen`) triggered if no source is configured.
  - Afterwards opens the setup input; PAT is optional.
- Reset
  - Show tips again: delete `pref:tips:*`; re-show onboarding: delete `pref:onboardingSeen`. Full reset via Setup → “Wipe all”.

---

## Universal File Browser

Overview of ALL repository files (text and binary) with filtering, search and quick preview.

- Screen: `lib/screens/universal_file_browser_screen.dart`
- Viewer: `lib/widgets/universal_file_viewer.dart`
- Listing/typing: `lib/services/universal_file_reader.dart` (+ `WikiService`)
- Features
  - Category grouping or flat list; search by name/path; “text only” filter.
  - Stats (visible/total count, approximate total size).
  - Quick preview dialog and full detail view.
- Notes
  - PDFs show a placeholder + download/copy actions; code highlighting planned.

---

## Advanced Search (Details)

Combines content and filename/path search over all files with category filter and progressive results.

- Screen: `lib/screens/enhanced_search_screen.dart`
- Filters & UI
  - Chips: Content, Filename, Text only; Category selector (internal sentinel `'ALL_INTERNAL'` for “all”).
  - Snippets: context window with highlighted matches (rendered as RichText).
- Algorithm
  - O(n·m): n files, m terms (AND). Content is loaded only for text files.
  - Progressive updates in batches; new input cancels running searches.
- Data sources
  - Files via `WikiService.listAllFiles(..)`/`listTextFiles(..)`; content via `fetchFileByPath(..)`.

---

## Change Polling & Notifications

Periodic check for changes with exponential backoff and optional system notifications.

- Flow
  - Controlled in `lib/screens/home_shell.dart`: minute ticker; base interval `pref:pollMinutes` (default 5).
  - Backoff: doubles effective interval every 5 “no change” cycles (up to 8× base).
  - Detection/details via `ChangeTrackerService` (`lib/services/change_tracker_service.dart`).
- Notifications
  - `NotificationService` shows platform notifications (Android/iOS/Desktop), guarded by permission where required.
  - Preference `pref:notifyChanges` (default on).
- Relevant preferences
  - `pref:pollMinutes`, `pref:notifyChanges`, `pref:showChangeDialog`.

---

## Device Flow (GitHub Login)

Alternative to manual PAT entry using GitHub Device Authorization Flow—no client secret required.

- Components
  - Service: `lib/services/private_auth_service.dart` (start/poll, secure storage)
  - WebView screen: `lib/screens/device_login_webview.dart` (or external browser fallback)
  - Setup integration: `lib/screens/setup_screen.dart` (token is transferred into the field and saved to `cfg:token`).
- Requirements
  - Build-time: `--dart-define=GITHUB_CLIENT_ID=<client_id>`.
- Flow
  - Start → show code/URL → open verification page → poll until token granted → store token → apply in setup → save.
- Security
  - Fine‑grained read-only scope recommended (Contents: Read). Token stored via secure storage.
