# Android Release Signierung & Upload (Play Store)

Diese Anleitung zeigt, wie du aus deinem aktuellen Projekt (Stand: Flutter + Gradle Kotlin DSL) ein korrekt signiertes Release App Bundle (AAB) erstellst.

## 1. Überblick
Für die Veröffentlichung im Play Store MUSS das AAB mit deinem eigenen Release Keystore signiert sein. Derzeit nutzt dein `build.gradle.kts` einen Fallback auf das Debug Keystore, falls keine `android/key.properties` existiert – das führt zu der Fehlermeldung im Play Store ("im Debug-Modus signiert").

## 2. Keystore erstellen
Im Projektwurzelverzeichnis (oder außerhalb, z.B. in einem sicheren Ordner) ausführen:

### macOS / Linux
```bash
keytool -genkeypair -v \
    -keystore reporeader-release.keystore \
    -alias reporeader \
    -keyalg RSA -keysize 2048 -validity 10000
```

### Windows (PowerShell)
In PowerShell funktionieren die Backslashes als Zeilenumbruch NICHT. Entweder alles in einer Zeile oder PowerShell-Backticks (`) verwenden. Am einfachsten: eine Zeile.

```powershell
keytool -genkeypair -v -keystore android\keystore\reporeader-release.keystore -alias reporeader -keyalg RSA -keysize 2048 -validity 10000
```

Wenn `keytool` nicht gefunden wird:
```powershell
where keytool
```
Falls leer: JDK installieren oder den Pfad zum JDK `bin` Ordner in `PATH` aufnehmen (z.B. `"C:\Program Files\Android\Android Studio\jbr\bin"`). Dann PowerShell neu öffnen.

Optional kannst du den Distinguished Name direkt setzen (spart interaktive Eingaben):
```powershell
keytool -genkeypair -v -keystore android\keystore\reporeader-release.keystore -alias reporeader -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Mindoro Evolution, OU=Apps, O=Mindoro Evolution, L=Düsseldorf, ST=NRW, C=DE"
```
Eingaben:
- Keystore Passwort
- Vor- und Nachname / Orga → Fülle sinnvoll aus (oder kann generisch sein)
- "What is your first and last name?" → z.B. Mindoro Evolution
- Am Ende: "Enter key password" → kann gleich dem Keystore Passwort sein

Verschiebe / Speichere die Datei unter: `android/keystore/reporeader-release.keystore` (Ordner ggf. anlegen). **Nicht committen!**

## 3. `key.properties` anlegen
Kopiere `android/key.properties.example` nach `android/key.properties` und trage Passwörter ein:
```
storeFile=keystore/reporeader-release.keystore
storePassword=DEIN_STORE_PASSWORT
keyAlias=reporeader
keyPassword=DEIN_KEY_PASSWORT
```
Sichere die Passwörter (Passwortmanager). Datei bleibt lokal (wird durch `.gitignore` ausgeschlossen).

## 4. Verifikation der Gradle Konfiguration
In `android/app/build.gradle.kts` existiert bereits:
```kotlin
val keystorePropertiesFile = rootProject.file("android/key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
...
signingConfigs {
    create("release") {
        if (keystorePropertiesFile.exists()) {
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        } else {
            // Fallback debug (NICHT für Store)
        }
    }
}
```
Damit wird bei vorhandener Datei automatisch korrekt signiert.

## 5. Release Build erzeugen
Im Projektwurzelverzeichnis (Windows PowerShell Beispiel):
```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```
Das signierte AAB liegt danach unter: `build\app\outputs\bundle\release\app-release.aab`

## 6. Upload Play Console
1. In der Play Console: "Neue Version" unter Produktion (oder Test Track) anlegen
2. AAB hochladen (jetzt ohne Debug Fehlermeldung)
3. Versionshinweise eintragen
4. Prüfen: App-Signatur aktivieren (Google Play App Signing – empfohlen)

## 7. Google Play App Signing (Empfohlen)
Bei erstmaliger Veröffentlichung bietet Google an, den Upload Key und Signing Key zu verwalten.
- Du lädst dein signiertes AAB hoch
- Google extrahiert den Signatur-Key für zukünftige Optimierungen
Vorteil: Key Recovery bei Verlust möglich.

## 8. Versionierung
Passe vor dem Build die Version in `pubspec.yaml` an:
```
version: 0.1.0+1
```
- Linker Teil (0.1.0) = versionName
- Rechter Teil (+1) = versionCode → muss bei jedem Store Upload erhöht werden

## 9. Häufige Fehler
| Meldung | Ursache | Lösung |
|---------|--------|--------|
| "Debug signed" | Fallback verwendet | `key.properties` korrekt anlegen |
| "Version Code already exists" | versionCode nicht erhöht | In `pubspec.yaml` +1 |
| "Missing upload certificate" | Manuell Signing-Konfiguration fehlerhaft | Keystore Pfad prüfen |
| R8 / Missing classes | ProGuard Shrinking aktiviert ohne Keep Rules | Shrinking vorerst deaktiviert oder Rules anpassen |

## 10. Sicherheitsempfehlungen
- Keystore niemals ins Repo committen
- Backup Keystore + Passwörter verschlüsselt
- Bei Verdacht auf Leak: neuen Keystore generieren & Upload Key Rotation (Google Play Developer Console Anweisungen folgen)

## 11. Optional: Separater Upload Key
Fortgeschritten: Unterschied zwischen Upload Key (zum Hochladen) und App Signing Key (von Google verwaltet). Kann später rotiert werden. Für Start: Standard ausreichend.

## 12. Überprüfung Signatur (Lokal)
APK (falls erstellt) prüfen:
```bash
jarsigner -verify -verbose -certs app-release.apk
```
AAB direkt ist komplexer; alternativ BundleTool nutzen, um APKs zu extrahieren.

## 13. Nächste Schritte nach erfolgreichem Upload
- Store Listing (Beschreibung, Icons, Screenshots, Privacy Policy URL)
- Content Rating Fragebogen ausfüllen
- Datenschutz (Data Safety Section) → angeben: keine Sammlung/Weitergabe persönlicher Daten außer technisch notwendige API Requests
- Interne Testerkonten hinzufügen

## 14. Checkliste Kurz
- [ ] Keystore erstellt
- [ ] `android/key.properties` ausgefüllt
- [ ] Version in `pubspec.yaml` angepasst
- [ ] `flutter build appbundle --release` erfolgreich
- [ ] AAB hochgeladen ohne Debug Fehler
- [ ] Store Listing ausgefüllt

---
*Dokument erstellt: 09.10.2025*
