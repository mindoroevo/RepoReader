// ============================================================================
// RepoReader
// File: about_screen.dart
// Author: Mindoro Evolution
// Description: About / Credits & Projektinfo.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openMail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'mindoro.evolution@gmail.com',
      queryParameters: const {
        'subject': 'RepoReader Feedback',
      },
    );
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // sicherstellt, dass echter Mail-Client geöffnet wird
      );
      if (!ok) {
        throw Exception('launchUrl returned false');
      }
    } catch (_) {
      // Fallback: Nutzer informieren & Mailadresse in Zwischenablage kopieren
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noMailClientFound)),
      );
      await Clipboard.setData(const ClipboardData(text: 'mindoro.evolution@gmail.com'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutProject)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l10n.appTitle, style: style.headlineSmall),
          const SizedBox(height: 4),
          Text(l10n.appTagline, style: style.bodyMedium),
          const SizedBox(height: 12),
          Text(l10n.author, style: style.titleSmall),
          const SizedBox(height: 4),
          const Text('Mindoro Evolution'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _openMail(context),
            icon: const Icon(Icons.email),
            label: Text(l10n.sendEmail),
          ),
          const SizedBox(height: 24),
          Text(l10n.note, style: style.titleSmall),
          const SizedBox(height: 4),
          Text(l10n.projectNote),
          const SizedBox(height: 16),
          Text(l10n.license, style: style.titleSmall),
          const SizedBox(height: 4),
          Text(l10n.licenseText),
          const SizedBox(height: 16),
          Text(l10n.version, style: style.titleSmall),
          const SizedBox(height: 4),
          // TODO: Optional dynamic version via PackageInfo
          Text(l10n.manualVersion),
        ],
      ),
    );
  }
}
