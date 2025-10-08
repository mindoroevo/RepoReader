// ============================================================================
// RepoReader
// File: change_tracker_service.dart
// Author: Mindoro Evolution
// Description: Änderungs-/Diff-Erkennung über Git Tree Snapshot Vergleich.
// ============================================================================
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// ChangeTrackerService
/// ====================
///
/// Vergleicht den aktuellen Git Tree (über GitHub Git Tree API) mit dem zuletzt
/// gespeicherten Snapshot und ermittelt eine Liste betroffener Markdown-Dateien.
/// Dieser Service ist absichtlich leichtgewichtig und nutzt keinen komplexen
/// diff-Algorithmus – stattdessen einen simplen zeilenweisen Vergleich.
///
/// Motivation:
/// * Schnelles Feedback: Welche Dateien wurden hinzugefügt / entfernt / geändert?
/// * Anzeige kurzer Vorschau (erste Zeilen) zur raschen Einschätzung ohne vollständiges Öffnen.
/// * Minimale Persistenz (SharedPreferences) genügt – kein relationales Schema nötig.
///
/// Grenzen / Trade-Offs:
/// * Zeilenbasierter Diff (keine Wort-/Token-Präzision)
/// * Signatur (hash) rein heuristisch – kein Sicherheitsmerkmal
/// * Entfernte Dateien ohne Diff (nur Status)
///
/// Potenzielle Erweiterungen (Roadmap):
/// * Wort-/Token-Level Diff
/// * Ignore-Patterns (glob)
/// * Historienabruf via Git Blobs (statt rely auf Cache)
/// * ETag Nutzung zur Bandbreiten-Reduktion

enum ChangeStatus { added, modified, removed }

/// Einzelne Diff-Zeile (vereinfachtes Modell).
class DiffLine {
  final String text;   // Zeileninhalt ohne ursprüngliches Prefix
  final String prefix; // '+', '-', ' ', '➜'
  DiffLine(this.prefix, this.text);
}

class ChangeFile {
  final String path;              // Repository Pfad
  final ChangeStatus status;      // Art der Änderung
  final int addedLines;           // Heuristische Anzahl hinzugefügter Zeilen
  final int removedLines;         // Heuristische Anzahl entfernter Zeilen
  final String? sample;           // Vorschau (erste Zeilen neue Version)
  final List<DiffLine>? diff;     // Diff-Liste (gekürzt)
  ChangeFile({
    required this.path,
    required this.status,
    this.addedLines = 0,
    this.removedLines = 0,
    this.sample,
    this.diff,
  });
}

class ChangeSummary {
  final List<ChangeFile> files;   // Änderungen
  final String newSignature;      // Aktuelle Snapshot Signatur
  final DateTime timestamp;       // Zeitpunkt der Erstellung
  ChangeSummary(this.files, this.newSignature, this.timestamp);
  bool get isEmpty => files.isEmpty;
}

class ChangeTrackerService {
  static const _snapshotKey = 'tree:snapshot';
  static const _signatureKey = 'tree:lastSig';
  static const _timestampKey = 'tree:lastCheckedAt';
  static const _ackSigKey = 'tree:ackSig';

  final _client = http.Client();

  /// Führt eine Änderungsprüfung durch.
  /// Rückgabe: `null` wenn (a) erster Durchlauf oder (b) Signatur unverändert oder (c) nur irrelevante Änderungen.
  Future<ChangeSummary?> detectChanges() async {
    final prefs = await SharedPreferences.getInstance();
    final previousJson = prefs.getString(_snapshotKey);
    Map<String, dynamic>? previous;
    if (previousJson != null) {
      try { previous = json.decode(previousJson) as Map<String,dynamic>; } catch (_) {}
    }

    final current = await _fetchCurrentSnapshot();
    final currentSig = _signature(current);
    final lastSig = prefs.getString(_signatureKey);

    // First run or unchanged signature -> just persist & exit
    if (previous == null || lastSig == currentSig) {
      await _persist(prefs, current, currentSig);
      return null;
    }

    final prevMap = previous.map((k,v) => MapEntry(k, v as String));
    final curMap = current;

    final files = <ChangeFile>[];

    // Added & Modified
    for (final e in curMap.entries) {
      final prevSha = prevMap[e.key];
      if (prevSha == null) {
        final sample = await _fetchSample(e.key);
        files.add(ChangeFile(path: e.key, status: ChangeStatus.added, sample: sample));
      } else if (prevSha != e.value) {
        final diffInfo = await _diffLines(e.key, prevSha);
        files.add(ChangeFile(
          path: e.key,
          status: ChangeStatus.modified,
          addedLines: diffInfo.$1,
          removedLines: diffInfo.$2,
          sample: diffInfo.$3,
          diff: diffInfo.$4,
        ));
      }
    }

    // Removed
    for (final path in prevMap.keys) {
      if (!curMap.containsKey(path)) {
        files.add(ChangeFile(path: path, status: ChangeStatus.removed));
      }
    }

    if (files.isEmpty) {
      await _persist(prefs, current, currentSig); // Nothing relevant changed (maybe non-md)
      return null;
    }

    // Persist new snapshot AFTER returning summary? We persist now so it won't repeatedly show; store signature inside summary.
    await _persist(prefs, current, currentSig);
    return ChangeSummary(files, currentSig, DateTime.now());
  }

