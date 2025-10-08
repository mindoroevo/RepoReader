import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/wiki_service.dart';
import '../services/universal_file_reader.dart';
import '../config.dart';
import '../utils/naming.dart';
import 'page_screen.dart';
import 'universal_file_browser_screen.dart';

/// EnhancedSearchScreen
/// ====================
/// Erweiterte, kombinierte Suche (Dateiname + Inhalt) über ALLE Dateitypen.
///
/// Features:
/// * Volltext (nur Textdateien) + Dateinamen-Pfad Suche (alle Dateien)
/// * Kategorie / Nur-Text-Filter
/// * Snippet Hervorhebung (Mehrfachtreffer, Ellipsen)
/// * Progressive Resultat-Aktualisierung
///
/// Trade-Offs:
/// * Kein persistenter Index – jeder Lauf lädt Dateien erneut (Cache nutzt Reader)
/// * Für sehr große Repos potentiell langsam (Roadmap: Pre-Index / Inverted Index)
class EnhancedSearchScreen extends StatefulWidget {
  const EnhancedSearchScreen({super.key});

  @override
  State<EnhancedSearchScreen> createState() => _EnhancedSearchScreenState();
}

class _EnhancedSearchScreenState extends State<EnhancedSearchScreen> {
  final _svc = WikiService();
  final _controller = TextEditingController();
  
  bool _loading = false;
  List<_EnhancedSearchResultItem> _results = [];
  int _searchToken = 0;
  String _lastQuery = '';
  
  // Filter-Optionen
  String _selectedCategory = 'ALL_INTERNAL'; // sentinel for all categories
  bool _searchInContent = true;
  bool _searchInFilename = true;
  bool _onlyTextFiles = false;
  
