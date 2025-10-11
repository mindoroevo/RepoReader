// _TokenStep nach unten verschoben
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../services/wiki_service.dart';
import '../services/private_auth_service.dart';
import '../widgets/tips_overlay.dart';
import '../services/tips_service.dart';
import 'device_login_webview.dart';
import 'package:url_launcher/url_launcher.dart';

/// SetupScreen (Erstkonfiguration / Wechsel)
/// ========================================
/// Vereinfachte Konfiguration mit EINEM Eingabefeld (Repository- oder Raw-Link) + optionalem Token.
/// Unterstützte Formen (Auto-Parsing):
/// Der Nutzer kann einfügen:
///  - https://github.com/OWNER/REPO
///  - https://github.com/OWNER/REPO/tree/BRANCH/path/zu/docs
///  - https://raw.githubusercontent.com/OWNER/REPO/BRANCH/docs/README.md (wird auf Ordner zurückgeführt)
///  - Optional gefolgt von einem Token (separat)
/// Parsing extrahiert: owner, repo, branch (Fallback `main`), dirPath (Fallback `docs`).
/// Persistenz-Schlüssel: `cfg:*` + optional Token `cfg:token`.
/// Cache-Löschung: nutzt `WikiService.clearAllCaches` (inkl. universeller Datei-Cache) vor Neusetzung.
class SetupScreen extends StatefulWidget {
  final VoidCallback onApplied;
  const SetupScreen({super.key, required this.onApplied});
  @override State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  final _repoSearch = TextEditingController();
  bool _saving = false;
  String? _error; // parse Fehleranzeige

  // --- GitHub Repo Suchzustand ---
  List<_RepoSearchResult> _searchResults = [];
  bool _searchLoading = false;
  String? _searchError;
  Timer? _debounce;
  Timer? _autoApplyDebounce;

  static const _minSearchLen = 3;

  // ============== TREE / DIRECTORY AUSWAHL ==============
  bool _treeLoading = false;
  String? _treeError;
  List<_DirNode> _dirNodes = [];
  String? _selectedDir; // vom Nutzer gewählter docs Root
  String? _pendingOwner; // aus parse / search
  String? _pendingRepo;
  String? _pendingBranch; // für erneutes Laden

  // --- Device Authorization Flow ---
  bool _deviceFlowActive = false;
  String? _deviceUserCode;
  String? _deviceVerificationUri;
  int _deviceInterval = 5;
  String? _deviceCode;
  String? _deviceStatus;

