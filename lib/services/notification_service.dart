import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';
import '../utils/web_notification/web_notification.dart';

/// Wraps `flutter_local_notifications` behind a small, app-specific API.
///
/// Actual permission requesting is handled by [PermissionHelper] elsewhere
/// (via permission_handler or Web Notification API) — this service assumes
/// permission has already been granted by the time any show* method is called.
///
/// ## 4 Notification Types
/// 1. **Active Location Watch** — persistent notification while monitoring is on.
/// 2. **Perimeter Alerts** — going towards (approaching), inside, going away (left).
/// 3. **Task Status** — task completed & task pending/created.
/// 4. **Reminders Data Summary** — active, pending, completed counts.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ─── Channel: Perimeter Alerts (Type 2) ───────────────────────────────────
  static const String _geofenceChannelId = 'smartspot_geofence_alerts_channel_v3';
  static const String _geofenceChannelName = 'Location Reminders';
  static const String _geofenceChannelDescription =
      'Alerts you when you enter, leave, or approach a reminder location';

  // ─── Channel: Due Time Alarms (Type 5) ────────────────────────────────────
  static const String _alarmChannelId = 'smartspot_alarm_channel_v4';
  static const String _alarmChannelName = 'Reminder Alarms';
  static const String _alarmChannelDescription =
      'Alerts you with sound and vibration when a reminder due time is reached';

  // ─── Channel: Live Perimeter Navigation (Type 1) ──────────────────────────
  static const String _liveMonitorChannelId =
      'smartspot_live_guidance_channel_v3';
  static const String _liveMonitorChannelName = 'Live Perimeter Navigation';
  static const String _liveMonitorChannelDescription =
      'Shows live distance to nearby perimeter locations like Google Maps';

  // ─── Channel: Task Status (Type 3) ────────────────────────────────────────
  static const String _taskChannelId = 'smartspot_task_status_channel_v3';
  static const String _taskChannelName = 'Task Status';
  static const String _taskChannelDescription =
      'Notifies you when a task is completed or pending';

  // ─── Channel: Reminders Summary (Type 4) ──────────────────────────────────
  static const String _summaryChannelId = 'smartspot_summary_channel_v3';
  static const String _summaryChannelName = 'Reminders Summary';
  static const String _summaryChannelDescription =
      'Shows an overview of your active, pending, and completed reminders';

  // ─── Stable notification IDs ───────────────────────────────────────────────
  static const int liveMonitorNotificationId = 0x7ffffffd;
  static const int _taskCompletedBaseId = 0x6aaaaaaa;
  static const int _taskPendingBaseId = 0x5bbbbbbb;
  static const int _taskTimeDueBaseId = 0x3ddddddd;
  static const int _summaryNotificationId = 0x4ccccccc;

  // ─── Vibration patterns ────────────────────────────────────────────────────
  /// Two short pulses — "approaching, heads-up"
  static final Int64List _approachingVibration =
      Int64List.fromList([0, 300, 150, 300]);

  /// One strong pulse — "you are inside"
  static final Int64List _insideVibration =
      Int64List.fromList([0, 600, 0, 0]);

  /// Three escalating pulses — "alert, you left"
  static final Int64List _leftVibration =
      Int64List.fromList([0, 600, 200, 600, 200, 800]);

  /// Single celebratory pulse — "done!"
  static final Int64List _completedVibration =
      Int64List.fromList([0, 200, 100, 400]);

  /// Two urgent taps — "something needs attention"
  static final Int64List _pendingVibration =
      Int64List.fromList([0, 400, 200, 400]);

  /// One gentle pulse — "informational"
  static final Int64List _summaryVibration =
      Int64List.fromList([0, 250, 0, 0]);

  // ─── Helpers ───────────────────────────────────────────────────────────────
  static String formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return '--';
    if (distanceMeters < 1000) {
      return '${distanceMeters.toInt()}m';
    } else {
      final km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)}km';
    }
  }

  // ─── Initialisation ────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    try {
      tz.initializeTimeZones();
      final dynamic timeZoneResult = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = (timeZoneResult is String)
          ? timeZoneResult
          : (timeZoneResult?.identifier?.toString() ?? 'UTC');
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('NotificationService timezone init failed: $e');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    try {
      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(initSettings);

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        try {
          await androidPlugin?.requestNotificationsPermission();
          await androidPlugin?.requestExactAlarmsPermission();
        } catch (e) {
          debugPrint('Error requesting Android notification/alarm permissions: $e');
        }

        const customSound =
            RawResourceAndroidNotificationSound('vibration_sound');

        // 1. Geofence / perimeter alerts channel
        await androidPlugin?.createNotificationChannel(
          AndroidNotificationChannel(
            _geofenceChannelId,
            _geofenceChannelName,
            description: _geofenceChannelDescription,
            importance: Importance.high,
            playSound: true,
            sound: customSound,
            enableVibration: true,
            vibrationPattern: _insideVibration,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
            enableLights: true,
            showBadge: true,
          ),
        );

        // 2. Live perimeter navigation / active watch channel (silent)
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            _liveMonitorChannelId,
            _liveMonitorChannelName,
            description: _liveMonitorChannelDescription,
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
          ),
        );

        // 3. Task status channel
        await androidPlugin?.createNotificationChannel(
          AndroidNotificationChannel(
            _taskChannelId,
            _taskChannelName,
            description: _taskChannelDescription,
            importance: Importance.high,
            playSound: true,
            sound: customSound,
            enableVibration: true,
            vibrationPattern: _completedVibration,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
            enableLights: true,
            showBadge: true,
          ),
        );

        // 4. Summary channel
        await androidPlugin?.createNotificationChannel(
          AndroidNotificationChannel(
            _summaryChannelId,
            _summaryChannelName,
            description: _summaryChannelDescription,
            importance: Importance.defaultImportance,
            playSound: false,
            enableVibration: true,
            vibrationPattern: _summaryVibration,
          ),
        );

        // 5. Alarm channel (Loud Time Due alarms)
        await androidPlugin?.createNotificationChannel(
          AndroidNotificationChannel(
            _alarmChannelId,
            _alarmChannelName,
            description: _alarmChannelDescription,
            importance: Importance.max,
            playSound: true,
            sound: customSound,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 1000]),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableLights: true,
            showBadge: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('NotificationService init skipped/failed: $e');
    }

    _initialized = true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TYPE 1 — Active Location Watch (persistent)
  // ══════════════════════════════════════════════════════════════════════════

  /// Google Maps-style live persistent perimeter guidance notification.
  ///
  /// Updated on every GPS tick while background monitoring is active; shows
  /// current nearest spot, direction status (going towards / inside /
  /// going away), and live edge distance.
  Future<void> updateLivePerimeterGuidanceNotification({
    required String activeSpotTitle,
    required String statusTag,
    required double edgeDistanceMeters,
    required int totalActiveSpots,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) return;

    final formattedDist = formatDistance(edgeDistanceMeters);
    final title = '📍 SmartSpot Active • $activeSpotTitle';
    final body =
        '$statusTag ($formattedDist) • $totalActiveSpots spot${totalActiveSpots > 1 ? 's' : ''} monitored';

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

    const iosDetails = DarwinNotificationDetails(
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

  // ══════════════════════════════════════════════════════════════════════════
  // TYPE 2 — Perimeter Alerts (going towards / inside / going away)
  // ══════════════════════════════════════════════════════════════════════════

  /// Shows a going-towards (approaching) perimeter notification.
  ///
  /// Fires when the user enters the 1.5× radius "approach zone" but has not
  /// yet crossed the actual geofence boundary.
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
    final place = _formatPlace(reminder);
    final formattedEdge = formatDistance(edgeDistanceMeters);
    final tag = 'Going towards spot • $formattedEdge to perimeter';
    final title = '🎯 Going Towards Perimeter • ${reminder.title}';
    final body =
        'Reminder: ${reminder.title}\nCategory: [$categoryName] ${reminder.categoryEmoji}\nLocation: $place\n$tag';

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
      sound: withSound
          ? const RawResourceAndroidNotificationSound('vibration_sound')
          : null,
      enableVibration: withVibration,
      vibrationPattern: _approachingVibration,
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

  /// Shows an inside / left-perimeter notification.
  ///
  /// - [isEnter] `true`  → "Inside Perimeter" (spot trigger active)
  /// - [isEnter] `false` → "Going Away From Perimeter" (Left Perimeter)
  Future<void> showGeofenceNotification({
    required Reminder reminder,
    required bool isEnter,
    double? edgeDistanceMeters,
    bool withSound = true,
    bool withVibration = true,
  }) async {
    if (!_initialized) await init();

    if (withVibration) {
      try {
        if (isEnter) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 200),
              () => HapticFeedback.heavyImpact());
          Future.delayed(const Duration(milliseconds: 450),
              () => HapticFeedback.heavyImpact());
        }
      } catch (_) {}
    }

    final categoryName = reminder.category.name.toUpperCase();
    final place = _formatPlace(reminder);
    final formattedEdge =
        edgeDistanceMeters != null ? formatDistance(edgeDistanceMeters) : null;

    final String tag;
    final String title;

    if (isEnter) {
      tag = 'Inside perimeter! Spot trigger active.';
      title = '📍 Inside Perimeter • ${reminder.title}';
    } else if (formattedEdge != null && formattedEdge != '--') {
      tag = 'Going away from perimeter ($formattedEdge to perimeter edge)';
      title = '⚠️ Going Away From Perimeter • ${reminder.title}';
    } else {
      tag = 'Going away from perimeter';
      title = '⚠️ Going Away From Perimeter • ${reminder.title}';
    }

    final body =
        'Reminder: ${reminder.title}\nCategory: [$categoryName] ${reminder.categoryEmoji}\nLocation: $place\n$tag';

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
      sound: withSound
          ? const RawResourceAndroidNotificationSound('vibration_sound')
          : null,
      enableVibration: withVibration,
      vibrationPattern: isEnter ? _insideVibration : _leftVibration,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText:
            isEnter ? 'Inside Perimeter' : 'Going Away From Perimeter',
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

    // Stable unique id: enter and exit for the same reminder get different ids
    // so they don't overwrite each other, but repeat triggers of the *same*
    // event do (anti-spam).
    final notificationId =
        (reminder.id.hashCode & 0x7fffffff) ^ (isEnter ? 1 : 0);

    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: reminder.id,
    );
  }

  /// Shows a single grouped notification summarising multiple geofence events
  /// that fired close together.
  Future<void> showBundledGeofenceNotification({
    required List<({Reminder reminder, bool isEnter, double? edgeDistanceMeters})>
        events,
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
    if (exitCount > 0) summaryParts.add('$exitCount going away');
    final summary = summaryParts.join(' · ');

    final lines = events.map((e) {
      final cat = e.reminder.category.name.toUpperCase();
      final loc = _formatPlace(e.reminder);
      final formattedEdge = e.edgeDistanceMeters != null
          ? formatDistance(e.edgeDistanceMeters)
          : null;
      if (e.isEnter) {
        return '📍 ${e.reminder.title} • [$cat] • $loc — Inside perimeter! Spot trigger active';
      } else {
        final edgeInfo = (formattedEdge != null && formattedEdge != '--')
            ? 'Going away ($formattedEdge to edge)'
            : 'Going away from perimeter';
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
      sound: withSound
          ? const RawResourceAndroidNotificationSound('vibration_sound')
          : null,
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

  // ══════════════════════════════════════════════════════════════════════════
  // TYPE 3 — Task Status (Completed & Pending)
  // ══════════════════════════════════════════════════════════════════════════

  /// Shows a "Task Completed" notification with a celebratory vibration
  /// pattern, fired immediately after the user marks a reminder as done.
  Future<void> showTaskCompletedNotification({
    required Reminder reminder,
    bool withSound = true,
    bool withVibration = true,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) {
      WebNotificationHelper.show(
        '✅ Task Completed • ${reminder.title}',
        'Great job! You completed: ${reminder.title}',
      );
      return;
    }

    if (withVibration) {
      try {
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 150),
            () => HapticFeedback.lightImpact());
      } catch (_) {}
    }

    final categoryName = reminder.category.name.toUpperCase();
    final place = _formatPlace(reminder);
    const title = '✅ Task Completed!';
    final body =
        '${reminder.title}\nCategory: [$categoryName] ${reminder.categoryEmoji}\nLocation: $place\nGreat job — reminder marked as done!';

    final androidDetails = AndroidNotificationDetails(
      _taskChannelId,
      _taskChannelName,
      channelDescription: _taskChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      visibility: NotificationVisibility.public,
      playSound: withSound,
      sound: withSound
          ? const RawResourceAndroidNotificationSound('vibration_sound')
          : null,
      enableVibration: withVibration,
      vibrationPattern: _completedVibration,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Completed',
      ),
      color: const Color(0xFF10B981),
      autoCancel: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: withSound,
      sound: withSound ? 'vibration_sound.mp3' : null,
      subtitle: 'Completed',
    );

    final notificationId =
        (_taskCompletedBaseId ^ (reminder.id.hashCode & 0x0fffffff));

    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: reminder.id,
    );
  }

  /// Shows a "Task Pending" notification with an alert vibration pattern,
  /// fired when a reminder is created or toggled back to pending.
  Future<void> showTaskPendingNotification({
    required Reminder reminder,
    bool withSound = true,
    bool withVibration = true,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) {
      WebNotificationHelper.show(
        '⏳ Task Pending • ${reminder.title}',
        'Reminder set: ${reminder.title}',
      );
      return;
    }

    if (withVibration) {
      try {
        HapticFeedback.lightImpact();
        Future.delayed(
            const Duration(milliseconds: 200), () => HapticFeedback.lightImpact());
      } catch (_) {}
    }

    final categoryName = reminder.category.name.toUpperCase();
    final place = _formatPlace(reminder);
    const title = '⏳ Task Pending';
    final body =
        '${reminder.title}\nCategory: [$categoryName] ${reminder.categoryEmoji}\nLocation: $place\nWe\'ll remind you when you reach this spot!';

    final androidDetails = AndroidNotificationDetails(
      _taskChannelId,
      _taskChannelName,
      channelDescription: _taskChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      playSound: withSound,
      sound: withSound
          ? const RawResourceAndroidNotificationSound('vibration_sound')
          : null,
      enableVibration: withVibration,
      vibrationPattern: _pendingVibration,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Pending',
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_open_map',
          'View on Map 🗺️',
          showsUserInterface: true,
        ),
      ],
      color: const Color(0xFFF59E0B),
      autoCancel: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: withSound,
      sound: withSound ? 'vibration_sound.mp3' : null,
      subtitle: 'Pending',
    );

    final notificationId =
        (_taskPendingBaseId ^ (reminder.id.hashCode & 0x0fffffff));

    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: reminder.id,
    );
  }

  /// Shows a "Reminder Due Time Reached" notification with a strong alarm vibration pattern,
  /// fired when a reminder's scheduled time is reached.
  Future<void> showTimeDueNotification({
    required Reminder reminder,
    bool withSound = true,
    bool withVibration = true,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) {
      WebNotificationHelper.show(
        '⏰ Reminder Due • ${reminder.title}',
        'The scheduled time has arrived for: ${reminder.title}',
      );
      return;
    }

    if (withVibration) {
      try {
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 150),
            () => HapticFeedback.heavyImpact());
        Future.delayed(const Duration(milliseconds: 300),
            () => HapticFeedback.heavyImpact());
      } catch (_) {}
    }

    final categoryName = reminder.category.name.toUpperCase();
    final place = _formatPlace(reminder);
    final title = '⏰ Reminder Due • ${reminder.title}';
    final body =
        'Category: [$categoryName] ${reminder.categoryEmoji}\nLocation: $place\nThe scheduled time has arrived!';

    final androidDetails = AndroidNotificationDetails(
      _alarmChannelId,
      _alarmChannelName,
      channelDescription: _alarmChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      playSound: withSound,
      sound: withSound
          ? const RawResourceAndroidNotificationSound('vibration_sound')
          : null,
      enableVibration: withVibration,
      vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 1000]),
      fullScreenIntent: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Reminder Due',
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_open_app',
          'Open SmartSpot 📱',
          showsUserInterface: true,
        ),
      ],
      color: const Color(0xFF5B5FEF),
      autoCancel: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: withSound,
      sound: withSound ? 'vibration_sound.mp3' : null,
      subtitle: 'Reminder Due',
    );

    final notificationId =
        (_taskTimeDueBaseId ^ (reminder.id.hashCode & 0x0fffffff));

    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: reminder.id,
    );
  }

  Future<void> scheduleTimeDueNotification({
    required Reminder reminder,
  }) async {
    if (!_initialized) await init();
    if (kIsWeb || reminder.dueDate == null) return;

    final now = DateTime.now();
    if (reminder.dueDate!.isBefore(now)) return;

    final categoryName = reminder.category.name.toUpperCase();
    final place = _formatPlace(reminder);
    final title = '⏰ Reminder Due • ${reminder.title}';
    final body =
        'Category: [$categoryName] ${reminder.categoryEmoji}\nLocation: $place\nThe scheduled time has arrived!';

    final androidDetails = AndroidNotificationDetails(
      _alarmChannelId,
      _alarmChannelName,
      channelDescription: _alarmChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('vibration_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 1000]),
      fullScreenIntent: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Reminder Due',
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_open_app',
          'Open SmartSpot 📱',
          showsUserInterface: true,
        ),
      ],
      color: const Color(0xFF5B5FEF),
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'vibration_sound.mp3',
      subtitle: 'Reminder Due',
    );

    final notificationId =
        (_taskTimeDueBaseId ^ (reminder.id.hashCode & 0x0fffffff));

    await _plugin.cancel(notificationId);

    final due = reminder.dueDate!.toLocal();
    final scheduledDate = tz.TZDateTime.from(due, tz.local);
    final tzNow = tz.TZDateTime.now(tz.local);
    if (scheduledDate.isBefore(tzNow)) return;

    try {
      await _plugin.zonedSchedule(
        notificationId,
        title,
        'The scheduled time has arrived for: ${reminder.title}',
        scheduledDate,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminder.id,
      );
    } catch (e) {
      debugPrint('Exact alarm zonedSchedule failed, falling back to inexact: $e');
      await _plugin.zonedSchedule(
        notificationId,
        title,
        'The scheduled time has arrived for: ${reminder.title}',
        scheduledDate,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminder.id,
      );
    }
  }

  Future<void> cancelScheduledTimeDueNotification(String reminderId) async {
    if (kIsWeb) return;
    final notificationId =
        (_taskTimeDueBaseId ^ (reminderId.hashCode & 0x0fffffff));
    await _plugin.cancel(notificationId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TYPE 4 — Reminders Data Summary
  // ══════════════════════════════════════════════════════════════════════════

  /// Shows an overview notification with active, pending, and completed counts.
  ///
  /// Optionally accepts the first few reminder titles to show inline.
  Future<void> showActiveRemindersSummaryNotification({
    required int activeCount,
    required int pendingCount,
    required int completedCount,
    List<Reminder>? reminders,
    bool withVibration = true,
  }) async {
    if (!_initialized) await init();

    if (withVibration) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }

    final total = activeCount + completedCount;
    final title = '📊 SmartSpot Overview • $activeCount Active Reminder${activeCount != 1 ? 's' : ''}';
    final body =
        '🟢 $activeCount Active  •  ⏳ $pendingCount Pending  •  ✅ $completedCount Completed\n'
        'Total reminders: $total';

    if (kIsWeb) {
      WebNotificationHelper.show(title, body);
      return;
    }

    // Build InboxStyle lines: summary row + up to 5 reminder titles
    final lines = <String>[];
    lines.add('🟢 $activeCount Active  •  ⏳ $pendingCount Pending  •  ✅ $completedCount Completed');
    if (reminders != null && reminders.isNotEmpty) {
      final preview = reminders.take(5).toList();
      for (final r in preview) {
        final statusIcon = r.isCompleted ? '✅' : '📍';
        lines.add('$statusIcon ${r.title} — ${r.categoryEmoji} ${r.category.name.toUpperCase()}');
      }
      if (reminders.length > 5) {
        lines.add('… and ${reminders.length - 5} more reminder${reminders.length - 5 > 1 ? 's' : ''}');
      }
    }

    final androidDetails = AndroidNotificationDetails(
      _summaryChannelId,
      _summaryChannelName,
      channelDescription: _summaryChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      visibility: NotificationVisibility.public,
      playSound: false,
      enableVibration: withVibration,
      vibrationPattern: _summaryVibration,
      styleInformation: InboxStyleInformation(
        lines,
        contentTitle: title,
        summaryText: '$total reminder${total != 1 ? 's' : ''} total',
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'action_open_app',
          'Open SmartSpot 📱',
          showsUserInterface: true,
        ),
      ],
      color: const Color(0xFF5B5FEF),
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      subtitle: 'Reminders Overview',
    );

    await _plugin.show(
      _summaryNotificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  // ─── Utilities ─────────────────────────────────────────────────────────────

  /// Formats a [Reminder]'s location as a human-readable string.
  static String _formatPlace(Reminder reminder) {
    return (reminder.locationName != null &&
            reminder.locationName!.trim().isNotEmpty)
        ? reminder.locationName!
        : '(${reminder.latitude.toStringAsFixed(4)}, ${reminder.longitude.toStringAsFixed(4)})';
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