  /// Holt aktuellen Git Tree Snapshot (Markdown Pfade → SHA).
  Future<Map<String,String>> _fetchCurrentSnapshot() async {
    final res = await _client.get(AppConfig.gitTreeUri(), headers: {
      if (AppConfig.githubToken.isNotEmpty) 'Authorization': 'Bearer ${AppConfig.githubToken}',
      'Accept': 'application/vnd.github+json'
    });
    if (res.statusCode != 200) throw Exception('Git tree API: ${res.statusCode}');
    final data = json.decode(res.body) as Map<String,dynamic>;
    final tree = (data['tree'] as List<dynamic>).cast<Map<String,dynamic>>();
    final map = <String,String>{};
    for (final node in tree) {
      if (node['type'] == 'blob') {
        final path = node['path'] as String;
  if (path.startsWith('${AppConfig.dirPath}/') && path.toLowerCase().endsWith('.md')) {
          map[path] = node['sha'] as String;
        }
      }
    }
    return map;
  }

  /// Persistiert Snapshot + Signatur + Zeitstempel.
  Future<void> _persist(SharedPreferences prefs, Map<String,String> snap, String sig) async {
    await prefs.setString(_snapshotKey, json.encode(snap));
    await prefs.setString(_signatureKey, sig);
    await prefs.setString(_timestampKey, DateTime.now().toIso8601String());
  }

  /// Erzeugt einfache deterministische Signatur (kein Kryptographie-Ersatz!).
  String _signature(Map<String,String> snap) {
  final entries = snap.entries.toList()..sort((a,b)=>a.key.compareTo(b.key));
    int hash = 0;
    for (final e in entries) {
      hash = 0x1fffffff & (hash + e.key.hashCode);
      hash = 0x1fffffff & (hash + e.value.hashCode * 31);
    }
    return hash.toRadixString(16);
  }

  /// Lädt eine Vorschau (erste Zeilen) der neuen Version einer Datei.
  Future<String?> _fetchSample(String path) async {
    try {
      final url = Uri.parse(AppConfig.rawFile(path));
      final res = await _client.get(url, headers: {
        if (AppConfig.githubToken.isNotEmpty) 'Authorization': 'Bearer ${AppConfig.githubToken}',
      });
      if (res.statusCode == 200) {
        final text = utf8.decode(res.bodyBytes);
      final lines = text.trim().split('\n').map(sanitizeForPreview).take(6).toList();
        return lines.join('\n');
      }
    } catch (_) {}
    return null;
  }

