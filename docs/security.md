# Sicherheit

## Prinzipien
- Minimaler Angriffsvektor (kein eigenes Backend)
- Volle Kontrolle beim Nutzer (lokale Datenlöschung)
- Transparenz: Open Source Code

## Token Schutz
| Risiko | Maßnahme | Status |
|--------|----------|--------|
| Klartext-Zugriff auf Token | App Sandbox schützt Speicher | Aktiv |
| Abgriff durch Log-Ausgaben | Kein Logging des Token | Aktiv |
| Shoulder Surfing | Optional: Verstecken / Toggle Anzeige (geplant) | Geplant |
| Unsicherer Scope | Empfehlung Fine-grained minimal | Dokumentiert |

## Geplante Verbesserungen
- Secure Storage (KeyStore / Keychain)
- Optional Token Verschlüsselung mit Hardware-gestütztem Key

## Netzwerk
- Nur HTTPS Endpunkte (GitHub)
- Keine Zertifikats-Pinning (Abwägung: Komplexität vs. Benefit) – optional evaluierbar

## Supply Chain
- Pubspec Dependencies minimal halten
- Regelmäßige Audit (z.B. `flutter pub outdated` / manuelle Prüfung)

## Daten im Offline Snapshot
- Textbasiert (Markdown / .txt)
- Keine automatische Aufnahme sensibler Secrets (Nutzerverantwortung)

## Bedrohungsmodell (Auszug)
| Bedrohung | Eintrittswahrscheinlichkeit | Auswirkung | Mitigation |
|-----------|-----------------------------|------------|-----------|
| Token Leak lokal durch Malware | Niedrig | Mittel | Nutzer OS Sicherheit, später Secure Storage |
| Man-in-the-Middle | Niedrig | Hoch | HTTPS Nutzung |
| Bösartige Dependency Update | Niedrig-Mittel | Mittel | Audits |
| Missbrauch bei gestohlenem Gerät | Mittel | Mittel | Token Löschung / Secure Storage geplant |

## Empfehlungen an Nutzer
- Token regelmäßig rotieren
- Gerät gegen unbefugten Zugriff schützen
- Nur minimal notwendige Scopes vergeben

## Offenlegung von Schwachstellen
Kontakt per E-Mail (siehe Datenschutzerklärung). Responsible Disclosure erwünscht.
