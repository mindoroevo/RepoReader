# Guide: GitHub Device Flow Login

## Warum Device Flow?
Für private Repositories oder höhere Rate Limits kann ein Access Token nötig sein. Der Device Flow erlaubt eine Anmeldung ohne Eingabe des Passworts in der App und ohne Client Secret.

## Voraussetzungen
- GitHub OAuth App (ohne Secret) bzw. Client ID
- Beim Start oder Build setzen: `--dart-define=GITHUB_CLIENT_ID=<client_id>`

## Ablauf
1. In der App den Device-Flow starten (Setup-Screen).
2. App zeigt `user_code` und `verification_uri`.
3. Verifikationsseite öffnen (WebView oder externer Browser) und Code eingeben.
4. Die App pollt periodisch; nach Erteilung wird das Access Token sicher gespeichert.
5. Token wird im Setup übernommen; Speichern persistiert es für künftige Anfragen.

## Komponenten
- Service: `lib/services/private_auth_service.dart`
  - `startDeviceFlow()` → holt `user_code`, `verification_uri`, `interval`, `device_code`
  - `pollForDeviceToken(deviceCode, interval)` → liefert `access_token`
  - Secure Storage via `flutter_secure_storage`
- WebView-Fallback: `lib/screens/device_login_webview.dart`

## Sicherheit & Scopes
- Empfohlen: Fine-grained Token mit minimalem Read-Scope („Contents: Read“)
- Token bleibt lokal (Secure Storage)
- Regelmäßig rotieren; bei Verlust Gerät/Tokens entfernen

## Fehlerbehandlung
- `authorization_pending`: Weiter warten (automatisch)
- `slow_down`: Intervall wird erhöht (automatisch)
- Sonstige Fehler: Token nicht erzeugt → erneut versuchen

