import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/wiki_service.dart';
import '../services/universal_file_reader.dart';
import '../widgets/universal_file_viewer.dart';
import '../utils/naming.dart';
import '../config.dart';

/// UniversalFileBrowserScreen
/// ==========================
/// Interaktive Ansicht für ALLE Repository-Dateien (Text & Binär) mit Kategorie-,
/// Such-, und Anzeige-Filtern.
///
/// Features:
/// * Kategorie-Gruppierung ODER flache Liste
/// * Textsuche auf Name & Pfad
/// * Optionaler „Nur Text“-Filter
/// * Schnelle Inline-Vorschau (Dialog) + Detail-Navigation
/// * Größen-/MIME-Anzeige + einfache Statistiken
///
/// Performance: Vollständiges Listing (Git Tree) pro Refresh; für sehr große Repos
/// denkbar: Paging oder server-seitiger Index.
class UniversalFileBrowserScreen extends StatefulWidget {
  const UniversalFileBrowserScreen({super.key});

  @override
  State<UniversalFileBrowserScreen> createState() => _UniversalFileBrowserScreenState();
}

class _UniversalFileBrowserScreenState extends State<UniversalFileBrowserScreen> {
  final _svc = WikiService();
  
  List<UniversalRepoEntry> _allFiles = [];
  List<UniversalRepoEntry> _filteredFiles = [];
  Map<String, List<UniversalRepoEntry>> _categorizedFiles = {};
  
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedCategory = 'ALL_INTERNAL'; // sentinel for all categories
  bool _showOnlyTextFiles = false;
  bool _groupByCategory = true;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final files = await _svc.listAllFiles(AppConfig.dirPath);
      final categories = await _svc.listFilesByCategory(AppConfig.dirPath);
      
