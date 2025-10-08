// ============================================================================
// RepoReader
// File: wiki_service.dart
// Author: Mindoro Evolution
// Description: Kernservice für Markdown Fetching, Index & universelle Datei-APIs.
// ============================================================================
import 'dart:convert';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'universal_file_reader.dart';
import 'offline_snapshot_service.dart';

/// Einfaches Datenobjekt für einen Repository-Eintrag (Datei oder Verzeichnis).
/// In dieser App werden nur Einträge mit `type == 'file'` und der Endung `.md`
/// weiterverarbeitet.
class RepoEntry {
  final String name;
  final String path;
  final String type; // 'file' | 'dir'
  RepoEntry({required this.name, required this.path, required this.type});
}

/// WikiService
/// ===========
/// Kernservice für markdown-spezifische Operationen & ergänzende Dateilisten.
///
/// Verantwortlichkeiten:
/// * Abruf & Caching von Markdown-Dateien (Raw → Contents API → Cache)
/// * Rekursive Ermittlung von README-Navigationseinträgen (Git Tree API)
/// * Aufbau eines Normalisierungsindex für robuste Relative-Link-Auflösung
/// * Aggregations-Hilfen (alle Readmes + Inhalte, alle Markdown-Dateien)
/// * Delegation universeller Dateifunktionen an `UniversalFileReader`
///
/// Nicht-Ziele:
/// * Preprocessing / Sanitizing (→ `markdown_preprocess.dart`)
/// * Diff / Änderungslogik (→ `change_tracker_service.dart`)
/// * Relevanz-Ranking / Volltextindex (nur naive Iteration)
///
/// Caching:
/// * Key: `cache:v<version>:<repoPath>` (reiner Klartext ohne Preprocessing im Service – Preprocessing geschieht beim Abruf in UI)
/// * Invalidation durch Versionserhöhung oder globales Löschen
///
/// Sicherheit: Token wird nur angehängt falls gesetzt; keine Speicherung sensibler Daten jenseits SharedPreferences (Plaintext!) – für private Repos künftig Secure Storage erwägen.
class WikiService {
  final _client = http.Client();
  final _universalReader = UniversalFileReader();

  // Static index of available README paths (normalized -> actual path)
  static Map<String, String>? _readmeIndex;
  static bool _buildingIndex = false;

  static String _normalize(String path) {
    var p = path;
    p = p.replaceAll('\\', '/');
    if (AppConfig.dirPath.isNotEmpty) {
      final prefix = AppConfig.dirPath.endsWith('/') ? AppConfig.dirPath : '${AppConfig.dirPath}/';
      if (p.startsWith(prefix)) p = p.substring(prefix.length);
    }
    p = p.replaceAll(RegExp(r'/README\.md$', caseSensitive: false), '');
    p = p.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');
    p = p.toLowerCase();
    return p;
  }

  /// Baut – sofern nicht vorhanden – den README Normalisierungsindex auf.
  static Future<void> ensureIndex() async {
    if (_readmeIndex != null || _buildingIndex) return;
    _buildingIndex = true;
    try {
      final svc = WikiService();
      final entries = await svc.listReadmesRecursively(AppConfig.dirPath);
      final map = <String,String>{};
      for (final e in entries) {
        map[_normalize(e.path)] = e.path; // store canonical
      }
      _readmeIndex = map;
    } catch (_) {
      // ignore; fallback just won't have index
    } finally {
      _buildingIndex = false;
    }
  }

  /// Passt einen eingegebenen README Pfad (evtl. andere Groß/Kleinschreibung,
  /// fehlendes `README.md`) an den echten Pfad an sofern im Index vorhanden.
  static Future<String> resolveExistingReadmePath(String candidate) async {
    await ensureIndex();
    final idx = _readmeIndex;
    if (idx == null) return candidate;
    final norm = _normalize(candidate);
    final hit = idx[norm];
    return hit ?? candidate;
  }

  Map<String, String> get _headers {
    final base = <String,String>{
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'RepoReaderApp/1.0 (+https://example.local)'
    };
    if (AppConfig.githubToken.isNotEmpty) {
      base['Authorization'] = 'Bearer ${AppConfig.githubToken}';
    }
    return base;
  }

