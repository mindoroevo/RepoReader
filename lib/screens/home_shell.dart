import 'package:flutter/material.dart';
/// HomeShell ist der zentrale Einstiegspunkt der App.
///
/// Verantwortlichkeiten:
///  * Laden und Gruppieren aller README-Dateien (rekursiv) aus dem Repo-Pfad
///  * Verwaltung von Favoriten (persistiert über [FavoritesService])
///  * Sichtbarer Indikator für erkannte Änderungen (Badge + Bottom Sheet + Detail Navigation)
///  * Einstieg in Suche, Einstellungen und Seitenanzeige
///  * Präsentation einer kollabierbaren gruppierten Liste („Fancy“ Cards) für bessere Übersicht
///
/// Nicht-Ziele:
///  * Kein Caching eigener Inhalte (übernimmt [WikiService])
///  * Kein Diff-Berechnungscode (liegt in [ChangeTrackerService])
///  * Keine Markdown-Rendering-Logik (liegt in `markdown_view.dart` / `page_screen.dart`)
///
/// Badge-/Änderungslogik:
///  * Beim Start wird asynchron ein Snapshot erstellt und mit letztem Snapshot verglichen
///  * Wenn Änderungen vorliegen wird `_changeSummary` gesetzt und ein rotes Badge angezeigt
///  * Nach "Als gelesen" (Bottom Sheet Aktion) bleibt das Badge (Icon) erhalten, aber Farbe wechselt
///  * Dialog für Änderungen erscheint optional automatisch (abschaltbar in Einstellungen)
///
/// UX-Entscheidungen:
///  * Liste sofort anzeigen (optimistic UI) – Change-Erkennung läuft parallel
///  * Favoriten-Gruppe immer oben, einklappbar, Stern-Interaktion ohne Navigation
///  * Gruppenbildung: erstes Verzeichnis-Segment nach `docs/` bestimmt Gruppenschlüssel
///  * Tiefe beeinflusst Einrückung einzelner Einträge (visuelle Hierarchie)
///
/// Erweiterungs-Ideen (Future Work):
///  * Globale Suche in AppBar direkt (Schnelleinstieg)
///  * Kontextmenü pro Eintrag (z.B. "In neuem Tab" oder Kopieren des Repo-Pfads)
///  * Mehrfach-Markierung / Bulk Favorite Toggle
///  * Persistenz von aufgeklappten Gruppen zwischen Sessions
///
/// Fehler-/Edge Cases:
///  * Leere Ergebnisliste (keine README.md gefunden) → RefreshIndicator mit Hinweis
///  * Netzwerkfehler beim Laden: stillschweigend – UI zeigt ggf. leere Liste; könnte erweitert werden
///  * Entfernte Dateien tauchen nur im Änderungs-Bottom-Sheet / Dialog auf (nicht anklickbar)
///
/// Performance-Hinweis:
///  * Gruppierung ist O(n) für Anzahl Dateien – derzeit unkritisch wegen erwarteter moderater README-Menge
///  * Change-Erkennung läuft nur beim Start (oder manuell via Neustart App) – kein kontinuierliches Polling
///
/// Zusatz seit Erweiterungsphase:
/// * Globaler Erweiterungs-Auswahldialog (Extension Toggle Sheet) mit Kategorien & Suchfeld
/// * First-Run Gating (kein Default Repo) – zeigt SetupScreen modal
/// * Inline-Badges für zusätzliche Dateitypen in Gruppen
///
/// Stil: Deutschsprachige Doc-Kommentare gemäß Projektstandard.
import '../services/wiki_service.dart';
import '../services/universal_file_reader.dart';
import '../services/favorites_service.dart';
import '../services/change_tracker_service.dart';
import '../services/notification_service.dart';
import '../services/offline_snapshot_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'page_screen.dart';
import 'search_screen.dart';
import 'enhanced_search_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';
import 'universal_file_browser_screen.dart';
import '../config.dart';
import '../utils/naming.dart';
import 'change_detail_screen.dart';
import 'about_screen.dart';
import 'onboarding_screen.dart';
import '../widgets/tips_overlay.dart';
import '../services/tips_service.dart';
// sanitizeForPreview direkt aus change_tracker_service exportiert
// sanitizeForPreview kommt aus obiger Service-Import (zweiter show-Import entfernt)
// Removed all_in_one_screen ("Alles von oben nach unten") entry from drawer

class HomeShell extends StatefulWidget { const HomeShell({super.key}); @override State<HomeShell> createState() => _HomeShellState(); }

enum _MainViewMode { readmes, allFlat, tree }

class _HomeShellState extends State<HomeShell> {
  /// Zentraler Zugriff auf das Wiki (Verzeichnis-Auflistung / Markdown Laden)
  final _svc = WikiService();
  bool _loading = true;
  // README Navigationseinträge (alte Struktur beibehalten)
  List<RepoEntry> _files = [];
  // Alle Dateien (universell) für Zusatzanzeigen unter den README-Karten
  List<UniversalRepoEntry> _allFiles = [];
  // Letzter Ladefehler (z.B. 403 Rate Limit / Pfad nicht existent)
  String? _lastLoadError;
  // recursive mode always on now
  Set<String> _favorites = {};
  /// Zusammenfassung der zuletzt erkannten Änderungen (null wenn nicht geladen / keine)
  ChangeSummary? _changeSummary; // letzter erkannter Stand
  final Set<String> _activeExtensions = {}; // global ausgewählte file extensions (ohne Punkt)
  Set<String> _availableFileExts = {}; // alle außer md
  bool _configured = true; // wird im init() verifiziert; true = es existiert gespeicherte Quelle
  static const _prefsActiveExtsKey = 'pref:activeExtensions';
  bool _postConfigCheckDone = false;
  // Haupt-Ansichtsmodus: README Navigation, flache Alle-Dateien-Liste oder Baum-Explorer
  _MainViewMode _mode = _MainViewMode.readmes;

  Timer? _pollTimer; bool _pollBusy = false; int _pollBaseMinutes = 0; int _noChangeStreak = 0; int _minuteCounter = 0;

  @override
  void initState() {
    super.initState();
    // Build README index in background for robust internal link resolution
    WikiService.ensureIndex();
    _init();
  }

  /// Fügt einen Pfad zu Favoriten hinzu oder entfernt ihn.
  ///
  /// Aktualisiert sofort das lokale Set (optimistic) und persistiert anschließend.
  void _toggleFavorite(String path) async {
    final s = Set<String>.from(_favorites);
    if (s.contains(path)) {
      s.remove(path);
    } else {
      s.add(path);
    }
    setState(()=> _favorites = s);
    await FavoritesService.save(s);
  }