  @override
  void initState() {
    super.initState();
    _initSecureToken();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted && await TipsService.shouldShow('setup')) {
        _showSetupTips();
      }
    });
  }

  Future<void> _initSecureToken() async {
    final stored = await PrivateAuthService.loadToken();
    if (stored != null && stored.isNotEmpty) {
      _token.text = stored; // zeigt *noch* Klartext; optional: nur Platzhalter anzeigen
    }
    // (Collapse entfernt) – keine Panel-Öffnungslogik mehr notwendig
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    _repoSearch.dispose();
    _debounce?.cancel();
    _autoApplyDebounce?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    setState(()=> _saving = true);
    try {
      final parsed = _parseRepoUrl(_url.text.trim());
      if (parsed == null) {
        setState(()=> _error = 'Konnte Link nicht interpretieren. Erwartet z.B. https://github.com/OWNER/REPO oder .../tree/BRANCH/docs');
        return;
      }
      var (owner, repo, branch, dirPath) = parsed;
      if (_selectedDir != null && _selectedDir!.isNotEmpty) {
        dirPath = _selectedDir!; // Nutzerwahl priorisieren
      }
      // Validierung: Existiert Repo & Directory? (Directory optional – wenn nicht vorhanden -> Fehler)
      final validationError = await _validateRepoAndDir(owner, repo, branch, dirPath);
      if (validationError != null) {
        setState(()=> _error = validationError);
        return;
      }
      // Erst jetzt Caches leeren, damit bei Fehlern vorher Zustand erhalten bleibt
      await WikiService.clearAllCaches(keepConfig: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cfg:owner', owner);
      await prefs.setString('cfg:repo', repo);
      await prefs.setString('cfg:branch', branch);
      await prefs.setString('cfg:dir', dirPath);
      if (_token.text.trim().isNotEmpty) {
        await prefs.setString('cfg:token', _token.text.trim());
      }
      AppConfig.configure(
        owner: owner,
        repo: repo,
        branch: branch,
        dirPath: dirPath,
        token: _token.text.trim().isEmpty ? null : _token.text.trim(),
      );
      widget.onApplied();
      if (mounted) Navigator.pop(context);
    } finally { if (mounted) setState(()=> _saving = false); }
  }

  Future<void> _reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in ['cfg:owner','cfg:repo','cfg:branch','cfg:dir','cfg:token']) { await prefs.remove(k); }
    AppConfig.resetToDefaults();
    widget.onApplied();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _wipeAll() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx){
      final l = AppLocalizations.of(context)!;
      return AlertDialog(
        title: Text(l.allDeleteConfirmTitle),
        content: Text(l.allDeleteConfirmContent),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(ctx,false), child: Text(l.cancelSmall)),
          FilledButton(onPressed: ()=>Navigator.pop(ctx,true), child: Text(l.delete)),
        ],
      );
    });
    if (confirm != true) return;
    setState(()=> _saving = true);
    await WikiService.clearAllCaches();
    widget.onApplied();
    if (mounted) Navigator.pop(context);
  }

  // ================== REPO SUCHE ==================
  /// Führt eine Suche über die GitHub Repositories Search API aus.
  /// Nutzt optional das eingegebene Token für höhere Limits.
  /// Führt eine Repository-Suche (GitHub Search API) für den eingegebenen Text aus.
  ///
  /// Minimale Länge: `_minSearchLen`. Begrenzung auf 10 Ergebnisse.
  /// Token (falls gesetzt) erhöht Rate Limits.
  /// Fehler werden als kurze HTTP/Exception Nachricht in `_searchError` abgelegt.
  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.length < _minSearchLen) {
      setState(() { _searchResults = []; _searchError = null; });
      return;
    }
    setState(() { _searchLoading = true; _searchError = null; });
    try {
      final headers = <String,String>{
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'RepoReaderApp/1.0'
      };
      final t = _token.text.trim();
      if (t.isNotEmpty) headers['Authorization'] = 'Bearer $t';
      // Basic heuristik: q in name, fork:false priorisieren, sort=stars
      final uri = Uri.parse('https://api.github.com/search/repositories?q=${Uri.encodeQueryComponent(q)}+in:name&per_page=10');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        final jsonData = json.decode(res.body) as Map<String,dynamic>;
        final items = (jsonData['items'] as List<dynamic>).cast<Map<String,dynamic>>();
        final list = items.map((e) => _RepoSearchResult(
          fullName: e['full_name'] as String,
          description: (e['description'] as String?) ?? '',
          stars: (e['stargazers_count'] as int?) ?? 0,
          defaultBranch: (e['default_branch'] as String?) ?? 'main',
        )).toList();
        setState(() { _searchResults = list; });
      } else {
        setState(() { _searchError = 'HTTP ${res.statusCode}'; _searchResults = []; });
      }
    } catch (e) {
      setState(() { _searchError = e.toString(); _searchResults = []; });
    } finally {
      if (mounted) setState(() { _searchLoading = false; });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () => _runSearch(value));
  }

  void _applySearchResult(_RepoSearchResult r) {
    // Befülle nur OWNER/REPO – Branch & docs bleibt default (User kann später anpassen via tree Link).
    if (r.defaultBranch == 'main') {
      _url.text = 'https://github.com/${r.fullName}';
    } else {
      // Direkt vollständigen Tree-Link inklusive docs Fallback setzen (Nutzer kann anpassen)
      _url.text = 'https://github.com/${r.fullName}/tree/${r.defaultBranch}/docs';
      // Kurzer unobtrusiver Hinweis
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(seconds:2), content: Text('Branch automatisch: ${r.defaultBranch}')),
      );
    }
    // Setze pending für Tree Ladefunktion
    final parts = r.fullName.split('/');
    if (parts.length==2) {
      _pendingOwner = parts[0];
      _pendingRepo = parts[1];
      _pendingBranch = r.defaultBranch;
      _loadRepoTree();
    }
  }

  /// Versucht einen GitHub Link zu parsen und extrahiert (owner, repo, branch, dirPath)
  /// Unterstützt verschiedene Formen.
  (String owner, String repo, String branch, String dirPath)? _parseRepoUrl(String input) {
    if (input.isEmpty) return null;
    var url = input.trim();
    // Entferne evtl. .git Suffix
    if (url.endsWith('.git')) url = url.substring(0, url.length - 4);
    // Kleinbuchstaben für stabile Muster-Vergleiche (Owner/Repo Case bleibt unverändert beim Extrahieren)
    // (Nur für Matching; Original wird aus Regex Gruppen entnommen)
    // Raw URLs -> normalisieren
    url = url.replaceAll('raw.githubusercontent.com', 'github.com');
    // Falls raw Pfad: github.com/OWNER/REPO/BRANCH/... => zu /tree/BRANCH
    final rawMatch = RegExp(r'https://github.com/([^/]+)/([^/]+)/([^/]+)/(.*)').firstMatch(url);
    if (rawMatch != null && !url.contains('/tree/')) {
      // Vermutlich war es eine raw Struktur (nach replace). Wir interpretieren dritten Teil als Branch und hängen /tree/<branch>/ an.
      final o = rawMatch.group(1)!; final r = rawMatch.group(2)!; final b = rawMatch.group(3)!; final rest = rawMatch.group(4)!;
      // Versuche README oder Datei entfernen um Ordner zu bekommen
      String dirPath = rest;
      if (dirPath.contains('/')) {
        // Wenn es wie docs/README.md aussieht → nur docs
        dirPath = dirPath.replaceAll(RegExp(r'/README\.md$', caseSensitive: false), '');
      }
      if (dirPath.isEmpty) dirPath = 'docs';
      return (o, r, b, dirPath);
    }

    // Standardfälle: https://github.com/OWNER/REPO
    final base = RegExp(r'^https://github.com/([^/]+)/([^/]+)/?$');
    final mBase = base.firstMatch(url);
    if (mBase != null) {
      // Root-Mode (kein obligatorischer docs Ordner)
      return (mBase.group(1)!, mBase.group(2)!, 'main', '');
    }

    // Mit Branch & optionalem Pfad: /tree/<branch>/<dirPath>
    final tree = RegExp(r'^https://github.com/([^/]+)/([^/]+)/tree/([^/]+)(/(.*))?$');
    final mTree = tree.firstMatch(url);
    if (mTree != null) {
      final owner = mTree.group(1)!;
      final repo = mTree.group(2)!;
      final branch = mTree.group(3)!;
  final dirPath = (mTree.group(5) ?? '').replaceAll(RegExp(r'^/+'), '');
  return (owner, repo, branch, dirPath); // leer erlaubt
    }
    return null;
  }

  /// Prüft ob Repository existiert und ob der gewünschte docs-Pfad (dirPath) im Branch existiert.
  /// Rückgabe: null = ok, sonst Fehlermeldung.
  Future<String?> _validateRepoAndDir(String owner, String repo, String branch, String dirPath) async {
    try {
      final headers = <String,String>{ 'Accept': 'application/vnd.github+json' };
      final t = _token.text.trim();
      if (t.isNotEmpty) headers['Authorization'] = 'Bearer $t';
      // Repo prüfen (lightweight)
      final repoRes = await http.get(Uri.parse('https://api.github.com/repos/$owner/$repo'), headers: headers);
  if (repoRes.statusCode == 404) return AppLocalizations.of(context)!.repositoryNotFound;
      if (repoRes.statusCode == 403) {
        final remaining = repoRes.headers['x-ratelimit-remaining'];
        if (remaining == '0') {
          return AppLocalizations.of(context)!.rateLimitReachedNeedToken;
        }
        return AppLocalizations.of(context)!.accessDeniedPrivateOrToken;
      }
  if (repoRes.statusCode >= 400) return AppLocalizations.of(context)!.repoErrorHttp(repoRes.statusCode.toString());
      if (dirPath.isNotEmpty) {
        final dirRes = await http.get(Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$dirPath?ref=$branch'), headers: headers);
        if (dirRes.statusCode == 404) {
          return AppLocalizations.of(context)!.folderDoesNotExist(dirPath, branch);
        }
  if (dirRes.statusCode == 403) return AppLocalizations.of(context)!.directoryAccessDenied;
  if (dirRes.statusCode >= 400) return AppLocalizations.of(context)!.directoryErrorHttp(dirRes.statusCode.toString());
      }
      return null;
    } catch (e) {
  return AppLocalizations.of(context)!.validationFailed(e.toString());
    }
  }

  Future<void> _startDeviceFlow() async {
  setState(()=> _deviceStatus = AppLocalizations.of(context)!.startDeviceFlow);
    try {
      final (userCode, uri, interval, deviceCode) = await PrivateAuthService.startDeviceFlow();
  setState(() { _deviceFlowActive = true; _deviceUserCode = userCode; _deviceVerificationUri = uri; _deviceInterval = interval; _deviceCode = deviceCode; _deviceStatus = AppLocalizations.of(context)!.enterCodeAt(uri); });
    } catch (e) {
      setState(()=> _deviceStatus = 'Error: $e');
    }
  }

  /// Pollt den GitHub Device Flow bis ein Token erteilt oder ein Fehler geworfen wird.
  /// Intervall (`_deviceInterval`) wurde beim Start geliefert. Erfolgreiches Token
  /// wird direkt gespeichert und ins Token-Textfeld übernommen.
  Future<void> _pollDeviceFlow() async {
    if (_deviceCode == null) return;
  setState(()=> _deviceStatus = AppLocalizations.of(context)!.waitingForGrant);
    try {
      final token = await PrivateAuthService.pollForDeviceToken(_deviceCode!, _deviceInterval);
      await PrivateAuthService.saveToken(token);
      _token.text = token;
      setState(()=> _deviceStatus = AppLocalizations.of(context)!.successTokenStored);
    } catch (e) {
      setState(()=> _deviceStatus = 'Error: $e');
    }
  }

  Future<void> _clearSecureToken() async {
    await PrivateAuthService.clearToken();
  setState(() { _token.clear(); _deviceStatus = AppLocalizations.of(context)!.tokenRemoved; });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.changeSource),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: _showSetupTips),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16,8,16,12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_saving) const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 10),
              Row(children:[
                Expanded(child: ElevatedButton.icon(key: _kApplyBtn, onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: Text(l.applyButton))),
                const SizedBox(width:10),
                TextButton(onPressed: _saving ? null : _reset, child: Text(l.reset)), 
                const SizedBox(width:4),
                TextButton(onPressed: _saving ? null : _wipeAll, child: Text(l.wipeAll)),
              ]),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 12),
            _buildStaticSections(),
            const SizedBox(height: 20),
            _examplesCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ---------------- Zusammenfassung -----------------
  Widget _buildSummaryCard() {
    final parsed = _parseRepoUrl(_url.text.trim());
    String summary;
    final loc = AppLocalizations.of(context)!;
    if (parsed == null) {
      summary = loc.noValidLinkYet;
    } else {
      final (o,r,b,d) = parsed;
      final dir = _selectedDir ?? d;
      summary = '$o/$r • branch: $b • dir: $dir';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(loc.currentSelection, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
            Text(summary, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          const SizedBox(height: 4),
          Row(children:[
            Icon(_token.text.isEmpty ? Icons.lock_open : Icons.lock, size:14, color: _token.text.isEmpty? Colors.orange : Colors.green),
            const SizedBox(width:4),
            Text(_token.text.isEmpty ? loc.withoutToken : loc.tokenActive, style: TextStyle(fontSize:12, color: _token.text.isEmpty? Colors.orange : Colors.green)),
            const Spacer(),
            TextButton.icon(
              onPressed: _showTokenSheet,
              icon: const Icon(Icons.vpn_key, size:16),
              label: Text(_token.text.isEmpty ? loc.addToken : loc.manageToken),
            )
          ])
        ]),
      ),
    );
  }

  // ---------------- Statische Sektionen (Collapse entfernt) -----------------

  Future<void> _showTokenSheet() async {
    await showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(left:16,right:16, top:16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children:[
                  const Icon(Icons.vpn_key),
                  const SizedBox(width:8),
                  const Text('Token / Auth'),
                  const Spacer(),
                  IconButton(onPressed: ()=>Navigator.pop(ctx), icon: const Icon(Icons.close))
                ]),
                const SizedBox(height:12),
                _buildTokenRow(),
                const SizedBox(height:12),
                Text('Hinweis: Device Login benötigt build flag GITHUB_CLIENT_ID', style: const TextStyle(fontSize:11,fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
      );
    });
    // Nach Schließen Zusammenfassung aktualisieren
    setState((){});
  }

  Widget _buildStaticSections() {
    return Column(
      children: [
        // 1. Repository wählen
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16,12,16,16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children:[
                  const Icon(Icons.link, size:18),
                  const SizedBox(width:8),
                  Text(AppLocalizations.of(context)!.stepRepositorySelectTitle, style: Theme.of(context).textTheme.titleSmall),
                ]),
                const SizedBox(height: 14),
                TextField(
                  key: _kUrlField,
                  controller: _url,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.githubLink,
                    hintText: 'https://github.com/OWNER/REPO …',
                    errorText: _error,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  onChanged: (_) {
                    if (_error != null) setState(()=> _error = null);
                    setState(()=>{});
                    _autoApplyDebounce?.cancel();
                    final txt = _url.text.trim();
                    if (txt.startsWith('https://github.com/') || txt.startsWith('https://raw.githubusercontent.com/')) {
                      _autoApplyDebounce = Timer(const Duration(milliseconds: 1200), () { if (mounted && !_saving) { _save(); } });
                    }
                  },
                ),
                const SizedBox(height: 14),
                _buildSearchSection(),
                const SizedBox(height: 4),
                Text(AppLocalizations.of(context)!.pasteOrSearchRepo, style: const TextStyle(fontSize:11, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
        // 2. Ordner Auswahl
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16,12,16,16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children:[
                  const Icon(Icons.folder, size:18),
                  const SizedBox(width:8),
                  Text(AppLocalizations.of(context)!.stepOptionalDirectory, style: Theme.of(context).textTheme.titleSmall),
                ]),
                const SizedBox(height: 12),
                _buildDirectoryCompact(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Kompakte Ordner-Auswahl mit Vorschlags-Chips
  Widget _buildDirectoryCompact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
  if (_pendingOwner == null) Text(AppLocalizations.of(context)!.chooseRepositoryFirst, style: const TextStyle(fontSize:12,fontStyle: FontStyle.italic)),
            if (_pendingOwner != null) ...[
              Row(children:[
                Text(AppLocalizations.of(context)!.suggestions, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (_treeLoading) const SizedBox(height:16,width:16,child:CircularProgressIndicator(strokeWidth:2)),
                if (!_treeLoading) TextButton(onPressed: _loadRepoTree, child: Text(AppLocalizations.of(context)!.rescan)),
              ]),
          const SizedBox(height:8),
          if (_treeError != null) Text('${AppLocalizations.of(context)!.errorPrefix} $_treeError', style: const TextStyle(color: Colors.red, fontSize:12)),
          Wrap(spacing: 8, runSpacing: 8, children: _buildDirSuggestionChips()),
          const SizedBox(height: 10),
          Text(AppLocalizations.of(context)!.selectionLabel((_selectedDir ?? 'docs')), style: const TextStyle(fontSize:12)),
          const SizedBox(height: 6),
          TextButton.icon(key: _kDirBtn, onPressed: () => _showFullDirList(), icon: const Icon(Icons.list), label: Text(AppLocalizations.of(context)!.showAllDirectories)),
        ]
      ],
    );
  }

  List<Widget> _buildDirSuggestionChips() {
    if (_dirNodes.isEmpty) {
  return [Text(AppLocalizations.of(context)!.noDataYetScanOrAdopt, style: const TextStyle(fontSize:11, fontStyle: FontStyle.italic))];
    }
    // Filter: nur tiefe <=2 und Namen, die wahrscheinlich Doku enthalten oder README beherbergen
    final candidates = <_DirNode>[];
    for (final n in _dirNodes) {
      if (n.depth <= 2) {
        final name = n.displayName.toLowerCase();
        if (name.contains('doc') || name.contains('wiki') || name.contains('guide') || name == 'src' || name == 'packages') {
          candidates.add(n);
        }
      }
    }
    if (candidates.isEmpty) {
      // fallback: docs plus root-nodes depth 0
      candidates.addAll(_dirNodes.where((n) => n.depth==0 || n.path=='docs').take(6));
    }
    final dedup = <String, _DirNode>{};
    for (final c in candidates) { dedup[c.path] = c; }
    final list = dedup.values.toList()..sort((a,b)=>a.path.compareTo(b.path));
    return list.map((n) => ChoiceChip(
      label: Text(n.displayName),
      selected: (_selectedDir ?? 'docs') == n.path,
      onSelected: (_) {
        setState(()=> _selectedDir = n.path);
        _save();
      },
    )).toList();
  }

  Future<void> _showFullDirList() async {
    if (_dirNodes.isEmpty) return;
    await showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx){
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children:[
                const Icon(Icons.folder),
                const SizedBox(width:8),
                Text(AppLocalizations.of(context)!.allDirectories),
                const Spacer(),
                IconButton(onPressed: ()=> Navigator.pop(ctx), icon: const Icon(Icons.close))
              ]),
              const SizedBox(height:8),
              Expanded(
                child: ListView.builder(
                  itemCount: _dirNodes.length,
                  itemBuilder: (c,i){
                    final n = _dirNodes[i];
                    final sel = (_selectedDir ?? 'docs') == n.path;
                    return ListTile(
                      dense: true,
                      leading: Icon(sel? Icons.check_box : Icons.check_box_outline_blank, size:18),
                      title: Text(n.path, style: const TextStyle(fontFamily: 'monospace', fontSize:12)),
                      onTap: () { setState(()=> _selectedDir = n.path); Navigator.pop(ctx); _save(); },
                    );
                  },
                ),
              )
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTokenRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: _kTokenField,
          controller: _token,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.tokenOptionalHigherLimits,
            prefixIcon: const Icon(Icons.key),
          ),
          obscureText: true,
          onChanged: (v) async { if (v.isNotEmpty) await PrivateAuthService.saveToken(v); },
        ),
        const SizedBox(height:6),
        Row(children:[
          Text(AppLocalizations.of(context)!.whyToken, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(width:8),
          TextButton.icon(onPressed: _showTokenHelp, icon: const Icon(Icons.help_outline, size:16), label: Text(AppLocalizations.of(context)!.tokenHelp)),
        ]),
        Wrap(spacing:8, runSpacing:4, children:[
          ElevatedButton.icon(onPressed: AppConfig.githubClientId.isEmpty ? null : _startDeviceFlow, icon: const Icon(Icons.devices), label: Text(AppLocalizations.of(context)!.deviceLoginCode)),
          ElevatedButton.icon(onPressed: AppConfig.githubClientId.isEmpty ? null : _openEmbeddedLogin, icon: const Icon(Icons.browser_updated), label: Text(AppLocalizations.of(context)!.inAppLogin)),
          ElevatedButton.icon(onPressed: _deviceFlowActive ? _pollDeviceFlow : null, icon: const Icon(Icons.refresh), label: Text(AppLocalizations.of(context)!.check)),
          ElevatedButton.icon(onPressed: _token.text.isNotEmpty ? _clearSecureToken : null, icon: const Icon(Icons.delete), label: Text(AppLocalizations.of(context)!.deleteToken)),
        ]),
        if (_deviceUserCode != null) Padding(
          padding: const EdgeInsets.only(top:4),
          child: Text('Code: ${_deviceUserCode!}', style: const TextStyle(fontSize:12,fontWeight: FontWeight.bold)),
        ),
        if (_deviceVerificationUri != null) Text(_deviceVerificationUri!, style: const TextStyle(fontSize:12, decoration: TextDecoration.underline)),
        if (_deviceStatus != null) Padding(
          padding: const EdgeInsets.only(top:4),
          child: Text(_deviceStatus!, style: TextStyle(fontSize:12, color: _deviceStatus!.startsWith('Fehler') ? Colors.red : null)),
        ),
      ],
    );
  }

  // ---- Tips ----
  final _kUrlField = GlobalKey();
  final _kDirBtn = GlobalKey();
  final _kApplyBtn = GlobalKey();
  final _kTokenField = GlobalKey();
  final _kSearchField = GlobalKey();

  Future<void> _showSetupTips() async {
    final l = AppLocalizations.of(context)!;
    await showTipsOverlay(
      context,
      tips: [
        TipTarget(key: _kUrlField, title: l.tipSetupLinkTitle, body: l.tipSetupLinkBody),
        TipTarget(key: _kSearchField, title: l.tipSetupSearchTitle, body: l.tipSetupSearchBody),
        TipTarget(key: _kDirBtn, title: l.tipSetupDirTitle, body: l.tipSetupDirBody),
        TipTarget(key: _kApplyBtn, title: l.tipSetupApplyTitle, body: l.tipSetupApplyBody),
        TipTarget(key: _kTokenField, title: l.tipSetupTokenTitle, body: l.tipSetupTokenBody),
      ],
      skipLabel: l.onbSkip,
      nextLabel: l.onbNext,
      doneLabel: l.onbDone,
    );
    await TipsService.markShown('setup');
  }

  void _showTokenHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20,12,20,24),
            child: LayoutBuilder(builder:(c,cons){
              final maxHeight = MediaQuery.of(context).size.height * .82;
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Row(children:[
                  const Icon(Icons.info_outline),
                  const SizedBox(width:12),
                  Expanded(child: Text(AppLocalizations.of(context)!.githubTokenHelp, style: Theme.of(context).textTheme.titleMedium)),
                  IconButton(onPressed: ()=> Navigator.pop(ctx), icon: const Icon(Icons.close))
                ]),
                const SizedBox(height:12),
                Text(AppLocalizations.of(context)!.whyPersonalAccessToken, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height:6),
                Text(AppLocalizations.of(context)!.tokenReasonRateLimits),
                const SizedBox(height:16),
                Text(AppLocalizations.of(context)!.createTokenSteps, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height:6),
                _TokenStep(num:1, text:AppLocalizations.of(context)!.tokenStep1),
                _TokenStep(num:2, text:AppLocalizations.of(context)!.tokenStep2),
                _TokenStep(num:3, text:AppLocalizations.of(context)!.tokenStep3),
                _TokenStep(num:4, text:AppLocalizations.of(context)!.tokenStep4),
                _TokenStep(num:5, text:AppLocalizations.of(context)!.tokenStep5),
                const SizedBox(height:18),
                Wrap(spacing:12, runSpacing:8, children:[
                  OutlinedButton.icon(onPressed: ()=> _openUrl('https://github.com/settings/tokens?type=beta'), icon: const Icon(Icons.open_in_new), label: const Text('Fine-grained Tokens')),
                  OutlinedButton.icon(onPressed: ()=> _openUrl('https://github.com/settings/tokens'), icon: const Icon(Icons.open_in_new), label: const Text('Classic Tokens')),
                  OutlinedButton.icon(onPressed: ()=> _openUrl('https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting'), icon: const Icon(Icons.open_in_new), label: Text(AppLocalizations.of(context)!.rateLimitDocs)),
                ]),
                const SizedBox(height:20),
                Text(AppLocalizations.of(context)!.securityNote, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height:6),
                Text(AppLocalizations.of(context)!.tokenSecurityLocal),
                const SizedBox(height:20),
                Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: ()=> Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.closeDialog))),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      }
    );
  }

  void _openUrl(String url) async {
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch(_){ }
  }

  Future<void> _openEmbeddedLogin() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceLoginWebView()));
    if (result == true) {
      final stored = await PrivateAuthService.loadToken();
      if (stored != null) setState(()=> _token.text = stored);
    }
  }

  Widget _buildSearchSection() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.search, size: 18),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.githubRepoSearchTitle, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (_searchLoading) const SizedBox(height:16,width:16,child: CircularProgressIndicator(strokeWidth:2))
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: _kSearchField,
              controller: _repoSearch,
              decoration: InputDecoration(
                isDense: true,
                labelText: AppLocalizations.of(context)!.repositorySearchFieldLabel,
                hintText: AppLocalizations.of(context)!.atLeastNChars(_minSearchLen.toString()),
                border: const OutlineInputBorder(),
                suffixIcon: _repoSearch.text.isEmpty ? null : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () { _repoSearch.clear(); _onSearchChanged(''); },
                ),
              ),
              onChanged: _onSearchChanged,
            ),
            if (_searchError != null) Padding(
              padding: const EdgeInsets.only(top:8),
              child: Text('${AppLocalizations.of(context)!.error}: $_searchError', style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
            const SizedBox(height: 10),
            if (_searchResults.isEmpty && _repoSearch.text.length >= _minSearchLen && !_searchLoading && _searchError==null)
              Text(AppLocalizations.of(context)!.noMatches, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            if (_searchResults.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (c,i){
                    final r = _searchResults[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.book),
                      title: Text(r.fullName, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                      subtitle: r.description.isEmpty ? null : Text(r.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                          const SizedBox(width:4),
                          Text(r.stars.toString(), style: const TextStyle(fontSize: 12)),
                          IconButton(
                            icon: const Icon(Icons.add_link, size: 18),
                            tooltip: AppLocalizations.of(context)!.adoptIntoLinkField,
                            onPressed: () => _applySearchResult(r),
                          )
                        ],
                      ),
                      onTap: () => _applySearchResult(r),
                    );
                  },
                ),
              ),
            const SizedBox(height:10),
            if (_dirNodes.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _dirNodes.take(10).map((n){
                  final selected = (_selectedDir ?? 'docs') == n.path;
                  return ChoiceChip(
                    label: Text(n.displayName),
                    selected: selected,
                    onSelected: (_) => setState(()=> _selectedDir = n.path),
                  );
                }).toList(),
              ),
            if (_selectedDir != null) Padding(
              padding: const EdgeInsets.only(top:8),
              child: Text(AppLocalizations.of(context)!.selectedLabel(_selectedDir!), style: const TextStyle(fontSize:12)),
            ),
            if (_selectedDir == null && _dirNodes.any((d)=>d.path=='docs')) Padding(
              padding: const EdgeInsets.only(top:8),
              child: Text(AppLocalizations.of(context)!.willAutomaticallyUseDocs, style: const TextStyle(fontSize:12,fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRepoTree() async {
    if (_pendingOwner == null || _pendingRepo == null) return;
    setState(() { _treeLoading = true; _treeError = null; _dirNodes = []; });
    final owner = _pendingOwner!;
    final repo  = _pendingRepo!;
    final branch = _pendingBranch ?? 'main';
    try {
      final headers = <String,String>{ 'Accept': 'application/vnd.github+json' };
      final t = _token.text.trim();
      if (t.isNotEmpty) headers['Authorization'] = 'Bearer $t';
      final uri = Uri.parse('https://api.github.com/repos/$owner/$repo/git/trees/$branch?recursive=1');
      final res = await http.get(uri, headers: headers);
      if (res.statusCode != 200) {
        setState(()=> _treeError = 'HTTP ${res.statusCode}');
      } else {
        final body = json.decode(res.body) as Map<String,dynamic>;
        final tree = (body['tree'] as List).cast<Map<String,dynamic>>();
        final dirs = <String>{};
        for (final node in tree) {
          if (node['type'] == 'tree') {
            final p = node['path'] as String;
            dirs.add(p);
            // ensure parent directories also present
            var acc = '';
            for (final seg in p.split('/')) {
              acc = acc.isEmpty ? seg : '$acc/$seg';
              dirs.add(acc);
            }
          }
        }
        final list = dirs.toList()..sort((a,b)=>a.compareTo(b));
        final nodes = <_DirNode>[];
        for (final d in list) {
          final depth = d.split('/').length;
          nodes.add(_DirNode(path: d, depth: depth-1, displayName: d.split('/').last.isEmpty? d : d.split('/').last));
        }
        setState(() { _dirNodes = nodes; if (_dirNodes.any((n)=>n.path=='docs')) _selectedDir ??= 'docs'; });
      }
    } catch (e) {
      setState(()=> _treeError = e.toString());
    } finally {
      if (mounted) setState(()=> _treeLoading = false);
    }
  }

  Widget _examplesCard() {
    final l = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.examplesNeutral, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height:8),
          const SelectableText('https://github.com/OWNER/REPO'),
            const SelectableText('https://github.com/OWNER/REPO/tree/main/docs'),
            const SelectableText('https://raw.githubusercontent.com/OWNER/REPO/main/docs/README.md'),
          const SizedBox(height:12),
          Text(l.recognizedPattern),
        ]),
      ),
    );
  }
}

class _RepoSearchResult {
  final String fullName; // owner/repo
  final String description;
  final int stars;
  final String defaultBranch;
  _RepoSearchResult({required this.fullName, required this.description, required this.stars, required this.defaultBranch});
}

class _DirNode {
  final String path;
  final int depth;
  final String displayName;
  bool expanded;
  _DirNode({required this.path, required this.depth, required this.displayName, this.expanded = false});
}

class _TokenStep extends StatelessWidget {
  final int num; final String text; const _TokenStep({required this.num, required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical:4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Container(
          width:22,height:22,
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: .35)),
          ),
          alignment: Alignment.center,
          child: Text('$num', style: TextStyle(fontSize:11,fontWeight: FontWeight.w600,color: cs.onPrimaryContainer)),
        ),
        const SizedBox(width:10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }
}
