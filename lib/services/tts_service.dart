import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vorlese-Modi
enum TtsMode { words, sentences, blocks }

/// Statusobjekt für UI Binding
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

/// Erweiterter TTS Service mit chunkbasiertem Streaming & Persistenz.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();
  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<TtsStatus> status = ValueNotifier(
    const TtsStatus(playing: false, paused: false, index: 0, total: 0, mode: TtsMode.sentences, rate: 0.5, pitch: 1.0),
  );
  // Aktuell gesprochenes Wort (falls Engine Progress liefert)
  final ValueNotifier<String?> currentWord = ValueNotifier(null);
  // Aktueller Chunk Text für UI Overlay
  final ValueNotifier<String?> currentChunk = ValueNotifier(null);
  // Gesamte Wortliste des Quelltextes für Offset-Start
  List<String> _allWords = [];
  int _startWordOffset = 0;

  bool _initialized = false;
  List<String> _chunks = [];
  int _current = 0;
  bool _stopRequested = false;
  SharedPreferences? _prefs;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    // Einstellungen laden
    final rate = _prefs!.getDouble('tts:rate') ?? 0.5;
    final pitch = _prefs!.getDouble('tts:pitch') ?? 1.0;
    final modeIndex = _prefs!.getInt('tts:mode') ?? 1; // default sentences
    status.value = status.value.copyWith(rate: rate, pitch: pitch, mode: TtsMode.values[modeIndex]);

    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    // Gespeicherte Sprache + Voice wiederherstellen
    final storedLang = _prefs!.getString('tts:lang');
    if (storedLang != null) {
      try { await _tts.setLanguage(storedLang); status.value = status.value.copyWith(language: storedLang); } catch (_) {}
    }
    final storedVoice = _prefs!.getString('tts:voice');
    if (storedVoice != null && storedLang != null) {
      try { await _tts.setVoice({'name': storedVoice, 'locale': storedLang}); status.value = status.value.copyWith(voiceId: storedVoice); } catch (_) {}
    }
    // Handler
    _tts.setCompletionHandler(_handleCompletion);
    _tts.setCancelHandler(_handleCancel);
    _tts.setPauseHandler(() { status.value = status.value.copyWith(paused: true); });
    _tts.setContinueHandler(() { status.value = status.value.copyWith(paused: false); });
    // Fortschritt (Android/iOS/Web unterschiedlich – Word kann leer sein)
    try {
      _tts.setProgressHandler((text, start, end, word) {
        if (word != null && word.trim().isNotEmpty) {
          currentWord.value = word;
        }
      });
    } catch (_) {}
    // Verhindert Überschneidungen (Engine wartet bis speak fertig)
    try { await _tts.awaitSpeakCompletion(true); } catch (_) {}
    _initialized = true;
  }

  Future<List<dynamic>> availableLanguages() async { await _ensureInit(); return (await _tts.getLanguages) ?? []; }
  Future<List<dynamic>> availableVoices() async { await _ensureInit(); try { return await _tts.getVoices ?? []; } catch (_) { return []; } }

  Future<void> configure({double? rate, double? pitch, String? language, String? voiceId, TtsMode? mode}) async {
    await _ensureInit();
    if (rate != null) { await _tts.setSpeechRate(rate); status.value = status.value.copyWith(rate: rate); _prefs?.setDouble('tts:rate', rate); }
    if (pitch != null) { await _tts.setPitch(pitch); status.value = status.value.copyWith(pitch: pitch); _prefs?.setDouble('tts:pitch', pitch); }
    if (mode != null) { status.value = status.value.copyWith(mode: mode); _prefs?.setInt('tts:mode', mode.index); }
    if (language != null) { try { await _tts.setLanguage(language); status.value = status.value.copyWith(language: language); _prefs?.setString('tts:lang', language); } catch (_) {} }
    if (voiceId != null) { 
      final loc = (language ?? status.value.language) ?? '';
      try { await _tts.setVoice({'name': voiceId, 'locale': loc}); status.value = status.value.copyWith(voiceId: voiceId); _prefs?.setString('tts:voice', voiceId); } catch (_) {} 
    }
  }

  Future<void> start(String fullText, {TtsMode? overrideMode, int startWord = 0}) async {
    await _ensureInit();
    await stop();
    final mode = overrideMode ?? status.value.mode;
    // Automatische Sprach-Initialisierung falls keine gesetzt
    if (status.value.language == null) {
      final mapped = _mapLocaleToPreferred(await _deviceOrStoredLocale());
      if (mapped != null) {
        // Check availability
        final langs = await availableLanguages();
        if (langs.contains(mapped)) {
          try { await _tts.setLanguage(mapped); status.value = status.value.copyWith(language: mapped); } catch (_) {}
        }
      }
    }
    final cleanedFull = _cleanText(fullText);
    _allWords = cleanedFull.split(RegExp(r'\\s+')).where((w)=>w.isNotEmpty).toList();
    _startWordOffset = startWord.clamp(0, _allWords.length);

    if (mode == TtsMode.words) {
      // Für Wort-Modus behalten wir exakte Wort-Startposition (präziser Start mitten im Absatz erwünscht)
      final slicedWords = _allWords.skip(_startWordOffset).toList();
      final groupSize = 20;
      final wordChunks = <String>[];
      for (var i = 0; i < slicedWords.length; i += groupSize) {
        wordChunks.add(slicedWords.sublist(i, i + groupSize > slicedWords.length ? slicedWords.length : i + groupSize).join(' '));
      }
      _chunks = wordChunks;
      _current = 0; // progress index
    } else {
      // Für Sätze / Blöcke: vollständige Chunks, dann Chunk ermitteln der das Start-Wort enthält
      _chunks = _buildChunks(cleanedFull, mode);
      int _countWords(String s) => s.split(RegExp(r'\\s+')).where((w)=>w.isNotEmpty).length;
      int cumulative = 0; _current = 0;
      for (var i=0;i<_chunks.length;i++) {
        final wc = _countWords(_chunks[i]);
        if (_startWordOffset < cumulative + wc) { _current = i; break; }
        cumulative += wc;
      }
      if (_startWordOffset > 0 && _current == 0 && _chunks.length > 1) {
        // Fallback: falls Mapping fehlgeschlagen (z.B. Wortanzahl-Differenz), versuche grob zu schätzen
        final approxRatio = _startWordOffset / (_allWords.isEmpty ? 1 : _allWords.length);
        _current = (approxRatio * (_chunks.length - 1)).round().clamp(0, _chunks.length-1);
      }
    }
    // Doppelte direkt hintereinander entfernen
    final dedup = <String>[];
    for (final c in _chunks) { if (dedup.isEmpty || dedup.last != c) dedup.add(c); }
    _chunks = dedup.where((c)=>c.trim().isNotEmpty).toList();
    status.value = status.value.copyWith(playing: true, paused: false, index: _current, total: _chunks.length, mode: mode);
    if (_chunks.isEmpty) { status.value = status.value.copyWith(playing: false); return; }
    _speakCurrent();
  }

  List<String> _buildChunks(String text, TtsMode mode) {
    final cleaned = _cleanText(text);
    if (cleaned.trim().isEmpty) return [];
    switch (mode) {
      case TtsMode.words:
        final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        // Gruppiere 20 Wörter pro Chunk für bessere Performance / weniger Unterbrechungen
        final out = <String>[];
        const groupSize = 20;
        for (var i=0; i<words.length; i+=groupSize) { out.add(words.sublist(i, i+groupSize > words.length ? words.length : i+groupSize).join(' ')); }
        return out;
      case TtsMode.sentences:
        final raw = cleaned.split(RegExp(r'(?<=[.!?])\s+'));
        final sentences = raw.map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList();
        // Sehr kurze Sätze mit dem nächsten zusammenführen, um ständiges Stop/Start (Knacken) zu reduzieren
        final merged = <String>[];
        final buffer = StringBuffer();
        for (var i=0;i<sentences.length;i++) {
          final s = sentences[i];
            if ((s.length < 25 || !s.contains(' ')) && i < sentences.length-1) {
              buffer.write(s + ' ');
              continue;
            }
          if (buffer.isNotEmpty) {
            buffer.write(s);
            merged.add(buffer.toString().trim());
            buffer.clear();
          } else {
            merged.add(s);
          }
        }
        if (buffer.isNotEmpty) merged.add(buffer.toString().trim());
        return merged;
      case TtsMode.blocks:
        final paras = cleaned.split(RegExp(r'\n{2,}'));
        final chunks = <String>[];
        for (final p in paras) {
          final t = p.trim();
          if (t.isEmpty) continue;
            if (t.length <= 220) { chunks.add(t); } else {
              // Soft wrap auf whitespace
              var rest = t;
              while (rest.length > 220) {
                final cut = rest.lastIndexOf(' ', 200);
                if (cut <= 0) { chunks.add(rest.substring(0,200)); rest = rest.substring(200); } else { chunks.add(rest.substring(0,cut)); rest = rest.substring(cut+1); }
              }
              if (rest.trim().isNotEmpty) chunks.add(rest.trim());
            }
        }
        return chunks;
    }
  }

  String _cleanText(String txt) {
    return txt
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAll(RegExp(r'`[^`]+`'), ' ')
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'\[[^\]]*\]\([^)]*\)'), ' ')
      // HTML / Tags und spitze Klammern
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'^#+ ', multiLine: true), '')
      .replaceAll(RegExp(r'> '), '')
      .replaceAll(RegExp(r'[_*`#>|\-]'), ' ')
      // Emojis & Misc Symbols (vereinfachter Bereich)
      .replaceAll(RegExp(r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true), ' ')
      .replaceAll(RegExp(r' {2,}'), ' ')
      .replaceAll(RegExp(r'\n +'), '\n')
      .trim();
  }

  void _speakCurrent() {
    if (_current >= _chunks.length) { status.value = status.value.copyWith(playing: false, paused: false); return; }
    final chunk = _chunks[_current];
    currentChunk.value = chunk;
    currentWord.value = null; // reset
    // Kleine Verzögerung zwischen Chunks reduziert harte Übergänge / Knacken bei einigen Engines
    Future.delayed(const Duration(milliseconds: 60), () { _tts.speak(chunk); });
  }

  void _handleCompletion() {
    if (_stopRequested) return; // stop() triggered
    _current += 1;
    status.value = status.value.copyWith(index: _current);
    if (_current < _chunks.length) {
      _speakCurrent();
    } else {
      status.value = status.value.copyWith(playing: false, paused: false);
    }
  }

  void _handleCancel() {
    if (_stopRequested) return; // treat as pause maybe
  }

  Future<void> pause() async {
    if (!status.value.playing || status.value.paused) return;
    try { await _tts.pause(); status.value = status.value.copyWith(paused: true); } catch (_) {
      // Fallback: nicht unterstützt -> stop + merken Index (vereinfachte Lösung)
      await stop();
    }
  }

  Future<void> resume() async {
    if (!status.value.playing || !status.value.paused) return;
    // Viele Plattformen unterstützen resume() nicht -> wir starten aktuellen Chunk neu.
    status.value = status.value.copyWith(paused: false, playing: true);
    _speakCurrent();
  }

  Future<void> stop() async {
    _stopRequested = true;
    await _tts.stop();
    _current = 0; _chunks = [];
    status.value = status.value.copyWith(playing: false, paused: false, index: 0, total: 0);
    _stopRequested = false;
    currentWord.value = null; currentChunk.value = null;
  }

  double get rate => status.value.rate;
  double get pitch => status.value.pitch;
  String? get language => status.value.language;
  String? get voiceId => status.value.voiceId;

  // Locale Mapping (einfach): de->de-DE, en->en-US, es->es-ES, fr->fr-FR, it->it-IT, pt->pt-PT, ru->ru-RU, ja->ja-JP, zh->zh-CN, ko->ko-KR, nl->nl-NL
  String? _mapLocaleToPreferred(String? code) {
    if (code == null) return null;
    const map = {
      'de':'de-DE','en':'en-US','es':'es-ES','fr':'fr-FR','it':'it-IT','pt':'pt-PT','ru':'ru-RU','ja':'ja-JP','zh':'zh-CN','ko':'ko-KR','nl':'nl-NL'
    };
    return map[code] ?? code;
  }

  Future<String?> _deviceOrStoredLocale() async {
    // Stored locale in prefs (reusing pref key from LocalizationController)
    try { return _prefs?.getString('pref:locale'); } catch (_) { return null; }
  }
}
