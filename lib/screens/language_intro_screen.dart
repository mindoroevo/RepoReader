import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../localization_controller.dart';
import 'home_shell.dart';

class LanguageIntroScreen extends StatefulWidget {
  const LanguageIntroScreen({super.key});
  @override
  State<LanguageIntroScreen> createState() => _LanguageIntroScreenState();
}

class _LanguageIntroScreenState extends State<LanguageIntroScreen> {
  Locale? _selected;

  final Map<String, String> _flagByLang = const {
    'en': '🇺🇸',
    'de': '🇩🇪',
    'fr': '🇫🇷',
    'es': '🇪🇸',
    'it': '🇮🇹',
    'pt': '🇵🇹',
    'ru': '🇷🇺',
    'ja': '🇯🇵',
    'zh': '🇨🇳',
    'ko': '🇰🇷',
    'nl': '🇳🇱',
  };

  String _nameFor(Locale locale){
    switch(locale.languageCode){
      case 'en': return 'English';
      case 'de': return 'Deutsch';
      case 'fr': return 'Français';
      case 'es': return 'Español';
      case 'it': return 'Italiano';
      case 'pt': return 'Português';
      case 'ru': return 'Русский';
      case 'ja': return '日本語';
      case 'zh': return '中文';
      case 'ko': return '한국어';
      case 'nl': return 'Nederlands';
      default: return locale.languageCode.toUpperCase();
    }
  }

  Future<void> _apply() async {
    if (_selected == null) return;
    final controller = LocalizationProvider.of(context);
    await controller.setLocale(_selected!);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref:localeSelected', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final langs = LocalizationController.supportedLocales;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Choose Your Language', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Bitte Sprache auswählen • Please select your language',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 320,
                    child: LayoutBuilder(builder: (ctx, cons) {
                      final n = langs.length;
                      final center = Offset(cons.maxWidth/2, cons.maxHeight/2);
                      final iconSize = 56.0;
                      final r = math.min(cons.maxWidth, cons.maxHeight) * 0.38;
                      final children = <Widget>[];
                      // Center preview (selected or default)
                      final centerFlag = _flagByLang[_selected?.languageCode ?? 'en'] ?? '🇺🇸';
                      children.add(Positioned(
                        left: center.dx - 36,
                        top: center.dy - 36,
                        child: _FlagCircle(flag: centerFlag, size: 72, selected: true, onTap: (){}),
                      ));
                      for (var i=0;i<n;i++){
                        final angle = (2*math.pi*i)/n - math.pi/2; // start top
                        final x = center.dx + r*math.cos(angle) - iconSize/2;
                        final y = center.dy + r*math.sin(angle) - iconSize/2;
                        final loc = langs[i];
                        final flag = _flagByLang[loc.languageCode] ?? '🏳️';
                        final isSel = _selected?.languageCode == loc.languageCode;
                        children.add(Positioned(
                          left: x,
                          top: y,
                          child: _FlagCircle(
                            flag: flag,
                            size: iconSize,
                            selected: isSel,
                            onTap: () => setState(() => _selected = loc),
                          ),
                        ));
                      }
                      return Stack(children: children);
                    }),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () { setState(()=> _selected = const Locale('en')); _apply(); },
                        child: const Text('English (default)'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.check),
                        onPressed: _selected == null ? null : _apply,
                        label: const Text('Continue'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlagCircle extends StatelessWidget {
  final String flag;
  final double size;
  final bool selected;
  final VoidCallback onTap;
  const _FlagCircle({required this.flag, required this.size, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color.primaryContainer : color.surfaceContainerHighest.withValues(alpha: .6),
          border: Border.all(color: selected ? color.primary : color.outlineVariant, width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: color.primary.withOpacity(.25), blurRadius: 10)] : null,
        ),
        alignment: Alignment.center,
        child: Text(flag, style: TextStyle(fontSize: size*0.45)),
      ),
    );
  }
}
