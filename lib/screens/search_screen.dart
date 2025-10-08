import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
/// SearchScreen (Basis Markdown Suche)
/// ===================================
/// Volltext-Suche über alle Markdown-Dateien.
///
/// Strategie:
///  * Rekursives Auflisten aller Markdown-Dateien bei jedem Suchlauf (kein persistent Index)
///  * Multi-Term AND: Jeder eingegebene Suchbegriff (Whitespace getrennt) muss vorkommen
///  * Fallunabhängig (lowercase Vergleich)
///  * Snippet-Generierung: Fenster von ±60 Zeichen um erste Treffer-Position
///  * Hervorhebung: Markierung von Begriffen über temporäre Delimiter « » und spätere RichText-Auflösung
///
/// Performance / Trade-offs:
///  * Für moderate Mengen an Dateien ausreichend. Für sehr große Repos könnte man Pre-Indexing / Caching erwägen.
///  * Abbruchsteuerung via einfacher _searchToken (wenn neue Eingabe => laufende Schleife beendet)
///  * Progressive UI-Aktualisierung alle 10 Treffer (gefühlte Responsiveness)
///
/// Erweiterungsideen:
///  * Ranking / Relevanz-Score (Termhäufigkeit, Titel-Matches höher gewichten)
///  * Highlight im Dateinamen / Pfad
///  * Fuzzy Matching (Levenshtein) / Präfix / Substring-Optimierung
///  * Synonym-Lexikon oder deutsche Umlaute Normalisierung
///
/// Bekannte Limitierungen:
///  * Inline-Markdown-Syntax wird nicht entfernt – Treffer können in Formatierungszeichen landen
///  * Snippet kann Worte mitten im Markdown Link abschneiden
///  * Kein Scrollen zum Treffer in Zielseite (nur Öffnen der Datei ganz oben)
///
/// Fehlerbehandlung: Netzwerk- / Ladefehler werden still ignoriert → Datei wird übersprungen.
/// Hinweis: Für große Repos empfiehlt sich später ein persistenter Index.
import '../services/wiki_service.dart';
import '../config.dart';
import '../utils/naming.dart';
import 'page_screen.dart';

class SearchScreen extends StatefulWidget { const SearchScreen({super.key}); @override State<SearchScreen> createState() => _SearchScreenState(); }

/// Interner Container für ein Suchergebnis.
class _SearchResultItem {
  final String title;
  final String path;
  final String snippet;
  _SearchResultItem(this.title, this.path, this.snippet);
}

class _SearchScreenState extends State<SearchScreen> {
  final _svc = WikiService();
  final _controller = TextEditingController();
  bool _loading = false;
  List<_SearchResultItem> _results = [];
  int _searchToken = 0; // cancellation token
  String _lastQuery = '';

  /// Führt eine neue Suche aus.
  /// Setzt Ladezustand, bricht via Token ab falls Benutzer eine neue Eingabe startet.
  Future<void> _run() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) { setState(()=> _results = []); return; }
    final q = raw.toLowerCase();
    if (q == _lastQuery) return; // avoid duplicate
    _lastQuery = q;
    final terms = q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final token = ++_searchToken;
    setState(() { _loading = true; _results = []; });
    List<RepoEntry> files;
    try {
      files = await _svc.listAllMarkdownFilesRecursively(AppConfig.dirPath);
    } catch (_) { setState(()=> _loading = false); return; }
    final List<_SearchResultItem> out = [];
    for (final f in files) {
      if (token != _searchToken) return; // cancelled
      try {
        final (txt, _) = await _svc.fetchMarkdownByRepoPath(f.path);
        final lower = txt.toLowerCase();
        bool allMatch = true;
        int firstPos = -1;
        for (final t in terms) {
          final p = lower.indexOf(t);
            if (p < 0) { allMatch = false; break; }
          if (firstPos == -1 || (p >=0 && p < firstPos)) firstPos = p;
        }
        if (!allMatch) continue;
        // Build snippet around firstPos
        const contextChars = 60;
        if (firstPos < 0) continue;
        final start = (firstPos - contextChars).clamp(0, lower.length);
        final end = (firstPos + contextChars).clamp(0, lower.length);
        var snippet = txt.substring(start, end);
        // Highlight: wrap each term (case-insensitive) with markers « » temporarily
        for (final t in terms) {
          final regex = RegExp(RegExp.escape(t), caseSensitive: false);
          snippet = snippet.replaceAllMapped(regex, (m) => '«${m.group(0)}»');
        }
        snippet = snippet.replaceAll('\n', ' ').trim();
        final displayTitle = prettifyTitle(f.name.replaceAll('.md',''));
        out.add(_SearchResultItem(displayTitle, f.path, snippet));
      } catch (_) {}
      // Progressive update every 10 matches
      if (out.length % 10 == 0) {
        if (!mounted || token != _searchToken) return;
        setState(() => _results = List.of(out));
      }
    }
    if (!mounted || token != _searchToken) return;
    setState(() { _results = out; _loading = false; });
  }

  @override
  void dispose() {
    _searchToken++; // cancel
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.search)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: l10n.searchMultiHint,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.clear,
                      onPressed: () { _controller.clear(); _lastQuery=''; setState(()=> _results=[]); },
                    ),
                  IconButton(icon: const Icon(Icons.search), onPressed: _run),
                ],
              ),
            ),
            onChanged: (_) { _debounceRun(); },
            onSubmitted: (_) => _run(),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty && !_loading
                ? Center(child: Text(l10n.noHits))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (_, i) {
                      final r = _results[i];
                      return _SearchResultTile(item: r, query: _lastQuery.split(RegExp(r'\s+')).where((e)=>e.isNotEmpty).toList());
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  /// Primitive 320ms Debounce: Jede Änderung erhöht Token; verzögerter Future prüft Konsistenz.
  void _debounceRun() {
    // Quick debounce via 300ms future cancel; simple approach
    final currentToken = ++_searchToken;
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return; if (currentToken != _searchToken) return; _run();
    });
  }
}

/// Listeneintrag für ein Suchergebnis inklusive RichText-Hervorhebung.
class _SearchResultTile extends StatelessWidget {
  final _SearchResultItem item; final List<String> query;
  const _SearchResultTile({required this.item, required this.query});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final spans = <TextSpan>[];
    final text = item.snippet;
    int index = 0; // iterate over snippet and mark « » segments
    while (true) {
      final start = text.indexOf('«', index);
      if (start < 0) { spans.add(TextSpan(text: text.substring(index))); break; }
      if (start > index) spans.add(TextSpan(text: text.substring(index, start)));
      final end = text.indexOf('»', start+1);
      if (end < 0) { spans.add(TextSpan(text: text.substring(start))); break; }
      final word = text.substring(start+1, end);
      spans.add(TextSpan(text: word, style: TextStyle(color: primary, fontWeight: FontWeight.w600)));
      index = end + 1;
    }
    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PageScreen(
              repoPath: item.path,
              title: item.title,
            ),
          ),
        );
      },
      title: Text(item.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top:4),
        child: RichText(text: TextSpan(style: theme.textTheme.bodySmall, children: spans)),
      ),
      trailing: Text(item.path.split('/').last, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}
