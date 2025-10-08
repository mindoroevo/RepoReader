// Markdown Vorverarbeitungspipeline
// =================================
//
// Aufgabe: Roh-Markdown (README) aus GitHub vereinheitlichen, bereinigen und
// an Renderer-Annahmen anpassen. GitHub Wikis / Repos enthalten häufig HTML-Fragmenten
// (z.B. `<p align="center">`, direkte `<h1>` Tags, `<img>`), Navigationsreste oder
// relative Asset-Pfade, die lokal nicht sofort funktionieren.
//
// Transformationsübersicht (Reihenfolge relevant / idempotent ausgelegt):
//  1. Zeilenendungen normalisieren (CRLF -> LF)
//  2. HTML Headings `<h1>`..`<h6>` -> Markdown `#`, inkl. Anchor-Kommentar voran gestellt
//  3. Zentrierte `<p align="center">` Abschnitte zu H1 promoten (für prominente Titelbanner)
//  4. `<br>` außerhalb Codefences -> Newline
//  5. Generische `<p>` Blöcke -> Absatztrennung (Leerzeilen) entfernt Formatierungstags
//  6. Navigationszeilen ("Zurück | Weiter" etc.) heuristisch filtern
//  7. Relative Bildpfade (`![alt](rel.png)`, `<img src="rel.png">`) -> absolute RAW URLs über [AppConfig.rawFile]
//  8. Inline HTML Vereinheitlichung (_applyInlineHtmlTransform): Links, strong/em, code, span etc.
//  9. Mehrfache Leerzeilen reduzieren (>2 -> 1)
//
// Anker-Kommentare: `<!--anchor:slug-->` vor einer Überschrift erleichtern spätere Scroll-Implementierung
// (TOC kann Slugs matchen). Der Renderer ignoriert HTML-Kommentare.
//
// Nicht behandelt:
//  * Tabellen mit komplexem HTML
//  * Block-Level Code (<pre><code>) – bisher selten beobachtet, könnte ergänzt werden
//  * MathJax / LaTeX
//
// Sicherheit: Explizites Entfernen von unbekannten Inline-Tags – minimiert Rendering-Artefakte.
//
// Beispiel (vereinfachter Ausschnitt):
// ```html
// <h2> Titel </h2>\n<p align="center">Zentriert</p>\nZurück | Weiter
// ```
// wird zu
// ```markdown
// <!--anchor:titel-->
// ## Titel
// <!--anchor:zentriert-->
// # Zentriert
// ```
// (Navigationszeile entfernt)
//
// Edge Cases:
//  * Mehrere aufeinanderfolgende nav-Zeilen: alle gefiltert
//  * Bilder mit bereits absoluter http(s) URL bleiben unverändert
//  * Codefences: HTML darin bleibt unverändert (bewusst)
//
// Performance: String-Ersatz / Regex auf gesamten Dokument – für typische README Größen (<200 KB) unkritisch.
// Kann später in kleinere Streaming-Schritte refaktoriert werden falls nötig.
import '../config.dart';

