import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

/// PrivateAuthService
/// ==================
/// Verwaltet Tokens für private Repositories.
/// Unterstützt zwei Modi:
///  * Manuell eingetragenes PAT (Personal Access Token)
///  * GitHub Device Authorization Flow (ohne client secret)
///
/// Sicherheit: Token wird nur verschlüsselt über `flutter_secure_storage` abgelegt.
/// Key Prefix: `sec:token`
class PrivateAuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'sec:token';

  /// Lädt gespeichertes Token (oder null wenn keins).
  static Future<String?> loadToken() async {
    try { return await _storage.read(key: _tokenKey); } catch (_) { return null; }
  }

  /// Speichert / ersetzt Token.
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token.trim());
  }

  /// Löscht Token.
  static Future<void> clearToken() async { await _storage.delete(key: _tokenKey); }

  /// Startet den GitHub Device Flow. Liefert (user_code, verification_uri, interval, device_code).
  /// Der Nutzer gibt den Code unter der URL ein; anschließend `pollForDeviceToken` aufrufen.
  static Future<(String userCode, String verificationUri, int interval, String deviceCode)> startDeviceFlow({List<String> scopes = const ['repo','read:org']}) async {
    if (AppConfig.githubClientId.isEmpty) {
      throw Exception('Kein GitHub Client Id gesetzt (GITHUB_CLIENT_ID).');
    }
    final res = await http.post(
      Uri.parse('https://github.com/login/device/code'),
      headers: {'Accept':'application/json'},
      body: {
        'client_id': AppConfig.githubClientId,
        'scope': scopes.join(' '),
      },
    );
    if (res.statusCode != 200) throw Exception('Device Flow Start HTTP ${res.statusCode}');
    final data = json.decode(res.body) as Map<String,dynamic>;
    return (
      data['user_code'] as String,
      data['verification_uri'] as String? ?? data['verification_uri_complete'] as String? ?? 'https://github.com/login/device',
      (data['interval'] as num?)?.toInt() ?? 5,
      data['device_code'] as String,
    );
  }

  /// Pollt nach erfolgreicher Benutzer-Autorisierung. Liefert Access Token.
  static Future<String> pollForDeviceToken(String deviceCode, int intervalSeconds) async {
    while (true) {
      await Future.delayed(Duration(seconds: intervalSeconds));
      final res = await http.post(
        Uri.parse('https://github.com/login/oauth/access_token'),
        headers: {'Accept':'application/json'},
        body: {
          'client_id': AppConfig.githubClientId,
          'device_code': deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        },
      );
      if (res.statusCode != 200) throw Exception('Poll HTTP ${res.statusCode}');
      final data = json.decode(res.body) as Map<String,dynamic>;
      if (data['error'] == 'authorization_pending') {
        continue; // noch warten
      }
      if (data['error'] == 'slow_down') {
        intervalSeconds += 5;
        continue;
      }
      if (data['error'] != null) {
        throw Exception('Device Flow Fehler: ${data['error']}');
      }
      final token = data['access_token'] as String?;
      if (token == null || token.isEmpty) throw Exception('Kein access_token bekommen');
      return token;
    }
  }
}
