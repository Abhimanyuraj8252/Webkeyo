import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper over flutter_local_notifications used to notify the user
/// about long-running pipeline jobs (start / complete / failure).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'webkeyo_pipeline';
  static const String _channelName = 'Pipeline Jobs';
  static const String _channelDesc =
      'Notifications for script, audio and video generation jobs';

  late final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  /// Must be called once from main() before any show() call.
  Future<void> init() async {
    if (_ready) return;
    try {
      // Android 13+ requires the runtime POST_NOTIFICATIONS permission.
      try {
        final status = await Permission.notifications.request();
        if (!status.isGranted) {
          debugPrint('Notifications not granted; job notifications disabled');
        }
      } catch (_) {}

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      _plugin = FlutterLocalNotificationsPlugin();
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: (_) {},
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                _channelName,
                channelDescription: _channelDesc,
                importance: Importance.defaultImportance,
              ),
            ),
          );
      _ready = true;
    } catch (e) {
      // Notifications are non-critical; never break the app over them.
      debugPrint('NotificationService init failed: $e');
    }
  }

  Future<void> show(String title, String body, {int? id}) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id ?? DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('NotificationService show failed: $e');
    }
  }
}
