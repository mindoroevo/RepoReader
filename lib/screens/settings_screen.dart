import 'package:flutter/material.dart';
/// SettingsScreen
/// ==============
/// Einstellungsseite.
///
/// Enthält aktuell:
///  * Quell-Repo / Branch / Modus Anzeige (Read-Only)
///  * Theme-Auswahl (System / Hell / Dunkel) über [ThemeProvider]
///  * Sprache-Auswahl über [LocalizationProvider]
///  * Schalter: Änderungen-Dialog beim Start anzeigen
///  * Cache-Version (nur informativ; hilft bei Support & Invalidierung)
///
/// Persistenz:
///  * `pref:themeMode` (in `main.dart` verwaltet) – hier nur Setter-Aufruf
///  * `pref:locale` (in `localization_controller.dart` verwaltet)
///  * `pref:showChangeDialog` – boolean
///
/// Erweiterungs-Potential:
///  * Manuelles Leeren des Cache
///  * Force "Snapshot jetzt neu berechnen"
///  * Token-Eingabe UI (falls private Repos)
///
/// Edge Cases:
///  * Fehlende SharedPreferences liefern Default-Werte (true für Dialog)
///  * Während Laden wird Spinner gezeigt
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../config.dart';
import '../main.dart';
import '../localization_controller.dart';
import '../services/offline_snapshot_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showChangeDialog = true;
  bool _loading = true;
  int _pollMinutes = 0; // 0 = aus
  bool _notifyEnabled = false;
  bool _offlineEnabled = false;
  bool _snapshotExists = false;
  String? _snapshotStatus;

  @override void initState() { super.initState(); _load(); }
  /// Lädt gespeicherte Präferenzen.
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { 
      _showChangeDialog = prefs.getBool('pref:showChangeDialog') ?? true; 
      _pollMinutes = prefs.getInt('pref:pollMinutes') ?? 0; 
      _notifyEnabled = prefs.getBool('pref:notifyChanges') ?? false; 
      // Offline Flags
      _loading = false; 
    });
    _offlineEnabled = await OfflineSnapshotService.isOfflineEnabled();
    _snapshotExists = await OfflineSnapshotService.hasSnapshot();
    setState(() {});
  }
  /// Setzt Sichtbarkeit des automatischen Änderungsdialogs.
  Future<void> _setShow(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref:showChangeDialog', v);
    setState(()=> _showChangeDialog = v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.source, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(l10n.repoLabel(AppConfig.owner, AppConfig.repo), style: const TextStyle(fontFamily: 'monospace')),
          Text(l10n.branchLabel(AppConfig.branch), style: const TextStyle(fontFamily: 'monospace')),
          Text('${l10n.modePublic} / ${AppConfig.githubToken.isEmpty ? l10n.modePublic : l10n.modeAuthenticated}'),
          const Divider(height: 32),
          Text(l10n.display, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Builder(builder: (ctx) {
            final controller = ThemeProvider.of(ctx);
            ThemeMode current = controller.mode;
            Widget radio(ThemeMode m, String label) => RadioListTile<ThemeMode>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: m,
              groupValue: current,
              onChanged: (v) { if (v!=null) controller.setMode(v); setState(() {}); },
              title: Text(label),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                radio(ThemeMode.system, l10n.system),
                radio(ThemeMode.light, l10n.light),
                radio(ThemeMode.dark, l10n.dark),
              ],
            );
          }),
          const Divider(height: 32),
          Text(l10n.language, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Builder(builder: (ctx) {
            final controller = LocalizationProvider.of(ctx);
            return Row(
              children: [
                Text('${l10n.language}: '),
                const SizedBox(width: 8),
                Expanded(child: LanguageSwitcher()),
              ],
            );
          }),
          const Divider(height: 32),
          Text(l10n.notifications, style: Theme.of(context).textTheme.titleSmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.changesDialogOnStart),
            subtitle: Text(l10n.changesDialogOnStartSubtitle),
            value: _showChangeDialog,
            onChanged: _setShow,
          ),
          const SizedBox(height: 8),
          Text(l10n.pollInterval, style: Theme.of(context).textTheme.bodySmall),
          DropdownButton<int>(
            value: _pollMinutes,
            items: [0,5,10,30,60].map((m)=> DropdownMenuItem(value:m, child: Text(m==0? l10n.offOption : '$m ${l10n.minutesSuffix}'))).toList(),
            onChanged: (v) async { if (v==null) return; final prefs = await SharedPreferences.getInstance(); await prefs.setInt('pref:pollMinutes', v); setState(()=> _pollMinutes = v); },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.systemNotificationOnChanges),
            subtitle: Text(l10n.systemNotificationOnChangesSubtitle),
            value: _notifyEnabled,
            onChanged: (v) async { final prefs = await SharedPreferences.getInstance(); await prefs.setBool('pref:notifyChanges', v); setState(()=> _notifyEnabled = v); },
          ),
          const SizedBox(height: 24),
          Text(l10n.cacheVersion(AppConfig.cacheVersion.toString()), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Divider(height: 40),
          Text(l10n.offlineSection, style: Theme.of(context).textTheme.titleSmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.offlineMode),
            subtitle: Text(_offlineEnabled ? l10n.offlineModeSubtitleEnabled : l10n.offlineModeSubtitleDisabled),
            value: _offlineEnabled,
            onChanged: (v) async {
              await OfflineSnapshotService.setOfflineEnabled(v);
              setState(()=> _offlineEnabled = v);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_snapshotExists ? l10n.snapshotRecreateTitle : l10n.snapshotCreateTitle),
            subtitle: Text(_snapshotExists ? l10n.snapshotRecreateSubtitle : l10n.snapshotCreateSubtitle),
            trailing: const Icon(Icons.download),
            onTap: () async {
              setState(()=> _snapshotStatus = l10n.snapshotStarting);
              try {
                await OfflineSnapshotService.createSnapshot(onProgress: (msg){ setState(()=> _snapshotStatus = msg); });
                _snapshotExists = await OfflineSnapshotService.hasSnapshot();
                setState(()=> _snapshotStatus = l10n.snapshotDone);
              } catch (e) {
                setState(()=> _snapshotStatus = '${l10n.error}: $e');
              }
            },
          ),
          if (_snapshotExists) ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.snapshotDeleteTitle),
            subtitle: Text(l10n.snapshotDeleteSubtitle),
            trailing: const Icon(Icons.delete_outline),
            onTap: () async {
              await OfflineSnapshotService.deleteSnapshot();
              _snapshotExists = await OfflineSnapshotService.hasSnapshot();
              setState(()=> _snapshotStatus = l10n.snapshotDeleted);
            },
          ),
          if (_snapshotStatus != null) Padding(
            padding: const EdgeInsets.only(top:8.0),
            child: Text(_snapshotStatus!, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
