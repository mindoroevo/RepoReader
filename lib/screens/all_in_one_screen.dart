import 'package:flutter/material.dart';
/// AllInOneScreen (Legacy / Optional)
/// =================================
/// Bildschirm der alle README-Dateien untereinander in EINEM langen Dokument
/// zusammenfasst (historisches/optionales Feature – aktuell nicht verlinkt).
///
/// Motivation:
///  * Schnelles Volltext-Scrollen durch gesamten Wissensbestand
///  * Offline-Ausdruck / PDF-Erstellung (System Print) einfacher
///
/// Vorgehen beim Laden:
///  1. Falls `files` leer: rekursiv alle README-Dateien ermitteln
///  2. Jede Datei laden → `preprocessMarkdown` anwenden (gleiche Pipeline wie Einzelansicht)
///  3. Vor jede Datei einen künstlichen H1-Header mit ihrem (bereinigten) Namen setzen
///  4. Dateien mit `---` (Markdown Horizontal Rule) trennen
///
/// Einschränkungen / Nicht-Ziele:
///  * Keine inkrementelle Nachladung (alles oder nichts)
///  * Keine Inhaltsverzeichnisse / Sprunganker (könnte nachgerüstet werden)
///  * Kein dediziertes Change-Highlighting pro Abschnitt (Diff nur im Einzelmodus)
///
/// Performance-Hinweis:
///  * Bei sehr vielen README-Dateien kann Startzeit steigen → evtl. spätere Streaming- oder Lazy-Implementierung.
///  * Aktuell tolerierbar für mittelgroße Dokumentations-Repos.
///
/// Mögliche Erweiterungen:
///  * Generiertes globales TOC oben (Sammeln aller H1/H2 Anker)
///  * Collapse/Expand Abschnitte über Outline
///  * Such-Highlight innerhalb dieses zusammengesetzten Dokuments
///
/// Edge Cases:
///  * Fehler beim Laden einzelner Dateien: still ignoriert (Abschnitt fehlt dann schlicht)
///  * Doppelte Hauptüberschriften in Originaldateien: werden nicht dedupliziert
///
/// Hinweis: Aktuell im Haupt-Menü entfernt – kann bei Bedarf wieder aktiviert oder
/// vollständig entfernt werden (Refactor Cleanup möglich).
import '../services/wiki_service.dart';
import '../widgets/markdown_view.dart';
import '../config.dart';
import '../utils/naming.dart';
import '../utils/markdown_preprocess.dart';

class AllInOneScreen extends StatefulWidget {
  final List<RepoEntry> files;
  const AllInOneScreen({super.key, required this.files});
  @override State<AllInOneScreen> createState() => _AllInOneScreenState();
}

class _AllInOneScreenState extends State<AllInOneScreen> {
  final _svc = WikiService();
  String _content = '';
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  /// Baut den zusammengeführten Markdown-String aller übergebenen bzw. ermittelten Dateien.
  /// Fehler pro Datei werden abgefangen, damit der Rest weiterlaufen kann.
  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = widget.files.isEmpty
        ? await _svc.listReadmesRecursively(AppConfig.dirPath)
        : widget.files;
    final buffer = StringBuffer();
    for (final f in entries) {
    try {
  final (txt, _) = await _svc.fetchMarkdownByRepoPath(f.path);
  final processed = preprocessMarkdown(txt, currentRepoPath: f.path).trim();
  buffer.writeln('# ${prettifyTitle(f.name)}\n');
  buffer.writeln(processed);
        buffer.writeln('\n\n---\n');
      } catch (_) {}
    }
    setState(() { _content = buffer.toString(); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alles – von oben nach unten')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [ MarkdownView(content: _content) ]),
    );
  }
}