  /// Erzeugt einen groben Diff (Added/Removed anhand Index / Unterschied) – bewusst simpel gehalten.
  /// Naiver Zeilen-Diff zwischen vorheriger Cache-Version (falls vorhanden) und aktueller Remote-Version.
  ///
  /// Ansatz:
  /// - Holt alten Inhalt aus SharedPreferences Cache (Key basiert auf `cacheVersion`).
  /// - Lädt aktuelle Datei via Raw Endpoint.
  /// - Vergleicht zeilenweise nach Index (kein LCS) und zählt hinzugefügte / entfernte.
  /// - Erstellt bis zu 6 Vorschauzeilen (`DiffLine`) für UI-Anzeige.
  ///
  /// Rückgabe: (added, removed, samplePreview, diffLines?) – diffLines nur bei vollständigem Vergleich.
  /// Falls alter oder neuer Inhalt fehlt: liefert (0,0,sample,null).
  Future<(int,int,String?,List<DiffLine>?)> _diffLines(String path, String oldSha) async {
    // We don't have old content by sha; rely on cached previous version if present.
    // (Key: cache:<path>)
    final prefs = await SharedPreferences.getInstance();
  final oldContent = prefs.getString('cache:v${AppConfig.cacheVersion}:$path');
    final nowUrl = Uri.parse(AppConfig.rawFile(path));
    String? newContent;
    try {
      final res = await _client.get(nowUrl, headers: {
        if (AppConfig.githubToken.isNotEmpty) 'Authorization': 'Bearer ${AppConfig.githubToken}',
      });
      if (res.statusCode == 200) newContent = utf8.decode(res.bodyBytes);
    } catch (_) {}
    if (oldContent == null || newContent == null) {
      return (0,0,newContent?.trim().split('\n').take(6).join('\n'), null);
    }
    final oldLines = oldContent.split('\n');
    final newLines = newContent.split('\n');
    int added = 0, removed = 0;
    // Simple diff: count lines not present by index & trailing differences
    final maxLen = oldLines.length > newLines.length ? oldLines.length : newLines.length;
    for (int i=0;i<maxLen;i++) {
      final o = i < oldLines.length ? oldLines[i] : null;
      final n = i < newLines.length ? newLines[i] : null;
      if (o == null && n != null) {
        added++;
      } else if (n == null && o != null) {
        removed++;
      } else if (o != n) { 
        added++; 
        removed++; 
      }
    }
    // Mark changed lines (very naive: mark when different index-wise)
    final preview = <String>[];
    final diffLines = <DiffLine>[];
    for (int i=0;i<newLines.length && preview.length<6;i++) {
      final rawNew = newLines[i];
      final rawOld = i < oldLines.length ? oldLines[i] : null;
      final display = sanitizeForPreview(rawNew);
      final oldDisplay = rawOld == null ? null : sanitizeForPreview(rawOld);
      if (oldDisplay != null && oldDisplay != display) {
        preview.add('➜ $display');
        diffLines.add(DiffLine('➜', display));
      } else if (oldDisplay == null) {
        preview.add('+ $display');
        diffLines.add(DiffLine('+', display));
      } else {
        preview.add('  $display');
        diffLines.add(DiffLine(' ', display));
      }
    }
    final sample = preview.join('\n');
    // Begrenze diffLines auf max 150 zur Schonung
    if (diffLines.length > 150) diffLines.removeRange(150, diffLines.length);
    return (added, removed, sample, diffLines);
  }

  /// Zeitstempel des letzten gespeicherten Snapshots.
  static Future<DateTime?> lastCheckedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_timestampKey); if (iso==null) return null; return DateTime.tryParse(iso);
  }

  /// Signatur die als "gelesen" markiert wurde.
  static Future<String?> acknowledgedSignature() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ackSigKey);
  }

  /// Markiert eine Signatur als gelesen.
  static Future<void> markRead(String signature) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ackSigKey, signature);
  }
}

/// Entfernt einfache HTML Tags und wandelt einige Strukturen um damit der Vorschau-Text sauber ist.
String sanitizeForPreview(String input) {
  var s = input;
  // Zeilenumbrüche von <br>
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  // Headings <h1>-<h6> in Markdown-Stil umwandeln
  for (int i=1;i<=6;i++) {
    s = s.replaceAll(RegExp('<h$i[^>]*>', caseSensitive: false), ('#'*i)+' ');
    s = s.replaceAll(RegExp('</h$i>', caseSensitive: false), '');
  }
  // Script / Style Inhalte komplett entfernen
  s = s.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
  // Block/Inline Tags entfernen aber Inhalt behalten
  s = s.replaceAll(RegExp(r'</?(p|div|span|strong|b|em|i|u|center|section|article|header|footer)[^>]*>', caseSensitive: false), '');
  // Links: nur inneren Text behalten
  s = s.replaceAllMapped(RegExp(r'<a [^>]*>([\s\S]*?)</a>', caseSensitive: false), (m) => m.group(1) ?? '');
  // Einzelne eröffnende oder schließende a-Tags (mehrzeilig auseinandergerissen)
  s = s.replaceAll(RegExp(r'<a [^>]*>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'</a>', caseSensitive: false), '');
  // Bilder ersetzen
  s = s.replaceAllMapped(RegExp(r'<img [^>]*alt="([^"]*)"[^>]*>', caseSensitive: false), (m) => '[Bild:${m.group(1)}]');
  s = s.replaceAll(RegExp(r'<img [^>]*>', caseSensitive: false), '[Bild]');
  // Listenpunkte
  s = s.replaceAll(RegExp(r'</?(ul|ol)[^>]*>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n- ');
  s = s.replaceAll(RegExp(r'</li>', caseSensitive: false), '');
  // Code Inline
  s = s.replaceAll(RegExp(r'</?code[^>]*>', caseSensitive: false), '`');
  // Restliche Tags entfernen
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  // HTML Entities
  s = s.replaceAll('&nbsp;', ' ')
       .replaceAll('&amp;', '&')
       .replaceAll('&lt;', '<')
       .replaceAll('&gt;', '>')
       .replaceAll('&quot;', '"')
       .replaceAll('&#39;', "'");
  // Mehrfache Whitespaces reduzieren
  s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  // Mehrfache Leerzeilen reduzieren
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  // Leerräume am Zeilenende entfernen
  s = s.split('\n').map((l)=>l.trimRight()).join('\n');
  return s.trimRight();
}