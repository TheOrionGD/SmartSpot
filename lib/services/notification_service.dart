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
      'Alerts you when you enter, leave, or approach a reminder location';

  static String formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return '--';
    if (distanceMeters < 1000) {
      return '${distanceMeters.toInt()}m';
    } else {
      final km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)}km';
    }
  }

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
        const customSound = RawResourceAndroidNotificationSound('vibration_sound');
        final channel = AndroidNotificationChannel(
          _geofenceChannelId,
          _geofenceChannelName,
          description: _geofenceChannelDescription,
          importance: Importance.high,
          playSound: true,
          sound: customSound,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
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
    double? edgeDistanceMeters,
    bool withSound = true,
    bool withVibration = true,
  }) async {
    if (!_initialized) await init();

    // Trigger physical device tactile vibration feedback on enter and leave alerts
    if (withVibration) {
      try {
        if (isEnter) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.heavyImpact());
        }
      } catch (_) {}
    }

    final categoryName = reminder.category.name.toUpperCase();
    final place = (reminder.locationName != null && reminder.locationName!.trim().isNotEmpty)
        ? reminder.locationName!
        : '(${reminder.latitude.toStringAsFixed(4)}, ${reminder.longitude.toStringAsFixed(4)})';

    final formattedEdge = edgeDistanceMeters != null
        ? formatDistance(edgeDistanceMeters)
        : null;

    final String tag;
    if (isEnter) {
      tag = 'Inside perimeter! Spot trigger active.';
    } else if (formattedEdge != null && formattedEdge != '--') {
      tag = 'Outside perimeter ($formattedEdge to perimeter edge)';
    } else {
      tag = 'YOU ARE OUTSIDE THE PERIMETER';
    }

    final title = isEnter
        ? '📍 Inside Perimeter • ${reminder.title}'
        : '⚠️ Left Perimeter • ${reminder.title}';

    final body =
        'Reminder: ${reminder.title}\nCategory: [$categoryName] ${reminder.categoryEmoji}\nLocation: $place\nTag: $tag';

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
      category: AndroidNotificationCategory.reminder,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      visibility: NotificationVisibility.public,
      playSound: withSound,
      sound: withSound ? const RawResourceAndroidNotificationSound('vibration_sound') : null,
      enableVibration: withVibration,
      vibrationPattern: isEnter
          ? Int64List.fromList([0, 500, 200, 500])
          : Int64List.fromList([0, 600, 200, 600, 200, 600]),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: isEnter ? 'Inside Perimeter' : 'Outside Perimeter',
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_silence',
          'Silence 🔕',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'action_open_map',
          'Open Map 🗺️',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'action_done',
          'Mark Done ✅',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
      color: isEnter ? const Color(0xFF10B981) : const Color(0xFFFF5252),
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: withSound,
      sound: withSound ? 'vibration_sound.mp3' : null,
      subtitle: tag,
      categoryIdentifier: 'geofence_actions',
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

  /// Shows an approaching perimeter alert when the user nears the geofence perimeter.
  Future<void> showApproachingNotification({
    required Reminder reminder,
    required double edgeDistanceMeters,
    bool withSound = true,
    bool withVibration = true,
  }) async {
    if (!_initialized) await init();

    if (withVibration) {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }

    final categoryName = reminder.category.name.toUpperCase();
    final place = (reminder.locationName != null && reminder.locationName!.trim().isNotEmpty)
        ? reminder.locationName!
        : '(${reminder.latitude.toStringAsFixed(4)}, ${reminder.longitude.toStringAsFixed(4)})';

    final formattedEdge = formatDistance(edgeDistanceMeters);
    final tag = 'Approaching spot ($formattedEdge to perimeter)';
    final title = '🎯 Approaching Perimeter • ${reminder.title}';
    final body =
        'Reminder: ${reminder.title}\nCategory: [$categoryName] ${reminder.categoryEmoji}\nLocation: $place\nTag: $tag';

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
      category: AndroidNotificationCategory.reminder,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      visibility: NotificationVisibility.public,
      playSound: withSound,
      sound: withSound ? const RawResourceAndroidNotificationSound('vibration_sound') : null,
      enableVibration: withVibration,
      vibrationPattern: Int64List.fromList([0, 300, 150, 300]),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: tag,
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_silence',
          'Silence 🔕',
          showsUserInterface: false,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'action_open_map',
          'Open Map 🗺️',
          showsUserInterface: true,
        ),
      ],
      color: const Color(0xFFF59E0B),
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: withSound,
      sound: withSound ? 'vibration_sound.mp3' : null,
      subtitle: tag,
      categoryIdentifier: 'geofence_actions',
    );

    final notificationId = (reminder.id.hashCode & 0x7fffffff) ^ 2;

    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: reminder.id,
    );
  }

  /// Shows a single grouped notification summarizing multiple geofence
  /// events that fired close together.
  Future<void> showBundledGeofenceNotification({
    required List<({Reminder reminder, bool isEnter, double? edgeDistanceMeters})> events,
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
        edgeDistanceMeters: only.edgeDistanceMeters,
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
      final formattedEdge = e.edgeDistanceMeters != null
          ? formatDistance(e.edgeDistanceMeters)
          : null;
      if (e.isEnter) {
        return '📍 ${e.reminder.title} • [$cat] • $loc (Inside perimeter! Spot trigger active)';
      } else {
        final edgeInfo = (formattedEdge != null && formattedEdge != '--')
            ? 'Outside perimeter ($formattedEdge to perimeter edge)'
            : 'OUTSIDE THE PERIMETER';
        return '⚠️ ${e.reminder.title} • [$cat] • $loc — $edgeInfo';
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
      category: AndroidNotificationCategory.reminder,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      visibility: NotificationVisibility.public,
      playSound: withSound,
      sound: withSound ? const RawResourceAndroidNotificationSound('vibration_sound') : null,
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
      sound: withSound ? 'vibration_sound.mp3' : null,
      subtitle: summary,
      threadIdentifier: 'smartspot_geofence_group',
    );

    const bundledNotificationId = 0x7ffffffe;

    await _plugin.show(
      bundledNotificationId,
      title,
      summary,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  static const String _liveMonitorChannelId = 'smartspot_live_guidance_channel';
  static const String _liveMonitorChannelName = 'Live Perimeter Navigation';
  static const String _liveMonitorChannelDescription =
      'Shows live distance to nearby perimeter locations like Google Maps';
  static const int liveMonitorNotificationId = 0x7ffffffd;

  /// Google Maps-style live persistent perimeter guidance notification
  Future<void> updateLivePerimeterGuidanceNotification({
    required String activeSpotTitle,
    required String statusTag,
    required double edgeDistanceMeters,
    required int totalActiveSpots,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) return;

    final formattedDist = formatDistance(edgeDistanceMeters);
    final title = '📍 SmartSpot Live • $activeSpotTitle';
    final body = '$statusTag ($formattedDist) • $totalActiveSpots perimeter${totalActiveSpots > 1 ? 's' : ''} monitored';

    final androidDetails = AndroidNotificationDetails(
      _liveMonitorChannelId,
      _liveMonitorChannelName,
      channelDescription: _liveMonitorChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      onlyAlertOnce: true,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_open_app',
          'Open SmartSpot 📱',
          showsUserInterface: true,
        ),
      ],
      color: const Color(0xFF5B5FEF),
    );

    final iosDetails = const DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    await _plugin.show(
      liveMonitorNotificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> cancelLiveGuidanceNotification() =>
      _plugin.cancel(liveMonitorNotificationId);

  Future<void> cancelAll() => _plugin.cancelAll();
}


