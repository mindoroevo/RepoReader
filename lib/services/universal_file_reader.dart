import 'dart:convert';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'offline_snapshot_service.dart';

/// UniversalFileReader
/// ===================
/// Einheitliche Schnittstelle zum Laden beliebiger Repository-Dateien
/// (Text & Binär) mit heuristischer Typbestimmung über Dateiendung.
///
/// Fähigkeiten:
/// * Raw GitHub Abruf → Fallback Contents API (Base64) → Cache
/// * Textdekodierung (UTF‑8) & Binärspeicherung (Base64) in SharedPreferences
/// * MIME-Type Heuristik zur UI-Beschriftung
/// * Kategorisierung (siehe `UniversalRepoEntry.category`) für Browser / Filter
///
/// Caching:
/// * Key Schema: `universal_cache:v<cacheVersion>:<repoPath>`
/// * Invalidation: über `AppConfig.cacheVersion` & explizites Leeren (`clearCache` / globaler Reset)
///
/// Trade-Offs:
/// * Keine Inhaltsfragmentierung (volle Datei im Speicher)
/// * Keine Streaming-Dekodierung (für sehr große Dateien optional nachrüstbar)
/// * Heuristik basiert nur auf Endung (keine Magic Bytes Analyse)
class UniversalFileReader {
  final _client = http.Client();

  /// Dateityp-Definitionen
  static const textExtensions = {
    '.md', '.txt', '.dart', '.js', '.ts', '.py', '.java', '.cpp', '.c', '.h',
    '.json', '.yaml', '.yml', '.xml', '.html', '.htm', '.css', '.scss', '.sass',
    '.sql', '.sh', '.bat', '.ps1', '.dockerfile', '.gitignore', '.readme',
    '.config', '.ini', '.env', '.log', '.csv', '.tsv', '.R', '.rb', '.php',
    '.go', '.rs', '.kt', '.swift', '.m', '.mm', '.scala', '.clj', '.hs',
    '.pl', '.r', '.matlab', '.vue', '.jsx', '.tsx', '.svelte'
  };

  static const binaryExtensions = {
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.svg', '.ico', '.webp',
    '.mp3', '.mp4', '.wav', '.avi', '.mov', '.wmv', '.flv',
    '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2',
    '.exe', '.msi', '.dmg', '.deb', '.rpm',
    '.ttf', '.otf', '.woff', '.woff2'
  };

  /// HTTP Headers für GitHub API Anfragen
  Map<String, String> get _headers => AppConfig.githubToken.isEmpty
      ? { 'Accept': 'application/vnd.github+json' }
      : {
          'Accept': 'application/vnd.github+json',
          'Authorization': 'Bearer ${AppConfig.githubToken}',
        };

  /// Bestimmt ob eine Datei als Text behandelt werden soll
  bool isTextFile(String filePath) {
    final ext = _getFileExtension(filePath).toLowerCase();
    if (textExtensions.contains(ext)) return true;
    if (binaryExtensions.contains(ext)) return false;
    
    // Fallback: Dateien ohne Endung oder unbekannte Endungen als Text behandeln
    return true;
  }

