import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/wiki_service.dart';
import '../utils/naming.dart';
import '../utils/markdown_preprocess.dart';
import '../utils/toc.dart';
import '../services/tts_service.dart';
import '../widgets/markdown_view.dart';
import '../widgets/tips_overlay.dart';
import '../services/tips_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
  // Anchored rendering
  final ScrollController _listController = ScrollController();
  final Map<String, GlobalKey> _anchorKeys = {};
  List<_AnchoredSection> _sections = [];
  // TTS
  final _tts = TtsService.instance;
  List<String> _availableLanguages = [];
  String? _selectedLanguage;
  List<String> _availableVoices = [];
  List<Map<String,String>> _parsedVoices = [];
  String? _selectedVoiceId;
  bool _speaking = false;
  bool _paused = false;
  bool _sliderActive = false;
  // UI-configurable TTS params
  double _uiRate = 0.5;
  double _uiPitch = 1.0;
  int _uiChunkPause = 180;
  int _uiParagraphPause = 450;
  bool _uiUseParagraphPause = true;
  bool _showAllVoices = false;
  bool _controlsExpanded = false;

  @override
  void initState() { super.initState(); _load(); WidgetsBinding.instance.addPostFrameCallback((_) async { if (mounted && await TipsService.shouldShow('page')) { _showPageTips(); } });
    // Keep local UI flags in sync with service status
    _tts.status.addListener(_onTtsStatusChanged);
  }

  void _onTtsStatusChanged(){
    final s = _tts.status.value;
    if (!mounted) return;
    setState((){
      _speaking = s.playing;
      _paused = s.paused;
    });
  }

  @override
  void dispose() {
    try { _tts.status.removeListener(_onTtsStatusChanged); } catch (_) {}
    // Do NOT stop TTS automatically on dispose; user may want background playback
    // or control via app-level UI. Removing the unconditional stop prevents
    // accidental interruptions when the page is disposed.
    super.dispose();
  }

  /// Lädt den Markdown-Text, führt Preprocessing (Normalisierung & Link/Bild-Umsetzung)
  /// durch und baut anschließend das TOC. Fehler werden im State gespeichert.
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
    final (txt, fromCache) = await _svc.fetchMarkdownByRepoPath(widget.repoPath);
  final processed = preprocessMarkdown(txt, currentRepoPath: widget.repoPath);
  final toc = buildToc(processed);
  setState(() { _content = processed; _toc = toc; _fromCache = fromCache; _error = null; });
  // rebuild anchored sections for TOC scroll
  _buildAnchoredSections();
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally { setState(() => _loading = false); }
  }

  Future<void> _ensureTtsReady() async {
    // Only enable TTS on Android/iOS/web. Desktop (Windows/macOS/Linux) support
    // for flutter_tts may be missing or cause native crashes; guard against that.
    final supported = kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    if (!supported) return;
    try {
      // Initialize and load available languages from singleton service
      final langsDyn = await _tts.availableLanguages();
      final langs = langsDyn.map((e) => e.toString()).toList();
      setState(() {
        _availableLanguages = langs;
        // prefer document locale or device locale
        if (_availableLanguages.contains('de-DE')) _selectedLanguage = 'de-DE';
        else if (_availableLanguages.contains('en-US')) _selectedLanguage = 'en-US';
        else if (_availableLanguages.isNotEmpty) _selectedLanguage = _availableLanguages.first;
      });
      // load voices as well
      try {
        final rawVoices = await _tts.availableVoices();
        final parsed = rawVoices.map((e){
          if (e is Map) {
            final nameRaw = (e['name'] ?? e['voice'] ?? e['id'] ?? e['label'] ?? '').toString();
            final locale = (e['locale'] ?? e['localeId'] ?? e['lang'] ?? '').toString();
            final id = nameRaw.isNotEmpty ? nameRaw : e.toString();
            final label = _formatVoiceLabel(id, locale);
            return {'id': id, 'label': label, 'locale': locale};
          }
          final s = e.toString();
          return {'id': s, 'label': s, 'locale': ''};
        }).toList();
        setState(()=> _parsedVoices = parsed.cast<Map<String,String>>());
        setState(()=> _availableVoices = parsed.map((v)=> v['id'] as String).toList());
  if (_selectedVoiceId == null && parsed.isNotEmpty) _selectedVoiceId = parsed.first['id'] as String;
  // read defaults from service (rate/pitch) and persisted pause values
  _uiRate = _tts.rate;
  _uiPitch = _tts.pitch;
  _uiChunkPause = _tts.chunkPauseMs;
  _uiParagraphPause = _tts.paragraphPauseMs;
  _uiUseParagraphPause = _tts.paragraphPauseMs > 0;
      } catch (_) {}
    } catch (_) {}
  }

  // pause defaults are static unless user changes them from UI

  void _updateSelectedVoiceForLanguage(){
    if (_parsedVoices.isEmpty) return;
    if (_selectedLanguage == null) return;
    final pref = _selectedLanguage!.split('-').first.toLowerCase();
    final byLocale = _parsedVoices.where((v) => (v['locale'] ?? '').toLowerCase().startsWith(pref)).toList();
    if (byLocale.isNotEmpty) {
      setState(()=> _selectedVoiceId = byLocale.first['id']);
    }
  }

  String _formatVoiceLabel(String id, String locale){
    // e.g. de-de-x-nfh-local -> try to extract a human-readable short name
    final parts = id.split('-');
    String short = id;
    if (parts.length >= 3) {
      short = parts.sublist(2).join('-');
    } else if (parts.length == 2) {
      short = parts[1];
    }
    short = short.replaceAll(RegExp(r'[_\.]'), ' ').trim();
    if (locale.isNotEmpty) return '${locale.toUpperCase()} — ${_capitalize(short)}';
    return _capitalize(short);
  }

  String _capitalize(String s){ if (s.isEmpty) return s; return s[0].toUpperCase()+s.substring(1); }


  Widget build(BuildContext context) {
    final displayTitle = prettifyTitle(widget.title);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 6,
        actionsIconTheme: const IconThemeData(size: 18),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            displayTitle,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
        actions: [
          // Toggle controls panel
          IconButton(
            tooltip: _controlsExpanded ? 'Steuerung einklappen' : 'Steuerung ausklappen',
            icon: Icon(_controlsExpanded ? Icons.expand_less : Icons.expand_more),
            iconSize: 18,
            padding: const EdgeInsets.all(4),
            onPressed: () => setState(() => _controlsExpanded = !_controlsExpanded),
          ),
          if (_fromCache) const Padding(padding: EdgeInsets.only(right: 12), child: Center(child: Text('Offline')))
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_controlsExpanded ? 48 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            height: _controlsExpanded ? 48 : 0,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: (_controlsExpanded)
                ? ValueListenableBuilder(
                    valueListenable: _tts.status,
                    builder: (context, TtsStatus s, _) {
                      final playing = s.playing;
                      final paused = s.paused;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Open TTS dialog
                          IconButton(
                            key: _kTtsOpenBtn,
                            tooltip: 'Vorlesen',
                            icon: const Icon(Icons.volume_up),
                            iconSize: 18,
                            padding: const EdgeInsets.all(4),
                            onPressed: () => _openTtsDialog(),
                          ),
                          const SizedBox(width: 6),
                          // Play
                          IconButton(
                            key: _kPlayBtn,
                            tooltip: 'Start Vorlesen',
                            icon: const Icon(Icons.play_arrow),
                            iconSize: 20,
                            padding: const EdgeInsets.all(4),
                            onPressed: (!_sliderActive)
                                ? () async {
                                    try {
                                      final paragraphMs = _uiUseParagraphPause ? _uiParagraphPause : 0;
                                      await _tts.configure(
                                        language: _selectedLanguage,
                                        voiceId: _selectedVoiceId,
                                        rate: _uiRate,
                                        pitch: _uiPitch,
                                        chunkPauseMs: _uiChunkPause,
                                        paragraphPauseMs: paragraphMs,
                                      );
                                      await _tts.start(_plainMarkdown());
                                    } catch (e, st) { debugPrint('Main Play error: $e\n$st'); }
                                  }
                                : null,
                          ),
                          const SizedBox(width: 6),
                          // Pause
                          IconButton(
                            key: _kPauseBtn,
                            tooltip: 'Pause',
                            icon: const Icon(Icons.pause),
                            iconSize: 18,
                            padding: const EdgeInsets.all(4),
                            onPressed: (playing && !paused) ? () async { try { await _tts.pause(); } catch (e, st) { debugPrint('pause error: $e\n$st'); } } : null,
                          ),
                          const SizedBox(width: 6),
                          // Stop
                          IconButton(
                            key: _kStopBtn,
                            tooltip: 'Stop',
                            icon: const Icon(Icons.stop),
                            iconSize: 18,
                            padding: const EdgeInsets.all(4),
                            onPressed: playing ? () async { try { await _tts.stop(); } catch (e, st) { debugPrint('stop error: $e\n$st'); } } : null,
                          ),
                          const SizedBox(width: 10),
                          // TOC (if available)
                          if (_toc.isNotEmpty)
                            IconButton(
                              key: _kTocBtn,
                              tooltip: 'Inhalt',
                              icon: const Icon(Icons.list_alt),
                              iconSize: 18,
                              padding: const EdgeInsets.all(4),
                              onPressed: () => _openToc(context),
                            ),
                          const SizedBox(width: 6),
                          // Help
                          IconButton(
                            tooltip: 'Hilfe',
                            icon: const Icon(Icons.help_outline),
                            iconSize: 18,
                            padding: const EdgeInsets.all(4),
                            onPressed: _showPageTips,
                          ),
                        ],
                      );
                    })
                : const SizedBox.shrink(),
          ),
        ),
      ),
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
          // Single-page markdown rendering (stable)
          return RefreshIndicator(
            onRefresh: _load,
            child: MarkdownView(
              content: _content,
              controller: _listController,
              onInternalLink: (path) => _openInternal(path),
            ),
          );
        },
      ),
    );
  }

  // --- Tips ---
  final _kTocBtn = GlobalKey();
  final _kTtsOpenBtn = GlobalKey();
  final _kPlayBtn = GlobalKey();
  final _kPauseBtn = GlobalKey();
  final _kStopBtn = GlobalKey();
  Future<void> _showPageTips() async {
    final l = AppLocalizations.of(context)!;
    await showTipsOverlay(
      context,
      tips: [
        // Controls
        TipTarget(key: _kTtsOpenBtn, title: 'Vorlesen', body: 'Einstellungen für Stimme, Tempo und Tonhöhe öffnen.'),
        TipTarget(key: _kPlayBtn, title: 'Start', body: 'Startet das Vorlesen. Wenn Text markiert ist, wird nur die Auswahl gelesen.'),
        TipTarget(key: _kPauseBtn, title: 'Pause', body: 'Pausiert die Wiedergabe.'),
        TipTarget(key: _kStopBtn, title: 'Stop', body: 'Beendet die Wiedergabe.'),
        if (_toc.isNotEmpty) TipTarget(key: _kTocBtn, title: l.tipPageTocTitle, body: l.tipPageTocBody),
      ],
      skipLabel: l.onbSkip,
      nextLabel: l.onbNext,
      doneLabel: l.onbDone,
    );
    await TipsService.markShown('page');
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
    final key = _anchorKeys[anchor];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  void _openInternal(String internalPath) {
    // Interne Links öffnen (neue PageScreen Instanz)
    if (internalPath.isEmpty) return;
    final title = prettifyTitle(internalPath.split('/').last.replaceAll(RegExp(r'\.md$', caseSensitive: false), ''));
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PageScreen(repoPath: internalPath, title: title)),
    );
  }

  String _plainMarkdown() => _content; // Cleaning passiert im Service

  Future<void> _openTtsDialog() async {
    final l = AppLocalizations.of(context)!;
    await _ensureTtsReady();
    if (!mounted) return;

    // Use a dialog to avoid bottom-sheet drag gesture interfering with sliders
    await showDialog<void>(
      context: context,
      builder: (c) {
        return Dialog(
          child: StatefulBuilder(
            builder: (c2, setStateDialog) {
              return SingleChildScrollView(
                padding: MediaQuery.of(c).viewInsets,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Vorlesen', style: Theme.of(c).textTheme.titleLarge),
                            IconButton(onPressed: () => Navigator.of(c).pop(), icon: const Icon(Icons.close)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _LanguageDropdown(
                          languages: _availableLanguages,
                          value: _selectedLanguage,
                          onChanged: (val) {
                            setStateDialog(() => _selectedLanguage = val);
                            _updateSelectedVoiceForLanguage();
                          },
                        ),
                        const SizedBox(height: 8),
                        (_parsedVoices.isEmpty)
                            ? const SizedBox(height: 8, child: Center(child: Text('Lade Stimmen...')))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(labelText: 'Stimme'),
                                    value: _parsedVoices.any((v) => v['id'] == _selectedVoiceId) ? _selectedVoiceId : (_parsedVoices.isNotEmpty ? _parsedVoices.first['id'] : null),
                                    items: [
                                      for (final v in _parsedVoices)
                                        DropdownMenuItem(value: v['id'], child: Text(v['label'] ?? v['id'] ?? '', overflow: TextOverflow.ellipsis)),
                                    ],
                                    onChanged: (val) => setState(() => _selectedVoiceId = val),
                                  ),
                                  const SizedBox(height: 6),
                                  const SizedBox(height: 8),
                                  Text('Stimm-Parameter', style: Theme.of(context).textTheme.labelLarge),
                                  const SizedBox(height: 8),
                                  Row(children: [Expanded(child: Text('Tempo')), SizedBox(width: 72, child: Text('${_uiRate.toStringAsFixed(2)}'))]),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanDown: (_) { setStateDialog(() => _sliderActive = true); },
                                      onPanCancel: () { setStateDialog(() => _sliderActive = false); },
                                      onPanEnd: (_) { setStateDialog(() => _sliderActive = false); },
                                      child: Slider(
                                        value: _uiRate,
                                        min: 0.2,
                                        max: 1.2,
                                        onChangeStart: (v) {
                                          debugPrint('Slider rate start $v');
                                          setStateDialog(() => _sliderActive = true);
                                        },
                                        onChanged: (v) {
                                          debugPrint('Slider rate changed $v');
                                          setStateDialog(() => _uiRate = v);
                                        },
                                        onChangeEnd: (v) {
                                          debugPrint('Slider rate end $v');
                                          setStateDialog(() => _sliderActive = false);
                                        },
                                      ),
                                    ),
                                  ),
                                  Row(children: [Expanded(child: Text('Pitch')), SizedBox(width: 72, child: Text('${_uiPitch.toStringAsFixed(2)}'))]),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanDown: (_) { setStateDialog(() => _sliderActive = true); },
                                      onPanCancel: () { setStateDialog(() => _sliderActive = false); },
                                      onPanEnd: (_) { setStateDialog(() => _sliderActive = false); },
                                      child: Slider(
                                        value: _uiPitch,
                                        min: 0.5,
                                        max: 2.0,
                                        onChangeStart: (v) {
                                          debugPrint('Slider pitch start $v');
                                          setStateDialog(() => _sliderActive = true);
                                        },
                                        onChanged: (v) {
                                          debugPrint('Slider pitch changed $v');
                                          setStateDialog(() => _uiPitch = v);
                                        },
                                        onChangeEnd: (v) {
                                          debugPrint('Slider pitch end $v');
                                          setStateDialog(() => _sliderActive = false);
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.check),
                                      label: const Text('Anwenden'),
                                      onPressed: (_selectedVoiceId == null && _selectedLanguage == null)
                                          ? null
                                          : () async {
                                              try {
                                                final paragraphMs = _uiUseParagraphPause ? _uiParagraphPause : 0;
                                                await _tts.configure(
                                                  language: _selectedLanguage,
                                                  voiceId: _selectedVoiceId,
                                                  rate: _uiRate,
                                                  pitch: _uiPitch,
                                                  chunkPauseMs: _uiChunkPause,
                                                  paragraphPauseMs: paragraphMs,
                                                );
                                                if (mounted) setState(() => _speaking = _tts.status.value.playing);
                                              } catch (e, st) {
                                                debugPrint('Apply voice error: $e\n$st');
                                              }
                                            },
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.volume_up),
                                      label: const Text('Vorschau'),
                                      onPressed: (_selectedVoiceId == null && _selectedLanguage == null)
                                          ? null
                                          : () async {
                                              try {
                                                final paragraphMs = _uiUseParagraphPause ? _uiParagraphPause : 0;
                                                await _tts.configure(
                                                  language: _selectedLanguage,
                                                  voiceId: _selectedVoiceId,
                                                  rate: _uiRate,
                                                  pitch: _uiPitch,
                                                  chunkPauseMs: _uiChunkPause,
                                                  paragraphPauseMs: paragraphMs,
                                                );
                                                await _tts.start('Dies ist eine kurze Stimmprobe.');
                                              } catch (e, st) {
                                                debugPrint('Voice preview error: $e\n$st');
                                              }
                                            },
                                    ),
                                  ])
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
              );
          },
        ),
      );
    },
  );
}

}

