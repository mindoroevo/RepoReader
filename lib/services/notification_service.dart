import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// NotificationService
/// ===================
/// Kapselt lokale System-Benachrichtigungen (Desktop + Mobile) und dient als
/// zukünftiger Ankerpunkt für eingehende Push-/Webhook Signale.
///
/// Aktuell implementiert:
///  * Initialisierung des Plugins
///  * Einfaches Anzeigen von Änderungs-Hinweisen (title + body)
///  * Kanaldefinition (Android)
///  * Platzhalter für Webhook-Registrierung (Server später)
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    final init = InitializationSettings(android: androidInit, iOS: darwinInit, macOS: darwinInit, linux: LinuxInitializationSettings(defaultActionName: 'Öffnen'));
    await _plugin.initialize(init);
    // Request permissions where needed
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        // On Android 13+ a runtime permission is required
        await android?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        await ios?.requestPermissions(alert: true, badge: true, sound: true);
      } else if (Platform.isMacOS) {
        final mac = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
        await mac?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (_) {}
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'changes', 'Änderungen',
        description: 'Benachrichtigungen über neue oder geänderte Dateien',
        importance: Importance.defaultImportance,
        showBadge: true,
      );
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(channel);
    }
    _initialized = true;
  }

  /// Zeigt einfache Änderungs-Notification.
  static Future<void> showChangeNotification({required int count}) async {
    await init();
    const androidDetails = AndroidNotificationDetails('changes', 'Änderungen', importance: Importance.defaultImportance, priority: Priority.defaultPriority);
    const darwinDetails = DarwinNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();
    final det = const NotificationDetails(android: androidDetails, iOS: darwinDetails, macOS: darwinDetails, linux: linuxDetails);
    await _plugin.show(100, '$count geänderte Datei(en)', 'Tippen zum Anzeigen der Änderungen', det, payload: 'changes');
  }

  /// Placeholder: Registrierung eines Webhook Endpoints (später via externem Service oder local tunnel).
  static Future<void> registerWebhookPlaceholder() async {
    if (kDebugMode) {
      // ignore: avoid_print
  debugPrint('[NotificationService] Webhook Registrierung Placeholder – noch nicht implementiert');
    }
  }
}
