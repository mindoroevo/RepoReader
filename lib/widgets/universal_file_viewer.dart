import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/universal_file_reader.dart';
import '../utils/naming.dart';

/// UniversalFileViewer
/// ===================
/// Universeller Datei-Viewer für alle unterstützten Dateitypen (Text/Binär) zur
/// Einbettung in Listen, Dialoge oder Detailseiten.
/// 
/// Unterstützt (aktuell):
/// * Textdateien (Plain Anzeige, Code Highlighting Placeholder – noch nicht implementiert)
/// * Bilder (Memory → Image)
/// * PDFs (Platzhalter Hinweis + Download)
/// * Generische Binärdateien (Hex-Vorschau + Base64 Kopierfunktion)
///
/// TODO / Roadmap:
/// * Syntax Highlighting
/// * Streaming großer Dateien
/// * Interne PDF Preview (z.B. via WebView / wasm)
class UniversalFileViewer extends StatelessWidget {
  final FileReadResult fileResult;
  final String fileName;
  final String filePath;

  const UniversalFileViewer({
    super.key,
    required this.fileResult,
    required this.fileName,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
  color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getFileIcon(),
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${fileResult.mimeType} • ${_formatFileSize(context)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (fileResult.isText)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => _copyToClipboard(context),
              tooltip: AppLocalizations.of(context)!.copyToClipboard,
            ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openInNewWindow(context),
            tooltip: AppLocalizations.of(context)!.openInNewWindow,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (fileResult.isText) {
      return _buildTextContent(context);
    } else {
      return _buildBinaryContent(context);
    }
  }

  Widget _buildTextContent(BuildContext context) {
    final content = fileResult.asText;
  // final language = _getLanguageFromExtension(); // (derzeit ungenutzt – zukünftiges Syntax Highlighting)
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.length > 10000)
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.largeFileWarning(content.length.toString()),
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: SelectableText(
                content,
                style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildFileStats(context, content),
        ],
      ),
    );
  }

  Widget _buildBinaryContent(BuildContext context) {
    final mimeType = fileResult.mimeType;
    
    if (mimeType.startsWith('image/')) {
      return _buildImageContent(context);
    } else if (mimeType == 'application/pdf') {
      return _buildPdfContent(context);
    } else {
      return _buildGenericBinaryContent(context);
    }
  }

  Widget _buildImageContent(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            child: Image.memory(
              fileResult.asBytes,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(AppLocalizations.of(context)!.imageCouldNotBeLoaded),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.base64Data(fileResult.asBytes.length.toString()),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildPdfContent(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.picture_as_pdf, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.pdfDocument),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.pdfPreviewNotSupported,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _downloadFile(context),
            icon: const Icon(Icons.download),
            label: Text(AppLocalizations.of(context)!.downloadPdf),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericBinaryContent(BuildContext context) {
    final bytes = fileResult.asBytes;
    final preview = bytes.take(256).toList(); // Erste 256 Bytes für Hex-Preview
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.binaryFileHexPreview,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: SingleChildScrollView(
                    child: Text(
                      _formatHexDump(preview),
                      style: const TextStyle(
                        fontFamily: 'Courier New',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _downloadFile(context),
                icon: const Icon(Icons.download),
                label: Text(AppLocalizations.of(context)!.downloadFile),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _copyBase64(context),
                icon: const Icon(Icons.code),
                label: Text(AppLocalizations.of(context)!.copyAsBase64),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileStats(BuildContext context, String content) {
    final lines = content.split('\n').length;
    final words = content.split(RegExp(r'\s+')).length;
    final chars = content.length;
    
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(context, AppLocalizations.of(context)!.lines, lines.toString()),
          _statItem(context, AppLocalizations.of(context)!.words, words.toString()),
          _statItem(context, AppLocalizations.of(context)!.characters, chars.toString()),
        ],
      ),
    );
  }

  Widget _statItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  IconData _getFileIcon() {
    final ext = fileName.split('.').last.toLowerCase();
    
    switch (ext) {
      case 'md':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'dart':
        return Icons.code;
      case 'js':
      case 'ts':
        return Icons.javascript;
      case 'py':
        return Icons.code;
      case 'json':
        return Icons.data_object;
      case 'yaml':
      case 'yml':
        return Icons.settings;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return Icons.image;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return fileResult.isText ? Icons.text_snippet : Icons.insert_drive_file;
    }
  }

  // _getLanguageFromExtension entfernt (unused; zukünftige Syntax-Highlighting Erweiterung)

  String _formatFileSize(BuildContext context) {
    if (!fileResult.isText) {
      final bytes = fileResult.asBytes.length;
      return _formatBytes(bytes);
    } else {
      final chars = fileResult.asText.length;
      return '$chars ${AppLocalizations.of(context)!.charactersSuffix}';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatHexDump(List<int> bytes) {
    final buffer = StringBuffer();
    for (int i = 0; i < bytes.length; i += 16) {
      // Offset
      buffer.write(i.toRadixString(16).padLeft(8, '0'));
      buffer.write('  ');
      
      // Hex bytes
      for (int j = 0; j < 16; j++) {
        if (i + j < bytes.length) {
          buffer.write(bytes[i + j].toRadixString(16).padLeft(2, '0'));
          buffer.write(' ');
        } else {
          buffer.write('   ');
        }
        if (j == 7) buffer.write(' ');
      }
      
      // ASCII representation
      buffer.write(' |');
      for (int j = 0; j < 16 && i + j < bytes.length; j++) {
        final byte = bytes[i + j];
        if (byte >= 32 && byte <= 126) {
          buffer.writeCharCode(byte);
        } else {
          buffer.write('.');
        }
      }
      buffer.write('|\n');
    }
    return buffer.toString();
  }

  void _copyToClipboard(BuildContext context) {
    if (fileResult.isText) {
      Clipboard.setData(ClipboardData(text: fileResult.asText));
      ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(AppLocalizations.of(context)!.contentCopied)),
      );
    }
  }

  void _copyBase64(BuildContext context) {
    if (!fileResult.isText) {
      Clipboard.setData(ClipboardData(text: fileResult.asBase64));
      ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(AppLocalizations.of(context)!.base64Copied)),
      );
    }
  }

  void _downloadFile(BuildContext context) {
    // In einer echten App würde hier ein Download ausgelöst
    // Für jetzt zeigen wir nur eine Info
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
  title: Text(AppLocalizations.of(context)!.download),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppLocalizations.of(context)!.file}: $fileName'),
            Text('${AppLocalizations.of(context)!.size}: ${_formatFileSize(context)}'),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.downloadInfo),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  void _openInNewWindow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(prettifyTitle(fileName)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: UniversalFileViewer(
              fileResult: fileResult,
              fileName: fileName,
              filePath: filePath,
            ),
          ),
        ),
      ),
    );
  }
}