  Map<String, List<UniversalRepoEntry>> _availableCategories = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _svc.listFilesByCategory(AppConfig.dirPath);
      setState(() {
        _availableCategories = categories;
      });
    } catch (_) {
      // Fehler beim Laden der Kategorien - wird ignoriert
    }
  }

  /// Führt die erweiterte Suche aus und aktualisiert `_results`.
  ///
  /// Schritte:
  /// 1. Liest Query, normalisiert auf lowercase und splittet in Terme (Whitespace getrimmt).
  /// 2. Holt Dateiliste (optional gefiltert nach Kategorie und/oder nur Text-Dateien).
  /// 3. Prüft Dateinamen/Pfad ODER (falls aktiviert & Text) Datei-Inhalt auf UND-Vorkommen aller Terme.
  /// 4. Erzeugt Snippet: Inhalt (mit Kontextfenster) oder Pfad-Fallback.
  /// 5. Sendet alle 10 Treffer einen progressiven Zwischenstand an die UI.
  ///
  /// Nebenläufigkeit / Abbruch: `_searchToken` wird inkrementiert bei neuem Lauf.
  /// Läuft eine ältere Iteration weiter, endet sie still durch Token-Mismatch.
  ///
  /// Performance: O(n * m) mit n=Dateien, m=Terme; Inhalte werden lazy geladen
  /// (nur bei aktivierter Content-Suche & Textdatei). Roadmap: Indexierung.
  Future<void> _runSearch() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _results = []);
      return;
    }

    final query = raw.toLowerCase();
    if (query == _lastQuery) return;
    _lastQuery = query;

    final terms = query.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final token = ++_searchToken;

    setState(() {
      _loading = true;
      _results = [];
    });

    try {
      // Lade alle Dateien oder gefilterte Dateien
      List<UniversalRepoEntry> files;
  if (_selectedCategory == 'ALL_INTERNAL') {
        files = _onlyTextFiles 
          ? await _svc.listTextFiles(AppConfig.dirPath)
          : await _svc.listAllFiles(AppConfig.dirPath);
      } else {
        files = _availableCategories[_selectedCategory] ?? [];
        if (_onlyTextFiles) {
          files = files.where((f) => f.isText).toList();
        }
      }

      final List<_EnhancedSearchResultItem> results = [];

      for (final file in files) {
        if (token != _searchToken) return; // Abgebrochen

        // Dateiname-Suche
        bool filenameMatch = false;
        if (_searchInFilename) {
          final filename = file.name.toLowerCase();
          final filepath = file.path.toLowerCase();
          filenameMatch = terms.every((term) => 
            filename.contains(term) || filepath.contains(term)
          );
        }

        // Content-Suche (nur für Textdateien)
        bool contentMatch = false;
        String? contentSnippet;
        
        if (_searchInContent && file.isText) {
          try {
            final result = await _svc.fetchFileByPath(file.path);
            final content = result.asText.toLowerCase();
            
            // Prüfe ob alle Suchterme im Inhalt vorkommen
            if (terms.every((term) => content.contains(term))) {
              contentMatch = true;
              contentSnippet = _generateSnippet(result.asText, terms);
            }
          } catch (_) {
            // Fehler beim Laden der Datei - ignorieren
          }
        }

        // Wenn mindestens ein Match-Typ zutrifft
        if (filenameMatch || contentMatch) {
          final l10n = AppLocalizations.of(context)!;
          final matchTypes = <String>[];
          if (filenameMatch) matchTypes.add(l10n.filename);
          if (contentMatch) matchTypes.add(l10n.content);

          results.add(_EnhancedSearchResultItem(
            title: prettifyTitle(file.name.replaceAll(RegExp(r'\.[^.]*$'), '')),
            path: file.path,
            file: file,
            snippet: contentSnippet ?? _generateFilenameSnippet(file, terms),
            matchType: matchTypes.join(' & '),
            isContentMatch: contentMatch,
          ));
        }

        // Progressive Updates alle 10 Dateien
        if (results.length % 10 == 0 && results.isNotEmpty) {
          if (!mounted || token != _searchToken) return;
          setState(() => _results = List.of(results));
        }
      }

      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = results;
        _loading = false;
      });

    } catch (e) {
      if (!mounted || token != _searchToken) return;
      setState(() => _loading = false);
    }
  }

  /// Baut ein Kontext-Snippet aus dem Datei-Inhalt für einen Content-Treffer.
  ///
  /// - Sucht die früheste Fundstelle irgendeines Terms.
  /// - Schneidet ein Fenster von `contextChars` Zeichen davor/dahinter aus.
  /// - Markiert alle Terme mit Guillemets « » (einfacher, Markdown-neutraler Marker).
  /// - Reduziert Whitespace, setzt Ellipsen wenn Start/Ende abgeschnitten sind.
  /// - Falls kein Term mehr lokalisierbar ist (Race / Inkonsistenz) wird der Kopf
  ///   der Datei (max 160 Zeichen) zurückgegeben.
  String _generateSnippet(String content, List<String> terms) {
    const contextChars = 80;
    
    // Finde die erste Position eines Suchterms
    int firstPos = -1;
    String foundTerm = '';
    
    for (final term in terms) {
      final pos = content.toLowerCase().indexOf(term);
      if (pos >= 0 && (firstPos == -1 || pos < firstPos)) {
        firstPos = pos;
        foundTerm = term;
      }
    }

    if (firstPos < 0) return content.substring(0, 160.clamp(0, content.length));

    final start = (firstPos - contextChars).clamp(0, content.length);
    final end = (firstPos + foundTerm.length + contextChars).clamp(0, content.length);
    
    var snippet = content.substring(start, end);
    
    // Hervorhebung der Suchterme
    for (final term in terms) {
      final regex = RegExp(RegExp.escape(term), caseSensitive: false);
      snippet = snippet.replaceAllMapped(regex, (m) => '«${m.group(0)}»');
    }
    
    // Ersetze Zeilenumbrüche durch Leerzeichen
    snippet = snippet.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Füge Ellipsen hinzu falls gekürzt
    if (start > 0) snippet = '...$snippet';
    if (end < content.length) snippet = '$snippet...';
    
    return snippet;
  }

  /// Erzeugt Snippet bei reinem Dateinamen-/Pfad-Treffer.
  /// Markiert alle Terme im Pfad und ergänzt MIME + formattierte Größe.
  /// Kein Datei-Content notwendig (schnell für reine Struktur-Suchen).
  String _generateFilenameSnippet(UniversalRepoEntry file, List<String> terms) {
    var snippet = '📁 ${file.path}';
    
    // Hervorhebe Suchterme im Pfad
    for (final term in terms) {
      final regex = RegExp(RegExp.escape(term), caseSensitive: false);
      snippet = snippet.replaceAllMapped(regex, (m) => '«${m.group(0)}»');
    }
    
    return '$snippet\n${file.mimeType} • ${file.formattedSize}';
  }

  @override
  void dispose() {
    _searchToken++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: Text(AppLocalizations.of(context)!.enhancedSearch),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showFilterDialog,
            tooltip: AppLocalizations.of(context)!.adjustFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBox(),
          _buildFilterChips(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchAllFilesHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _loading 
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16, 
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    setState(() {
                      _results = [];
                      _lastQuery = '';
                    });
                  },
                )
              : null,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) {
          // Debounce search
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _runSearch();
          });
        },
        onSubmitted: (_) => _runSearch(),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: Text(AppLocalizations.of(context)!.content),
            selected: _searchInContent,
            onSelected: (selected) {
              setState(() => _searchInContent = selected);
              if (_controller.text.isNotEmpty) _runSearch();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(AppLocalizations.of(context)!.filename),
            selected: _searchInFilename,
            onSelected: (selected) {
              setState(() => _searchInFilename = selected);
              if (_controller.text.isNotEmpty) _runSearch();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(AppLocalizations.of(context)!.textOnly),
            selected: _onlyTextFiles,
            onSelected: (selected) {
              setState(() => _onlyTextFiles = selected);
              if (_controller.text.isNotEmpty) _runSearch();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(_selectedCategory == 'ALL_INTERNAL'
                ? AppLocalizations.of(context)!.allFiles
                : _selectedCategory),
            selected: true,
            onSelected: (_) => _showCategoryFilter(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty && _controller.text.isNotEmpty && !_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noResultsFor(_controller.text),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.tryOtherSearch,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.enterSearchTerm,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.searchContentOrFilename,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _results.length && _loading) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final result = _results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                _getFileIcon(result.file),
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            title: Text(result.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.file.path,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: _buildHighlightedText(result.snippet),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: result.isContentMatch 
                          ? Colors.green.shade100 
                          : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        result.matchType,
                        style: TextStyle(
                          fontSize: 10,
                          color: result.isContentMatch 
                            ? Colors.green.shade700 
                            : Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      result.file.category,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () => _openFile(result),
          ),
        );
      },
    );
  }

  TextSpan _buildHighlightedText(String text) {
    final spans = <TextSpan>[];
    final parts = text.split('«');
    
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.contains('»')) {
        final subParts = part.split('»');
        if (subParts.length >= 2) {
          // Highlighted part
          spans.add(TextSpan(
            text: subParts[0],
            style: const TextStyle(
              backgroundColor: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ));
          // Regular part after highlight
          if (subParts[1].isNotEmpty) {
            spans.add(TextSpan(text: subParts[1]));
          }
        } else {
          spans.add(TextSpan(text: part));
        }
      } else {
        spans.add(TextSpan(text: part));
      }
    }
    
    return TextSpan(
      children: spans,
      style: const TextStyle(fontSize: 12),
    );
  }

  IconData _getFileIcon(UniversalRepoEntry file) {
    final ext = file.extension.toLowerCase();
    
    switch (ext) {
      case '.md': return Icons.description;
      case '.txt': return Icons.text_snippet;
      case '.dart': return Icons.code;
      case '.js': case '.ts': return Icons.javascript;
      case '.py': return Icons.code;
      case '.json': return Icons.data_object;
      case '.yaml': case '.yml': return Icons.settings;
      case '.pdf': return Icons.picture_as_pdf;
      case '.png': case '.jpg': case '.jpeg': case '.gif': return Icons.image;
      case '.zip': case '.rar': return Icons.archive;
      default: return file.isText ? Icons.text_snippet : Icons.insert_drive_file;
    }
  }

  void _openFile(_EnhancedSearchResultItem result) {
    if (result.file.extension.toLowerCase() == '.md') {
      // Öffne Markdown-Dateien im normalen PageScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PageScreen(
            repoPath: result.path,
            title: result.title,
          ),
        ),
      );
    } else {
      // Öffne andere Dateien im Universal File Browser Detail
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UniversalFileDetailScreen(file: result.file),
        ),
      );
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
  title: Text(AppLocalizations.of(context)!.searchFiltersTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(AppLocalizations.of(context)!.searchInContentTitle),
              subtitle: Text(AppLocalizations.of(context)!.searchInContentSubtitle),
              value: _searchInContent,
              onChanged: (value) => setState(() => _searchInContent = value),
            ),
            SwitchListTile(
              title: Text(AppLocalizations.of(context)!.searchInFilenameTitle),
              subtitle: Text(AppLocalizations.of(context)!.searchInFilenameSubtitle),
              value: _searchInFilename,
              onChanged: (value) => setState(() => _searchInFilename = value),
            ),
            SwitchListTile(
              title: Text(AppLocalizations.of(context)!.textOnly),
              subtitle: Text(AppLocalizations.of(context)!.onlyTextFilesSubtitle),
              value: _onlyTextFiles,
              onChanged: (value) => setState(() => _onlyTextFiles = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  void _showCategoryFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
  title: Text(AppLocalizations.of(context)!.chooseCategory),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(AppLocalizations.of(context)!.allFiles),
                leading: Radio<String>(
                  value: 'ALL_INTERNAL',
                  groupValue: _selectedCategory,
                  onChanged: (value) {
                    setState(() => _selectedCategory = value!);
                    Navigator.of(context).pop();
                    if (_controller.text.isNotEmpty) _runSearch();
                  },
                ),
                onTap: () {
                  setState(() => _selectedCategory = 'ALL_INTERNAL');
                  Navigator.of(context).pop();
                  if (_controller.text.isNotEmpty) _runSearch();
                },
              ),
              ..._availableCategories.entries.map(
                (entry) => ListTile(
                  title: Text('${entry.key} (${entry.value.length})'),
                  leading: Radio<String>(
                    value: entry.key,
                    groupValue: _selectedCategory,
                    onChanged: (value) {
                      setState(() => _selectedCategory = value!);
                      Navigator.of(context).pop();
                      if (_controller.text.isNotEmpty) _runSearch();
                    },
                  ),
                  onTap: () {
                    setState(() => _selectedCategory = entry.key);
                    Navigator.of(context).pop();
                    if (_controller.text.isNotEmpty) _runSearch();
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }
}

/// Interner Container für erweiterte Suchergebnisse
class _EnhancedSearchResultItem {
  final String title;
  final String path;
  final UniversalRepoEntry file;
  final String snippet;
  final String matchType;
  final bool isContentMatch;

  _EnhancedSearchResultItem({
    required this.title,
    required this.path,
    required this.file,
    required this.snippet,
    required this.matchType,
    required this.isContentMatch,
  });
}