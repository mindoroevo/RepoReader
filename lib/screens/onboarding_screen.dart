import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  Future<void> _markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pref:onboardingSeen', true);
    } catch (_) {}
  }

  void _next() {
    if (_index < 4) {
      _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _done();
    }
  }

  Future<void> _done() async {
    await _markSeen();
    if (!mounted) return;
    Navigator.of(context).pop('done');
  }

  Future<void> _skip() async {
    await _markSeen();
    if (!mounted) return;
    Navigator.of(context).pop('done');
  }

  Future<void> _configureNow() async {
    await _markSeen();
    if (!mounted) return;
    Navigator.of(context).pop('setup');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme;
    final pages = <Widget>[
      _OnbPage(
        icon: Icons.menu_book,
        title: l.onbWelcomeTitle,
        body: l.onbWelcomeBody,
      ),
      _OnbPage(
        icon: Icons.link,
        title: l.onbSetupTitle,
        body: l.onbSetupBody,
        extra: FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          onPressed: _configureNow,
          label: Text(l.configureNow),
        ),
      ),
      _OnbPage(
        icon: Icons.article,
        title: l.onbReadTitle,
        body: l.onbReadBody,
      ),
      _OnbPage(
        icon: Icons.search,
        title: l.onbSearchTitle,
        body: l.onbSearchBody,
      ),
      _OnbPage(
        icon: Icons.star_border,
        title: l.onbExtrasTitle,
        body: l.onbExtrasBody,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(onPressed: _skip, child: Text(l.onbSkip)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pages.length, (i) {
                      final active = i == _index;
                      return Container(
                        width: active ? 14 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: active ? color.primary : color.outlineVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _skip,
                        child: Text(l.onbSkip),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _next,
                        child: Text(_index == pages.length - 1 ? l.onbDone : l.onbNext),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnbPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? extra;
  const _OnbPage({required this.icon, required this.title, required this.body, this.extra});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.primaryContainer.withValues(alpha: .5),
                    border: Border.all(color: color.outlineVariant.withValues(alpha: .5)),
                  ),
                  child: Icon(icon, size: 44, color: color.primary),
                ),
              ),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: .2)),
              const SizedBox(height: 10),
              Text(body, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant)),
              if (extra != null) ...[
                const SizedBox(height: 18),
                Align(child: extra!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

