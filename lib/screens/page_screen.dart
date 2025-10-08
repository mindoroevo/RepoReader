import 'package:flutter/material.dart';
import '../services/wiki_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/markdown_view.dart';
import '../utils/naming.dart';
import '../utils/markdown_preprocess.dart';
import '../utils/toc.dart';

/// PageScreen
/// ==========
/// Anzeige einer einzelnen Markdown-Seite inkl. Preprocessing, TOC-Erstellung
/// und interner Link-Navigation. Kein globaler Zustand – jeder Navigationssprung
/// instanziiert eine neue `PageScreen`.
/// Zeigt bei Cache-Treffern einen "Offline" Hinweis in der AppBar.
class PageScreen extends StatefulWidget {
  final String repoPath; // z.B. 'docs/section/README.md'
  final String title;    // Display title (can be prettified)
  const PageScreen({super.key, required this.repoPath, required this.title});
  @override State<PageScreen> createState() => _PageScreenState();
}

class _PageScreenState extends State<PageScreen> {
  final _svc = WikiService();
  String _content = '';
  List<TocItem> _toc = [];
  bool _fromCache = false;
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  /// Lädt den Markdown-Text, führt Preprocessing (Normalisierung & Link/Bild-Umsetzung)
  /// durch und baut anschließend das TOC. Fehler werden im State gespeichert.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
    final (txt, fromCache) = await _svc.fetchMarkdownByRepoPath(widget.repoPath);
  final processed = preprocessMarkdown(txt, currentRepoPath: widget.repoPath);
  final toc = buildToc(processed);
  setState(() { _content = processed; _toc = toc; _fromCache = fromCache; _error = null; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally { setState(() => _loading = false); }
  }

  /// Öffnet interne Links oder startet den System-Mailclient für `mailto:` oder rohe E-Mail.
  /// Relative Pfade werden über `resolveRepoRelative` + README Index (Fallback) aufgelöst.
  void _openInternal(String target) {
    // Email links -> mail client
    if (target.startsWith('mailto:') || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(target)) {
      final uri = Uri.parse(target.startsWith('mailto:') ? target : 'mailto:$target');
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    final resolved = resolveRepoRelative(widget.repoPath, target);
    if (resolved == null) return; // external or anchor
    WikiService.resolveExistingReadmePath(resolved).then((actual) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PageScreen(
            repoPath: actual,
            title: prettifyTitle(actual),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = prettifyTitle(widget.title);
    return Scaffold(
      appBar: AppBar(title: Text(displayTitle), actions: [
        if (_toc.isNotEmpty)
          IconButton(
            tooltip: 'Inhalt',
            icon: const Icon(Icons.list_alt),
            onPressed: () => _openToc(context),
          ),
        if (_fromCache) const Padding(padding: EdgeInsets.only(right: 12), child: Center(child: Text('Offline')))
      ]),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_loading) {
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())],
              ),
            );
          }
          if (_error != null) {
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Fehler beim Laden:\n$_error', style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: const Text('Erneut versuchen')),
                ],
              ),
            );
          }
          if (_content.trim().isEmpty) {
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [Text('Keine Inhalte gefunden.', style: TextStyle(fontStyle: FontStyle.italic))],
              ),
            );
          }
          // Content state: use Markdown (already scrollable) directly.
          return RefreshIndicator(
            onRefresh: _load,
            child: MarkdownView(content: _content, onInternalLink: _openInternal),
          );
        },
      ),
    );
  }

  /// Zeigt das Inhaltsverzeichnis als Bottom-Sheet.
  void _openToc(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: ListView.builder(
            itemCount: _toc.length,
            itemBuilder: (c, i){
              final t = _toc[i];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.only(left: 12.0 + (t.level-1)*12.0, right: 12),
                title: Text(t.text, style: TextStyle(fontSize: 14 + (t.level==1?2:0), fontWeight: t.level<=2? FontWeight.w600: FontWeight.w400)),
                onTap: () {
                  Navigator.pop(c);
                  _scrollToAnchor(t.anchor);
                },
              );
            },
          ),
        );
      }
    );
  }

  void _scrollToAnchor(String anchor) {
    // (Noch nicht implementiert) – künftige Umsetzung über Keys pro Heading.
  }
}
