/// Render progress notifications — so a long FFmpeg render keeps the
/// user informed even if they leave the app, and so the render can be
/// cancelled from the notification shade (via the in-app Cancel
/// button, which uses [RenderCancellation]).
///
/// No server. flutter_local_notifications only.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class RenderNotification {
  static const int _id = 2;
  static const String _channelId = 'webkeyo_render';
  static const String _channelName = 'Video rendering';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<void> showProgress(double fraction, String projectName) async {
    await _ensureInitialized();
    final percent = (fraction * 100).round().clamp(0, 100);
    await _plugin.show(
      id: _id,
      title: 'Rendering video… $percent%',
      body: 'Webkeyo is rendering $projectName',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Video render progress',
          ongoing: true,
          autoCancel: false,
          showProgress: true,
          maxProgress: 100,
          progress: percent,
        ),
      ),
    );
  }

  Future<void> showDone(String videoPath) async {
    await _ensureInitialized();
    await _plugin.show(
      id: _id,
      title: 'Video ready 🎬',
      body: videoPath,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Video render progress',
          autoCancel: true,
        ),
      ),
    );
  }

  Future<void> hide() async {
    await _ensureInitialized();
    await _plugin.cancel(id: _id);
  }
}
