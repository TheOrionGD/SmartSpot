import 'web_notification_stub.dart'
    if (dart.library.html) 'web_notification_html.dart';

class WebNotificationHelper {
  static Future<bool> requestPermission() => requestWebNotificationPermission();
  static Future<bool> hasPermission() => hasWebNotificationPermission();
  static void show(String title, String body) => showWebNotification(title, body);
}