  /// Initialisiert Startzustand:
  ///  * Favoriten laden
  ///  * Änderungen (Diff Snapshot) ermitteln
  ///  * README-Liste laden
  ///  * Optional Änderungs-Dialog anzeigen
  Future<void> _init() async {
    // Runtime Config laden (falls gesetzt)
    try {
      final prefs = await SharedPreferences.getInstance();
      final o = prefs.getString('cfg:owner');
      final r = prefs.getString('cfg:repo');
      final b = prefs.getString('cfg:branch');
      final d = prefs.getString('cfg:dir');
      final t = prefs.getString('cfg:token');
      final onboardingSeen = prefs.getBool('pref:onboardingSeen') ?? false;
      final hasConfig = (o!=null && r!=null); // owner & repo notwendig – Branch / dir werden notfalls später gefüllt
      if (hasConfig) {
        AppConfig.configure(owner:o, repo:r, branch:b, dirPath:d, token:t);
        _configured = true;
      } else {
        setState(() { _configured = false; _loading = false; });
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          if (!onboardingSeen) {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
            if (!mounted) return;
            if (result == 'setup') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => SetupScreen(onApplied: () {
                setState(() { _configured = true; _loading = true; _files = []; _allFiles = []; _changeSummary = null; });
                _initAfterConfig();
              })));
            }
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => SetupScreen(onApplied: () {
              // Nach erstmaliger Konfiguration sofort alles neu laden (inkl. Favoriten / Changes / Polling)
              setState(() { _configured = true; _loading = true; _files = []; _allFiles = []; _changeSummary = null; });
              _initAfterConfig();
            })));
          }
        });
        return;
      }
    } catch(_) {}
    await _initAfterConfig();
  }

  Future<void> _initAfterConfig() async {
    final favs = await FavoritesService.load();
    if (mounted) setState(() => _favorites = favs);
    // gespeicherte Extension-Toggles laden
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_prefsActiveExtsKey);
      if (stored != null && stored.isNotEmpty) {
        setState(() => _activeExtensions.addAll(stored));
      }
    } catch(_) {}
    final tracker = ChangeTrackerService();
    ChangeSummary? summary;
    try { summary = await tracker.detectChanges(); } catch (_) {}
    await _load();
    await _startPollingIfEnabled();
    // Prepare notification permission if enabled by preference
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifyPref = prefs.getBool('pref:notifyChanges') ?? true;
      if (notifyPref) { await NotificationService.init(); }
    } catch (_) {}
    if (summary != null && mounted) {
      setState(()=> _changeSummary = summary);
      final prefs = await SharedPreferences.getInstance();
      final show = prefs.getBool('pref:showChangeDialog') ?? true;
      if (show) _showChangesDialog(summary);
      // Send a system notification if enabled
      final notify = prefs.getBool('pref:notifyChanges') ?? true;
      if (notify) {
        try { await NotificationService.showChangeNotification(count: summary.files.length); } catch (_) {}
      }
    }
    // Show onboarding once even if already configured
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('pref:onboardingSeen') ?? false;
      if (!seen && mounted) {
        // fire-and-forget; not awaiting keeps UI responsive
        // ignore: use_build_context_synchronously
        // We don't care about the result here
        // ignore: unawaited_futures
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      }
    } catch(_) {}
    // Show home tips once
    try {
      if (mounted && await TipsService.shouldShow('home')) {
        WidgetsBinding.instance.addPostFrameCallback((_) { _showHomeTips(); });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startPollingIfEnabled() async {
    // Initialisiert periodisches Minuten-Timer-Polling falls Basisintervall > 0.
    // Liest Nutzerpräferenzen (Grundintervall, Benachrichtigungen) und setzt
    // einen 1-Minuten-Ticker, der in `_maybePoll` dynamisch entscheidet ob ein
    // echter Poll-Lauf stattfinden soll (Backoff).
    final prefs = await SharedPreferences.getInstance();
    // Defaults: always on by default
    if (!prefs.containsKey('pref:pollMinutes')) {
      await prefs.setInt('pref:pollMinutes', 5);
    }
    if (!prefs.containsKey('pref:notifyChanges')) {
      await prefs.setBool('pref:notifyChanges', true);
    }
    _pollBaseMinutes = prefs.getInt('pref:pollMinutes') ?? 5;
    final notify = prefs.getBool('pref:notifyChanges') ?? true;
    if (_pollBaseMinutes <= 0) { _pollTimer?.cancel(); return; }
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 1), (_) => _maybePoll(notify));
  }

  Future<void> _maybePoll(bool notify) async {
    // Führt einen einzelnen Änderungs-Check aus wenn der dynamische Minuten-Zähler
    // das aktuelle effektive Intervall getroffen hat. Verwendet exponentielles
    // Backoff (Verdopplung alle 5 Leerlaufzyklen) via `_effectiveIntervalMinutes`.
    if (_pollBusy || !_configured) return;
    _minuteCounter = (_minuteCounter + 1) % 1000000;
    if (_minuteCounter % _effectiveIntervalMinutes() != 0) return;
    _pollBusy = true;
    try {
      final tracker = ChangeTrackerService();
      final summary = await tracker.detectChanges();
      if (summary != null && summary.files.isNotEmpty) {
        _noChangeStreak = 0;
        if (mounted) setState(()=> _changeSummary = summary);
        final prefs = await SharedPreferences.getInstance();
        final showDialogPref = prefs.getBool('pref:showChangeDialog') ?? true;
        if (showDialogPref && mounted) _showChangesDialog(summary);
        if (notify) await NotificationService.showChangeNotification(count: summary.files.length);
      } else {
        _noChangeStreak++;
      }
    } catch (_) {} finally { _pollBusy = false; }
  }

  int _effectiveIntervalMinutes() {
    // Berechnet das aktuelle Polling-Intervall: Basis * 2^factor, wobei factor
    // jeden 5. Leerlauf (keine Änderungen) bis max 3 hoch zählt (1x,2x,4x,8x).
    if (_pollBaseMinutes <= 0) return 999999; // disabled
    final factor = (_noChangeStreak ~/ 5).clamp(0, 3); // 0..3 -> 1x,2x,4x,8x
    return _pollBaseMinutes * (1 << factor);
  }

  Future<void> _persistActiveExtensions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsActiveExtsKey, _activeExtensions.toList());
    } catch(_) {}
  }

  // Kapselt Änderung der aktiven Extensions (vermeidet geschützten setState-Aufruf in externem Kontext)
  void _applyExtensionSelection(Set<String> newSet) {
    if (!mounted) return;
    setState(() {
      _activeExtensions
        ..clear()
        ..addAll(newSet);
    });
    _persistActiveExtensions();
  }

  void _openChangesSheet() {
    final summary = _changeSummary;
    if (summary == null) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: _ChangesList(
          summary: summary,
          onOpen: (f) => _openChangeDetail(context, f),
          onMarkRead: () async {
            await ChangeTrackerService.markRead(summary.newSignature);
            if (!mounted) return;
            // Frame-sicheres Rebuild
            WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() {}); });
          },
        ),
      ),
    );
  }

  /// Zeigt modalen Dialog mit allen Änderungen (nur einmal beim Start sofern aktiviert).
  ///
  /// Hinweise:
  ///  * Schließen navigiert NICHT automatisch irgendwohin
  ///  * Entfernte Dateien sind nicht anklickbar
  void _showChangesDialog(ChangeSummary summary) {
    showDialog(context: context, builder: (ctx) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20,18,20,6),
                child: Row(
                  children: [
                    const Icon(Icons.update),
                    const SizedBox(width: 12),
                    Expanded(child: Text(AppLocalizations.of(context)!.newChangedFiles, style: Theme.of(context).textTheme.titleMedium)),
                    IconButton(onPressed: ()=>Navigator.pop(ctx), icon: const Icon(Icons.close))
                  ],
                ),
              ),
              const Divider(height:1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: summary.files.length,
                  itemBuilder: (_, i) {
                    final f = summary.files[i];
                    Color chipColor;
                    String label;
                    switch(f.status){
                      case ChangeStatus.added: chipColor = Colors.green; label='Neu'; break;
                      case ChangeStatus.modified: chipColor = Colors.orange; label='Geändert'; break;
                      case ChangeStatus.removed: chipColor = Colors.red; label='Entfernt'; break;
                    }
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical:6),
                      child: InkWell(
                        onTap: f.status == ChangeStatus.removed ? null : () {
                          Navigator.pop(ctx);
                          final title = prettifyTitle(f.path.split('/').last);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => PageScreen(repoPath: f.path, title: title)));
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal:8, vertical:4),
                                    decoration: BoxDecoration(
                                      color: chipColor.withAlpha((255*.15).round()),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(label, style: TextStyle(color: chipColor, fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width:10),
                                  Expanded(child: Text(f.path, style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
                                ],
                              ),
                              if (f.status == ChangeStatus.modified) Padding(
                                padding: const EdgeInsets.only(top:6),
                                child: Text('+${f.addedLines} / -${f.removedLines} Zeilen', style: TextStyle(color: Colors.orange.shade700, fontSize: 12)),
                              ),
                              if (f.sample != null && f.sample!.trim().isNotEmpty) Container(
                                margin: const EdgeInsets.only(top:8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha((255*.4).round()),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(f.sample!, maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize:12,height:1.25)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16,4,16,12),
                child: Row(
                  children: [
                    const Spacer(),
                    FilledButton(onPressed: ()=>Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.close))
                  ],
                ),
              )
            ],
          ),
        ),
      );
    });
  }

  /// Lädt README-Dateien (Navigation) und komplette Dateiliste (für Zusatzdateien unterhalb der README-Verzeichnisse).
  Future<void> _load() async {
    try {
      // Offline erster Versuch: Falls Offline-Modus aktiv & Snapshot vorhanden versuchen wir Navigation lokal aufzubauen
      final offlineEnabled = await OfflineSnapshotService.isOfflineEnabled();
      if (offlineEnabled && await OfflineSnapshotService.hasSnapshot()) {
        bool networkReachable = true;
        // Kleiner Probeversuch: nur DNS vermeiden – wir skippen echten Call und verlassen uns bei Exception unten auf Offline
        try {
          // Kein aktiver Test nötig – falls nachfolgend Netzwerk scheitert fallen wir in Catch und lassen Offline greifen
        } catch (_) { networkReachable = false; }
        if (!networkReachable) {
          final offlineNav = await OfflineSnapshotService.listOfflineNavTextEntries();
          if (mounted) setState(() {
            _files = offlineNav.map((e)=> RepoEntry(name: e.name, path: e.path, type: 'file')).toList();
            _allFiles = []; // Könnten wir optional aus Manifest aufbauen
            _lastLoadError = null;
            _loading = false;
          });
          return; // fertig (rein offline)
        }
      }
      // Wir laden weiterhin alle Dateien (Universaldienst) und optional Readmes (für Link-Resolution Index),
      // aber die Navigation basiert jetzt auf ALLEN relevanten Textdateien (nicht nur README.md).
      final readmesFuture = _svc.listReadmesRecursively(AppConfig.dirPath); // für Index / spätere Features
      final all = await _svc.listAllFiles(AppConfig.dirPath);
      // Fire & forget: Readme Index Build (Fehler ignorieren)
      // ignore: unawaited_futures
      readmesFuture;
      if (!mounted) return;
      setState(() {
        // Navigierbare Textdateien bestimmen (erweiterter Satz an Extensions)
        bool isNavText(UniversalRepoEntry f){
          if (!f.isText) return false;
          final ln = f.name.toLowerCase();
          return ln.endsWith('.md') || ln.endsWith('.mdx') || ln.endsWith('.markdown') || ln.endsWith('.txt') || ln.endsWith('.rst') || ln.endsWith('.adoc');
        }
        final nav = <RepoEntry>[];
        for (final f in all) {
          if (isNavText(f)) {
            nav.add(RepoEntry(name: f.name, path: f.path, type: 'file'));
          }
        }
        nav.sort((a,b)=> a.path.toLowerCase().compareTo(b.path.toLowerCase()));
        _files = nav;
        _allFiles = all;
        _lastLoadError = null; // erfolgreicher Durchlauf
        // verfügbare Exts initialisieren
        final extSet = <String>{};
        for (final f in all) {
          final idx = f.name.lastIndexOf('.');
          if (idx>0 && idx < f.name.length-1) {
            final e = f.name.substring(idx+1).toLowerCase();
            if (e != 'md' && e != 'readme') extSet.add(e);
          }
        }
        _availableFileExts = extSet;
      });
    } catch (e) {
      // Offline-Fallback falls möglich
      try {
        if (await OfflineSnapshotService.isOfflineEnabled() && await OfflineSnapshotService.hasSnapshot()) {
          final offlineNav = await OfflineSnapshotService.listOfflineNavTextEntries();
          if (offlineNav.isNotEmpty && mounted) {
            setState(() {
              _files = offlineNav.map((e)=> RepoEntry(name: e.name, path: e.path, type: 'file')).toList();
              _allFiles = [];
              _lastLoadError = null;
            });
          } else if (mounted) {
            setState(() { _lastLoadError = '$e'; });
          }
        } else if (mounted) {
          setState(() { _lastLoadError = '$e'; });
        }
      } catch (_) {
        if (mounted) setState(() { _lastLoadError = '$e'; });
      }
    } finally { if (mounted) setState(() { _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    // Safety net: if prefs now contain config but UI still shows first-run, auto-initialize once
    if (!_configured && !_postConfigCheckDone) {
      _postConfigCheckDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final o = prefs.getString('cfg:owner');
          final r = prefs.getString('cfg:repo');
          if (o != null && r != null) {
            if (mounted) setState(() { _configured = true; _loading = true; });
            await _initAfterConfig();
          }
        } catch (_) {}
      });
    }
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final hasChanges = _changeSummary != null && _changeSummary!.files.isNotEmpty;
    final ackedSigFuture = ChangeTrackerService.acknowledgedSignature();
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        actions: [
          IconButton(
            key: _kModeBtn,
            tooltip: (){
              switch(_mode){
                case _MainViewMode.readmes: return 'Alle Dateien (flach)';
                case _MainViewMode.allFlat: return 'Explorer (Baum)';
                case _MainViewMode.tree: return 'README Navigation';
              }
            }(),
            icon: (){
              switch(_mode){
                case _MainViewMode.readmes: return const Icon(Icons.folder_open);
                case _MainViewMode.allFlat: return const Icon(Icons.account_tree);
                case _MainViewMode.tree: return const Icon(Icons.article);
              }
            }(),
            onPressed: () => setState(() {
              _mode = _mode == _MainViewMode.readmes
                  ? _MainViewMode.allFlat
                  : _mode == _MainViewMode.allFlat
                      ? _MainViewMode.tree
                      : _MainViewMode.readmes;
            }),
          ),
          IconButton(
            key: _kFilterBtn,
            tooltip: 'Dateitypen ein/ausblenden',
            icon: const Icon(Icons.filter_alt),
            onPressed: _openExtensionToggleSheet,
          ),
          IconButton(
            key: _kSearchBtn,
            tooltip: 'Suche',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          if (hasChanges)
            FutureBuilder<String?>(
              future: ackedSigFuture,
              builder: (ctx, snap) {
                final acknowledged = snap.data == _changeSummary!.newSignature;
                final count = _changeSummary!.files.length;
                return IconButton(
                  tooltip: acknowledged ? 'Änderungen (gelesen)' : 'Änderungen',
                  icon: Stack(children:[
                    const Icon(Icons.priority_high),
                    // Always show badge until user "löscht" (markRead invoked from sheet)
                    Positioned(
                      right: 0, top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: acknowledged ? Theme.of(context).colorScheme.secondaryContainer : Theme.of(context).colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text('$count', style: TextStyle(fontSize: 9,color: acknowledged ? Theme.of(context).colorScheme.onSecondaryContainer : Colors.white)),
                      ),
                    )
                  ]),
                  onPressed: () => _openChangesSheet(),
                );
              }),
          IconButton(
            tooltip: 'Hilfe',
            icon: const Icon(Icons.help_outline),
            onPressed: _showHomeTips,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(children: [
          DrawerHeader(child: Align(alignment: Alignment.bottomLeft, child: Text(AppLocalizations.of(context)!.menu, style: const TextStyle(fontSize: 20)))),
          // Removed toggle; recursive listing always enabled
          ListTile(
            leading: const Icon(Icons.search),
            title: Text(AppLocalizations.of(context)!.search),
            subtitle: Text(AppLocalizations.of(context)!.searchMarkdownFiles),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text(AppLocalizations.of(context)!.allFiles),
            subtitle: Text(AppLocalizations.of(context)!.pdfScriptsImages),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalFileBrowserScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: Text(AppLocalizations.of(context)!.changeSource),
            subtitle: Text('${AppConfig.owner}/${AppConfig.repo}@${AppConfig.branch}/${AppConfig.dirPath}', style: const TextStyle(fontSize:11)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SetupScreen(onApplied: () {
              setState(() { _loading = true; _files = []; _allFiles = []; _changeSummary = null; });
              _initAfterConfig();
            })) ),
          ),
          // Tutorial link moved into Settings screen for a cleaner drawer
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(AppLocalizations.of(context)!.settings),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(AppLocalizations.of(context)!.about),
            subtitle: Text(AppLocalizations.of(context)!.authorProjectInfo),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
        ]),
      ),
      body: SafeArea(
        child: !_configured
            ? LayoutBuilder(builder: (ctx, constraints) {
                final narrow = constraints.maxWidth < 520;
                final theme = Theme.of(context);
                final color = theme.colorScheme;
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Hero Icon Badge
                          Align(
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.primaryContainer.withValues(alpha: .55),
                                border: Border.all(color: color.outlineVariant.withValues(alpha: .5)),
                              ),
                              child: Icon(Icons.link, size: 40, color: color.primary),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(AppLocalizations.of(context)!.noSourceConfigured, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: .4)),
                          const SizedBox(height: 14),
                          Text(AppLocalizations.of(context)!.addGitHubLink,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
                          ),
                          const SizedBox(height: 22),
                          // Quick Steps Card
                          Card(
                            elevation: 0,
                            color: color.surfaceContainerLowest.withValues(alpha: .6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20,16,20,18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppLocalizations.of(context)!.quickStart, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: color.primary)),
                                  const SizedBox(height: 10),
                                  if (narrow) ...[
                                    _OnbStep(num: 1, text: AppLocalizations.of(context)!.quickStepConfigureOpen),
                                    _OnbStep(num: 2, text: AppLocalizations.of(context)!.quickStepPasteLink),
                                    _OnbStep(num: 3, text: AppLocalizations.of(context)!.quickStepOptionalToken),
                                    _OnbStep(num: 4, text: AppLocalizations.of(context)!.quickStepSaveStructure),
                                  ] else Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: Column(children:[
                                        _OnbStep(num: 1, text: AppLocalizations.of(context)!.quickStepConfigureOpen),
                                        _OnbStep(num: 2, text: AppLocalizations.of(context)!.quickStepPasteLinkSearch),
                                      ])),
                                      const SizedBox(width: 28),
                                      Expanded(child: Column(children:[
                                        _OnbStep(num: 3, text: AppLocalizations.of(context)!.quickStepOptionalToken),
                                        _OnbStep(num: 4, text: AppLocalizations.of(context)!.quickStepSaveStructureShort),
                                      ])),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Link-Badges entfernt (User-Wunsch: "das bitte weg")
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 26), shape: const StadiumBorder()),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(AppLocalizations.of(context)!.configureNow),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => SetupScreen(onApplied: () {
                                setState(() { _configured = true; _loading = true; _files = []; _allFiles = []; _changeSummary = null; });
                                _initAfterConfig();
                              })));
                            },
                          ),
                          const SizedBox(height: 32),
                          Opacity(
                            opacity: .70,
                            child: Text(AppLocalizations.of(context)!.tipCanChange,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              })
            : (_files.isEmpty
                ? RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 48, 24, 140),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(Icons.description_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(height: 18),
                                Text(AppLocalizations.of(context)!.noTextFiles, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                if (_lastLoadError != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.error_outline,size:20),
                                        const SizedBox(width:8),
                                        Expanded(child: Text('${AppLocalizations.of(context)!.loadError}: $_lastLoadError', style: Theme.of(context).textTheme.bodySmall)),
                                      ],
                                    ),
                                  ),
                                ],
                                Text('Ensure the repository contains at least one file with extension .md, .mdx, .markdown, .txt, .rst or .adoc.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 22),
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    FilledButton.icon(
                                      icon: const Icon(Icons.cloud_sync),
                                      label: Text(AppLocalizations.of(context)!.checkSource),
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => SetupScreen(onApplied: () {
                                          setState(() { _configured = true; _loading = true; _files = []; _allFiles = []; _changeSummary = null; });
                                          _initAfterConfig();
                                        })));
                                      },
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.refresh),
                                      label: Text(AppLocalizations.of(context)!.reloadFiles),
                                      onPressed: _load,
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: (){
                      switch(_mode){
                        case _MainViewMode.readmes: // nutzt jetzt _files = alle Textdateien
                          return _FancyDocList(
                            entries: _files,
                            favorites: _favorites,
                            universalFiles: _allFiles,
                            activeExtensions: _activeExtensions,
                            onToggleFavorite: _toggleFavorite,
                            onTap: (entry){
                              final lower = entry.path.toLowerCase();
                              final isMd = lower.endsWith('.md') || lower.endsWith('.mdx') || lower.endsWith('.markdown');
                              if (isMd) {
                                final title = prettifyTitle(entry.name);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => PageScreen(repoPath: entry.path, title: title)));
                              } else {
                                // generischer Viewer (lädt UniversalReader)
                                final match = _allFiles.firstWhere((f)=> f.path == entry.path, orElse: () => _allFiles.first);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => _GenericFilePreview(entry: match)));
                              }
                            },
                          );
                        case _MainViewMode.allFlat:
                          return _AllFilesList(files: _allFiles, onOpen: _openUniversalEntry);
                        case _MainViewMode.tree:
                          return _ExplorerTree(files: _allFiles, onOpen: _openUniversalEntry);
                      }
                    }(),
                  )),
      ),
    );
  }

  // --- Tips ---
  final _kModeBtn = GlobalKey();
  final _kFilterBtn = GlobalKey();
  final _kSearchBtn = GlobalKey();

  Future<void> _showHomeTips() async {
    final l = AppLocalizations.of(context)!;
    await showTipsOverlay(
      context,
      tips: [
        TipTarget(key: _kModeBtn, title: l.tipHomeModeTitle, body: l.tipHomeModeBody),
        TipTarget(key: _kFilterBtn, title: l.tipHomeFilterTitle, body: l.tipHomeFilterBody),
        TipTarget(key: _kSearchBtn, title: l.tipHomeSearchTitle, body: l.tipHomeSearchBody),
      ],
      skipLabel: l.onbSkip,
      nextLabel: l.onbNext,
      doneLabel: l.onbDone,
    );
    await TipsService.markShown('home');
  }
}

