import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/reminder.dart';
import '../utils/web_notification/web_notification.dart';

/// Wraps `flutter_local_notifications` behind a small, app-specific API.
///
/// Actual permission requesting is handled by [PermissionHelper] elsewhere
/// (via permission_handler or Web Notification API) — this service assumes permission has already
/// been granted by the time [showGeofenceNotification] is called.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _geofenceChannelId = 'smartspot_geofence_channel';
  static const String _geofenceChannelName = 'Location Reminders';
  static const String _geofenceChannelDescription =
      'Alerts you when you enter or leave a reminder location';

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(initSettings);

      if (defaultTargetPlatform == TargetPlatform.android) {
        const channel = AndroidNotificationChannel(
          _geofenceChannelId,
          _geofenceChannelName,
          description: _geofenceChannelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }
    } catch (e) {
      debugPrint('NotificationService init skipped/failed: $e');
    }

    _initialized = true;
  }

  /// Shows a notification for a reminder's geofence enter/exit event.
  Future<void> showGeofenceNotification({
    required Reminder reminder,
    required bool isEnter,
    bool withSound = true,
    bool withVibration = true,
  }) async {
    if (!_initialized) await init();

    // Trigger physical device tactile vibration feedback on enter and leave alerts
    if (withVibration) {
      try {
        HapticFeedback.heavyImpact();
        HapticFeedback.vibrate();
      } catch (_) {}
    }

    final categoryName = reminder.category.name.toUpperCase();
    final place = (reminder.locationName != null && reminder.locationName!.trim().isNotEmpty)
        ? reminder.locationName!
        : '(${reminder.latitude.toStringAsFixed(4)}, ${reminder.longitude.toStringAsFixed(4)})';

    final title = isEnter
        ? "📍 Inside Perimeter • ${reminder.title}"
        : "⚠️ Left Perimeter • ${reminder.title}";

    final body = isEnter
        ? "Reminder: ${reminder.title}\nCategory: [$categoryName] ${reminder.categoryEmoji}\nLocation: $place\nYou are inside the perimeter"
        : "Reminder: ${reminder.title}\nCategory: [$categoryName] ${reminder.categoryEmoji}\nLocation: $place\nYOU ARE OUTSIDE THE PERIMETER";

    if (kIsWeb) {
      WebNotificationHelper.show(title, body);
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _geofenceChannelId,
      _geofenceChannelName,
      channelDescription: _geofenceChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: withSound,
      enableVibration: withVibration,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: isEnter ? 'Inside Perimeter' : 'Outside Perimeter',
      ),
      color: isEnter ? const Color(0xFF10B981) : const Color(0xFFFF5252),
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: withSound,
      subtitle: isEnter ? 'Inside perimeter' : 'YOU ARE OUTSIDE THE PERIMETER',
    );

    // Use enter/exit + reminder id to produce a stable, unique notification
    // id so an enter and an exit for the same reminder don't overwrite
    // each other, but repeat triggers of the *same* event do (no spam).
    final notificationId = (reminder.id.hashCode & 0x7fffffff) ^ (isEnter ? 1 : 0);

    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: reminder.id,
    );
  }

  /// Shows a single grouped notification summarizing multiple geofence
  /// events that fired close together (e.g. several reminders near the
  /// same place, or several unrelated reminders that happened to trigger
  /// on the same location update) instead of showing one notification per
  /// reminder. Falls back gracefully — callers should only invoke this with
  /// 2+ events; with exactly 1 event, prefer [showGeofenceNotification].
  Future<void> showBundledGeofenceNotification({
    required List<({Reminder reminder, bool isEnter})> events,
    bool withSound = true,
    bool withVibration = true,
  }) async {
    if (withVibration) {
      try {
        HapticFeedback.heavyImpact();
        HapticFeedback.vibrate();
      } catch (_) {}
    }

    if (events.length == 1) {
      final only = events.first;
      return showGeofenceNotification(
        reminder: only.reminder,
        isEnter: only.isEnter,
        withSound: withSound,
        withVibration: withVibration,
      );
    }

    final enterCount = events.where((e) => e.isEnter).length;
    final exitCount = events.length - enterCount;
    final title = '📍 ${events.length} perimeter alerts nearby';
    final summaryParts = <String>[];
    if (enterCount > 0) summaryParts.add('$enterCount inside');
    if (exitCount > 0) summaryParts.add('$exitCount outside');
    final summary = summaryParts.join(' · ');

    final lines = events.map((e) {
      final cat = e.reminder.category.name.toUpperCase();
      final loc = (e.reminder.locationName != null && e.reminder.locationName!.trim().isNotEmpty)
          ? e.reminder.locationName!
          : '(${e.reminder.latitude.toStringAsFixed(4)}, ${e.reminder.longitude.toStringAsFixed(4)})';
      if (e.isEnter) {
        return '📍 ${e.reminder.title} • [$cat] • $loc (Inside perimeter)';
      } else {
        return '👋 ${e.reminder.title} • [$cat] • $loc — YOU ARE OUTSIDE THE PERIMETER';
      }
    }).toList();

    if (kIsWeb) {
      WebNotificationHelper.show(title, lines.join('\n'));
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _geofenceChannelId,
      _geofenceChannelName,
      channelDescription: _geofenceChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: withSound,
      enableVibration: withVibration,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
      styleInformation: InboxStyleInformation(
        lines,
        contentTitle: title,
        summaryText: summary,
      ),
      color: const Color(0xFFFF8A73),
      groupKey: 'smartspot_geofence_group',
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: withSound,
      subtitle: summary,
      threadIdentifier: 'smartspot_geofence_group',
    );

    // A fixed id (distinct from any single-reminder id, which is derived
    // from reminder.id.hashCode) so repeated bundles replace each other
    // instead of stacking, and never collide with a single-event id.
    const bundledNotificationId = 0x7ffffffe;

    await _plugin.show(
      bundledNotificationId,
      title,
      summary,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
