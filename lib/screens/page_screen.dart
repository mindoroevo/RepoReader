import 'package:flutter/material.dart';
import '../services/wiki_service.dart';
import '../utils/naming.dart';
import '../utils/markdown_preprocess.dart';
import '../utils/toc.dart';
import '../services/tts_service.dart';
import '../widgets/markdown_view.dart';

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
  bool _ttsDialogOpen = false;
  TtsMode _mode = TtsMode.sentences;

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


  @override
  Widget build(BuildContext context) {
    final displayTitle = prettifyTitle(widget.title);
    return Scaffold(
      appBar: AppBar(
        title: Text(displayTitle),
        actions: [
          IconButton(
            tooltip: 'TTS Optionen',
            icon: const Icon(Icons.record_voice_over),
            onPressed: _content.trim().isEmpty ? null : _openTtsDialog,
          ),
          ValueListenableBuilder(
            valueListenable: TtsService.instance.status,
            builder: (context, st, _) {
              if (!st.playing) {
                return IconButton(
                  tooltip: 'Keine Wiedergabe aktiv',
                  icon: const Icon(Icons.stop_outlined),
                  onPressed: null,
                );
              }
              return Row(children: [
                IconButton(
                  tooltip: st.paused ? 'Weiter' : 'Pause',
                  icon: Icon(st.paused ? Icons.play_arrow : Icons.pause),
                  onPressed: () => st.paused ? TtsService.instance.resume() : TtsService.instance.pause(),
                ),
                IconButton(
                  tooltip: 'Stop',
                  icon: const Icon(Icons.stop),
                  onPressed: () => TtsService.instance.stop(),
                ),
              ]);
            },
          ),
          if (_toc.isNotEmpty)
            IconButton(
              tooltip: 'Inhalt',
              icon: const Icon(Icons.list_alt),
              onPressed: () => _openToc(context),
            ),
          if (_fromCache) const Padding(padding: EdgeInsets.only(right: 12), child: Center(child: Text('Offline')))
        ],
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
          // Wieder normale Markdown-Darstellung verwenden
          final scrollCtrl = ScrollController();
          return RefreshIndicator(
            onRefresh: _load,
            child: MarkdownView(
              content: _content,
              controller: scrollCtrl,
              onInternalLink: (path) => _openInternal(path),
            ),
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
    // Noch nicht umgesetzt (TOC Scroll). Placeholder.
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
    if (_ttsDialogOpen) return; _ttsDialogOpen = true;
    final tts = TtsService.instance;
    final langs = await tts.availableLanguages();
  final voicesRaw = await tts.availableVoices();
    if (!mounted) return;
  String? selLang = tts.language ?? (langs.isNotEmpty ? langs.first : null);
  // Sprache aus App übernehmen falls noch nicht gesetzt
  selLang ??= Localizations.localeOf(context).languageCode;
  String? selVoice = tts.voiceId;
  double rate = tts.rate;
  double pitch = tts.pitch;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSt) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.record_voice_over),
                      const SizedBox(width: 8),
                      Text('Vorlesen', style: Theme.of(ctx).textTheme.titleMedium),
                      const Spacer(),
                      DropdownButton<TtsMode>(
                        value: _mode,
                        onChanged: (m){ if (m!=null) setSt(()=> _mode=m); },
                        items: const [
                          DropdownMenuItem(value: TtsMode.words, child: Text('Wörter')),
                          DropdownMenuItem(value: TtsMode.sentences, child: Text('Sätze')),
                          DropdownMenuItem(value: TtsMode.blocks, child: Text('Blöcke')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _LanguageDropdown(
                    languages: langs.cast<String>(),
                    value: selLang,
                    onChanged: (v){ setSt(()=> selLang = v); },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selVoice,
                    decoration: const InputDecoration(labelText: 'Voice (optional)'),
                    items: [
                      for (final v in voicesRaw.cast<dynamic>())
                        if (v is Map && v['name']!=null && (selLang==null || (v['locale']?.toString().startsWith(selLang!) ?? true)))
                          DropdownMenuItem(value: v['name'], child: Text(v['name'])),
                    ],
                    onChanged: (v){ setSt(()=> selVoice = v); },
                  ),
                  const SizedBox(height: 12),
                  Row(children:[const Text('Speed'), Expanded(child: Slider(min:0.2,max:1.0,value: rate,onChanged:(val){ setSt(()=> rate=val);}) ), SizedBox(width:46, child: Text(rate.toStringAsFixed(2), textAlign: TextAlign.right))]),
                  Row(children:[const Text('Pitch'), Expanded(child: Slider(min:0.5,max:2.0,value: pitch,onChanged:(val){ setSt(()=> pitch=val);}) ), SizedBox(width:46, child: Text(pitch.toStringAsFixed(2), textAlign: TextAlign.right))]),
                  ValueListenableBuilder(
                    valueListenable: tts.status,
                    builder: (context, st, _) => st.playing ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(value: st.total==0? null : st.index / st.total),
                    ) : const SizedBox(height: 8),
                  ),
                  ValueListenableBuilder(
                    valueListenable: tts.currentWord,
                    builder: (context, w, _) => w==null? const SizedBox.shrink() : Padding(
                      padding: const EdgeInsets.only(top:4,bottom:4),
                      child: Text(w, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  // Start-Offset (Wortindex) Slider
                  Builder(builder: (ctx2){
                    final plain = _plainMarkdown();
                    final cleanedWords = plain
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim()
                        .split(' ')
                        .where((w)=>w.isNotEmpty)
                        .toList();
                    int startIndex = 0;
                    return StatefulBuilder(builder: (ctx3,setInner){
                      return Column(
                        children: [
                          if (cleanedWords.length > 30)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text('Start bei Wort: $startIndex / ${cleanedWords.length}', style: Theme.of(context).textTheme.labelMedium)),
                                    Text('${((startIndex/cleanedWords.length)*100).round()}%', style: Theme.of(context).textTheme.labelSmall),
                                  ],
                                ),
                                Slider(
                                  min:0,
                                  max:(cleanedWords.length-1).toDouble(),
                                  value:startIndex.toDouble(),
                                  divisions: cleanedWords.length-1,
                                  label: cleanedWords[startIndex],
                                  onChanged:(v){ setInner(()=> startIndex=v.round()); },
                                ),
                                Builder(builder: (_) {
                                  // Paragraph Mapping: finde Paragraph, der dieses Wort enthält
                                  final paraRaw = plain.split(RegExp(r'\n{2,}'));
                                  int wordCursor = 0;
                                  String? paragraphText;
                                  for (final raw in paraRaw) {
                                    final wordsInPara = raw
                                        .replaceAll(RegExp(r'\s+'), ' ')
                                        .trim()
                                        .split(' ')
                                        .where((w)=>w.isNotEmpty)
                                        .toList();
                                    final start = wordCursor;
                                    final end = wordCursor + wordsInPara.length - 1;
                                    if (startIndex >= start && startIndex <= end) {
                                      paragraphText = raw.trim();
                                      break;
                                    }
                                    wordCursor = end + 1;
                                  }
                                  paragraphText ??= paraRaw.isNotEmpty ? paraRaw.first.trim() : cleanedWords[startIndex];
                                  // Kürzen für Vorschau
                                  final preview = paragraphText.length > 260 ? paragraphText.substring(0, 260).trim() + '…' : paragraphText;
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top:4.0),
                                      child: Text(
                                        preview,
                                        style: const TextStyle(fontStyle: FontStyle.italic, height: 1.3),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(height:8),
                                FilledButton.tonal(
                                  onPressed: () async {
                                    await tts.configure(rate: rate, pitch: pitch, language: selLang, voiceId: selVoice, mode: _mode);
                                    await tts.start(_plainMarkdown(), overrideMode: _mode, startWord: startIndex);
                                    if (context.mounted) Navigator.pop(context); // Dialog schließen nach Start
                                  },
                                  child: const Text('Ab hier vorlesen'),
                                ),
                                const Divider(height:24),
                              ],
                            ),
                        ],
                      );
                    });
                  }),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.stop), label: const Text('Stop'), onPressed: ()=> tts.stop())),
                      const SizedBox(width: 12),
                      Expanded(child: FilledButton.icon(icon: const Icon(Icons.play_arrow), label: const Text('Start'), onPressed: () async {
                        await tts.configure(rate: rate, pitch: pitch, language: selLang, voiceId: selVoice, mode: _mode);
                        await tts.start(_plainMarkdown(), overrideMode: _mode, startWord: 0);
                        if (context.mounted) Navigator.pop(context); // Dialog schließen
                      })),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        });
      }
    ).whenComplete(() { _ttsDialogOpen = false; });
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
