import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../services/offline_snapshot_service.dart';

/// MarkdownView
/// ============
/// Darstellungskomponente für (bereits vorprozessierten) Markdown Text.
///
/// Features:
/// * Selektierbarer Text
/// * Externe Links → System Browser
/// * Interne Links → Callback (`onInternalLink`)
/// * Angepasstes Styling (Headings, Quotes, Codeblöcke, Tabellen)
/// * Custom Image Builder mit Fehleranzeige
class MarkdownView extends StatelessWidget {
  final String content;
  final void Function(String internalPath)? onInternalLink;
  final ScrollController? controller;
  const MarkdownView({super.key, required this.content, this.onInternalLink, this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = MediaQuery.of(context).textScaler;
    final base = MarkdownStyleSheet.fromTheme(theme).copyWith(
      textScaler: scale,
      h1: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.15),
      h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.18),
      h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      p: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
      listBullet: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      blockquoteDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha((255 * .5).round()),
        border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4)),
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha((255 * .6).round()),
        borderRadius: BorderRadius.circular(10),
      ),
      code: TextStyle(
        fontSize: 13 * (MediaQuery.of(context).textScaler.scale(1.0)),
        fontFamily: 'monospace',
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha((255 * .35).round()),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha((255 * .6).round()),
            width: 2,
          ),
        ),
      ),
      tableBorder: TableBorder.all(
        color: theme.dividerColor.withAlpha((255 * .4).round()),
        width: 1,
      ),
      blockSpacing: 16,
      listBulletPadding: const EdgeInsets.only(right: 10),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      codeblockPadding: const EdgeInsets.all(14),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );

    return Markdown(
      data: content,
      selectable: true,
      controller: controller,
      onTapLink: (text, href, title) async {
        if (href == null) return;
        if (href.startsWith('http://') || href.startsWith('https://')) {
          final uri = Uri.parse(href);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } else {
          onInternalLink?.call(href.replaceAll(RegExp(r'^/'), ''));
        }
      },
      softLineBreak: true,
      styleSheet: base,
      // ignore: deprecated_member_use
      imageBuilder: (uri, title, alt) => FutureBuilder<bool>(
        future: OfflineSnapshotService.isOfflineEnabled(),
        builder: (context, snap) {
          final offline = snap.data == true;
          Widget error() => Container(
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.errorContainer.withAlpha((255 * .9).round()),
            child: const Icon(Icons.broken_image),
          );
          if (offline && !uri.toString().startsWith('http')) {
            return FutureBuilder<String>(
              future: () async {
                try {
                  if (!await OfflineSnapshotService.hasSnapshot()) { throw Exception('Kein Snapshot'); }
                  final rel = uri.toString().replaceAll(RegExp(r'^/'), '');
                  final root = await OfflineSnapshotService.currentSnapshotRootPath();
                  final f = File('$root/files/$rel');
                  if (await f.exists()) return f.path; throw Exception('Nicht gefunden');
                } catch (_) { rethrow; }
              }(),
              builder: (context, fileSnap) {
                if (fileSnap.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 40, width: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                }
                if (fileSnap.hasError || fileSnap.data == null) return error();
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(fileSnap.data!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => error()),
                );
              },
            );
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              uri.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => error(),
            ),
          );
        },
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
    );
  }
}
