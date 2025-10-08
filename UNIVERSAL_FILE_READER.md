# 🔧 Universeller Datei-Reader - Erweiterte Funktionalitäten

## Übersicht

Die Anwendung wurde um umfassende Datei-Lese-Funktionalitäten erweitert, die weit über Markdown-Dateien hinausgehen. Das System kann jetzt **alle Dateitypen** lesen, anzeigen und durchsuchen – von Programmcode über PDFs bis hin zu Bildern und Binärdateien.

## 🚀 Neue Features

### 1. Universeller Datei-Reader (`UniversalFileReader`)

Der neue `UniversalFileReader` Service erweitert die bisherige Funktionalität:

**Unterstützte Dateitypen:**
- **Textdateien**: `.md`, `.txt`, `.dart`, `.js`, `.py`, `.json`, `.yaml`, `.xml`, `.html`, `.css`, etc.
- **Programmcode**: Alle gängigen Programmiersprachen
- **Binärdateien**: `.pdf`, `.png`, `.jpg`, `.zip`, `.mp3`, `.mp4`, etc.
- **Konfigurationsdateien**: `.ini`, `.env`, `.config`, etc.

**Features:**
- ✅ Automatische Typ-Erkennung basierend auf Dateiendung
- ✅ UTF-8 Dekodierung für Textdateien
- ✅ Base64-Behandlung für Binärdateien
- ✅ Intelligentes Caching-System
- ✅ Raw GitHub API + Contents API Fallback
- ✅ MIME-Type-Bestimmung

### 2. Universeller Datei-Browser

**Pfad**: `lib/screens/universal_file_browser_screen.dart`

Neue Screen für das Browsen aller Dateitypen:

- 📁 **Kategorisierte Anzeige**: Dateien werden nach Typ gruppiert
- 🔍 **Filter & Suche**: Nach Namen, Kategorie, Text/Binär filtern
- 📊 **Datei-Statistiken**: Größe, Anzahl, Gesamtübersicht
- 👀 **Schnellvorschau**: Inline-Preview für unterstützte Dateitypen
- 📱 **Responsive UI**: Optimiert für verschiedene Bildschirmgrößen

**Kategorien:**
- Dokumentation (`.md`, `.txt`, `.readme`)
- Programmcode (`.dart`, `.js`, `.py`, etc.)
- Konfiguration (`.json`, `.yaml`, `.xml`)
- Bilder (`.png`, `.jpg`, `.gif`)
- Dokumente (`.pdf`, `.doc`)
- Media (`.mp3`, `.mp4`)
- Archive (`.zip`, `.rar`)

### 3. Universeller Datei-Viewer

**Pfad**: `lib/widgets/universal_file_viewer.dart`

Intelligenter Viewer für verschiedene Dateitypen:

**Textdateien:**
- 📝 Syntax-Highlighting-Vorbereitung
- 📊 Statistiken (Zeilen, Wörter, Zeichen)
- 📋 Zwischenablage-Integration
- ⚡ Performance-Warnung bei großen Dateien

**Bilder:**
- 🖼️ Native Bildanzeige
- 🔍 Responsive Skalierung
- 📏 Größeninformationen

**PDFs:**
- 📄 PDF-Erkennung und Info-Display
- ⬇️ Download-Funktionalität (vorbereitet)
- 🔗 Externe Viewer-Integration (geplant)

**Binärdateien:**
- 🔢 Hex-Dump Preview (erste 256 Bytes)
- 📊 Base64-Export
- ⬇️ Download-Funktionen

### 4. Erweiterte Suche

**Pfad**: `lib/screens/enhanced_search_screen.dart`

Komplett neue Suchfunktionalität:

**Suchbereiche:**
- 📄 **Dateiinhalt**: Volltextsuche in allen Textdateien
- 📁 **Dateinamen**: Suche in Pfaden und Dateinamen
- 🏷️ **Kategoriefilter**: Eingrenzung nach Dateityp
- ⚙️ **Flexible Filter**: Text/Binär, Kategorien, etc.

