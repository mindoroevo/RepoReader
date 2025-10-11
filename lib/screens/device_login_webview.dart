import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/private_auth_service.dart';

/// DeviceLoginWebView
/// ------------------
/// Alternative zum Copy/Paste des Codes: startet Device Flow, öffnet GitHub Seite direkt eingebettet
/// und pollt automatisch bis der Token erteilt wurde.
class DeviceLoginWebView extends StatefulWidget {
  const DeviceLoginWebView({super.key});
  @override State<DeviceLoginWebView> createState() => _DeviceLoginWebViewState();
}

class _DeviceLoginWebViewState extends State<DeviceLoginWebView> {
  String? _userCode; String? _verificationUri; String? _deviceCode; int _interval = 5; String? _status; Timer? _pollTimer; bool _done=false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (AppConfig.githubClientId.isEmpty) {
      setState(()=> _status = 'Kein GITHUB_CLIENT_ID gesetzt.');
      return;
    }
    try {
      final (userCode, uri, interval, deviceCode) = await PrivateAuthService.startDeviceFlow();
      setState(() { _userCode = userCode; _verificationUri = uri; _interval = interval; _deviceCode = deviceCode; _status = 'Code wird überwacht...'; });
      _startPolling();
    } catch (e) { setState(()=> _status = 'Fehler: $e'); }
  }

  void _startPolling() {
    // Startet periodisches Polling des Device Codes. Erfolgreicher Abschluss
    // speichert Token sicher und schließt den Dialog automatisch (kleine Delay
    // für UX). Fehler (pending/slow_down) werden intern im Service gehandhabt.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: _interval), (_) async {
      if (_deviceCode == null) return;
      try {
        final token = await PrivateAuthService.pollForDeviceToken(_deviceCode!, _interval);
        await PrivateAuthService.saveToken(token);
        if (mounted) {
          setState(() { _status = 'Token erhalten'; _done = true; });
          Future.delayed(const Duration(milliseconds: 600), () => Navigator.pop(context, true));
        }
      } catch (e) {
        // Nur weiter warten bei pending/slow_down (im Service gehandhabt).
      }
    });
  }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final supportsWebView = !kIsWeb && (
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS
    );

    Widget content() {
      if (_verificationUri == null) {
        return Center(child: Text(_status ?? 'Starte...'));
      }
      final header = Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children:[
          const Icon(Icons.key, size:16),
          const Text('Code: ', style: TextStyle(fontWeight: FontWeight.bold)),
          SelectableText(_userCode ?? '-', style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
          if (!_done) const SizedBox(width:8),
          if (!_done) const CircularProgressIndicator(strokeWidth:2),
        ]),
      );

      if (supportsWebView) {
        return Column(children:[
          if (_userCode != null) header,
          Expanded(child: WebViewWidget(controller: WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..loadRequest(Uri.parse(_verificationUri!)),
          )),
          if (_status != null) Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_status!, style: TextStyle(fontSize:12, color: _done ? Colors.green : null)),
          )
        ]);
      }

      // Fallback: externen Browser nutzen
      return Column(children:[
        if (_userCode != null) header,
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Anmeldeseite im Browser öffnen'),
            onPressed: () => launchUrl(Uri.parse(_verificationUri!), mode: LaunchMode.externalApplication),
          ),
        ),
        if (_status != null) Padding(
          padding: const EdgeInsets.all(8),
          child: Text(_status!, style: TextStyle(fontSize:12, color: _done ? Colors.green : null)),
        )
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('GitHub Anmeldung')),
      body: content(),
    );
  }
}