// Einfache flache Liste aller Repository-Dateien
class _AllFilesList extends StatelessWidget {
  final List<UniversalRepoEntry> files;
  final void Function(UniversalRepoEntry entry) onOpen;
  const _AllFilesList({required this.files, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 160), Center(child: Text('Keine Dateien geladen.'))],
      );
    }
    final sorted = [...files]..sort((a,b)=> a.path.compareTo(b.path));
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: sorted.length,
      itemBuilder: (c,i){
        final f = sorted[i];
        final icon = _iconForExt(f.extension);
        return ListTile(
          dense: true,
          leading: CircleAvatar(radius:14, child: Icon(icon, size:16)),
          title: Text(f.name, style: const TextStyle(fontSize:14)),
          subtitle: Text(f.path, style: const TextStyle(fontSize:11, fontFamily: 'monospace')),
          trailing: Text(f.formattedSize, style: const TextStyle(fontSize:10, fontWeight: FontWeight.w500)),
          onTap: () => onOpen(f),
        );
      },
    );
  }
}

IconData _iconForExt(String ext){
  final e = ext.toLowerCase();
  switch(e){
    case '.md': case '.txt': return Icons.description;
    case '.dart': case '.js': case '.ts': case '.py': case '.java': case '.cpp': case '.c': case '.h': case '.kt': case '.rs': return Icons.code;
    case '.json': case '.yaml': case '.yml': case '.xml': return Icons.settings;
    case '.png': case '.jpg': case '.jpeg': case '.gif': case '.svg': return Icons.image;
    case '.pdf': return Icons.picture_as_pdf;
    case '.zip': case '.tar': case '.gz': case '.rar': case '.7z': return Icons.archive;
    default: return Icons.insert_drive_file;
  }
}

