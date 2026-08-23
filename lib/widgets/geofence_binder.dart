import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';
import '../providers/settings_provider.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/intelligence_service.dart';

/// Wraps the main app content and owns the lifecycle of geofence
/// monitoring: starts it when Background Monitoring is enabled (and
/// permission is granted), stops it when disabled, and turns geofence
/// enter/exit events into local notifications — respecting the user's
/// Sound/Vibration/Notifications/Quiet Hours/Bundling preferences from
/// Settings.
class GeofenceBinder extends StatefulWidget {
  final Widget child;

  const GeofenceBinder({super.key, required this.child});

  @override
  State<GeofenceBinder> createState() => _GeofenceBinderState();
}

class _GeofenceBinderState extends State<GeofenceBinder> {
  bool _monitoringActive = false;
  late final ReminderProvider _reminderProvider;

  // Short debounce buffer: a single position update can trigger multiple
  // reminders' geofences synchronously (e.g. several saved places near
  // each other). Rather than firing a notification per event immediately,
  // events are collected here and flushed together shortly after, so they
  // can be evaluated as a batch (for bundling) and against quiet hours.
  final List<({Reminder reminder, bool isEnter})> _pendingEvents = [];
  Timer? _flushTimer;

  @override
  void initState() {
    super.initState();
    _reminderProvider = context.read<ReminderProvider>();
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncMonitoring(SettingsProvider settings) async {
    if (!settings.isLoaded) return;

    if (settings.backgroundMonitoring && !_monitoringActive) {
      final started = await GeofenceLocationService.instance.start(
        getReminders: () => _reminderProvider.allReminders,
        onGeofenceEvent: (reminder, isEnter) =>
            _handleGeofenceEvent(reminder, isEnter, settings),
      );
      if (mounted && started != _monitoringActive) {
        setState(() => _monitoringActive = started);
      }
    } else if (!settings.backgroundMonitoring && _monitoringActive) {
      await GeofenceLocationService.instance.stop();
      if (mounted) setState(() => _monitoringActive = false);
    }
  }

  void _handleGeofenceEvent(
    Reminder reminder,
    bool isEnter,
    SettingsProvider settings,
  ) {
    if (!settings.notificationsEnabled) return;

    // Buffer the event instead of showing it immediately. All events
    // produced by the same location update arrive synchronously (the
    // location service loops over reminders in one pass), so a very short
    // timer is enough to catch the whole batch before flushing — this is
    // what makes bundling possible without changing the location service's
    // per-reminder callback signature.
    _pendingEvents.add((reminder: reminder, isEnter: isEnter));
    _flushTimer?.cancel();
    _flushTimer = Timer(
      const Duration(milliseconds: 300),
      () => _flushPendingEvents(settings),
    );
  }

  void _flushPendingEvents(SettingsProvider settings) {
    if (_pendingEvents.isEmpty) return;
    final events = List<({Reminder reminder, bool isEnter})>.from(_pendingEvents);
    _pendingEvents.clear();

    final isQuiet = settings.isWithinQuietHours();
    final hasHighPriority =
        events.any((e) => e.reminder.priority == ReminderPriority.high);
    final urgentBypassApplies =
        isQuiet && settings.allowHighPriorityDuringQuietHours && hasHighPriority;

    if (isQuiet && !urgentBypassApplies) {
      // Fully suppressed: quiet hours are active and nothing in this batch
      // qualifies for the high-priority bypass.
      return;
    }

    // If quiet hours are active but a high-priority reminder unlocked the
    // bypass, only surface the high-priority event(s) — low/medium ones in
    // the same batch stay suppressed rather than riding along.
    final toShow = urgentBypassApplies
        ? events.where((e) => e.reminder.priority == ReminderPriority.high).toList()
        : events;

    if (toShow.isEmpty) return;

    // Feature 13 — Intelligent Notification Ranking: when several
    // reminders trigger together (e.g. arriving somewhere with 5 pending
    // reminders), show the most urgent ones first instead of database/
    // insertion order.
    final rankedReminders = IntelligenceService.instance
        .rankForNotification(toShow.map((e) => e.reminder).toList());
    toShow.sort((a, b) =>
        rankedReminders.indexOf(a.reminder).compareTo(rankedReminders.indexOf(b.reminder)));

    if (settings.bundleNotifications && toShow.length > 1) {
      NotificationService.instance.showBundledGeofenceNotification(
        events: toShow,
        withSound: settings.soundEnabled,
        withVibration: settings.vibrationEnabled,
      );
    } else {
      for (final event in toShow) {
        NotificationService.instance.showGeofenceNotification(
          reminder: event.reminder,
          isEnter: event.isEnter,
          withSound: settings.soundEnabled,
          withVibration: settings.vibrationEnabled,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    // Defer to after this frame so we never call setState mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMonitoring(settings));
    return widget.child;
  }
}
