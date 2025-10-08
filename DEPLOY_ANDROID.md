## Android / Google Play Deployment Guide

Dieser Leitfaden beschreibt die Schritte, die du (manuell) für einen Play Store Release deiner App durchführen musst. Der Code ist vorbereitet; einzelne Pflichtangaben & Assets musst du ergänzen.

### 1. App-ID & Package Name
Aktuell: `com.mindoroevolution.reporeader` (in `android/app/build.gradle.kts` und `AndroidManifest.xml`).
Änderung (falls nötig):
1. In `defaultConfig { applicationId = "..." }` anpassen.
2. Java/Kotlin MainActivity-Package (falls existierend) synchron halten.
3. Neu bauen.

### 2. Signierung (Erforderlich für Upload)
Erstelle einen keystore (falls noch nicht):
```bash
keytool -genkey -v -keystore reporeader-release.keystore -alias reporeader -keyalg RSA -keysize 2048 -validity 10000
```
Lege `android/key.properties` an:
```
storeFile=../reporeader-release.keystore
storePassword=DEIN_STORE_PASS
keyAlias=reporeader
keyPassword=DEIN_KEY_PASS
```
Lege die Keystore-Datei NICHT ins Repo (Git ignore!).

### 3. Versionierung
Passe Version vor jedem Release an (Root `pubspec.yaml`):
```
version: 1.0.0+1   # <versionName>+<versionCode>
```
Nur `versionCode` (hinter `+`) muss monoton steigen.

### 4. App Bundle (Empfohlen vom Play Store)
```bash
flutter build appbundle --release
```
Ergebnis: `build/app/outputs/bundle/release/app-release.aab`

Du kannst zusätzlich weiterhin ein APK bauen für interne Tests:
```bash
flutter build apk --release
```

### 5. Play Console Upload
1. Google Play Console → Neue App anlegen (Titel, Standardsprache, App-Typ, kostenlos/kostenpflichtig).
2. App Bundle (`.aab`) hochladen unter „Produktion“ (oder interner Test).
3. Release-Notizen (Changelog) hinzufügen.
4. Richtlinien-Checks ausfüllen (Inhalte, Datenschutz, Daten-Erfassung).

### 6. Store Listing Assets
| Asset | Pflicht | Empfehlung |
|-------|---------|------------|
| App Icon | Ja | Verwende existierendes adaptive icon |
| Feature Graphic (1024x500) | Ja | Branding / Screenshot Collage |
| Screenshots (Phone 6.5", 5.5") | Ja | Haupt-Screens (README Ansicht, Suche, Datei Viewer, TTS Dialog) |
| Tablet Screenshots | Optional | Für bessere Auffindbarkeit |
| Kurzbeschreibung | Ja | 80 Zeichen Fokus Value Proposition |
| Vollständige Beschreibung | Ja | Copy aus README komprimiert (Features + Offline + Suche + TTS) |

### 7. Datenschutz / Berechtigungen
Aktuell verwendete Permissions:
| Permission | Grund |
|------------|-------|
| `INTERNET` | GitHub API / Laden von Assets |

Keine Standort‑, Kamera‑, Kontakt‑ oder Speicher-Permissions → einfacher Review.

Datenschutz-Erklärung: Erstelle eine kurze Seite (z.B. GitHub Pages / README Abschnitt) mit:
* Welche Daten verarbeitet werden (nur Repo-Inhalte + optionale Token lokal gespeichert)
* Keine Telemetrie / Tracking
* Token bleibt lokal (SharedPreferences) – Hinweis auf manuelles Entfernen

### 8. Security & Token Umgang (Play Review Hinweise)
* Erkläre im Listing / Privacy Policy: Nutzer kann optional einen Personal Access Token hinterlegen (nur read scope).
* Keine Übertragung an Drittserver.
* Empfehlung: Fine-grained Token mit nur `Contents: Read`.

### 9. Performance / Größe
Aktuelle Release APK Größe ~53 MB (universal). Optimieren:
| Maßnahme | Kommando / Änderung |
|----------|---------------------|
| Split APKs nach ABI | `flutter build apk --release --split-per-abi` |
| Code Shrinking | In `build.gradle.kts` in `release { isMinifyEnabled = true; shrinkResources = true }` + Proguard Rules pflegen |
| Entfernen ungenutzter Fonts | Keine zusätzlichen Fonts aktuell – ok |
| Obfuscation (Dart) | `--obfuscate --split-debug-info=build/debug_info` (nur wenn nötig) |

### 10. QA Checkliste vor Upload
| Punkt | Status (☐/✔) |
|-------|--------------|
| App öffnet Setup & kann Repo laden | ☐ |
| Suche liefert Ergebnisse | ☐ |
| Offline Snapshot funktioniert (falls genutzt) | ☐ |
| TTS startet ohne Sprache erneut wählen zu müssen | ☐ |
| Favoriten / Änderungen persistieren nach Neustart | ☐ |
| Dark/Light Umschaltung | ☐ |
| Kein Crash in Logs (adb logcat) | ☐ |
| Version bump erfolgt | ☐ |

### 11. Release Notes Vorlage
```
Neu:
• Integrierte Text‑to‑Speech Vorlese-Funktion (Absatz- & Satz-Modus)
• Absatz-Vorschau & Start-Slider
• Offline Snapshot Mode (Beta)

Verbesserungen:
• Markdown Preprocessing stabilisiert
• Navigationsrauschen entfernt (Footer Links etc.)

Fixes:
• Diverse Rendering/Spacing Regressionen behoben
```

### 12. Nach dem ersten Release
| Thema | Aktion |
|-------|--------|
| ANR / Crash Rate | Play Console überwachen |
| User Feedback | README / Issues sammeln |
| Performance | ggf. Chunking / Suche profilieren |
| Updates | VersionCode hoch + Changelog aktualisieren |

### 13. Interne / Geschlossene Tests
Nutze interne Test-Track vor Produktion für schnelle Verteilung:
```bash
flutter build appbundle --release
```
→ In „Interner Test“ hochladen, Tester per E-Mail hinzufügen.

---
Fragen oder Automatisierung (Fastlane, CI Pipeline) gewünscht? Sag Bescheid, dann erstelle ich eine `fastlane/` Vorlage.