      setState(() {
        _allFiles = files;
        _categorizedFiles = categories;
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    // Kombiniert die aktuell gesetzten Filter und aktualisiert `_filteredFiles`.
    // Reihenfolge:
    // 1. Suchtext (Name ODER kompletter Pfad matcht, case-insensitive)
    // 2. Kategorie (falls != 'Alle')
    // 3. Nur-Text-Flag (eliminiert Binärdateien)
    // Dann wird die gefilterte Liste in den State gesetzt.
    var filtered = List<UniversalRepoEntry>.from(_allFiles);

    // Textfilter anwenden
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((file) {
        return file.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               file.path.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Kategoriefilter anwenden
    if (_selectedCategory != 'Alle') {
      filtered = filtered.where((file) => file.category == _selectedCategory).toList();
    }

    // Nur Textdateien anzeigen
    if (_showOnlyTextFiles) {
      filtered = filtered.where((file) => file.isText).toList();
    }

    setState(() {
      _filteredFiles = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: Text(AppLocalizations.of(context)!.allFiles),
        actions: [
          IconButton(
            icon: Icon(_groupByCategory ? Icons.view_list : Icons.category),
            onPressed: () {
              setState(() {
                _groupByCategory = !_groupByCategory;
              });
            },
      tooltip: _groupByCategory
        ? AppLocalizations.of(context)!.listView
        : AppLocalizations.of(context)!.groupByCategory,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
            tooltip: AppLocalizations.of(context)!.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
  padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          // Suchleiste
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchFiles,
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
          ),
          const SizedBox(height: 12),
          
          // Filter-Optionen
          Row(
            children: [
              // Kategorie-Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.categoryLabel,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: 'ALL_INTERNAL', child: Text(AppLocalizations.of(context)!.allFiles)),
                    ..._categorizedFiles.keys.map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text('$category (${_categorizedFiles[category]!.length})'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value ?? 'ALL_INTERNAL';
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              
              // Nur Textdateien
              FilterChip(
                label: Text(AppLocalizations.of(context)!.textOnly),
                selected: _showOnlyTextFiles,
                onSelected: (selected) {
                  setState(() {
                    _showOnlyTextFiles = selected;
                    _applyFilters();
                  });
                },
              ),
            ],
          ),
          
          // Statistiken
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!
                    .filesOfTotal(_filteredFiles.length, _allFiles.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_allFiles.isNotEmpty)
                Text(
                  '${AppLocalizations.of(context)!.total}: ${_getTotalSize()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.loadingFilesErrorTitle),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFiles,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      );
    }

    if (_filteredFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? AppLocalizations.of(context)!.noFilesFoundFor(_searchQuery)
                  : AppLocalizations.of(context)!.noFilesInCategory,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_searchQuery.isNotEmpty || _selectedCategory != 'Alle')
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'ALL_INTERNAL';
                    _showOnlyTextFiles = false;
                    _searchController.clear();
                    _applyFilters();
                  });
                },
                child: Text(AppLocalizations.of(context)!.filterReset),
              ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _groupByCategory ? _buildGroupedContent() : _buildListContent(),
    );
  }

  List<Widget> _buildGroupedContent() {
    final groupedFiles = <String, List<UniversalRepoEntry>>{};
    
    for (final file in _filteredFiles) {
      final category = file.category;
      groupedFiles[category] ??= [];
      groupedFiles[category]!.add(file);
    }

    final widgets = <Widget>[];
    
    for (final entry in groupedFiles.entries) {
      final category = entry.key;
      final files = entry.value;
      
      widgets.add(
        Card(
          child: ExpansionTile(
            title: Text('$category (${files.length})'),
            leading: Icon(_getCategoryIcon(category)),
            children: files.map((file) => _buildFileListTile(file)).toList(),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }

    return widgets;
  }

  List<Widget> _buildListContent() {
    return _filteredFiles.map((file) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: _buildFileListTile(file),
      );
    }).toList();
  }

  Widget _buildFileListTile(UniversalRepoEntry file) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          _getFileIcon(file),
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(file.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.path,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                file.mimeType,
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(width: 8),
              Text(
                file.formattedSize,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (file.isText)
            IconButton(
              icon: const Icon(Icons.visibility, size: 20),
              onPressed: () => _previewFile(file),
              tooltip: AppLocalizations.of(context)!.preview,
            ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: () => _openFile(file),
            tooltip: AppLocalizations.of(context)!.open,
          ),
        ],
      ),
      onTap: () => _openFile(file),
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
      case '.html': case '.htm': return Icons.web;
      case '.css': return Icons.palette;
      default: return file.isText ? Icons.text_snippet : Icons.insert_drive_file;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
  case 'Dokumentation': return Icons.description; // categories come from service (already localized?)
      case 'Programmcode': return Icons.code;
      case 'Konfiguration': return Icons.settings;
      case 'Bilder': return Icons.image;
      case 'Dokumente': return Icons.picture_as_pdf;
      case 'Media': return Icons.video_library;
      case 'Archive': return Icons.archive;
      default: return Icons.folder;
    }
  }

  String _getTotalSize() {
    final totalBytes = _allFiles.fold<int>(0, (sum, file) => sum + file.size);
    
  if (totalBytes < 1024) return '$totalBytes B';
  if (totalBytes < 1024 * 1024) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
  if (totalBytes < 1024 * 1024 * 1024) return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _previewFile(UniversalRepoEntry file) {
    showDialog(
      context: context,
      builder: (context) => _FilePreviewDialog(file: file),
    );
  }

  void _openFile(UniversalRepoEntry file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UniversalFileDetailScreen(file: file),
      ),
    );
  }
}

/// Dialog für schnelle Dateivorschau
class _FilePreviewDialog extends StatefulWidget {
  final UniversalRepoEntry file;

  const _FilePreviewDialog({required this.file});

  @override
  State<_FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends State<_FilePreviewDialog> {
  final _svc = WikiService();
  FileReadResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final result = await _svc.fetchFileByPath(widget.file.path);
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            AppBar(
              title: Text(prettifyTitle(widget.file.name)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('${AppLocalizations.of(context)!.error}: $_error'))
                      : _result != null
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: UniversalFileViewer(
                                fileResult: _result!,
                                fileName: widget.file.name,
                                filePath: widget.file.path,
                              ),
                            )
                          : Center(child: Text(AppLocalizations.of(context)!.noData)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vollständige Detailansicht einer Datei (öffentlich nutzbar für andere Screens)
class UniversalFileDetailScreen extends StatefulWidget {
  final UniversalRepoEntry file;

  const UniversalFileDetailScreen({super.key, required this.file});

  @override
  State<UniversalFileDetailScreen> createState() => _UniversalFileDetailScreenState();
}

class _UniversalFileDetailScreenState extends State<UniversalFileDetailScreen> {
  final _svc = WikiService();
  FileReadResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final result = await _svc.fetchFileByPath(widget.file.path);
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(prettifyTitle(widget.file.name)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadFile();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.loadingFilesErrorTitle),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadFile();
                        },
                        child: Text(AppLocalizations.of(context)!.retry),
                      ),
                    ],
                  ),
                )
              : _result != null
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: UniversalFileViewer(
                        fileResult: _result!,
                        fileName: widget.file.name,
                        filePath: widget.file.path,
                      ),
                    )
                  : Center(child: Text(AppLocalizations.of(context)!.noData)),
    );
  }
}