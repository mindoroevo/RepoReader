import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:reporeader/services/tts_service.dart';

void main() {
  // Ensure binding is initialized so platform channels (flutter_tts) can be created safely.
  WidgetsFlutterBinding.ensureInitialized();
  final svc = TtsService.instance;

  test('abbreviation should not split sentence', () {
    final input = 'Dies ist ein Test bzgl. der Funktion. Es sollte nicht nach "bzgl." splitten.';
    final parts = svc.debugSplitSentences(input);
    // Expect 2 sentences (the first contains "bzgl.")
    expect(parts.length, greaterThanOrEqualTo(2));
    expect(parts[0].contains('bzgl.'), isTrue);
  });

  test('apply prosody hints marks headings', () {
    final md = '# Überschrift\n\nText nach Überschrift.';
    final out = svc.debugApplyProsodyHints(md);
    expect(out.contains('[HEADING]Überschrift'), isTrue);
  });
}
