# Datenschutzerklärung für die App "RepoReader"

*Letzte Aktualisierung: 08.10.2025*

## 1. Verantwortlicher (Art. 4 Nr. 7 DSGVO)
**Name / Firma:** Mindoro Evolution  
**Anschrift:** Jüchener Weg 49, 40547 Düsseldorf  
**E-Mail:** mindoro.evolution@gmail.com  
Ein Datenschutzbeauftragter ist nicht bestellt, da keine gesetzliche Pflicht besteht.

## 2. Kurze Beschreibung der App
RepoReader ist eine plattformübergreifende Read‑Only Anwendung zum Anzeigen, Durchsuchen, Offline‑Speichern ("Offline Snapshot") und Vorlesen (TTS) von Dateien (primär Markdown / Text) aus öffentlichen oder – bei optionaler Authentifizierung – privaten GitHub-Repositories. Es findet keine serverseitige Weiterleitung oder Aggregation der Inhalte durch eigene Backend-Systeme statt; alle Zugriffe erfolgen direkt von deinem Gerät zur GitHub API.

## 3. Verarbeitete Datenkategorien
| Kategorie | Beispiele | Zweck | Lokale Speicherung | Übermittlung an Dritte |
|-----------|-----------|-------|--------------------|------------------------|
| Repository-Inhalte | README, Markdown, Textdateien, Dateistruktur | Anzeige / Navigation / Suche / Offline Snapshot | Optional (Cache / Offline Snapshot) | Abruf direkt von GitHub (öffentliche Repos oder private mit Token) |
| Optionale Zugangstokens (Personal Access Token / Device Flow Token) | Token-String (nur Lese‑Scopes empfohlen) | Erhöhtes Rate Limit, Zugriff private Repos | Lokal (SharedPreferences / ggf. Secure Storage geplant) | Nicht weitergegeben |
| Änderungs-/Cache-Metadaten | Hashes von Dateipfaden + SHAs, Zeitstempel | Änderungsanzeige, Caching, Offline Verfügbarkeit | Lokal | Nein |
| Einstellungen | Theme, Sprache, aktivierte Dateierweiterungen, TTS Parameter (Rate, Pitch, Modus, Sprache, Stimme) | Personalisierung / Usability | Lokal | Nein |
| Offline Snapshot Dateien | Kopien von Repo-Inhalten (Text / ausgewählte Binärdateien) | Offline Nutzung | Lokal (App-Datenbereich) | Nein |

Keine Erhebung: Standortdaten, Kontakte, Kalender, Mikrofonaufnahmen, Kamera, Telemetrie, Werbe-IDs, eindeutige Tracking-Profile.

Keine Cookies oder vergleichbare Tracking-Technologien: Es werden keinerlei Cookies, Fingerprinting, Werbe- oder Analytics-SDKs eingesetzt.

## 4. Zwecke & Rechtsgrundlagen (Art. 6 Abs. 1 DSGVO)
| Zweck | Rechtsgrundlage | Erläuterung |
|-------|-----------------|-------------|
| App-Betrieb / Bereitstellung grundlegender Funktionen (Lesen öffentlicher Inhalte) | Art. 6 Abs. 1 lit. f (berechtigtes Interesse) | Funktionale Bereitstellung & technische Notwendigkeit lokaler Verarbeitung (Cache, Navigation) |
| Zugriff auf private Repositories (durch freiwillige Token-Hinterlegung) | Art. 6 Abs. 1 lit. f (Funktionswunsch Nutzer) | Token wird nur gespeichert, wenn Nutzer es aktiv eingibt; jederzeit entfernbar |
| Offline Snapshot Speicherung | Art. 6 Abs. 1 lit. a (Einwilligung) | Aktivierung durch Nutzer; Widerruf durch Löschen des Snapshots |
| Personalisierung (Theme, Sprache, TTS Einstellungen) | Art. 6 Abs. 1 lit. f | Komfortfunktion ohne weitergehende Profilbildung |
| TTS Wiedergabe systemseitig | Art. 6 Abs. 1 lit. f | Nutzung der lokalen Geräte‑TTS Engine ohne externe Übermittlung |

Es wird kein Profiling betrieben und keine automatisierte Entscheidungsfindung im Sinne von Art. 22 DSGVO vorgenommen.

## 5. Herkunft der Daten
* Direkte Eingabe des Nutzers (Token, Einstellungen, Aktivierung Offline Snapshot)
* Öffentliche GitHub API / Raw Endpunkte (öffentliche Repos)
* Private GitHub Repos – nur wenn ein Token freiwillig hinterlegt wurde
* System-TTS Engine (rein lokal; keine zusätzliche Datenerhebung durch die App)

## 6. Keine Weitergabe / Keine Drittanbieter-Trackingdienste
Die App sendet keine Inhalte an eigene Server, Analysedienste oder Marketingplattformen. Netzwerkverkehr erfolgt ausschließlich zu GitHub Domains (api.github.com, raw.githubusercontent.com) sowie systembedingt zu plattformspezifischen Diensteendpunkten (ohne personenbezogene Nutzungsprofile). Es werden keine Analytics-, Marketing- oder Crash-Tracking SDKs eingebunden.