class _AnchoredSection {
  final String anchor;
  final String content;
  _AnchoredSection(this.anchor, this.content);
}

extension on _PageScreenState {
  void _buildAnchoredSections() {
    _sections = [];
    _anchorKeys.clear();
    if (_content.trim().isEmpty) return;
    // Split by lines and detect headings
    final lines = _content.split('\n');
    final headingRe = RegExp(r'^\s{0,3}(#{1,6})\s+(.+?)\s*$');
    final used = <String,int>{};
    final indices = <int>[];
    final anchors = <String>[];
    for (int i=0; i<lines.length; i++) {
      final m = headingRe.firstMatch(lines[i]);
      if (m != null) {
        var text = m.group(2)!.trim();
        // strip trailing hashes in ATX style
        text = text.replaceFirst(RegExp(r'\s+#+\s*$'), '').trim();
        var anchor = text.toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\u00C0-\u024f\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '-');
        final count = used.update(anchor, (v)=>v+1, ifAbsent: ()=>0);
        if (count > 0) anchor = '$anchor-$count';
        indices.add(i);
        anchors.add(anchor);
        _anchorKeys.putIfAbsent(anchor, () => GlobalKey());
      }
    }
    if (indices.isEmpty) return;
    // Build sections from headings to next heading (exclusive)
    for (int s=0; s<indices.length; s++) {
      final start = indices[s];
      final end = (s < indices.length-1) ? indices[s+1] : lines.length;
      final slice = lines.sublist(start, end).join('\n');
      _sections.add(_AnchoredSection(anchors[s], slice));
    }
  }
}