  /// Entfernt alle gecachten universal_* Einträge aus SharedPreferences
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final k in keys) {
      if (k.startsWith('universal_cache:v')) {
        await prefs.remove(k);
      }
    }
  }

  /// Bestimmt ob eine Datei als Binärdatei behandelt werden soll
  bool isBinaryFile(String filePath) {
    return !isTextFile(filePath);
  }

  /// Extrahiert die Dateiendung (mit Punkt)
  String _getFileExtension(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot == -1) return '';
    return filePath.substring(lastDot);
  }

  /// Bestimmt den MIME-Type basierend auf der Dateiendung
  String getMimeType(String filePath) {
    final ext = _getFileExtension(filePath).toLowerCase();
    
    // Text-Dateien
    switch (ext) {
      case '.md': return 'text/markdown';
      case '.txt': return 'text/plain';
      case '.html': case '.htm': return 'text/html';
      case '.css': return 'text/css';
      case '.js': return 'application/javascript';
      case '.json': return 'application/json';
      case '.xml': return 'application/xml';
      case '.yaml': case '.yml': return 'application/x-yaml';
      case '.csv': return 'text/csv';
      
      // Programmiersprachen
      case '.dart': return 'application/dart';
      case '.py': return 'text/x-python';
      case '.java': return 'text/x-java-source';
      case '.cpp': case '.c': return 'text/x-c';
      case '.php': return 'application/x-php';
      case '.rb': return 'application/x-ruby';
      case '.go': return 'text/x-go';
      case '.rs': return 'text/rust';
      
      // Binärdateien
      case '.pdf': return 'application/pdf';
      case '.png': return 'image/png';
      case '.jpg': case '.jpeg': return 'image/jpeg';
      case '.gif': return 'image/gif';
      case '.svg': return 'image/svg+xml';
      case '.zip': return 'application/zip';
      case '.mp3': return 'audio/mpeg';
      case '.mp4': return 'video/mp4';
      
      default:
        return isTextFile(filePath) ? 'text/plain' : 'application/octet-stream';
    }
  }

  /// Universelle Datei-Lese-Funktion
  /// Gibt (Inhalt, fromCache, isText, mimeType) zurück
  Future<FileReadResult> readFile(String repoPath) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'universal_cache:v${AppConfig.cacheVersion}:$repoPath';
    final isText = isTextFile(repoPath);
    final mimeType = getMimeType(repoPath);
    final offlineEnabled = await OfflineSnapshotService.isOfflineEnabled();

    // Direkt Offline versuchen falls aktiviert und kein Cache vorhanden
    if (offlineEnabled) {
      try {
        if (isText) {
          final txt = await OfflineSnapshotService.readTextFileOffline(repoPath);
          return FileReadResult(content: txt, fromCache: true, isText: true, mimeType: mimeType);
        } else {
          final bytes = await OfflineSnapshotService.readBinaryFileOffline(repoPath);
          return FileReadResult(content: bytes, fromCache: true, isText: false, mimeType: mimeType);
        }
      } catch (_) {
        // Fallback auf Netzwerk unten
      }
    }

    try {
      // Versuche Raw GitHub API
      final rawResult = await _tryRawApi(repoPath, isText);
      if (rawResult != null) {
        // Cache speichern
        if (isText) {
          await prefs.setString(cacheKey, rawResult);
        } else {
          await prefs.setString(cacheKey, base64.encode(rawResult as Uint8List));
        }
        return FileReadResult(
          content: rawResult,
          fromCache: false,
          isText: isText,
          mimeType: mimeType,
        );
      }

      // Fallback: GitHub Contents API
      final contentsResult = await _tryContentsApi(repoPath, isText);
      if (contentsResult != null) {
        // Cache speichern
        if (isText) {
          await prefs.setString(cacheKey, contentsResult);
        } else {
          await prefs.setString(cacheKey, base64.encode(contentsResult as Uint8List));
        }
        return FileReadResult(
          content: contentsResult,
          fromCache: false,
          isText: isText,
          mimeType: mimeType,
        );
      }

      throw Exception('Beide API-Methoden fehlgeschlagen');

    } catch (e) {
      // Fallback: Cache
  debugPrint('Fehler beim Laden von $repoPath: $e');
      // Wenn Offline-Modus aktiv: zweiter Versuch rein offline (falls oben Netzwerk gewählt wurde)
      if (!offlineEnabled) {
        try {
          final enabled = await OfflineSnapshotService.isOfflineEnabled();
          if (enabled) {
            if (isText) {
              final txt = await OfflineSnapshotService.readTextFileOffline(repoPath);
              return FileReadResult(content: txt, fromCache: true, isText: true, mimeType: mimeType);
            } else {
              final bytes = await OfflineSnapshotService.readBinaryFileOffline(repoPath);
              return FileReadResult(content: bytes, fromCache: true, isText: false, mimeType: mimeType);
            }
          }
        } catch (_) {}
      }
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final content = isText ? cached : base64.decode(cached);
        return FileReadResult(
          content: content,
          fromCache: true,
          isText: isText,
          mimeType: mimeType,
        );
      }
      rethrow;
    }
  }

  /// Versucht die Raw GitHub API
  Future<dynamic> _tryRawApi(String repoPath, bool isText) async {
    final url = Uri.parse(AppConfig.rawFile(repoPath));
    final res = await _client.get(url, headers: _headers);
    
    if (res.statusCode == 200) {
      if (isText) {
        return utf8.decode(res.bodyBytes);
      } else {
        return res.bodyBytes;
      }
    }
    return null;
  }

  /// Versucht die GitHub Contents API
  Future<dynamic> _tryContentsApi(String repoPath, bool isText) async {
    final api = Uri.parse('https://api.github.com/repos/${AppConfig.owner}/${AppConfig.repo}/contents/$repoPath?ref=${AppConfig.branch}');
    final apiRes = await _client.get(api, headers: _headers);
    
    if (apiRes.statusCode == 200) {
      final jsonData = json.decode(apiRes.body) as Map<String, dynamic>;
      final encoding = (jsonData['encoding'] as String?) ?? 'base64';
      
      if (encoding == 'base64') {
        final contentB64 = (jsonData['content'] as String).replaceAll('\n', '');
        final bytes = base64.decode(contentB64);
        
        if (isText) {
          return utf8.decode(bytes);
        } else {
          return bytes;
        }
      }
      throw Exception('Unsupported encoding: $encoding');
    }
    return null;
  }

  /// Listet alle Dateien (nicht nur Markdown) rekursiv auf
  Future<List<UniversalRepoEntry>> listAllFilesRecursively(String dirPath) async {
    final res = await _client.get(AppConfig.gitTreeUri(), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Git tree API: HTTP ${res.statusCode}');
    }
    
    final data = json.decode(res.body) as Map<String, dynamic>;
    final tree = (data['tree'] as List<dynamic>).cast<Map<String, dynamic>>();
    final prefix = dirPath.endsWith('/') ? dirPath : '$dirPath/';
    final files = <UniversalRepoEntry>[];
    
    for (final node in tree) {
      if (node['type'] == 'blob') {
        final path = node['path'] as String;
        if (path.startsWith(prefix)) {
          final name = path.split('/').last;
          final ext = _getFileExtension(name);
          final mimeType = getMimeType(name);
          final isText = isTextFile(name);
          
          files.add(UniversalRepoEntry(
            name: name,
            path: path,
            type: 'file',
            extension: ext,
            mimeType: mimeType,
            isText: isText,
            size: node['size'] as int? ?? 0,
          ));
        }
      }
    }
    
    files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return files;
  }

  /// Listet alle Dateien eines bestimmten Typs auf
  Future<List<UniversalRepoEntry>> listFilesByType(String dirPath, Set<String> extensions) async {
    final allFiles = await listAllFilesRecursively(dirPath);
    return allFiles.where((file) => extensions.contains(file.extension.toLowerCase())).toList();
  }

  /// Listet nur Textdateien auf
  Future<List<UniversalRepoEntry>> listTextFiles(String dirPath) async {
    final allFiles = await listAllFilesRecursively(dirPath);
    return allFiles.where((file) => file.isText).toList();
  }

  /// Listet nur Binärdateien auf
  Future<List<UniversalRepoEntry>> listBinaryFiles(String dirPath) async {
    final allFiles = await listAllFilesRecursively(dirPath);
    return allFiles.where((file) => !file.isText).toList();
  }

  void dispose() {
    _client.close();
  }
}

