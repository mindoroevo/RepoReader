# Entwicklung & Beiträge

## Lokales Setup
1. Flutter SDK installieren (Version gemäß `pubspec.lock` Minor Bereich beibehalten)
2. `flutter pub get`
3. Plattform-spezifisch bauen: `flutter build apk` / `flutter build appbundle` / `flutter run -d chrome`

## Ordnerstruktur (vereinfacht)
```
lib/
  screens/
  services/
  widgets/
  utils/
  models/
  providers/ (State Management – falls eingesetzt)
```

## Coding Guidelines
- Kurze Methoden (≤ 40 Zeilen bevorzugt)
- Pure Functions für Parsing / Umwandlung
- Kein Logging sensibler Daten (Token nie ausgeben)
- Null-Sicherheit strikt einhalten

## Namenskonventionen
| Element | Konvention |
|---------|-----------|
| Dateien | snake_case.dart |
| Klassen | PascalCase |
| Methoden | camelCase |
| Konstanten | SCREAMING_SNAKE_CASE |

## State Management
Derzeit leichtgewichtig (lokaler State + evtl. Provider/ChangeNotifier). Empfehlung: Keine Über-Architektur bevor funktionaler Druck entsteht.

## Tests (Empfohlen Aufsetzen)
Pfad-Vorschläge:
```
/test
  utils/markdown_preprocess_test.dart
  services/tts_chunking_test.dart
```

## PR Checkliste (Vorschlag)
- [ ] Keine sensiblen Strings im Code
- [ ] Lints laufen sauber
- [ ] Feature dokumentiert (docs/ aktualisiert)
- [ ] Roadmap angepasst falls nötig
- [ ] Changelog Eintrag bei signifikanten Änderungen

## Versionierung
SemVer-inspiriert, solange API/Oberfläche stabil bleibt: `0.x` für schnelle Iteration.

## Release Flow (Beispiel)
1. Changelog aktualisieren
2. Version in `pubspec.yaml` hochsetzen
3. Build: `flutter build appbundle --release`
4. Hochladen Play Console
5. Tag setzen (`git tag v0.x.y && git push --tags`)

## Style / Linting
Empfehlung: `analysis_options.yaml` strikt halten. Erweiterungen: pedantic / lints Paket einbinden (falls nicht vorhanden).

## Beitragen (Contribution)
1. Issue erstellen / vorhandenes referenzieren
2. Fork / Branch
3. PR mit klarer Beschreibung + Screenshots (UI Änderungen)
4. Review Abwarten

## Security Disclosure
Sicherheitsrelevante Funde privat per Mail an Verantwortlichen (siehe Datenschutzerklärung) melden.