/// Freundlichere Sprach-Auswahl mit Flaggen und kompaktem Default.
class _LanguageDropdown extends StatefulWidget {
  final List<String> languages; // e.g. de-DE
  final String? value;
  final ValueChanged<String?> onChanged;
  const _LanguageDropdown({required this.languages, required this.value, required this.onChanged});
  @override State<_LanguageDropdown> createState() => _LanguageDropdownState();
}

class _LanguageDropdownState extends State<_LanguageDropdown> {
  bool showAll = false;

  static const Map<String,String> _flagFor = {
    'de':'🇩🇪','en':'🇬🇧','en-US':'🇺🇸','en-GB':'🇬🇧','fr':'🇫🇷','es':'🇪🇸','it':'🇮🇹','pt':'🇵🇹','pt-BR':'🇧🇷','nl':'🇳🇱','pl':'🇵🇱','ru':'🇷🇺','tr':'🇹🇷','sv':'🇸🇪','no':'🇳🇴','nb':'🇳🇴','da':'🇩🇰','fi':'🇫🇮','cs':'🇨🇿','sk':'🇸🇰','hu':'🇭🇺','ro':'🇷🇴','bg':'🇧🇬','el':'🇬🇷','zh':'🇨🇳','zh-TW':'🇹🇼','ja':'🇯🇵','ko':'🇰🇷'};
  static String _label(String code){
    final base = code.split('-').first;
    final flag = _flagFor[code] ?? _flagFor[base] ?? '';
    final nameMap = {
      'de':'Deutsch','en':'English','fr':'Français','es':'Español','it':'Italiano','pt':'Português','nl':'Nederlands','pl':'Polski','ru':'Русский','tr':'Türkçe','sv':'Svenska','no':'Norsk','nb':'Norsk Bokmål','da':'Dansk','fi':'Suomi','cs':'Čeština','sk':'Slovenčina','hu':'Magyar','ro':'Română','bg':'Български','el':'Ελληνικά','zh':'中文','ja':'日本語','ko':'한국어'
    };
    final langName = nameMap[base] ?? code;
    return [if(flag.isNotEmpty) flag, langName, if(code.contains('-')) '(${code})'].join(' ');
  }

  @override Widget build(BuildContext context) {
    // Kurze Favoritenliste (häufig west-europäische Sprachen + Auto-Locale)
    final Set<String> favorites = {
      'de-DE','de','en-US','en-GB','en','fr-FR','es-ES','it-IT','nl-NL','pt-PT','pt-BR'
    };
    final sorted = [...widget.languages];
    sorted.sort();
    final display = showAll
        ? sorted
        : [
            ...sorted.where((l) => favorites.contains(l) || favorites.contains(l.split('-').first)),
            ...sorted.where((l) => l.startsWith(Localizations.localeOf(context).languageCode)).take(3),
          ].toSet().toList();
    display.sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: widget.value != null && display.contains(widget.value) ? widget.value : (display.isNotEmpty? display.first : null),
          decoration: const InputDecoration(labelText: 'Sprache'),
          items: [for (final l in display) DropdownMenuItem(value: l, child: Text(_label(l)))],
          onChanged: widget.onChanged,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(()=> showAll = !showAll),
            icon: Icon(showAll ? Icons.unfold_less : Icons.unfold_more),
            label: Text(showAll ? 'Weniger' : 'Mehr Sprachen'),
          ),
        )
      ],
    );
  }
}
