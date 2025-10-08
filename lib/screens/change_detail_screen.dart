import 'package:flutter/material.dart';
import '../services/change_tracker_service.dart';
import '../services/wiki_service.dart';
import '../utils/markdown_preprocess.dart';
import '../widgets/markdown_view.dart';
import '../utils/naming.dart';

/// ChangeDetailScreen
/// ==================
/// Zeigt die Detailansicht einer einzelnen geänderten Markdown-Datei aus dem
/// Change-Tracking an. Unterstützt drei Darstellungsmodi:
///
/// 1. Diff (nur bei `ChangeStatus.modified`): Vereinfachter zeilenbasierter Delta-Vergleich.
/// 2. Gerenderte Markdown-Ansicht (Standard, wenn kein Diff oder Diff ausgeblendet).
/// 3. Raw-Ansicht (unverarbeiteter Markdown nach Preprocessing – hilfreich bei Analyse / Debug).
///
/// Gründe für vereinfachten Diff:
/// * Performance / Implementationsaufwand gering.
/// * Primäränderungen (Zeilen eingefügt / geändert) werden ausreichend signalisiert.
/// * Wort-Level Diff kann später ergänzt werden ohne API zu brechen.
class ChangeDetailScreen extends StatefulWidget {
  /// Datei-Metadaten & Diff-Infos.
  final ChangeFile file;
  const ChangeDetailScreen({super.key, required this.file});
  @override
  State<ChangeDetailScreen> createState() => _ChangeDetailScreenState();
}

class _ChangeDetailScreenState extends State<ChangeDetailScreen> {
  String? _content;          // Vorprozessierter Markdown-Text
  bool _loading = true;      // Ladezustand
  String? _error;            // Fehlermeldung falls Laden scheitert
  bool _showRaw = false;     // Raw vs gerendert
  bool _showDiff = true;     // Diff sichtbar (nur wenn modified)
  final _svc = WikiService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Holt den aktuellen Inhaltsstand und wendet Preprocessing an.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final (txt, _) = await _svc.fetchMarkdownByRepoPath(widget.file.path);
      _content = preprocessMarkdown(txt, currentRepoPath: widget.file.path);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final title = prettifyTitle(f.path.split('/').last.replaceAll('.md', ''));
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (f.status == ChangeStatus.modified) ...[
            IconButton(
              tooltip: _showDiff ? 'Diff ausblenden' : 'Diff anzeigen',
              icon: Icon(_showDiff ? Icons.history_toggle_off : Icons.compare),
              onPressed: () => setState(() => _showDiff = !_showDiff),
            ),
            IconButton(
              tooltip: _showRaw ? 'Gerendert anzeigen' : 'Rohtext anzeigen',
              icon: Icon(_showRaw ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _showRaw = !_showRaw),
            ),
          ]
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Fehler: $_error'))
              : _content == null
                  ? const Center(child: Text('Kein Inhalt'))
                  : _showRaw
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: SingleChildScrollView(child: SelectableText(_content!)),
                        )
                      : _showDiff && f.diff != null
                          ? _buildDiff(context, f)
                          : MarkdownView(content: _content!),
    );
  }

  /// Baut eine vereinfachte Diff-Ansicht (zeilenbasiert). HTML-Fragmente werden
  /// on-the-fly sanitisiert um Render-Artefakte zu vermeiden.
  Widget _buildDiff(BuildContext context, ChangeFile f) {
    final lines = f.diff ?? [];
    final theme = Theme.of(context);
    final spans = <TextSpan>[];
    for (final d in lines) {
      Color? c;
      if (d.prefix == '+') {
        c = Colors.green.shade500;
      } else if (d.prefix == '➜') {
        c = Colors.orange.shade400;
      } else if (d.prefix == '-') {
        c = Colors.red.shade400;
      }
      String base = d.text;
      if (base.contains('<')) {
        try { base = sanitizeForPreview(base); } catch (_) {}
      }
      spans.add(
        TextSpan(
          text: d.prefix == ' ' ? '  $base\n' : '${d.prefix} $base\n',
          style: theme.textTheme.bodySmall?.copyWith(color: c),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.bodySmall,
            children: spans,
          ),
        ),
      ),
    );
  }
}