extension _OpenUniversal on _HomeShellState {
  void _openUniversalEntry(UniversalRepoEntry e){
    final lower = e.extension.toLowerCase();
    if (lower == '.md' || lower == '.markdown' || lower == '.mdown' || lower == '.mkd') {
      final title = prettifyTitle(e.name);
      Navigator.push(context, MaterialPageRoute(builder: (_) => PageScreen(repoPath: e.path, title: title)));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => _GenericFilePreview(entry: e)));
  }
}

// ---------------- Explorer Tree (Dateien & Ordner hierarchisch) ----------------

class _ExplorerTree extends StatefulWidget {
  final List<UniversalRepoEntry> files;
  final void Function(UniversalRepoEntry entry) onOpen;
  const _ExplorerTree({required this.files, required this.onOpen});
  @override State<_ExplorerTree> createState() => _ExplorerTreeState();
}

class _TreeNode {
  final String name; // Segment
  final String path; // Vollständiger Pfad (für dirs ohne trailing /)
  final bool isDir;
  final UniversalRepoEntry? file; // null wenn Verzeichnis
  final Map<String,_TreeNode> children = {};
  _TreeNode({required this.name, required this.path, required this.isDir, this.file});
}

class _ExplorerTreeState extends State<_ExplorerTree> {
  final Map<String,bool> _expanded = {}; // Pfad -> expanded
  late final _TreeNode _root;