### System- / Verbindungsdaten bei GitHub
Beim Abruf von Inhalten kann GitHub serverseitig (eigene Verantwortlichkeit) technische Logdaten (z.B. IP-Adresse, User-Agent) protokollieren. Siehe [GitHub Privacy Policy](https://docs.github.com/en/site-policy/privacy-policies).

### TTS Engine
Die Text-to-Speech Ausgabe erfolgt über die auf dem Gerät vorhandene Engine (z.B. Google, Samsung oder Plattformanbieter). Die App übermittelt nur den jeweils zu lesenden Text lokal an diese Engine. Eine zusätzliche externe Weiterleitung darüber hinaus findet durch die App nicht statt.

## 7. Speicherung & Löschung
Alle lokal gespeicherten Daten können vollständig entfernt werden durch (a) Löschen des Tokens in den Einstellungen, (b) Offline Snapshot löschen, (c) "Cache leeren" (sobald Funktion verfügbar) oder (d) Deinstallation / Löschen der App-Daten im Betriebssystem.

| Datentyp | Speicherdauer | Löschmöglichkeit |
|----------|---------------|------------------|
| Token | Bis Nutzer löscht / App deinstalliert | In Einstellungen entfernen / App deinstallieren |
| Cache Einträge | Überschrieben bei neuen Versionen / zukünftige Clear Cache Funktion | (Geplant) Cache leeren / App-Daten löschen |
| Offline Snapshot | Bis Nutzer Snapshot löscht | In Einstellungen Snapshot löschen |
| Einstellungen | Persistiert bis Änderung / Deinstallation | In App ändern oder App-Daten löschen |

## 8. Sicherheit
* Token werden lokal im App-Sandbox Speicher gehalten (SharedPreferences) und nicht im Klartext an weitere Stellen kopiert.  
* Empfehlung: Nur "Fine-grained Personal Access Token" mit minimalem Lese-Scope verwenden.  
* Alle externen Zugriffe erfolgen über HTTPS (GitHub Endpunkte).  
* Keine Inline-Protokollierung des Tokens in Logs.

Geplant: Migration sensibler Werte in verschlüsselten Storage (Secure Storage / Android Keystore / iOS Keychain).

## 9. Rechte der betroffenen Personen (Art. 15–22 DSGVO)
Dir stehen – soweit die gesetzlichen Voraussetzungen erfüllt sind – folgende Rechte zu:
* Auskunft (Art. 15)
* Berichtigung (Art. 16)
* Löschung / "Recht auf Vergessenwerden" (Art. 17)
* Einschränkung der Verarbeitung (Art. 18)
* Datenübertragbarkeit (Art. 20) – praktisch hier gering relevant, da keine serverseitigen Datensätze
* Widerspruch (Art. 21)
* Widerruf erteilter Einwilligungen (Art. 7 Abs. 3)

Da keine serverseitige Speicherung erfolgt, beschränkt sich die praktische Ausübung auf lokale Löschhandlungen (Token / Snapshot / App entfernen). Für Anfragen kontaktiere den Verantwortlichen (Abschnitt 1).

## 10. Internationale Datenübermittlung
Der Zugriff auf GitHub kann eine Übermittlung personenbezogener Daten in Drittländer (u.a. USA) implizieren, da GitHub Inc. Server dort und global betreibt. Die App selbst initiiert nur API Calls, die du durch Nutzung veranlasst. Weitere Informationen: [GitHub Privacy Policy](https://docs.github.com/en/site-policy/privacy-policies).

## 11. Kinder / Minderjährige
Die App richtet sich nicht gezielt an Kinder. Es werden keine speziellen Minderjährigendaten verarbeitet.

## 12. Änderungen dieser Datenschutzerklärung
Bei funktionalen Erweiterungen (z.B. zusätzliche Telemetrie, Push-Benachrichtigungen, Secure Storage Einführung) wird diese Erklärung aktualisiert. Die jeweils aktuelle Version ist im Repository enthalten.

## 13. Kontakt & Beschwerderecht
Fragen oder Anliegen: Siehe Kontaktdaten oben.  
Beschwerderecht bei einer Datenschutzaufsichtsbehörde (Art. 77 DSGVO) bleibt unberührt.

---
## Kurzfassung (Plain Language)
Die App lädt GitHub-Dateien direkt auf dein Gerät, speichert optional Kopien (Offline Snapshot) und – nur wenn du es einträgst – einen Lese-Token. Es gibt kein Tracking und keinen eigenen Server. Entferne Token / lösche Snapshot oder deinstalliere die App – dann ist alles weg.

---
## Optionale Englische Kurzzusammenfassung (Optional)
**English Summary:** The app is a read-only GitHub content viewer. No analytics, no tracking, no server-side storage. Optional access token stays locally on the device. Remove it or uninstall the app to delete all stored data.

---
