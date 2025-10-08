// ============================================================================
// RepoReader
// File: offline_snapshot_service.dart
// Author: Mindoro Evolution (added offline capability)
// Description: Service zum Erstellen & Nutzen eines Offline-Snapshots
// ============================================================================
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'universal_file_reader.dart';

/// OfflineSnapshotService
/// ======================
/// Erzeugt einen vollständigen lokalen Snapshot des aktuell konfigurierten
/// Repositories (beschränkt durch AppConfig.dirPath). Speichert sowohl
/// Markdown-Dateien (als UTF-8 Text) als auch beliebige andere Dateien
/// (binär Base64) in einer einfachen Verzeichnisstruktur.
///
/// Layout (App-Dokumente Ordner):
///   offline_snapshots/
///     <owner>_<repo>_<branch>/
///       meta.json               -> Metadaten & Index
///       files/<pfad_zur_datei>  -> Originaldatei (Text oder Binär)
///
/// meta.json Format (vereinfachte Struktur):
/// {
///   "owner": "...",
///   "repo": "...",
///   "branch": "...",
///   "created": 1730000000, // epoch seconds
///   "files": [ { "path": "docs/Intro.md", "size": 1234, "text": true }, ... ]
/// }
///
/// Nutzung:
///  * createSnapshot(): Lädt alle Dateien über Git Tree API, speichert lokal
///  * hasSnapshot(): Prüft ob aktuelles Repo bereits Snapshot hat
///  * readTextFileOffline() / readBinaryFileOffline()
///  * enableOfflineMode(bool): Flag in SharedPreferences -> UI kann umschalten
///
/// Sicherheits-/Größenhinweis: Kein diff-basiertes Update; createSnapshot()
/// überschreibt existierenden Snapshot. Für sehr große Repos evtl. Warnung nötig.
class OfflineSnapshotService {
  static const _prefsOfflineEnabled = 'offline:enabled';
  static const _metaFile = 'meta.json';