  @override void initState(){ super.initState(); _root = _build(); }

  _TreeNode _build(){
    final root = _TreeNode(name: '', path: '', isDir: true);
    for (final f in widget.files){
      final segs = f.path.split('/');
      var cur = root; String accum='';
      for (int i=0;i<segs.length;i++){
        final s = segs[i];
        final last = i==segs.length-1;
        accum = accum.isEmpty? s : '$accum/$s';
        if (last){
          cur.children[s] = _TreeNode(name:s, path: accum, isDir:false, file:f);
        } else {
          cur = cur.children.putIfAbsent(s, ()=> _TreeNode(name:s, path: accum, isDir:true));
        }
      }
    }
    return root;
  }

  @override
  Widget build(BuildContext context) {
    final rows = <_Row>[];
    void walk(_TreeNode node, int depth){
      final children = node.children.values.toList()
        ..sort((a,b){
          if (a.isDir && !b.isDir) return -1; if (!a.isDir && b.isDir) return 1; return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      for (final c in children){
        rows.add(_Row(node: c, depth: depth));
        if (c.isDir && (_expanded[c.path] ?? depth<1)) { // Root Ebene standard offen
          walk(c, depth+1);
        }
      }
    }
    walk(_root, 0);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom:140),
      itemCount: rows.length,
      itemBuilder: (ctx,i){
        final r = rows[i];
        final n = r.node;
        final indent = 12.0 + r.depth * 14.0;
        final isExpanded = _expanded[n.path] ?? false;
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.only(left: indent, right: 12),
          leading: n.isDir ? Icon(isExpanded? Icons.folder_open : Icons.folder) : Icon(_iconForExt(n.file!.extension)),
          title: Text(n.name.isEmpty? '/' : n.name, style: const TextStyle(fontSize:13)),
          trailing: n.isDir ? IconButton(
            icon: Icon(isExpanded? Icons.expand_less : Icons.expand_more, size:18),
            onPressed: () => setState(()=> _expanded[n.path] = !isExpanded),
          ) : Text(n.file!.formattedSize, style: const TextStyle(fontSize:10,fontWeight: FontWeight.w500)),
          onTap: () {
            if (n.isDir) {
              setState(()=> _expanded[n.path] = !isExpanded);
            } else if (n.file != null) {
              widget.onOpen(n.file!);
            }
          },
        );
      },
    );
  }
}

class _Row { final _TreeNode node; final int depth; _Row({required this.node, required this.depth}); }

// (Legacy All-Files Sheet entfernt – globale Extension-Toggles übernehmen diese Funktion)

