// ============================================================================
// RepoReader
// File: config.dart
// Author: Mindoro Evolution
// Description: Zentrale statische Laufzeit-Konfiguration & GitHub URL Helper.
// ============================================================================
/// Konfiguration (AppConfig)
/// ========================
/// Zentrale, rein statische Konfiguration & URL-Helfer.
///
/// Design-Prinzipien:
/// * Keine Seiteneffekte (ausser reinem Setzen interner statischer Felder via `configure`).
/// * Kein IO – Persistenz erfolgt ausschliesslich in Setup-/Service-Schichten.
/// * Leere Default-Werte für `owner` & `repo` erzwingen explizites First-Run Setup (kein versehentlicher Fremdzugriff).
///
/// Wichtige Felder:
/// * `owner`, `repo`, `branch`, `dirPath` – bestimmen Wurzel & Navigationsbereich.
/// * `cacheVersion` – erhöht werden wenn Parser / Preprocessing inkompatibel geändert wird.
/// * `githubToken` – optionaler read‑only PAT (setzt höhere Rate Limits / private Repos).
///
/// Hinweis: Für dynamische Laufzeit-Umschaltungen (Repo-Wechsel) immer zuerst Caches leeren
/// (siehe `WikiService.clearAllCaches`) bevor neue Werte via `configure()` gesetzt werden.
class AppConfig {
  // Default Werte (Fallback)
  // Leere Defaults erzwingen Setup beim ersten Start.
  static const _defaultOwner   = '';
  static const _defaultRepo    = '';
  static const _defaultBranch  = 'main';
  static const _defaultDirPath = ''; // leer = gesamtes Repo Root durchsuchen

  // Aktuelle (effektive) Werte – initial auf Default, können zur Laufzeit via configure() überschrieben werden.
  static String _owner   = _defaultOwner;
  static String _repo    = _defaultRepo;
  static String _branch  = _defaultBranch;
  static String _dirPath = _defaultDirPath;
  static String? _runtimeToken; // optional zur Laufzeit gesetzt

  /// Zugriff auf aktuelle effektive Werte
  static String get owner => _owner;
  static String get repo => _repo;
  static String get branch => _branch;
  static String get dirPath => _dirPath;

  // Falls du später doch Wiki-Modus willst, lassen wir die Felder drin
  static const homePage = 'Home.md';
  static const sidebar  = '_Sidebar.md';

  /// Optionales Token für höhere Rate Limits (read-only PAT). Per `--dart-define` reinreichen.
  static const _buildTimeToken = String.fromEnvironment('GITHUB_TOKEN', defaultValue: '');
  static String get githubToken => _runtimeToken ?? _buildTimeToken;

  /// Optionaler GitHub OAuth Client (Device Flow). Setzbar via --dart-define GITHUB_CLIENT_ID=abc123
  static const githubClientId = String.fromEnvironment('GITHUB_CLIENT_ID', defaultValue: '');

    // Increment this when preprocessing / parsing changes so cached markdown invalidates.
  /// Version der Cache-Struktur. Bei inhaltlich inkompatiblen Parser/Sanitizer Änderungen inkrementieren.
  static const cacheVersion = 2; // v2 after image + paragraph + link improvements

  // RAW-Basis für Repo-Dateien
  /// Liefert eine Raw-Content URL für eine Datei im Repo.
  static String rawFile(String relativePath) => 'https://raw.githubusercontent.com/$owner/$repo/$branch/$relativePath';

  // GitHub Contents API (List Directory)
  /// GitHub *Contents API* URL (List Directory). Nutzt JSON Antwort.
  static Uri listDirUri(String path) => Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$path?ref=$branch');

  // Git tree API (recursive listing)
  /// GitHub *Git Tree API* (rekursives Listing) – liefert SHA Hashes für Änderungsdetektion.
  static Uri gitTreeUri() => Uri.parse('https://api.github.com/repos/$owner/$repo/git/trees/$branch?recursive=1');

  /// Laufzeit-Konfiguration setzen. Null-Werte lassen alte bestehen.
  static void configure({String? owner, String? repo, String? branch, String? dirPath, String? token}) {
    if (owner != null && owner.isNotEmpty) _owner = owner;
    if (repo != null && repo.isNotEmpty) _repo = repo;
    if (branch != null && branch.isNotEmpty) _branch = branch;
    if (dirPath != null && dirPath.isNotEmpty) _dirPath = dirPath;
    if (token != null && token.isNotEmpty) _runtimeToken = token;
  }

  /// Setzt alles auf Defaults zurück (z.B. beim "Anderes Repo" Wechsel + Reset).
  static void resetToDefaults() {
    _owner = _defaultOwner;
    _repo = _defaultRepo;
    _branch = _defaultBranch;
    _dirPath = _defaultDirPath;
    _runtimeToken = null;
  }
}
