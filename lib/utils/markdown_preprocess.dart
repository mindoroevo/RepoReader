// Simplified, robust Markdown preprocessing.
// Focus: remove anchors, empty headings, navigation noise, basic HTML inline normalization, resolve relative images.

import '../config.dart';

String preprocessMarkdown(String input, {String? currentRepoPath}) {
  var out = input.replaceAll('\r\n', '\n');

  // 1. HTML Headings -> Markdown
  out = out.replaceAllMapped(
    RegExp(r'<h([1-6])[^>]*>(.*?)</h\1>', caseSensitive: false, dotAll: true),
    (m) {
      final lvl = int.parse(m.group(1)!);
      final txt = _stripInline(m.group(2)!);
      return '\n${'#' * lvl} ${txt.trim()}\n';
    },
  );

  // 2. Center paragraphs -> H1 (use double quoted raw string to allow both ' and ")
  out = out.replaceAllMapped(
    RegExp(r'''<p[^>]*align=['"]center['"][^>]*>(.*?)</p>''', caseSensitive: false, dotAll: true),
    (m) {
      final inner = _stripInline(m.group(1)!).trim();
      if (inner.isEmpty) return '';
      return '\n# $inner\n';
    },
  );

  // 3. <br> outside code fences -> newline
  out = _outsideCode(out, (seg) => seg.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n'));

  // 4. Generic paragraph tags -> blank line separation
  out = out
      .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');

  // 5. Navigation noise lines removal
  final navLine = RegExp(r'^(zurück|weiter)(?:\s*\|.*)?$', caseSensitive: false);
  out = out
      .split('\n')
      .where((l) {
        final t = l.trim();
        if (t.isEmpty) return true;
        final norm = t.replaceAll(RegExp(r'^[#>]+'), '').trim().toLowerCase();
        if (navLine.hasMatch(norm)) return false;
        if (norm.contains('zurück zur themen-übersicht')) return false;
        if (norm.contains('zurück zur startseite des wikis')) return false;
        return true;
      })
      .join('\n');

  // 6. Relative images
  if (currentRepoPath != null) {
    final base = _dirOf(currentRepoPath);
    out = out.replaceAllMapped(
      RegExp(r'!\[[^\]]*]\(([^)]+)\)'),
      (m) {
        var inside = m.group(1)!.trim();
        final titleM = RegExp(r'^(.*?)(\s+".*")$').firstMatch(inside);
        String title = '';
        if (titleM != null) {
          inside = titleM.group(1)!.trim();
          title = titleM.group(2)!;
        }
        if (_isExternal(inside)) return m.group(0)!; // leave
        final resolved = _resolveAsset(base, inside);
        if (resolved == null) return m.group(0)!;
        return m.group(0)!.replaceFirst(inside, AppConfig.rawFile(resolved)) + title;
      },
    );
  }

  // 7. Inline HTML normalization (outside code)
  out = _outsideCode(out, _inlineHtmlToMarkdown);

  // 8. Remove legacy anchor comments (no longer used for scroll)
  out = out.replaceAll(RegExp(r'<!--anchor:[^>]+-->'), '');

  // 9. Remove empty headings (#, ##, ### with no text)
  out = out.replaceAll(RegExp(r'^#{1,6}\s*$', multiLine: true), '');

  // 10. Collapse >2 blank lines
  out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return out.trim();
}

String _stripInline(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');

String _inlineHtmlToMarkdown(String segment) {
  var s = segment;
  // Links
  s = s.replaceAllMapped(
    RegExp(r'''<a[^>]*href=['"]([^'"]+)['"][^>]*>(.*?)</a>''', caseSensitive: false, dotAll: true),
    (m) {
      final href = m.group(1)!.trim();
      var inner = _stripInline(m.group(2)!);
      if (inner.trim().isEmpty) inner = href;
      inner = inner.replaceAll(RegExp(r'\s+'), ' ').trim();
      return '[$inner]($href)';
    },
  );
  // strong/b
  s = s.replaceAllMapped(
    RegExp(r'<(strong|b)[^>]*>(.*?)</(strong|b)>', caseSensitive: false, dotAll: true),
    (m) {
      final inner = _stripInline(m.group(2)!).trim();
      return inner.isEmpty ? '' : '**$inner**';
    },
  );
  // em/i
  s = s.replaceAllMapped(
    RegExp(r'<(em|i)[^>]*>(.*?)</(em|i)>', caseSensitive: false, dotAll: true),
    (m) {
      var inner = _stripInline(m.group(2)!).trim();
      if (inner.isEmpty) return '';
      inner = inner.replaceAll('*', '\\*');
      return '*$inner*';
    },
  );
  // inline code
  s = s.replaceAllMapped(
    RegExp(r'<code[^>]*>(.*?)</code>', caseSensitive: false, dotAll: true),
    (m) {
      var inner = _stripInline(m.group(1)!).replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (inner.isEmpty) return '';
      if (inner.contains('`')) return inner; // avoid wrapping if backticks inside
      return '`$inner`';
    },
  );
  // Remove span/u/sup/sub wrappers
  s = s.replaceAll(RegExp(r'</?(span|u|sup|sub)[^>]*>', caseSensitive: false), '');
  // Strip any remaining tags (keep comments)
  s = s.replaceAll(RegExp(r'<(?!!--)[^>]+>'), '');
  return s;
}

String _outsideCode(String text, String Function(String) transform) {
  final fence = RegExp(r'(```|~~~).*?\1', dotAll: true);
  final b = StringBuffer();
  int i = 0;
  for (final m in fence.allMatches(text)) {
    if (m.start > i) b.write(transform(text.substring(i, m.start)));
    b.write(text.substring(m.start, m.end));
    i = m.end;
  }
  if (i < text.length) b.write(transform(text.substring(i)));
  return b.toString();
}

String _dirOf(String path) {
  final i = path.lastIndexOf('/');
  return i == -1 ? '' : path.substring(0, i);
}

bool _isExternal(String p) => p.startsWith('http://') || p.startsWith('https://') || p.startsWith('data:');

String? _resolveAsset(String baseDir, String href) {
  var h = href.trim();
  if (h.isEmpty) return null;
  h = h.replaceFirst(RegExp(r'^\./'), '');
  String candidate;
  if (h.startsWith('/')) {
    candidate = '${AppConfig.dirPath}$h';
  } else if (h.startsWith('../')) {
    var parts = baseDir.split('/');
    var rel = h;
    while (rel.startsWith('../') && parts.length > 1) {
      rel = rel.substring(3);
      if (parts.isNotEmpty) parts.removeLast();
    }
    candidate = '${parts.where((e) => e.isNotEmpty).join('/')}/$rel';
  } else if (h.startsWith('docs/')) {
    candidate = h;
  } else {
    candidate = baseDir.isEmpty ? h : '$baseDir/$h';
  }
  return candidate.replaceAll(RegExp(r'/+'), '/');
}