extension _ExtToggleSheet on _HomeShellState {
  void _openExtensionToggleSheet() {
    final working = {..._activeExtensions};
    String search = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final all = _availableFileExts.where((e)=> e.isNotEmpty && e.toLowerCase()!='md').toList()..sort();
          final theme = Theme.of(context);

          // Categorization (keys localized)
            final l10n = AppLocalizations.of(context)!;
            const code = {'dart','js','ts','py','java','cpp','c','h','hpp','cs','go','rs','php','rb','swift','kt','m','mm'};
            const config = {'json','yaml','yml','xml','ini','env','config','toml'};
            const images = {'png','jpg','jpeg','gif','svg','bmp','ico','webp'};
            const media = {'mp3','wav','mp4','avi','mov','webm'};
            const archives = {'zip','rar','7z','tar','gz','tgz'};
            const docs = {'txt','rst'};
            Map<String,List<String>> categorize(List<String> exts) {
              final map = <String,List<String>>{
                l10n.fileTypeCategoryCode:[],
                l10n.fileTypeCategoryConfig:[],
                l10n.fileTypeCategoryDocuments:[],
                l10n.fileTypeCategoryImages:[],
                l10n.fileTypeCategoryMedia:[],
                l10n.fileTypeCategoryArchives:[],
                l10n.fileTypeCategoryOther:[],
              };
              for (final e in exts) {
                if (code.contains(e)) { map[l10n.fileTypeCategoryCode]!.add(e); }
                else if (config.contains(e)) { map[l10n.fileTypeCategoryConfig]!.add(e); }
                else if (images.contains(e)) { map[l10n.fileTypeCategoryImages]!.add(e); }
                else if (media.contains(e)) { map[l10n.fileTypeCategoryMedia]!.add(e); }
                else if (archives.contains(e)) { map[l10n.fileTypeCategoryArchives]!.add(e); }
                else if (docs.contains(e)) { map[l10n.fileTypeCategoryDocuments]!.add(e); }
                else { map[l10n.fileTypeCategoryOther]!.add(e); }
              }
              map.removeWhere((_,v)=> v.isEmpty);
              for (final v in map.values) { v.sort(); }
              return map;
            }
          final filtered = search.isEmpty ? all : all.where((e)=> e.contains(search)).toList();
          final catMap = categorize(filtered);
          Widget chips(List<String> exts) => Wrap(
            spacing:6,
            runSpacing:-6,
            children:[ for (final ext in exts) FilterChip(label: Text(ext), selected: working.contains(ext), onSelected: (v){ setLocal(()=> v ? working.add(ext) : working.remove(ext)); }) ],
          );
          final totalSelected = working.length;
          return SafeArea(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: Padding(
                padding: EdgeInsets.only(left:16,right:16,top:8,bottom: MediaQuery.of(context).viewInsets.bottom + 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .85),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children:[
                        Icon(Icons.tune, size:20, color: theme.colorScheme.primary),
                        const SizedBox(width:8),
                        Expanded(child: Text(l10n.fileTypeDialogTitle, style: theme.textTheme.titleMedium)),
                        TextButton(onPressed: all.isEmpty? null : () => setLocal(()=> working.clear()), child: Text(l10n.none)),
                        TextButton(onPressed: all.isEmpty? null : () => setLocal(()=> working..clear()..addAll(all)), child: Text(l10n.all)),
                        IconButton(onPressed: ()=> Navigator.pop(context), icon: const Icon(Icons.close))
                      ]),
                      const SizedBox(height:4),
                      if (all.isEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                          child: Text(l10n.noAdditionalFileTypesFound, style: theme.textTheme.bodySmall),
                        ),
                        const SizedBox(height:8),
                        Text(l10n.onlyReadmeVisible, style: theme.textTheme.labelSmall),
                      ] else ...[
                        TextField(
                          decoration: InputDecoration(isDense:true,prefixIcon: const Icon(Icons.search),hintText: l10n.filterExtensionExample, border: const OutlineInputBorder()),
                          onChanged: (v)=> setLocal(()=> search = v.trim().toLowerCase()),
                        ),
                        const SizedBox(height:12),
                        Expanded(
                          child: ListView(
                            children: [
                              for (final e in catMap.entries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom:14),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                                    Row(children:[
                                      Text(e.key, style: theme.textTheme.titleSmall),
                                      const SizedBox(width:6),
                                      Text('${e.value.where(working.contains).length}/${e.value.length}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                    ]),
                                    const SizedBox(height:6),
                                    chips(e.value),
                                  ]),
                                ),
                              const SizedBox(height:4),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12,10,12,10),
                          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                          child: Row(children:[
                            Expanded(child: Text(totalSelected==0? l10n.onlyReadmeVisibleShort : l10n.fileTypeCountActive(totalSelected), style: theme.textTheme.labelMedium)),
                            FilledButton.icon(icon: const Icon(Icons.check), label: Text(l10n.applyButton), onPressed: () {
                              // Verwende safe helper statt direktem setState-Aufruf (Analyzer warning avoidance)
                              _applyExtensionSelection(working);
                              Navigator.pop(context);
                            }),
                          ]),
                        )
                      ]
                    ],
                  ),
                ),
              ),
            ));
          },
      ),
    );
  }
}
// Einfacher generischer Datei-Preview (Text vs Hinweis für Binär)
class _GenericFilePreview extends StatefulWidget {
  final UniversalRepoEntry entry; const _GenericFilePreview({required this.entry});
  @override State<_GenericFilePreview> createState() => _GenericFilePreviewState();
}

class _GenericFilePreviewState extends State<_GenericFilePreview> {
  String? _text; bool _binary = false; bool _loading = true; String? _error;
  final _svc = WikiService();
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final res = await _svc.fetchFileByPath(widget.entry.path);
      if (res.isText) {
        _text = res.asText;
      } else { _binary = true; }
    } catch(e){ _error = '$e'; }
    if (mounted) setState(()=> _loading = false);
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.entry.name)),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : _error != null ? Center(child: Text('Fehler: $_error'))
        : _binary ? _binaryHint() : SelectionArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Text(_text ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 13))))
    );
  }
  Widget _binaryHint() => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children:[const Icon(Icons.insert_drive_file_outlined, size:48), const SizedBox(height:12), Text('Keine Textvorschau verfügbar. (${widget.entry.mimeType})') ])));
}

/// Öffnet Detailanzeige für eine geänderte Datei (Diff/Raw/Render Ansicht).
void _openChangeDetail(BuildContext context, ChangeFile f) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeDetailScreen(file: f)));
}

// (extension _openChangesSheet entfernt; Methode jetzt direkt in State-Klasse)

/// Bottom Sheet Listendarstellung der Änderungen mit Filter-Chips.
///
/// Gründe für Stateful Umsetzung:
///  * Lokaler Filterstatus (added/modified/removed)
///  * Rebuild des Chips ohne Eltern-Widget zu beeinflussen
class _ChangesList extends StatefulWidget {
  final ChangeSummary summary; final void Function(ChangeFile) onOpen; final Future<void> Function() onMarkRead;
  const _ChangesList({required this.summary, required this.onOpen, required this.onMarkRead});
  @override State<_ChangesList> createState() => _ChangesListState();
}

class _ChangesListState extends State<_ChangesList> {
  ChangeStatus? _filter; // null = alle
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final files = widget.summary.files.where((f) => _filter == null || f.status == _filter).toList();

    Color statusColor(ChangeStatus s) {
      switch (s) {
        case ChangeStatus.added: return Colors.green;
        case ChangeStatus.modified: return Colors.orange;
        case ChangeStatus.removed: return Colors.red;
      }
    }