  /// Liefert `(Inhalt, fromCache)` einer Markdown-Datei.
  /// Strategiereihenfolge: Raw → Contents API → Cache → Exception.
  Future<(String text, bool fromCache)> fetchMarkdownByRepoPath(String repoPath) async {
    // repoPath z.B. 'docs/Intro.md'
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cache:v${AppConfig.cacheVersion}:$repoPath';
    final url = Uri.parse(AppConfig.rawFile(repoPath));
    // Falls Offline-Modus aktiv: zuerst versuchen lokal zu lesen (damit UI schnell reagiert)
    final offlineEnabled = await OfflineSnapshotService.isOfflineEnabled();
    if (offlineEnabled) {
      try {
        final local = await OfflineSnapshotService.readTextFileOffline(repoPath);
        return (local, true); // fromCache = true (lokal)
      } catch (_) {
        // ignorieren – wir versuchen Netzwerk / Cache normal
      }
    }
    try {
      final res = await _client.get(url, headers: _headers);
      if (res.statusCode == 200) {
        final text = utf8.decode(res.bodyBytes);
        await prefs.setString(cacheKey, text);
        return (text, false);
      }
      // debug print
      // ignore: avoid_print
  debugPrint('Raw fetch failed ${res.statusCode} for $repoPath, fallback to contents API');
      // Fallback: GitHub Contents API (base64 encoded)
      final api = Uri.parse('https://api.github.com/repos/${AppConfig.owner}/${AppConfig.repo}/contents/$repoPath?ref=${AppConfig.branch}');
      final apiRes = await _client.get(api, headers: _headers);
      if (apiRes.statusCode == 200) {
        final jsonData = json.decode(apiRes.body) as Map<String, dynamic>;
        final encoding = (jsonData['encoding'] as String?) ?? 'base64';
        if (encoding == 'base64') {
          final contentB64 = (jsonData['content'] as String).replaceAll('\n', '');
            final bytes = base64.decode(contentB64);
            final text = utf8.decode(bytes);
            await prefs.setString(cacheKey, text);
            return (text, false);
        }
        throw Exception('Unsupported encoding: $encoding');
      }
      throw Exception('HTTP ${res.statusCode} (raw) / ${apiRes.statusCode} (api)');
    } catch (e) {
      // ignore: avoid_print
  debugPrint('Error loading $repoPath: $e');
      // Zweiter Versuch: Offline Snapshot (falls nicht schon oben genutzt / Datei hinzugekommen nach Snapshot-Erstellung)
      if (!offlineEnabled) {
        try {
          if (await OfflineSnapshotService.isOfflineEnabled()) {
            final local = await OfflineSnapshotService.readTextFileOffline(repoPath);
            return (local, true);
          }
        } catch (_) {}
      }
      final cached = prefs.getString(cacheKey);
      if (cached != null) return (cached, true);
      rethrow;
    }
  }