/// Ergebnis einer Datei-Lese-Operation
class FileReadResult {
  final dynamic content; // String für Text, Uint8List für Binär
  final bool fromCache;
  final bool isText;
  final String mimeType;

  FileReadResult({
    required this.content,
    required this.fromCache,
    required this.isText,
    required this.mimeType,
  });

  /// Gibt den Inhalt als String zurück (nur für Textdateien)
  String get asText {
    if (!isText) throw Exception('Datei ist keine Textdatei');
    return content as String;
  }

  /// Gibt den Inhalt als Bytes zurück (für Binärdateien)
  Uint8List get asBytes {
    if (isText) throw Exception('Datei ist eine Textdatei');
    return content as Uint8List;
  }

  /// Gibt den Inhalt als Base64 String zurück (für Binärdateien)
  String get asBase64 {
    if (isText) throw Exception('Datei ist eine Textdatei');
    return base64.encode(content as Uint8List);
  }
}

/// Erweiterte Repository-Entry-Klasse mit mehr Metadaten
class UniversalRepoEntry {
  final String name;
  final String path;
  final String type;
  final String extension;
  final String mimeType;
  final bool isText;
  final int size;

  UniversalRepoEntry({
    required this.name,
    required this.path,
    required this.type,
    required this.extension,
    required this.mimeType,
    required this.isText,
    required this.size,
  });

  /// Formatierte Dateigröße
  String get formattedSize {
  if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Datei-Kategorie für UI-Gruppierung
  String get category {
  switch (extension.toLowerCase()) {
      case '.md':
      case '.txt':
      case '.readme':
  return 'Documentation';
      
      case '.dart':
      case '.js':
      case '.ts':
      case '.py':
      case '.java':
      case '.cpp':
      case '.c':
      case '.h':
      case '.go':
      case '.rs':
      case '.php':
      case '.rb':
  return 'Source Code';
      
      case '.json':
      case '.yaml':
      case '.yml':
      case '.xml':
      case '.config':
      case '.ini':
  return 'Configuration';
      
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.svg':
      case '.bmp':
      case '.ico':
  return 'Images';
      
      case '.pdf':
      case '.doc':
      case '.docx':
  return 'Documents';
      
      case '.mp3':
      case '.wav':
      case '.mp4':
      case '.avi':
  return 'Media';
      
      case '.zip':
      case '.rar':
      case '.7z':
  return 'Archives';
      
      default:
  return isText ? 'Text Files' : 'Binary Files';
    }
  }
}