    String statusLabel(ChangeStatus s) {
      switch (s) {
        case ChangeStatus.added: return 'Neu';
        case ChangeStatus.modified: return 'Geändert';
        case ChangeStatus.removed: return 'Entfernt';
      }
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12,4,12,0),
        child: Row(children: [
          Expanded(child: Text('Änderungen (${widget.summary.files.length})', style: Theme.of(context).textTheme.titleSmall)),
          TextButton(
            onPressed: () async {
              await widget.onMarkRead();
              if (mounted) setState(() {});
            },
            child: const Text('Als gelesen'),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip(context, null, 'Alle'),
            _filterChip(context, ChangeStatus.added, 'Neu'),
            _filterChip(context, ChangeStatus.modified, 'Geändert'),
            _filterChip(context, ChangeStatus.removed, 'Entfernt'),
            const SizedBox(width: 8),
            Text(_formatTimestamp(widget.summary.timestamp), style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
      ),
      const Divider(height: 16),
      Expanded(
        child: files.isEmpty
            ? const Center(child: Text('Keine Treffer für Filter'))
            : ListView.builder(
                itemCount: files.length,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemBuilder: (context, i) {
                  final f = files[i];
                  final chipColor = statusColor(f.status);
                  final label = statusLabel(f.status);
                  final sampleRich = f.sample == null ? null : _buildColoredSample(context, f.sample!);
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: InkWell(
                      onTap: f.status == ChangeStatus.removed ? null : () => widget.onOpen(f),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: chipColor.withAlpha((255 * .15).round()),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(color: chipColor, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    f.path,
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (f.status == ChangeStatus.modified)
                                  Text(
                                    '+${f.addedLines}/-${f.removedLines}',
                                    style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                                  ),
                              ],
                            ),
                            if (sampleRich != null)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest.withAlpha((255 * .35).round()),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: sampleRich,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  /// Baut einen Filter-Chip. Aktivierung setzt `_filter` auf Status oder null.
  Widget _filterChip(BuildContext context, ChangeStatus? st, String label) {
    final sel = _filter == st;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal:2),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_){ setState(()=> _filter = st); },
      ),
    );
  }

  /// Formatiert Zeitstempel (YYYY-MM-DD HH:MM) für Anzeige im Sheet-Header.
  String _formatTimestamp(DateTime ts) {
    final d = '${ts.year.toString().padLeft(4,'0')}-${ts.month.toString().padLeft(2,'0')}-${ts.day.toString().padLeft(2,'0')}';
    final t = '${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}';
    return '$d $t';
  }

  /// Färbt Diff-Snippet Zeilenweise ein.
  /// Unterstützte Präfixe: + (hinzugefügt), - (entfernt), ➜ (geändert), '  ' (unverändert Kontext)
  /// Zusätzlich Re-Sanitizing falls HTML Reste vorhanden.
  Widget _buildColoredSample(BuildContext context, String sample) {
    final theme = Theme.of(context);
    // Re-sanitize in case sample was generated before improved sanitizer
    final lines = sample.split('\n').map((l){
      String prefix = '';
      String body = l;
      // Diff-Prefix erkennen
      if (body.startsWith('+ ')) { prefix = '+ '; body = body.substring(2); }
      else if (body.startsWith('➜ ')) { prefix = '➜ '; body = body.substring(2); }
      else if (body.startsWith('- ')) { prefix = '- '; body = body.substring(2); }
      else if (body.startsWith('  ')) { prefix = '  '; body = body.substring(2); }
      if (body.contains('<')) {
        try { body = sanitizeForPreview(body); } catch(_) {}
      }
      return prefix + body;
    }).toList();
    final spans = <TextSpan>[];
    for (final l in lines) {
      if (l.startsWith('+ ')) {
        spans.add(TextSpan(text: '$l\n', style: TextStyle(color: Colors.green.shade500)));
      } else if (l.startsWith('➜ ')) {
        spans.add(TextSpan(text: '$l\n', style: TextStyle(color: Colors.orange.shade400)));
      } else if (l.startsWith('- ')) {
        spans.add(TextSpan(text: '$l\n', style: TextStyle(color: Colors.red.shade400)));
      } else {
        spans.add(TextSpan(text: '$l\n', style: theme.textTheme.bodySmall));
      }
    }
    return RichText(text: TextSpan(style: theme.textTheme.bodySmall, children: spans));
  }
}

/// Pretty grouped list with cards for each README entry.
/// Darstellung aller README-Einträge gruppiert nach erstem Verzeichnisteil.
///
/// Features:
///  * Kollabierbare Gruppen mit animierter Rotation
///  * Eigenständige Favoriten-Gruppe oben
///  * Einträge als kartenartige Buttons mit Stern
///  * Einrückung basierend auf Tiefe relativ zur Gruppe
class _FancyDocList extends StatefulWidget {
  final List<RepoEntry> entries;
  final Set<String> favorites;
  final List<UniversalRepoEntry> universalFiles;
  final Set<String> activeExtensions;
  final void Function(RepoEntry) onTap;
  final void Function(String path) onToggleFavorite;
  const _FancyDocList({required this.entries, required this.favorites, required this.universalFiles, required this.activeExtensions, required this.onTap, required this.onToggleFavorite});
  @override State<_FancyDocList> createState() => _FancyDocListState();
}

class _FancyDocListState extends State<_FancyDocList> {
  final Map<String,bool> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final grouped = <String, List<RepoEntry>>{};
    for (final e in widget.entries) {
      final groups = _extractGroups(e.path);
      final key = groups.isEmpty ? 'Allgemein' : groups.first;
      grouped.putIfAbsent(key, () => []).add(e);
    }
    final sortedGroupKeys = grouped.keys.toList()..sort();

    // Zusätzliche Dateien nach Extensions einsortieren
    final extraByGroup = <String,List<UniversalRepoEntry>>{};
    if (widget.activeExtensions.isNotEmpty) {
      for (final f in widget.universalFiles) {
        final ln = f.name.toLowerCase();
        if (ln == 'readme.md') continue;
        final ext = f.extension.startsWith('.') ? f.extension.substring(1).toLowerCase() : f.extension.toLowerCase();
        if (!widget.activeExtensions.contains(ext)) continue;
        final parts = f.path.split('/');
        final gKey = parts.length>1 ? parts[1] : 'Allgemein';
        extraByGroup.putIfAbsent(gKey, ()=> []).add(f);
      }
      for (final list in extraByGroup.values) { list.sort((a,b)=> a.path.compareTo(b.path)); }
    }

    // Favorites sammeln
    final favEntries = <RepoEntry>[];
    for (final list in grouped.values) {
      for (final e in list) {
        if (widget.favorites.contains(e.path)) favEntries.add(e);
      }
    }
    favEntries.sort((a,b)=>a.path.compareTo(b.path));

    final sections = <Widget>[];
    if (favEntries.isNotEmpty) {
      sections.add(_buildGroupSection(
        context,
        title: '★ Favoriten',
        groupKey: '__favorites__',
        entries: favEntries,
        extras: const [],
        color: color,
        initiallyCollapsed: true,
      ));
    }
    for (final g in sortedGroupKeys) {
      final list = grouped[g]!;
      list.sort((a,b){
        final da = _extractGroups(a.path).length;
        final db = _extractGroups(b.path).length;
        if (da != db) return da.compareTo(db);
        return a.path.compareTo(b.path);
      });
      sections.add(_buildGroupSection(
        context,
        title: prettifyTitle(g),
        groupKey: g,
        entries: list,
        extras: extraByGroup[g] ?? const [],
        color: color,
        initiallyCollapsed: true,
      ));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
      children: sections,
    );
  }

  /// Baut eine Gruppenkarte mit einklappbarem Bereich.
  Widget _buildGroupSection(BuildContext context, {required String title, required String groupKey, required List<RepoEntry> entries, required List<UniversalRepoEntry> extras, required ColorScheme color, bool initiallyCollapsed = true}) {
    final isExpanded = _expanded[groupKey] ?? !initiallyCollapsed;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
  color: Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: .4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(()=> _expanded[groupKey] = !isExpanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: isExpanded ? .25 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Icons.chevron_right, color: color.primary),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: .4,
                        color: color.primary,
                      )),
                    ),
                    Text('${entries.length}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color.onSurfaceVariant)),
                    if (extras.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildExtrasBadge(extras, color, context),
                    ],
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  for (final entry in entries) _buildEntryCard(context, entry, color),
                  if (extras.isNotEmpty) ...[
                    const SizedBox(height:6),
                    for (final f in extras) _ExtraFileRow(file: f, color: color, depth: 1, onOpen: _openUniversalFile),
                  ]
                ],
              ),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildExtrasBadge(List<UniversalRepoEntry> extras, ColorScheme color, BuildContext context) {
    // Count by extension
    final counts = <String,int>{};
    for (final f in extras) {
      var ext = f.extension;
      if (ext.startsWith('.')) ext = ext.substring(1);
      if (ext.toLowerCase() == 'md') continue; // skip markdown
      counts[ext] = (counts[ext] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox.shrink();
    final parts = counts.entries.map((e) => '${e.key}×${e.value}').toList()..sort();
    final shown = parts.take(3).join(' ');
    final more = parts.length > 3 ? ' +${parts.length - 3}' : '';
    final summaryFull = parts.join(', ');
    return Tooltip(
      message: 'Zusätzliche Dateien: $summaryFull',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.secondaryContainer.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.outlineVariant.withValues(alpha: .4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 14),
            const SizedBox(width: 4),
            Text(shown + more, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  /// Baut einzelne Dokumentenkarte (Entry). Berechnet Untertitel-Kette aus Verzeichnissen.
  Widget _buildEntryCard(BuildContext context, RepoEntry entry, ColorScheme color) {
    final depth = _depthWithoutReadme(entry.path);
    // Titel-Bestimmung:
    // * README / INDEX Dateien: Verwende Ordnernamen als Titel (letztes Verzeichnis)
    // * Andere Textdateien: Dateiname ohne Extension
    String computeTitle() {
      final ln = entry.name.toLowerCase();
      final isReadmeLike = ln == 'readme.md' || ln == 'readme.mdx' || ln == 'readme.markdown' || ln == 'index.md' || ln == 'index.mdx';
      if (isReadmeLike) {
        final parts = entry.path.split('/');
        if (parts.length >= 2) {
          return prettifyTitle(parts[parts.length - 2]);
        }
        return 'Übersicht';
      }
      final base = entry.name.replaceAll(RegExp(r'\.(mdx?|markdown|txt|rst|adoc)$', caseSensitive: false), '');
      return prettifyTitle(base);
    }
    final display = computeTitle();
    // Untertitel: Restliche Verzeichniskette (ohne die für den Titel verwendete Ebene)
    List<String> buildSubtitleSegments() {
      final parts = entry.path.split('/');
      if (parts.isEmpty) return const [];
      parts.removeLast(); // Datei entfernen
      if (parts.isEmpty) return const [];
      // Wenn README-artig: letzte Ebene war Titel -> entfernen
      final ln = entry.name.toLowerCase();
      final isReadmeLike = ln.startsWith('readme') || ln.startsWith('index');
      if (isReadmeLike && parts.isNotEmpty) parts.removeLast();
      // Optional führendes leeres Segment oder dirPath entfernen
      return parts.where((p) => p.isNotEmpty).map(prettifyTitle).toList();
    }
    final subSegments = buildSubtitleSegments();
    final subtitle = subSegments.isEmpty ? null : subSegments.join(' / ');
    final isFav = widget.favorites.contains(entry.path);
    return Card(
      margin: const EdgeInsets.symmetric(vertical:6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Color.alphaBlend(color.primary.withAlpha((255*.04).round()), color.surface),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => widget.onTap(entry),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14 + depth*6.0, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.description_outlined, size:20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(display, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                    if (subtitle != null) Padding(
                      padding: const EdgeInsets.only(top:4),
                      child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? color.primary : color.onSurfaceVariant),
                tooltip: isFav ? 'Aus Favoriten entfernen' : 'Zu Favoriten',
                onPressed: () => widget.onToggleFavorite(entry.path),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _openUniversalFile(UniversalRepoEntry file) {
    final ext = file.extension.toLowerCase();
    if (ext == '.md' || ext == '.readme' || ext == '.txt') {
      final title = prettifyTitle(file.name);
      Navigator.push(context, MaterialPageRoute(builder: (_) => PageScreen(repoPath: file.path, title: title)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => UniversalFileDetailScreen(file: file)));
    }
  }
}

// Separate stateless widget for extra (non-README) files inside a group section
class _ExtraFileRow extends StatelessWidget {
  final UniversalRepoEntry file; final ColorScheme color; final int depth; final void Function(UniversalRepoEntry) onOpen;
  const _ExtraFileRow({required this.file, required this.color, required this.depth, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final icon = _iconForExtension(file.extension.toLowerCase(), file.category);
    return InkWell(
      onTap: () => onOpen(file),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14 + depth*12.0, 6, 8, 6),
        child: Row(children:[
          Icon(icon, size: 18, color: color.primary),
          const SizedBox(width:10),
          Expanded(child: Text(file.name, style: Theme.of(context).textTheme.bodyMedium)),
          Text(file.formattedSize, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color.onSurfaceVariant))
        ]),
      ),
    );
  }
}

/// UI-Komponente für eine einzelne README-Karte.
/// Geringe Zustandsanforderungen → Stateless.

// _ListRenderItem removed in favor of collapsible section rendering.

List<String> _extractGroups(String path) {
  // path like docs/00-willkommen/03-styleguide/README.md
  final parts = path.split('/');
  final res = <String>[];
  for (int i=1;i<parts.length;i++) {
    final p = parts[i];
    if (p.toLowerCase() == 'readme.md') break;
    res.add(p);
  }
  return res;
}

int _depthWithoutReadme(String path) => _extractGroups(path).length - 1; // legacy helper (nur für alte README-Ansicht)

/// Liste zusätzlicher Dateien unterhalb eines README-Verzeichnisses.
// _DocCard & _ExtraFileList entfernt (legacy, nicht mehr genutzt)

// _EntryRow entfernt (legacy, nicht genutzt)

IconData _iconForExtension(String ext, String category) {
  switch (ext) {
    case '.md':
    case '.txt':
      return Icons.description_outlined;
    case '.dart': return Icons.code;
    case '.js':
    case '.ts':
    case '.py':
    case '.java':
    case '.cpp':
    case '.c':
    case '.h':
    case '.go':
    case '.rs':
    case '.php':
    case '.rb':
    case '.swift':
    case '.kt':
      return Icons.code;
    case '.json':
    case '.yaml':
    case '.yml':
    case '.xml':
    case '.ini':
    case '.config':
    case '.env':
      return Icons.settings_suggest_outlined;
    case '.png':
    case '.jpg':
    case '.jpeg':
    case '.gif':
    case '.svg':
    case '.bmp':
    case '.ico':
    case '.webp':
      return Icons.image_outlined;
    case '.pdf': return Icons.picture_as_pdf_outlined;
    case '.zip':
    case '.rar':
    case '.7z':
      return Icons.archive_outlined;
    case '.mp3':
    case '.wav':
    case '.mp4':
    case '.avi':
      return Icons.perm_media_outlined;
    default:
  if (category == 'Binary Files') return Icons.insert_drive_file_outlined;
      return Icons.description_outlined;
  }
}

// (Universelle Startseiten-Listen-Variante entfernt – README-Struktur wiederhergestellt.)

class _OnbStep extends StatelessWidget {
  final int num; final String text; const _OnbStep({required this.num, required this.text});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: color.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.primary.withValues(alpha: .35)),
          ),
          alignment: Alignment.center,
          child: Text('$num', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.primary)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }
}

// _MiniLink Klasse entfernt
