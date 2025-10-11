import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TtsMode { words, sentences, blocks }

class TtsStatus {
  final bool playing;
  final bool paused;
  final int index;
  final int total;
  final TtsMode mode;
  final double rate;
  final double pitch;
  final String? language;
  final String? voiceId;
  const TtsStatus({
    required this.playing,
    required this.paused,
    required this.index,
    required this.total,
    required this.mode,
    required this.rate,
    required this.pitch,
    this.language,
    this.voiceId,
  });
  TtsStatus copyWith({
    bool? playing,
    bool? paused,
    int? index,
    int? total,
    TtsMode? mode,
    double? rate,
    double? pitch,
    String? language,
    String? voiceId,
  }) => TtsStatus(
    playing: playing ?? this.playing,
    paused: paused ?? this.paused,
    index: index ?? this.index,
    total: total ?? this.total,
    mode: mode ?? this.mode,
    rate: rate ?? this.rate,
    pitch: pitch ?? this.pitch,
    language: language ?? this.language,
    voiceId: voiceId ?? this.voiceId,
  );
}

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<TtsStatus> status = ValueNotifier(
    const TtsStatus(playing: false, paused: false, index: 0, total: 0, mode: TtsMode.sentences, rate: 0.5, pitch: 1.0),
  );
  final ValueNotifier<String?> currentWord = ValueNotifier(null);
  final ValueNotifier<String?> currentChunk = ValueNotifier(null);

  SharedPreferences? _prefs;
  bool _initialized = false;
  // If configure is called while speaking, store values here and apply later
  final Map<String, dynamic> _pendingConfig = {};
  List<String> _chunks = [];
  int _current = 0;
  bool _stopRequested = false;
  bool _isRunning = false;
  // configurable pause durations (ms)
  int _chunkPauseMs = 180;
  int _paragraphPauseMs = 450;
  // subtle extra pauses around headings
  int _headingPrePauseMs = 140;
  int _headingPostPauseMs = 220;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    debugPrint('TtsService: _ensureInit starting');
    _prefs = await SharedPreferences.getInstance();
    final rate = _prefs!.getDouble('tts:rate') ?? 0.5;
    final pitch = _prefs!.getDouble('tts:pitch') ?? 1.0;
    final modeIndex = _prefs!.getInt('tts:mode') ?? TtsMode.sentences.index;
  _chunkPauseMs = _prefs!.getInt('tts:pause_chunk') ?? 180;
  _paragraphPauseMs = _prefs!.getInt('tts:pause_paragraph') ?? 450;
    status.value = status.value.copyWith(rate: rate, pitch: pitch, mode: TtsMode.values[modeIndex]);

  try { await _tts.setVolume(1.0); } catch (e, st) { debugPrint('TtsService: setVolume error $e\n$st'); }
  try { await _tts.setSpeechRate(rate); } catch (e, st) { debugPrint('TtsService: setSpeechRate error $e\n$st'); }
  try { await _tts.setPitch(pitch); } catch (e, st) { debugPrint('TtsService: setPitch error $e\n$st'); }

    final storedLang = _prefs!.getString('tts:lang');
    if (storedLang != null) {
      try {
        final langs = await _tts.getLanguages;
        if (langs == null || langs.contains(storedLang)) {
          await _tts.setLanguage(storedLang);
          status.value = status.value.copyWith(language: storedLang);
        }
      } catch (e, st) { debugPrint('TtsService: setLanguage(stored) error $e\n$st'); }
    }
    final storedVoice = _prefs!.getString('tts:voice');
    if (storedVoice != null && storedLang != null) {
      try { await _tts.setVoice({'name': storedVoice, 'locale': storedLang}); status.value = status.value.copyWith(voiceId: storedVoice); } catch (_) {}
    }

    try { _tts.setCompletionHandler(_handleCompletion); } catch (e, st) { debugPrint('TtsService: setCompletionHandler error $e\n$st'); }
    try { _tts.setCancelHandler(_handleCancel); } catch (e, st) { debugPrint('TtsService: setCancelHandler error $e\n$st'); }
    try { _tts.setStartHandler(() { status.value = status.value.copyWith(playing: true, paused: false); }); } catch (e, st) { debugPrint('TtsService: setStartHandler error $e\n$st'); }
    try { _tts.setPauseHandler(() { status.value = status.value.copyWith(paused: true); }); } catch (e, st) { debugPrint('TtsService: setPauseHandler error $e\n$st'); }
    try { _tts.setContinueHandler(() { status.value = status.value.copyWith(paused: false); }); } catch (e, st) { debugPrint('TtsService: setContinueHandler error $e\n$st'); }
    try {
      _tts.setProgressHandler((text, start, end, word) {
        if (word != null && word.trim().isNotEmpty) currentWord.value = word;
      });
    } catch (_) {}
    try { await _tts.awaitSpeakCompletion(true); } catch (e, st) { debugPrint('TtsService: awaitSpeakCompletion error $e\n$st'); }
    _initialized = true;
    debugPrint('TtsService: _ensureInit done (initialized=true)');
  }

  Future<List<dynamic>> availableLanguages() async { await _ensureInit(); return (await _tts.getLanguages) ?? []; }
  Future<List<dynamic>> availableVoices() async { await _ensureInit(); try { return await _tts.getVoices ?? []; } catch (_) { return []; } }

  Future<void> configure({double? rate, double? pitch, String? language, String? voiceId, TtsMode? mode, int? chunkPauseMs, int? paragraphPauseMs}) async {
    await _ensureInit();
    debugPrint('TtsService: configure(rate:$rate,pitch:$pitch,language:$language,voiceId:$voiceId,mode:$mode)');
    // If currently playing, apply rate/pitch and pause durations immediately
    // so UI sliders take effect; queue only language/voice/mode to avoid
    // interrupting speech while still permitting runtime parameter tweaks.
    if (status.value.playing) {
      debugPrint('TtsService: currently playing — applying immediate params and queuing rest');
      if (rate != null) {
        try { await _tts.setSpeechRate(rate); } catch (_) {}
        status.value = status.value.copyWith(rate: rate);
        _prefs?.setDouble('tts:rate', rate);
      }
      if (pitch != null) {
        try { await _tts.setPitch(pitch); } catch (_) {}
        status.value = status.value.copyWith(pitch: pitch);
        _prefs?.setDouble('tts:pitch', pitch);
      }
      if (chunkPauseMs != null) { _chunkPauseMs = chunkPauseMs; _prefs?.setInt('tts:pause_chunk', chunkPauseMs); }
      if (paragraphPauseMs != null) { _paragraphPauseMs = paragraphPauseMs; _prefs?.setInt('tts:pause_paragraph', paragraphPauseMs); }
      if (mode != null) _pendingConfig['mode'] = mode;
      if (language != null) _pendingConfig['language'] = language;
      if (voiceId != null) _pendingConfig['voiceId'] = voiceId;
      return;
    }
    if (rate != null) { try { await _tts.setSpeechRate(rate); } catch (_) {} status.value = status.value.copyWith(rate: rate); _prefs?.setDouble('tts:rate', rate); }
    if (pitch != null) { try { await _tts.setPitch(pitch); } catch (_) {} status.value = status.value.copyWith(pitch: pitch); _prefs?.setDouble('tts:pitch', pitch); }
    if (mode != null) { status.value = status.value.copyWith(mode: mode); _prefs?.setInt('tts:mode', mode.index); }
  if (paragraphPauseMs != null) { _paragraphPauseMs = paragraphPauseMs; _prefs?.setInt('tts:pause_paragraph', paragraphPauseMs); }
  if (chunkPauseMs != null) { _chunkPauseMs = chunkPauseMs; _prefs?.setInt('tts:pause_chunk', chunkPauseMs); }
    if (language != null) {
      final mapped = _mapLocaleToPreferred(language) ?? language;
  try { await _tts.setLanguage(mapped); status.value = status.value.copyWith(language: mapped); _prefs?.setString('tts:lang', mapped); } catch (e, st) { debugPrint('TtsService: setLanguage error $e\n$st'); }
    }
    if (voiceId != null) {
      final loc = (language ?? status.value.language) ?? '';
    try { await _tts.setVoice({'name': voiceId, 'locale': loc}); status.value = status.value.copyWith(voiceId: voiceId); _prefs?.setString('tts:voice', voiceId); } catch (e, st) { debugPrint('TtsService: setVoice error $e\n$st'); }
    }
  }

  void _applyPendingConfigIfAny() async {
    if (_pendingConfig.isEmpty) return;
    debugPrint('TtsService: applying pending config ${_pendingConfig.keys}');
    final rate = _pendingConfig.remove('rate') as double?;
    final pitch = _pendingConfig.remove('pitch') as double?;
    final mode = _pendingConfig.remove('mode') as TtsMode?;
    final chunkPauseMs = _pendingConfig.remove('chunkPauseMs') as int?;
    final paragraphPauseMs = _pendingConfig.remove('paragraphPauseMs') as int?;
    final language = _pendingConfig.remove('language') as String?;
    final voiceId = _pendingConfig.remove('voiceId') as String?;
    try {
      await configure(rate: rate, pitch: pitch, mode: mode, chunkPauseMs: chunkPauseMs, paragraphPauseMs: paragraphPauseMs, language: language, voiceId: voiceId);
    } catch (e, st) {
      debugPrint('TtsService: applyPendingConfig error $e\n$st');
    }
  }

  Future<void> start(String fullText, {TtsMode? overrideMode, int startWord = 0}) async {
    await _ensureInit();
    debugPrint('TtsService: start requested, fullText length=${fullText.length}, overrideMode=$overrideMode, startWord=$startWord');
    // If already playing and not paused, ignore duplicate start requests.
    if (status.value.playing && !status.value.paused) {
      debugPrint('TtsService: start() called but already playing; ignoring');
      return;
    }
    // If paused, resume from current position
    if (status.value.paused) {
      debugPrint('TtsService: start() called while paused; resuming');
      await resume();
      return;
    }
    final mode = overrideMode ?? status.value.mode;

    if (status.value.language == null) {
      final mapped = _mapLocaleToPreferred(await _deviceOrStoredLocale());
      if (mapped != null) {
        final langs = await availableLanguages();
        if (langs.contains(mapped)) {
          try { await _tts.setLanguage(mapped); status.value = status.value.copyWith(language: mapped); } catch (e, st) { debugPrint('TtsService: setLanguage(mapped) error $e\n$st'); }
        }
      }
    }

    final cleanedFull = _cleanText(_applyProsodyHints(fullText));
    _chunks = _buildChunks(cleanedFull, mode);
    if (startWord > 0 && _chunks.isNotEmpty) {
      final totalWords = cleanedFull.split(RegExp(r'\s+')).where((w)=>w.isNotEmpty).length;
      final idx = ((startWord / (totalWords == 0 ? 1 : totalWords)) * (_chunks.length-1)).round().clamp(0, _chunks.length-1);
      _current = idx;
    } else {
      _current = 0;
    }
    status.value = status.value.copyWith(playing: true, paused: false, index: _current, total: _chunks.length, mode: mode);
    if (_chunks.isEmpty) { status.value = status.value.copyWith(playing: false); return; }
    debugPrint('TtsService: starting speak, chunks=${_chunks.length}, current=$_current');
    _stopRequested = false;
    if (!_isRunning) {
      _runLoop();
    }
  }

  Future<void> _runLoop() async {
    _isRunning = true;
    try {
      while (_current < _chunks.length && !_stopRequested) {
        // If paused, break and leave state so resume() can continue
        if (status.value.paused) break;
        final raw = _chunks[_current];
        if (raw.trim().isEmpty) { _current++; continue; }
        currentChunk.value = raw; currentWord.value = null;
        var chunk = raw; var isHeading = false;
        // Detect and strip heading marker even with leading whitespace.
        final headingPrefix = RegExp(r'^\s*\[HEADING\]\s*');
        if (headingPrefix.hasMatch(chunk)) {
          isHeading = true;
          chunk = chunk.replaceFirst(headingPrefix, '');
        }
        // Safety: remove any stray markers inside the chunk so the word isn't spoken.
        if (chunk.contains('[HEADING]')) {
          chunk = chunk.replaceAll('[HEADING]', '');
        }
        chunk = chunk.trim();
        try {
          debugPrint('TtsService: _runLoop speaking chunk index=$_current len=${chunk.length} heading=$isHeading');
          if (isHeading) {
            // small pre-pause before headings
            if (_headingPrePauseMs > 0) {
              await Future.delayed(Duration(milliseconds: _headingPrePauseMs));
            }
            final oldPitch = status.value.pitch;
            try { await _tts.setPitch((oldPitch * 1.15).clamp(0.5, 2.0)); } catch (_) {}
            await awaitOrSpeakAsync(chunk);
            try { await _tts.setPitch(oldPitch); } catch (_) {}
          } else {
            await awaitOrSpeakAsync(chunk);
          }
          if (_stopRequested) break;
          var pauseMs = chunk.contains('\n\n') ? _paragraphPauseMs : _chunkPauseMs;
          if (isHeading) pauseMs += _headingPostPauseMs; // extra post pause after headings
          await Future.delayed(Duration(milliseconds: pauseMs));
        } catch (e, st) {
          debugPrint('TtsService: _runLoop speak error $e\n$st');
        }
        _current += 1;
        status.value = status.value.copyWith(index: _current);
      }
    } finally {
      _isRunning = false;
      // normal completion
      if (!_stopRequested && !status.value.paused && _current >= _chunks.length) {
        status.value = status.value.copyWith(playing: false, paused: false);
        _applyPendingConfigIfAny();
      }
    }
  }

  List<String> _buildChunks(String text, TtsMode mode) {
    final cleaned = _cleanText(text);
    if (cleaned.trim().isEmpty) return [];
    List<String> out = [];
    switch (mode) {
      case TtsMode.words:
        final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        const group = 20;
        for (var i=0;i<words.length;i+=group) {
          out.add(words.sublist(i, i+group > words.length ? words.length : i+group).join(' '));
        }
        break;
      case TtsMode.sentences:
        out = _splitSentencesSmart(cleaned);
        break;
      case TtsMode.blocks:
        final paras = cleaned.split(RegExp(r'\n{2,}'));
        for (final p in paras) {
          final t = p.trim(); if (t.isEmpty) continue;
          if (t.length <= 220) {
            out.add(t);
          } else {
            var rest = t;
            while (rest.length > 220) {
              final cut = rest.lastIndexOf(' ', 200);
              if (cut <= 0) { out.add(rest.substring(0,200)); rest = rest.substring(200); } else { out.add(rest.substring(0,cut)); rest = rest.substring(cut+1); }
            }
            if (rest.trim().isNotEmpty) out.add(rest.trim());
          }
        }
        break;
    }
    if (out.isEmpty) {
      // Fallback: stabile Zeichen-Chunks
      const maxLen = 1200;
      var s = cleaned;
      while (s.length > maxLen) {
        var cut = s.lastIndexOf(' ', maxLen);
        if (cut <= 0) cut = maxLen;
        out.add(s.substring(0, cut).trim());
        s = s.substring(cut).trimLeft();
      }
      if (s.isNotEmpty) out.add(s);
    }
    return out;
  }

  String _applyProsodyHints(String input) {
    // Überschriften leicht akzentuieren
    // Mark headings so the speaker can treat them specially at speak-time.
    // Instead of inserting a visible token that may be spoken, store a
    // lightweight marker that later speaking code can inspect and strip.
    // We'll replace headings with a non-word marker '[HEADING]' followed by
    // the heading text; speaking code must strip that marker before sending
    // to the engine.
    return input.replaceAllMapped(RegExp(r'^\s*#{1,6}\s+([^\n]+?)\s*$', multiLine: true), (m) => '[HEADING]${m.group(1)!.trim()}');
  }

  @visibleForTesting
  String debugApplyProsodyHints(String input) => _applyProsodyHints(input);

  List<String> _splitSentencesSmart(String cleaned) {
    final out = <String>[]; final buf = StringBuffer();
    bool isDigit(String ch) => ch.isNotEmpty && ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
    bool isBoundary(int i){
      final c = cleaned[i]; if (c=='!'||c=='?') return true; if (c!='.') return false;
      final prev = i>0 ? cleaned[i-1] : ''; final next = i+1<cleaned.length ? cleaned[i+1] : '';
      if (isDigit(prev) && isDigit(next)) return false; // 3.14 / 1.2.3
      final start = (i-16)<0 ? 0 : i-16; final ctx = cleaned.substring(start, i+1);
      // Expanded abbreviation list to avoid splitting on common short forms.
      final abbrRegex = RegExp(r'(?:z\.?B\.|z\.?\s?B\.|z\.B\.|z\.\s?B\.|bzw\.|bspw\.|bzw\.|u\.?a\.|u\.?v\.?m\.|u\.?s\.?w\.|usw\.|etc\.|ca\.|vgl\.|Dr\.|Prof\.|Mr\.|Mrs\.|Ms\.|Nr\.|S\.|Abb\.|Abs\.|Tel\.|cv\.|i\.e\.|e\.g\.)$', caseSensitive:false);
      if (abbrRegex.hasMatch(ctx)) return false;
      return true;
    }
    for (int i=0;i<cleaned.length;i++){
      final ch = cleaned[i]; buf.write(ch);
      if (isBoundary(i)){
        int j=i+1; while (j<cleaned.length && cleaned[j].trim().isEmpty) { buf.write(cleaned[j]); j++; }
        final s = buf.toString().trim(); if (s.isNotEmpty) out.add(s);
        buf.clear();
      }
    }
    final rest = buf.toString().trim(); if (rest.isNotEmpty) out.add(rest);
    return out;
  }

  // Public helper for tests/debugging to access sentence splitting logic.
  @visibleForTesting
  List<String> debugSplitSentences(String text) => _splitSentencesSmart(text);

  String _cleanText(String txt){
    // Preserve link and image alt/anchor text: transform
    //   ![alt](url) -> alt
    //   [text](url)  -> text
    var s = txt.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    s = s.replaceAll(RegExp(r'`[^`]+`'), ' ');
    s = s.replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), (m) => (m.group(1) ?? ''));
    s = s.replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => (m.group(1) ?? ''));
    return s
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'> '), '')
      .replaceAll(RegExp(r'[_*`#>|\-]'), ' ')
      .replaceAll(RegExp(r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true), ' ')
      .replaceAll(RegExp(r' {2,}'), ' ')
      .replaceAll(RegExp(r'\n +'), '\n')
      .trim();
  }

  Future<void> _speakCurrent() async {
    if (_current >= _chunks.length){ status.value = status.value.copyWith(playing:false, paused:false); return; }
    final raw = _chunks[_current];
    if (raw.trim().isEmpty) { _handleCompletion(); return; }
    currentChunk.value = raw; currentWord.value = null;
    // Handle heading marker and strip it before speaking (robustly)
    var chunk = raw;
    var isHeading = false;
    final headingPrefix = RegExp(r'^\s*\[HEADING\]\s*');
    if (headingPrefix.hasMatch(chunk)) {
      isHeading = true;
      chunk = chunk.replaceFirst(headingPrefix, '');
    }
    if (chunk.contains('[HEADING]')) {
      chunk = chunk.replaceAll('[HEADING]', '');
    }
    chunk = chunk.trim();
    try {
      debugPrint('TtsService: _speakCurrent chunk length=${chunk.length} heading=$isHeading');
      if (isHeading) {
        // small pre-pause before headings
        if (_headingPrePauseMs > 0) {
          await Future.delayed(Duration(milliseconds: _headingPrePauseMs));
        }
        // temporarily increase pitch for heading
        final oldPitch = status.value.pitch;
        try { await _tts.setPitch((oldPitch * 1.15).clamp(0.5, 2.0)); } catch (e, st) { debugPrint('setPitch error: $e\n$st'); }
        await awaitOrSpeakAsync(chunk);
        try { await _tts.setPitch(oldPitch); } catch (e, st) { debugPrint('restore pitch error: $e\n$st'); }
      } else {
        await awaitOrSpeakAsync(chunk);
      }
      // small pause after each chunk, longer pause after paragraph breaks
  var pauseMs = chunk.contains('\n\n') ? _paragraphPauseMs : _chunkPauseMs;
  if (isHeading) pauseMs += _headingPostPauseMs; // extra post pause after headings
      await Future.delayed(Duration(milliseconds: pauseMs));
    } catch (e, st) {
      debugPrint('TtsService: _speakCurrent error $e\n$st');
    }
    // proceed to next chunk (completion handlers may also trigger)
    _handleCompletion();
  }

  Future<void> awaitOrSpeakAsync(String chunk) async {
    try {
      final res = _tts.speak(chunk);
      if (res is Future) {
        await res;
      }
    } catch (e, st) {
      debugPrint('TtsService: speak call error $e\n$st');
    }
  }

  // helper to call speak and await where available
  // removed non-async awaitOrSpeak helper; use awaitOrSpeakAsync instead

  void _handleCompletion(){
    // If our manual run-loop is active, let it manage progression.
    if (_isRunning) return;
    if (_stopRequested) return;
    _current += 1; status.value = status.value.copyWith(index:_current);
    if (_current < _chunks.length) {
      _speakCurrent();
    } else {
      status.value = status.value.copyWith(playing:false, paused:false);
      // apply pending config if any after normal completion
      _applyPendingConfigIfAny();
    }
  }
  void _handleCancel(){
    debugPrint('TtsService: _handleCancel called (engine-level cancel)');
    // Do NOT clear playing/paused here or apply pending config. Engine
    // may signal cancellation for a single utterance when audio restarts
    // for the next chunk; keep run-loop responsible for progression.
    debugPrint('TtsService: _handleCancel stack:\n${StackTrace.current}');
  }

  /// Pause implementation: some platforms don't support native pause. In that
  /// case we stop the engine but retain the current chunk list and index so
  /// resume() can continue where it left off.
  Future<void> pause() async {
    if (!status.value.playing || status.value.paused) return;
    _stopRequested = true;
    try {
      // try native pause first
      await _tts.pause();
      status.value = status.value.copyWith(paused: true);
      return;
    } catch (e) {
      debugPrint('TtsService: native pause not available: $e');
    }
    // fallback: stop but keep chunks/_current so resume can continue
    try {
      await _tts.stop();
    } catch (e, st) {
      debugPrint('TtsService: stop during pause error $e\n$st');
    }
    status.value = status.value.copyWith(paused: true, playing: false);
    // keep _stopRequested true to prevent _handleCompletion from advancing
  }

  Future<void> resume() async {
    if (!status.value.paused) return;
    // clear stop flag and continue speaking remaining chunks via run-loop
    _stopRequested = false;
    status.value = status.value.copyWith(paused: false, playing: true);
    try {
      if (!_isRunning) await _runLoop();
    } catch (e, st) {
      debugPrint('TtsService: resume error $e\n$st');
    }
  }
  Future<void> stop() async {
    debugPrint('TtsService: stop requested');
    debugPrint('TtsService: stop called from:\n${StackTrace.current}');
    // If nothing is playing or paused and run-loop isn't active, ignore.
    if (!status.value.playing && !status.value.paused && !_isRunning) {
      debugPrint('TtsService: stop() ignored — nothing to stop');
      return;
    }
    _stopRequested = true;
    try {
      await _tts.stop();
    } catch (e, st) {
      debugPrint('TtsService: stop error $e\n$st');
    }
    // Wait briefly for the run-loop to observe _stopRequested and finish.
    final sw = Stopwatch()..start();
    while (_isRunning && sw.elapsedMilliseconds < 1200) {
      await Future.delayed(const Duration(milliseconds: 60));
    }
    // Now clear internal state
    _current = 0;
    _chunks = [];
    status.value = status.value.copyWith(playing: false, paused: false, index: 0, total: 0);
    _stopRequested = false;
    currentWord.value = null;
    currentChunk.value = null;
    // Apply any pending configuration now that playback has stopped
    _applyPendingConfigIfAny();
  }

  double get rate => status.value.rate; double get pitch => status.value.pitch; String? get language => status.value.language; String? get voiceId => status.value.voiceId;

  // expose current configured pause durations (ms) for UI initialization
  int get chunkPauseMs => _chunkPauseMs;
  int get paragraphPauseMs => _paragraphPauseMs;

  String? _mapLocaleToPreferred(String? code){ if (code==null) return null; const map={'de':'de-DE','en':'en-US','es':'es-ES','fr':'fr-FR','it':'it-IT','pt':'pt-PT','ru':'ru-RU','ja':'ja-JP','zh':'zh-CN','ko':'ko-KR','nl':'nl-NL'}; return map[code] ?? code; }
  Future<String?> _deviceOrStoredLocale() async { try { return _prefs?.getString('pref:locale'); } catch (_){ return null; } }
}