/// Führt alle oben dokumentierten Schritte aus.
/// [currentRepoPath] ermöglicht korrektes Auflösen relativer Assets.
String preprocessMarkdown(String input, {String? currentRepoPath}) {
  var out = input;

  // Normalize line endings
  out = out.replaceAll('\r\n', '\n');

  // Convert <h1>..<h6> to markdown syntax
  out = out.replaceAllMapped(
    RegExp(r'<h([1-6])[^>]*>(.*?)</h\1>', caseSensitive: false, dotAll: true),
    (m) {
      final level = int.parse(m.group(1)!);
      final text = _stripInlineHtml(m.group(2)!);
        return _headingWithAnchor(level, text.trim());
    },
  );

  // Convert <p align="center"> ... </p> into H1 (if not already containing heading marks)
  out = out.replaceAllMapped(
    RegExp(r'''<p[^>]*align=["']center["'][^>]*>(.*?)</p>''', caseSensitive: false, dotAll: true),
    (m) {
      var inner = m.group(1)!;
      // Breaks <br> -> space
      inner = inner.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
      inner = _stripInlineHtml(inner).replaceAll('&quot;', '"').trim();
      if (inner.isEmpty) return '';
      return _headingWithAnchor(1, inner);
    },
  );

  // Generic <br> -> single newline (outside of code fences)
  out = _mapOutsideCodeFences(out, (segment) => segment.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n'));

  // Replace generic <p> blocks with blank-line separated paragraphs.
  out = out.replaceAllMapped(
    RegExp(r'''<p(?![^>]*align=["']center["']).*?>''', caseSensitive: false),
    (_) => '\n\n',
  ).replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');

  // Remove simple wiki navigation footer/header lines (Zurück | Weiter ...)
  final navPatterns = [
    RegExp(r'^\s*zurück\s*\|?\s*$', caseSensitive: false),
    RegExp(r'^\s*weiter\s*\|?\s*$', caseSensitive: false),
    RegExp(r'zurück zur themen-übersicht', caseSensitive: false),
    RegExp(r'zurück zur startseite des wikis', caseSensitive: false),
  ];
    final filtered = <String>[];
  for (final line in out.split('\n')) {
    var l = line.trim();
    if (l.isEmpty) { filtered.add(line); continue; }

    // Remove leading markdown heading markers and blockquote markers for detection
    var detection = l.replaceFirst(RegExp(r'^[#>]+\s*'), '');

    final isNav = navPatterns.any((p) => p.hasMatch(detection));
    if (isNav) continue;

    // Normalize pipes/spaces
    final simplified = detection
        .toLowerCase()
        .replaceAll('|', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Patterns we consider pure navigation noise
    const navSingles = [
      'zurück',
      'weiter',
      'zurück weiter',
      'weiter zurück',
    ];
    if (navSingles.contains(simplified)) continue;

    // Specifically catch variants like 'zurück |', 'zurück | weiter', 'zurück | startseite des wikis'
    if (RegExp(r'^(zurück\s*\|.*|weiter\s*\|.*)$', caseSensitive: false).hasMatch(detection)) {
      // If the rest after first pipe contains only nav/overview words, skip
      final afterPipe = detection.split('|').skip(1).join(' ').toLowerCase().trim();
      if (afterPipe.isEmpty ||
          RegExp(r'^(weiter|zurück.*|themen-übersicht.*|startseite des wikis.*)$', caseSensitive: false)
              .hasMatch(afterPipe)) {
        continue;
      }
    }

    filtered.add(line);
  }
  out = filtered.join('\n');

  // Rewrite markdown image references relative to current file if provided
  if (currentRepoPath != null) {
    final baseDir = _dirOf(currentRepoPath);
    // ![alt](path "title") pattern
    out = out.replaceAllMapped(RegExp(r'!\[[^\]]*]\(([^)]+)\)'), (m) {
      final inner = m.group(1)!.trim();
      String urlPart = inner;
      // Separate optional " title"
      final titleMatch = RegExp(r'^(.*?)(\s+".*")$').firstMatch(inner);
      if (titleMatch != null) {
        urlPart = titleMatch.group(1)!.trim();
      }
      if (_isExternalOrData(urlPart)) return m.group(0)!; // leave untouched
      final resolved = _resolveAssetRelative(baseDir, urlPart);
      if (resolved == null) return m.group(0)!;
      return m.group(0)!.replaceFirst(urlPart, AppConfig.rawFile(resolved));
    });

    // <img src="..."> tags
    out = out.replaceAllMapped(
      RegExp(r'''<img[^>]+src=["']([^"']+)["'][^>]*>''', caseSensitive: false),
      (m) {
      final src = m.group(1)!;
      if (_isExternalOrData(src)) return m.group(0)!; // unchanged
      final resolved = _resolveAssetRelative(baseDir, src);
      if (resolved == null) return m.group(0)!;
    return m.group(0)!.replaceFirst(src, AppConfig.rawFile(resolved));
  });
  }

  // Collapse >2 blank lines to just one
  // First, normalize common inline HTML tags across the whole document (outside code fences)
  out = _applyInlineHtmlTransform(out);

  // Now collapse >2 blank lines to just one (after transformations which may introduce spacing)
  out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return out;
}

/// Entfernt einfache Inline HTML-Tags, behält aber Textinhalt.
/// Wird v.a. vor Heading-Konvertierung genutzt, um saubere Titel zu generieren.
String _stripInlineHtml(String s) {
  // Remove simple inline tags but keep their text content.
  return s
      .replaceAll(RegExp(r'</?(strong|em|b|i|span)[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<[^>]+>'), '');
}

/// Liefert Verzeichnisteil eines Repo-Pfades (`docs/a/b/README.md` -> `docs/a/b`).
String _dirOf(String repoPath) {
  final idx = repoPath.lastIndexOf('/');
  if (idx == -1) return '';
  return repoPath.substring(0, idx);
}

bool _isExternalOrData(String url) => url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:');

/// Versucht relativen Asset-Pfad (Bild) in Repo-Kontext zu normalisieren.
/// Behält Pfade innerhalb `docs/` Struktur; erlaubt `../` Traversal mit Begrenzung.
String? _resolveAssetRelative(String baseDir, String href) {
  String h = href.trim();
  if (h.isEmpty) return null;
  // strip leading ./
  h = h.replaceFirst(RegExp(r'^\./'), '');
  String candidate;
  if (h.startsWith('/')) {
    // Treat / as root of docs directory
  candidate = '${AppConfig.dirPath}$h';
  } else if (h.startsWith('../')) {
    var parts = baseDir.split('/');
    var rel = h;
    while (rel.startsWith('../') && parts.length > 1) { // keep at least docs
      rel = rel.substring(3);
      if (parts.isNotEmpty) parts.removeLast();
    }
    candidate = (parts.where((e) => e.isNotEmpty).join('/')) + '/' + rel;
  } else if (h.startsWith('docs/')) {
    candidate = h;
  } else {
    candidate = baseDir.isEmpty ? h : '$baseDir/$h';
  }
  // Normalize //
  candidate = candidate.replaceAll(RegExp(r'/+'), '/');
  return candidate;
}

/// Baut Markdown-Überschrift inklusive vorgelagertem HTML-Kommentar-Anker.
/// Anker wird aus normalisierter, diakritikfähiger Kleinschreibung erzeugt.
String _headingWithAnchor(int level, String text) {
  final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  var anchor = clean.toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u00C0-\u024f\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '-');
  return '\n<!--anchor:$anchor-->\n${'#' * level} $clean\n';
}

/// Apply conversions of simple inline HTML tags (<strong>, <em>, <a>, <span>, <code>, etc.)
/// to pure markdown equivalents (or strip them) across the full document outside fenced code.
/// Transformiert Inline-HTML außerhalb von Codefences in Markdown.
///
/// Details:
///  * `<a>` -> `[text](href)` (Fallback: href selbst falls leerer Inhalt)
///  * `<strong>/<b>` -> `**...**`
///  * `<em>/<i>` -> `*...*` (Escaping von * innerhalb)
///  * `<code>` -> `` `...` `` wenn keine Backticks enthalten
///  * `<span>` unwrap
///  * Restliche ungefährliche Tags (u, sup, sub) entfernt ohne Format
///  * Verbleibende unspezifische Tags (ohne Kommentar) restlos gestripped
String _applyInlineHtmlTransform(String text) {
  return _mapOutsideCodeFences(text, (segment) {
    var s = segment;

    // <a href="url">text</a> -> [text](url)
    s = s.replaceAllMapped(
      // Use raw triple-quoted string so both single and double quotes can appear inside the character class
      RegExp(r'''<a[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>''', caseSensitive: false, dotAll: true),
      (m) {
        final href = m.group(1)!.trim();
        var inner = m.group(2)!;
        inner = inner.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
        inner = inner.replaceAll(RegExp(r'</?(strong|b|em|i|span)[^>]*>', caseSensitive: false), '');
        inner = inner.replaceAll(RegExp(r'<[^>]+>'), '');
        inner = inner.replaceAll('&amp;', '&').replaceAll('&quot;', '"');
        if (inner.trim().isEmpty) inner = href;
        inner = inner.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return '[$inner]($href)';
      },
    );

    // <strong>/<b> -> **text**
    s = s.replaceAllMapped(
      RegExp(r'<(strong|b)[^>]*>(.*?)</(strong|b)>', caseSensitive: false, dotAll: true),
      (m) {
        var inner = m.group(2)!;
        inner = inner.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
        inner = inner.replaceAll(RegExp(r'</?(em|i|span)[^>]*>', caseSensitive: false), '');
        inner = inner.replaceAll(RegExp(r'<[^>]+>'), '');
        inner = inner.trim();
        if (inner.isEmpty) return '';
        if (inner.startsWith('**') && inner.endsWith('**')) return inner;
        return '**$inner**';
      },
    );

    // <em>/<i> -> *text*
    s = s.replaceAllMapped(
      RegExp(r'<(em|i)[^>]*>(.*?)</(em|i)>', caseSensitive: false, dotAll: true),
      (m) {
        var inner = m.group(2)!;
        inner = inner.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
        inner = inner.replaceAll(RegExp(r'</?(strong|b|span)[^>]*>', caseSensitive: false), '');
        inner = inner.replaceAll(RegExp(r'<[^>]+>'), '');
        inner = inner.trim();
        if (inner.isEmpty) return '';
        if (RegExp(r'^\*.*\*$').hasMatch(inner)) return inner; // already emphasized
        // Escape * inside text to avoid breaking formatting
        inner = inner.replaceAll('*', '\\*');
        return '*$inner*';
      },
    );

    // Inline <code>...</code> -> `...` (avoid if content contains backticks already, then just unwrap)
    s = s.replaceAllMapped(
      RegExp(r'<code[^>]*>(.*?)</code>', caseSensitive: false, dotAll: true),
      (m) {
        var inner = m.group(1)!;
        inner = inner.replaceAll(RegExp(r'<[^>]+>'), '');
        if (inner.contains('`')) return inner; // don't wrap to avoid conflicts
        // Collapse whitespace
        inner = inner.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        return inner.isEmpty ? '' : '`$inner`';
      },
    );

    // Unwrap <span ...>...</span>
    s = s.replaceAllMapped(
      RegExp(r'<span[^>]*>(.*?)</span>', caseSensitive: false, dotAll: true),
      (m) => m.group(1) ?? '',
    );

    // Remove any residual harmless inline tags leaving their content (u, sup, sub)
    s = s.replaceAll(RegExp(r'</?(u|sup|sub)[^>]*>', caseSensitive: false), '');

    // Finally remove any other stray tags that slipped through (but not HTML comments)
    s = s.replaceAll(RegExp(r'<(?!!--)[^>]+>'), '');

    return s;
  });
}

/// Apply a transformer only to text segments outside of fenced code blocks (``` ... ``` or ~~~ ... ~~~)
/// Hilfsfunktion, um Transformationen NUR außerhalb von Codefences anzuwenden.
/// Erkennung aktuell heuristisch (``` oder ~~~). Reicht für typische README Muster.
String _mapOutsideCodeFences(String text, String Function(String) transform) {
  final buffer = StringBuffer();
  final fenceRegex = RegExp(r'(^|\n)(```|~~~).*?\n.*?\n\2', dotAll: true); // simplistic
  int index = 0;
  for (final match in fenceRegex.allMatches(text)) {
    if (match.start > index) {
      buffer.write(transform(text.substring(index, match.start)));
    }
    buffer.write(text.substring(match.start, match.end));
    index = match.end;
  }
  if (index < text.length) buffer.write(transform(text.substring(index)));
  return buffer.toString();
}