  /// Prüft ob Offline-Modus aktiviert wurde.
  static Future<bool> isOfflineEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsOfflineEnabled) ?? false;
  }

  /// Aktiviert/Deaktiviert Offline-Modus.
  static Future<void> setOfflineEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsOfflineEnabled, value);
  }

  /// Basisordner für Snapshots.
  static Future<Directory> _baseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final base = Directory('${dir.path}/offline_snapshots');
    if (!await base.exists()) await base.create(recursive: true);
    return base;
  }

  /// Ordner für das aktuell konfigurierte Repo.
  static Future<Directory> _currentRepoDir() async {
    final base = await _baseDir();
    final safe = '${AppConfig.owner}_${AppConfig.repo}_${AppConfig.branch}'.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final repoDir = Directory('${base.path}/$safe');
    if (!await repoDir.exists()) await repoDir.create(recursive: true);
    return repoDir;
  }

  /// Interner Helper – für UI (z.B. Bildlade-Widget) bieten wir einen readonly Zugriff.
  static Future<String> currentSnapshotRootPath() async {
    final d = await _currentRepoDir();
    return d.path;
  }

  /// Pfad zu meta.json
  static Future<File> _metaFileHandle() async {
    final repoDir = await _currentRepoDir();
    return File('${repoDir.path}/$_metaFile');
  }

  /// Snapshot vorhanden?
  static Future<bool> hasSnapshot() async {
    final f = await _metaFileHandle();
    return f.exists();
  }

  /// Liest Metadaten (oder null wenn nicht vorhanden / defekt)
  static Future<Map<String, dynamic>?> readMeta() async {
    try {
      final f = await _metaFileHandle();
      if (!await f.exists()) return null;
      final txt = await f.readAsString();
      return json.decode(txt) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  /// Listet alle Dateien aus dem Snapshot (leichtgewichtige Struktur)
  static Future<List<OfflineFileEntry>> listSnapshotFiles() async {
    final meta = await readMeta();
    if (meta == null) return [];
    final files = (meta['files'] as List<dynamic>? )?.cast<Map<String,dynamic>>() ?? [];
    return files.map((m) => OfflineFileEntry(
      path: m['path'] as String,
      size: (m['size'] as num?)?.toInt() ?? 0,
      isText: (m['text'] as bool?) ?? false,
    )).toList();
  }

  /// Filtert Navigations-Texteinträge (README & gängige Text-Extensions)
  static Future<List<OfflineFileEntry>> listOfflineNavTextEntries() async {
    final all = await listSnapshotFiles();
    bool isNav(String p) {
      final ln = p.toLowerCase();
      return ln.endsWith('.md') || ln.endsWith('.mdx') || ln.endsWith('.markdown') || ln.endsWith('.txt') || ln.endsWith('.rst') || ln.endsWith('.adoc');
    }
    return all.where((f) => f.isText && isNav(f.path)).toList()
      ..sort((a,b)=> a.path.toLowerCase().compareTo(b.path.toLowerCase()));
  }

  /// Löscht Snapshot (nur aktuelles Repo)
  static Future<void> deleteSnapshot() async {
    final dir = await _currentRepoDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Erstellt oder ersetzt einen Snapshot aller Dateien im konfigurierten Scope.
  static Future<void> createSnapshot({void Function(String msg)? onProgress}) async {
    onProgress?.call('Lade Dateiliste (Git Tree)...');
    final headers = <String,String>{
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'RepoReaderApp/1.0 (+offline)'
    };
    if (AppConfig.githubToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${AppConfig.githubToken}';
    }
    final res = await http.get(AppConfig.gitTreeUri(), headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Git tree API: HTTP ${res.statusCode}');
    }
    final jsonData = json.decode(res.body) as Map<String, dynamic>;
    final tree = (jsonData['tree'] as List<dynamic>).cast<Map<String, dynamic>>();
    final prefix = AppConfig.dirPath.isEmpty ? '' : (AppConfig.dirPath.endsWith('/') ? AppConfig.dirPath : '${AppConfig.dirPath}/');
    final blobs = tree.where((n) => n['type'] == 'blob' && (prefix.isEmpty || (n['path'] as String).startsWith(prefix))).toList();

    final repoDir = await _currentRepoDir();
    final filesDir = Directory('${repoDir.path}/files');
    if (await filesDir.exists()) {
      await filesDir.delete(recursive: true);
    }
    await filesDir.create(recursive: true);

    final universal = UniversalFileReader();
    final manifest = <Map<String, dynamic>>[];
    int processed = 0;
    for (final node in blobs) {
      final path = node['path'] as String;
      final isText = universal.isTextFile(path);
      onProgress?.call('Lade ${++processed}/${blobs.length}: $path');
      try {
        final res = await universal.readFile(path); // nutzt Netzwerk & Cache
        final outFile = File('${filesDir.path}/$path');
        await outFile.parent.create(recursive: true);
        if (isText) {
          await outFile.writeAsString(res.asText, flush: true);
        } else {
          await outFile.writeAsBytes(res.asBytes, flush: true);
        }
        manifest.add({
          'path': path,
          'size': node['size'] ?? (isText ? (res.asText.length) : (res.asBytes.length)),
          'text': isText,
        });
      } catch (e) {
        debugPrint('Snapshot skip $path: $e');
      }
    }

    final meta = {
      'owner': AppConfig.owner,
      'repo': AppConfig.repo,
      'branch': AppConfig.branch,
      'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'dirPath': AppConfig.dirPath,
      'files': manifest,
    };
    final metaFile = await _metaFileHandle();
    await metaFile.writeAsString(const JsonEncoder.withIndent('  ').convert(meta));
    onProgress?.call('Snapshot abgeschlossen: ${manifest.length} Dateien.');
  }

  /// Liest Textdatei offline (wirft wenn nicht vorhanden oder nicht Text)
  static Future<String> readTextFileOffline(String repoPath) async {
    final repoDir = await _currentRepoDir();
    final f = File('${repoDir.path}/files/$repoPath');
    if (!await f.exists()) throw Exception('Offline-Datei nicht gefunden: $repoPath');
    return f.readAsString();
  }

  /// Liest Binärdatei offline
  static Future<Uint8List> readBinaryFileOffline(String repoPath) async {
    final repoDir = await _currentRepoDir();
    final f = File('${repoDir.path}/files/$repoPath');
    if (!await f.exists()) throw Exception('Offline-Datei nicht gefunden: $repoPath');
    return await f.readAsBytes();
  }
}

/// Leichtgewichtiger Offline-Datei-Eintrag aus meta.json Manifest
class OfflineFileEntry {
  final String path; final int size; final bool isText;
  OfflineFileEntry({required this.path, required this.size, required this.isText});
  String get name => path.split('/').last;
}