  /// Listet Markdown Dateien eines (nicht rekursiven) Verzeichnisses.
  Future<List<RepoEntry>> listMarkdownFiles(String dirPath) async {
    final res = await _client.get(AppConfig.listDirUri(dirPath), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Contents API: HTTP ${res.statusCode}');
    }
    final data = json.decode(res.body) as List<dynamic>;
    final entries = data.map((e) => RepoEntry(
      name: e['name'] as String,
      path: e['path'] as String,
      type: e['type'] as String,
    ));
    // Nur .md im aktuellen Ordner
    final md = entries.where((x) => x.type == 'file' && x.name.toLowerCase().endsWith('.md')).toList();
    md.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())); // alphabetisch
    return md;
  }

  /// Rekursive Auflistung aller `README.md` Dateien (Navigation).
  Future<List<RepoEntry>> listReadmesRecursively(String dirPath) async {
    final res = await _client.get(AppConfig.gitTreeUri(), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Git tree API: HTTP ${res.statusCode}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    final tree = (data['tree'] as List<dynamic>).cast<Map<String, dynamic>>();
  final prefix = dirPath.isEmpty ? '' : (dirPath.endsWith('/') ? dirPath : '$dirPath/');
    final readmes = <RepoEntry>[];
    for (final node in tree) {
      if (node['type'] != 'blob') continue;
      final path = node['path'] as String;
      final lower = path.toLowerCase();
      final inScope = prefix.isEmpty || path.startsWith(prefix);
      if (!inScope) continue;
      // Root README
      if (lower == 'readme.md') {
        readmes.add(RepoEntry(name: 'Übersicht', path: path, type: 'file'));
        continue;
      }
      if (lower.endsWith('/readme.md')) {
        final relative = prefix.isEmpty ? path : path.substring(prefix.length);
        final namePart = relative.substring(0, relative.length - '/README.md'.length);
        final display = namePart.isEmpty ? 'Übersicht' : namePart.split('/').last;
        readmes.add(RepoEntry(name: display, path: path, type: 'file'));
      }
    }
    readmes.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return readmes;
  }

  /// Rekursive Auflistung ALLER Markdown Dateien (Suche / Indexierung).
  Future<List<RepoEntry>> listAllMarkdownFilesRecursively(String dirPath) async {
    final res = await _client.get(AppConfig.gitTreeUri(), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Git tree API: HTTP ${res.statusCode}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    final tree = (data['tree'] as List<dynamic>).cast<Map<String, dynamic>>();
  final prefix = dirPath.isEmpty ? '' : (dirPath.endsWith('/') ? dirPath : '$dirPath/');
    final files = <RepoEntry>[];
    for (final node in tree) {
      if (node['type'] == 'blob') {
        final path = node['path'] as String;
        if ((prefix.isEmpty || path.startsWith(prefix)) && path.toLowerCase().endsWith('.md')) {
          final name = path.split('/').last;
          files.add(RepoEntry(name: name, path: path, type: 'file'));
        }
      }
    }
    files.sort((a,b)=> a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return files;
  }

  /// Lädt alle README Dateien plus ihren Inhalt (seriell). Für aggregierte
  /// Darstellungen / Offline Snapshot Features nutzbar.
  Future<List<(RepoEntry entry, String content)>> fetchAllReadmesWithContent(String dirPath) async {
    var entries = await listReadmesRecursively(dirPath);
    if (entries.isEmpty) {
      // Fallback: gesamte Markdown Dateien als Navigation verwenden
      final all = await listAllMarkdownFilesRecursively(dirPath);
      entries = all;
    }
    final result = <(RepoEntry, String)>[];
    for (final e in entries) {
      try {
        final (txt, _) = await fetchMarkdownByRepoPath(e.path);
        result.add((e, txt));
      } catch (_) {}
    }
    return result;
  }

  // =================== NEUE UNIVERSELLE DATEI-FUNKTIONEN ===================

  /// Universelle Datei-Lese-Funktion für alle Dateitypen
  /// Nutzt den UniversalFileReader für erweiterte Funktionalität
  Future<FileReadResult> fetchFileByPath(String repoPath) async {
    return await _universalReader.readFile(repoPath);
  }

  /// Listet alle Dateien (nicht nur Markdown) rekursiv auf
  Future<List<UniversalRepoEntry>> listAllFiles(String dirPath) async {
    return await _universalReader.listAllFilesRecursively(dirPath);
  }

  /// Listet nur Textdateien auf (inkl. Programmcode, JSON, etc.)
  Future<List<UniversalRepoEntry>> listTextFiles(String dirPath) async {
    return await _universalReader.listTextFiles(dirPath);
  }

  /// Listet nur Binärdateien auf (PDFs, Bilder, etc.)
  Future<List<UniversalRepoEntry>> listBinaryFiles(String dirPath) async {
    return await _universalReader.listBinaryFiles(dirPath);
  }

  /// Listet Dateien nach Kategorie gruppiert auf
  Future<Map<String, List<UniversalRepoEntry>>> listFilesByCategory(String dirPath) async {
    final allFiles = await listAllFiles(dirPath);
    final categories = <String, List<UniversalRepoEntry>>{};
    
    for (final file in allFiles) {
      final category = file.category;
      categories[category] ??= [];
      categories[category]!.add(file);
    }
    
    return categories;
  }

  /// Listet Dateien bestimmter Dateitypen auf
  Future<List<UniversalRepoEntry>> listFilesByExtensions(String dirPath, Set<String> extensions) async {
    return await _universalReader.listFilesByType(dirPath, extensions);
  }

  /// Spezielle Funktionen für häufig gebrauchte Dateitypen

  /// Listet alle Programmcode-Dateien auf
  Future<List<UniversalRepoEntry>> listCodeFiles(String dirPath) async {
    const codeExtensions = {
      '.dart', '.js', '.ts', '.py', '.java', '.cpp', '.c', '.h',
      '.go', '.rs', '.php', '.rb', '.swift', '.kt', '.scala'
    };
    return await listFilesByExtensions(dirPath, codeExtensions);
  }

  /// Listet alle Dokumentations-Dateien auf
  Future<List<UniversalRepoEntry>> listDocumentationFiles(String dirPath) async {
    const docExtensions = {
      '.md', '.txt', '.readme', '.rst', '.adoc'
    };
    return await listFilesByExtensions(dirPath, docExtensions);
  }

  /// Listet alle Konfigurations-Dateien auf
  Future<List<UniversalRepoEntry>> listConfigFiles(String dirPath) async {
    const configExtensions = {
      '.json', '.yaml', '.yml', '.xml', '.toml', '.ini', '.config', '.env'
    };
    return await listFilesByExtensions(dirPath, configExtensions);
  }

  /// Listet alle Bild-Dateien auf
  Future<List<UniversalRepoEntry>> listImageFiles(String dirPath) async {
    const imageExtensions = {
      '.png', '.jpg', '.jpeg', '.gif', '.svg', '.bmp', '.ico', '.webp'
    };
    return await listFilesByExtensions(dirPath, imageExtensions);
  }

  /// Listet alle PDF-Dokumente auf
  Future<List<UniversalRepoEntry>> listPdfFiles(String dirPath) async {
    return await listFilesByExtensions(dirPath, {'.pdf'});
  }

  /// Convenience-Methode: Lädt eine Textdatei und gibt den Inhalt als String zurück
  Future<(String content, bool fromCache)> fetchTextFile(String repoPath) async {
    final result = await fetchFileByPath(repoPath);
    if (!result.isText) {
      throw Exception('Datei $repoPath ist keine Textdatei (${result.mimeType})');
    }
    return (result.asText, result.fromCache);
  }

  /// Convenience-Methode: Lädt eine Binärdatei und gibt den Inhalt als Bytes zurück
  Future<(Uint8List content, bool fromCache)> fetchBinaryFile(String repoPath) async {
    final result = await fetchFileByPath(repoPath);
    if (result.isText) {
      throw Exception('Datei $repoPath ist eine Textdatei (${result.mimeType})');
    }
    return (result.asBytes, result.fromCache);
  }

  /// Prüft, ob eine Datei existiert (ohne sie zu laden)
  Future<bool> fileExists(String repoPath) async {
    try {
      final url = Uri.parse(AppConfig.rawFile(repoPath));
      final res = await _client.head(url, headers: _headers);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Gibt Metadaten zu einer Datei zurück (ohne sie zu laden)
  Future<UniversalRepoEntry?> getFileMetadata(String repoPath) async {
    final allFiles = await listAllFiles(AppConfig.dirPath);
    return allFiles.cast<UniversalRepoEntry?>().firstWhere(
      (file) => file?.path == repoPath,
      orElse: () => null,
    );
  }

  void dispose() {
    _client.close();
    _universalReader.dispose();
  }

  /// Löscht alle bekannten Cache-Einträge (Markdown + Universal Reader + Change Tracker + Favoriten + Konfiguration)
  static Future<void> clearAllCaches({bool keepConfig = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();
    for (final k in keys) {
      final lower = k.toLowerCase();
      if (lower.startsWith('cache:v') || lower.startsWith('universal_cache:v') || lower.startsWith('tree:')) {
        await prefs.remove(k);
      }
    }
    // Favoriten entfernen
    await prefs.remove('favorites:paths');
    if (!keepConfig) {
      for (final k in ['cfg:owner','cfg:repo','cfg:branch','cfg:dir','cfg:token']) { await prefs.remove(k); }
      AppConfig.resetToDefaults();
    }
    // Lokale Indizes zurücksetzen
    _readmeIndex = null;
  }
}
