/// naming.dart – Titel & Pfadaufbereitung
/// =====================================
/// Wandelt einen Roh-Titel (Dateiname oder Pfadsegment) in eine für die UI
/// freundlich lesbare Variante um:
/// * Entfernt führende Nummerierungspräfixe ("01-", "02_" ...)
/// * Entfernt Endungen `.md`, `README`
/// * Ersetzt `-` / `_` durch Leerzeichen
/// * Kapitalisiert jedes Wort
/// Leerer oder nur README → "Übersicht".
String prettifyTitle(String raw) {
  // Keep path for segment extraction; work on last segment only.
  String last = raw.split('/').where((e) => e.isNotEmpty).last;
  last = last.replaceAll(RegExp(r'\.md$', caseSensitive: false), '');
  last = last.replaceAll(RegExp(r'README$', caseSensitive: false), '');
  last = last.replaceFirst(RegExp(r'^[0-9]+[-_]?'), '');
  last = last.replaceAll(RegExp(r'[-_]'), ' ').trim();
  if (last.isEmpty) return 'Übersicht';
  return last.split(' ').map((w)=> w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

/// Erzeugt einen Breadcrumb-Titel aus Pfadsegmenten (› als Trenner).
String buildBreadcrumbTitle(List<String> segments) => segments.map(prettifyTitle).join(' › ');

/// Löst einen relativen Wiki/Repo Link zu einem absoluten Repo-Pfad auf.
/// Regeln:
/// * Absolute HTTP/HTTPS Links → `null` (extern)
/// * `#anchor` → `null` (handled im Markdown selbst)
/// * Ordnerpfade / Pfade ohne `.md` → `README.md` angehängt
/// * Navigation über `../` wird begrenzt ("docs" bleibt Root)
String? resolveRepoRelative(String currentRepoPath, String href) {
  if (href.startsWith('http://') || href.startsWith('https://')) return null; // external
  // currentRepoPath like docs/folder/sub/README.md
  final baseDir = currentRepoPath.substring(0, currentRepoPath.lastIndexOf('/'));
  String h = href.trim();
  if (h.startsWith('#')) return null; // anchor inside page (let markdown handle or ignore)
  // remove leading ./
  h = h.replaceFirst(RegExp(r'^\./'), '');
  // If absolute-ish (starts with docs/) treat as absolute
  String candidate;
  if (h.startsWith('/')) {
    // treat / as root of docs
  candidate = 'docs$h';
  } else if (h.startsWith('docs/')) {
    candidate = h;
  } else if (h.startsWith('../')) {
    // navigate up
    var parts = baseDir.split('/');
    var rel = h;
    while (rel.startsWith('../') && parts.length > 1) { // keep at least 'docs'
      rel = rel.substring(3);
      parts.removeLast();
    }
    candidate = parts.join('/') + '/' + rel;
  } else {
    candidate = baseDir + '/' + h;
  }
  // Normalize duplicate slashes
  candidate = candidate.replaceAll(RegExp(r'/+'), '/');
  // If ends with / append README.md
  if (candidate.endsWith('/')) candidate += 'README.md';
  // If references a folder (no .md) assume README.md inside
  if (!candidate.toLowerCase().endsWith('.md')) {
    // if already ends with README ignore
    if (!candidate.toLowerCase().endsWith('readme')) {
      candidate = candidate.replaceAll(RegExp(r'/+$'), '');
      candidate += '/README.md';
    } else {
      candidate += '.md';
    }
  }
  return candidate;
}
