/// Ein Eintrag im Inhaltsverzeichnis.
class TocItem {
  final int level; // 1..6
  final String text;
  final String anchor; // generated id
  TocItem(this.level, this.text, this.anchor);
}

/// Erstellt ein TOC aus Markdown-Inhalt (ATX Headings `#`..`######`).
/// Entfernt trailing Hashes und generiert eindeutige Anchors (dedupliziert mit Suffix).
List<TocItem> buildToc(String markdown) {
  final lines = markdown.split('\n');
  final items = <TocItem>[];
  final used = <String,int>{};
  final heading = RegExp(r'^(#{1,6})\s+(.+)$');
  for (final line in lines) {
    final m = heading.firstMatch(line.trim());
    if (m == null) continue;
    final level = m.group(1)!.length;
    var text = m.group(2)!.trim();
    // Strip trailing hashes (ATX heading style)
    text = text.replaceFirst(RegExp(r'\s+#+\s*$'), '').trim();
    var anchor = text.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u00C0-\u024f\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    final count = used.update(anchor, (v) => v+1, ifAbsent: ()=>0);
    if (count > 0) anchor = '$anchor-$count';
    items.add(TocItem(level, text, anchor));
  }
  return items;
}