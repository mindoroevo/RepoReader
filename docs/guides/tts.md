# Guide: Text-to-Speech (TTS)

## Überblick
Die TTS-Funktion liest Markdown/Text Inhalte vor. Ideal für Lernen, Barrierefreiheit oder Hands-Free Konsum.

## Modi
| Modus | Beschreibung | Einsatz |
|-------|--------------|---------|
| Wörter | Schrittweise Wort für Wort | Exaktes Folgen, Lernzwecke |
| Sätze | Satzweise Ausgabe | Ausgewogene Verständlichkeit |
| Blöcke | Absatz / zusammengefasste Segmente | Schnelles passives Zuhören |

## Startpunkt wählen
- Slider bewegt → zeigt Vorschau Absatz
- "Ab hier vorlesen" startet Wiedergabe ab Chunk-Beginn (Wort-Modus exakt ab Wort)

## Audio-Glättung
- Kurze Sätze werden zusammengeführt (< ~25 Zeichen)
- Kleine Verzögerung zwischen Chunks reduziert Knackser

## Einstellungen
- Rate: Geschwindigkeit (empfohlen: Mittel als Start)
- Pitch: Stimmhöhe
- Stimme: Gerätespezifische Auswahl
- Sprache: Automatisch geladen & gespeichert

## Edge Cases
- Sehr lange Code-Blöcke → Übersprungen oder gekürzt (geplant: Option)
- Inline Code / Formatierungen werden bereinigt

## Geplante Verbesserungen
- SSML Unterstützung (Pausen, Betonung)
- Anpassbare Pause zwischen Chunks
- Optional: Skip Code Blöcke / nur Headings lesen
- Automatisches Weiterblättern bei sehr langen Dateien

## Tipps
- Für konzentriertes Lernen Satz-Modus wählen
- Für Nebenbei-Hören Block-Modus
- Wort-Modus nur bei detaillierter Analyse nutzen (langsamer)