**Features:**
- 🔍 Multi-Term AND-Suche
- 💡 Intelligente Snippet-Generierung
- 🎯 Hervorhebung der Suchbegriffe
- 📊 Treffer-Kategorisierung
- ⚡ Progressive Ergebnis-Updates

## 🏗️ Technische Architektur

### Service-Layer

```dart
// Erweiterte WikiService-Methoden
Future<FileReadResult> fetchFileByPath(String repoPath)
Future<List<UniversalRepoEntry>> listAllFiles(String dirPath)
Future<Map<String, List<UniversalRepoEntry>>> listFilesByCategory(String dirPath)
Future<List<UniversalRepoEntry>> listCodeFiles(String dirPath)
Future<List<UniversalRepoEntry>> listImageFiles(String dirPath)
```

### Datenstrukturen

```dart
// UniversalRepoEntry - Erweiterte Datei-Metadaten
class UniversalRepoEntry {
  final String name;
  final String path;
  final String extension;
  final String mimeType;
  final bool isText;
  final int size;
  final String category;
  final String formattedSize;
}

// FileReadResult - Universeller Datei-Inhalt
class FileReadResult {
  final dynamic content;  // String oder Uint8List
  final bool fromCache;
  final bool isText;
  final String mimeType;
}
```

## 📱 UI/UX Integration

### Navigation

Die neuen Features sind über das Hauptmenü (Drawer) verfügbar:

1. **"Suche"** - Klassische Markdown-Suche (unverändert)
2. **"Erweiterte Suche"** - Neue universelle Suchfunktion
3. **"Alle Dateien"** - Universeller Datei-Browser

### Benutzerführung

- 🎯 **Kontextuelle Navigation**: Markdown-Dateien öffnen sich weiterhin im `PageScreen`
- 🔄 **Einheitliche UI**: Konsistente Icons und Styling
- 📱 **Responsive Design**: Optimiert für Mobile und Desktop
- ⚡ **Performance**: Intelligentes Caching und progressive Loading

## 🚧 Implementierungsdetails

### Dateityp-Erkennung

```dart
static const textExtensions = {
  '.md', '.txt', '.dart', '.js', '.ts', '.py', '.java', // ...
};

static const binaryExtensions = {
  '.pdf', '.png', '.jpg', '.zip', '.mp3', // ...
};
```

### MIME-Type-Bestimmung

Automatische MIME-Type-Zuordnung basierend auf Dateierweiterungen für optimale Darstellung und Verarbeitung.

### Caching-Strategie

- **Textdateien**: Als UTF-8 String gecacht
- **Binärdateien**: Als Base64 String gecacht
- **Cache-Keys**: `universal_cache:v{version}:{path}`
- **Invalidierung**: Über `AppConfig.cacheVersion`

## 🔮 Ausblick & Erweiterungen

### Geplante Features

1. **Syntax-Highlighting**: Echtes Code-Highlighting für verschiedene Sprachen
2. **PDF-Viewer**: Inline PDF-Anzeige
3. **Excel/Word-Support**: Office-Dokument-Preview
4. **Bildbearbeitung**: Grundlegende Bildanpassungen
5. **Download-Manager**: Offline-Verfügbarkeit von Binärdateien
6. **Volltext-Indexierung**: Persistenter Suchindex für bessere Performance

### Erweiterbare Architektur

Das System ist so konzipiert, dass neue Dateitypen und Viewer einfach hinzugefügt werden können:

```dart
// Neue Dateitypen hinzufügen
textExtensions.add('.newtype');

// Neue Viewer registrieren
if (mimeType == 'application/newtype') {
  return CustomViewer(content: fileResult);
}
```

## 🎉 Fazit

Mit diesen Erweiterungen entwickelt sich die Anwendung von einem reinen Markdown-Viewer zu einem **universellen Repository-Browser** – perfekt geeignet für die Erkundung kompletter Codebases, Dokumentationssammlungen und gemischter Inhalte.

Die Implementierung folgt den bestehenden Architekturprinzipien und erweitert die App nahtlos um mächtige neue Funktionalitäten, ohne die bewährten Markdown-Features zu beeinträchtigen.