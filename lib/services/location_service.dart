import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/reminder.dart';
import 'adaptive_service.dart';
import 'context_signals_service.dart';
import 'intelligence_service.dart';
import 'notification_service.dart';


/// Continuously monitors device location and evaluates it against each
/// active reminder's geofence, calling [onGeofenceEvent] on enter/exit
/// transitions.
///
/// On Android this runs as a genuine foreground service (via geolocator's
/// `AndroidSettings.foregroundNotificationConfig`), so monitoring keeps
/// working while the app is backgrounded — a persistent notification is
/// shown by the OS while it's active, as required for background location
/// access. It does NOT survive the app being force-killed; that would
/// require a separate platform-level background service.
///
/// This is also where the "context-aware engine" plugs in: on every fix it
/// (a) classifies the user's activity to drive adaptive radius + battery
/// tier, (b) checks route direction for route-aware reminders, (c) checks
/// weather for weather-aware reminders, and (d) evaluates any extra
/// multi-condition rules — all before deciding whether a geofence
/// enter/exit actually counts as a trigger.
class GeofenceLocationService {
  GeofenceLocationService._();
  static final GeofenceLocationService instance = GeofenceLocationService._();

  StreamSubscription<Position>? _positionSubscription;
  final Map<String, bool> _insideZone = {};
  final Map<String, bool> _approachingZone = {};
  Position? _previousPosition;
  LocationTier _currentTier = LocationTier.normal;

  final ActivityRecognitionService _activityService = ActivityRecognitionService.instance;
  final WeatherService _weatherService = WeatherService.instance;
  final IntelligenceService _intelligence = IntelligenceService.instance;

  bool get isMonitoring => _positionSubscription != null;

  UserActivity _lastActivity = UserActivity.stationary;
  UserActivity get lastActivity => _lastActivity;

  /// Starts monitoring. [getReminders] is called on every location update
  /// so the geofence list always reflects the latest active reminders
  /// without needing to restart the stream when reminders change.
  Future<bool> start({
    required List<Reminder> Function() getReminders,
    required void Function(Reminder reminder, bool isEnter, double edgeDistanceMeters) onGeofenceEvent,
    void Function(Reminder reminder, double edgeDistanceMeters)? onApproachingEvent,
  }) async {
    if (_positionSubscription != null) return true;

    final hasPermission = await _ensurePermission();
    if (!hasPermission) return false;

    _startStream(
      LocationTier.normal,
      getReminders,
      onGeofenceEvent,
      onApproachingEvent,
    );
    return true;
  }

  void _startStream(
    LocationTier tier,
    List<Reminder> Function() getReminders,
    void Function(Reminder reminder, bool isEnter, double edgeDistanceMeters) onGeofenceEvent,
    void Function(Reminder reminder, double edgeDistanceMeters)? onApproachingEvent,
  ) {
    _currentTier = tier;
    final locationSettings = _buildLocationSettings(tier);

    try {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (position) => _evaluate(
          position,
          getReminders,
          onGeofenceEvent,
          onApproachingEvent,
        ),
        onError: (Object e) {
          debugPrint('GeofenceLocationService stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('GeofenceLocationService failed to start: $e');
    }
  }

  /// Feature 10 — Intelligent Battery Optimization. Only restarts the
  /// underlying GPS stream when the tier actually needs to change, so we
  /// don't thrash the platform location APIs on every tick.
  void _maybeRetierStream(
    LocationTier newTier,
    List<Reminder> Function() getReminders,
    void Function(Reminder reminder, bool isEnter, double edgeDistanceMeters) onGeofenceEvent,
    void Function(Reminder reminder, double edgeDistanceMeters)? onApproachingEvent,
  ) {
    if (newTier == _currentTier || _positionSubscription == null) return;
    _positionSubscription?.cancel();
    _startStream(
      newTier,
      getReminders,
      onGeofenceEvent,
      onApproachingEvent,
    );
  }

  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _insideZone.clear();
    _approachingZone.clear();
    _previousPosition = null;
    _activityService.reset();
    try {
      await NotificationService.instance.cancelLiveGuidanceNotification();
    } catch (_) {}
  }

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  LocationSettings _buildLocationSettings(LocationTier tier) {
    final tuning = BatteryOptimizationService.settingsFor(tier);

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: tuning.accuracy,
        distanceFilter: tuning.distanceFilter,
        intervalDuration: tuning.interval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'SmartSpot is active',
          notificationText: 'Watching your location for nearby reminders',
          enableWakeLock: true,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: tuning.accuracy,
        activityType: ActivityType.other,
        distanceFilter: tuning.distanceFilter,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }

    return LocationSettings(
      accuracy: tuning.accuracy,
      distanceFilter: tuning.distanceFilter,
    );
  }

  Future<void> _evaluate(
    Position position,
    List<Reminder> Function() getReminders,
    void Function(Reminder reminder, bool isEnter, double edgeDistanceMeters) onGeofenceEvent,
    void Function(Reminder reminder, double edgeDistanceMeters)? onApproachingEvent,
  ) async {
    final reminders = getReminders();
    final activeIds = reminders.map((r) => r.id).toSet();
    // Drop tracked state for reminders that are no longer active
    // (completed/archived/deleted) so stale entries don't linger.
    _insideZone.removeWhere((id, _) => !activeIds.contains(id));
    _approachingZone.removeWhere((id, _) => !activeIds.contains(id));

    // --- Feature 9: classify current activity from GPS speed ---
    _lastActivity = _activityService.classify(position);

    // --- Feature 10: pick a battery tier from activity + proximity ---
    final nearestDistance = reminders.isEmpty
        ? double.infinity
        : reminders
            .map((r) => Geolocator.distanceBetween(
                position.latitude, position.longitude, r.latitude, r.longitude))
            .reduce((a, b) => a < b ? a : b);
    final tier = BatteryOptimizationService.chooseTier(
      activity: _lastActivity,
      distanceToNearestReminderMeters: nearestDistance,
    );
    _maybeRetierStream(
      tier,
      getReminders,
      onGeofenceEvent,
      onApproachingEvent,
    );

    for (final reminder in reminders) {
      // Recurring reminders only count on days that match their schedule
      // (e.g. a "weekdays" reminder shouldn't fire on a Saturday) — skip
      // evaluating the geofence for it entirely on off days.
      if (!reminder.isDueOn(DateTime.now())) continue;

      // --- Feature 8: adaptive radius ---
      final effectiveRadius = reminder.adaptiveRadius
          ? AdaptiveRadiusService.effectiveRadius(
              baseRadius: reminder.radius,
              activity: _lastActivity,
              currentSpeedMps: position.speed,
            )
          : reminder.radius;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        reminder.latitude,
        reminder.longitude,
      );
      final isInside = distance <= effectiveRadius;
      final isApproaching = !isInside && distance <= (effectiveRadius * 1.5);
      final wasInside = _insideZone[reminder.id] ?? false;
      final wasApproaching = _approachingZone[reminder.id] ?? false;
      final edgeDistance = (distance - effectiveRadius) < 0.0
          ? 0.0
          : (distance - effectiveRadius);

      if (isInside && !wasInside) {
        _insideZone[reminder.id] = true;
        _approachingZone[reminder.id] = false;
        if (!reminder.notifyOnEnter) continue;

        final allowed = await _passesIntelligentGates(reminder, position);
        if (!allowed) continue;

        // Feature 11: log the visit for location learning / predictive
        // suggestions, regardless of category — fire-and-forget.
        unawaited(_intelligence.recordVisit(
          latitude: reminder.latitude,
          longitude: reminder.longitude,
          locationName: reminder.locationName,
          category: reminder.category,
        ));

        onGeofenceEvent(reminder, true, edgeDistance);
      } else if (!isInside && wasInside) {
        _insideZone[reminder.id] = false;
        _approachingZone[reminder.id] = isApproaching;
        if (reminder.notifyOnExit) {
          onGeofenceEvent(reminder, false, edgeDistance);
        }
      } else {
        _insideZone[reminder.id] = isInside;
        if (isApproaching && !wasApproaching && !wasInside) {
          _approachingZone[reminder.id] = true;
          onApproachingEvent?.call(reminder, edgeDistance);
        } else if (!isApproaching) {
          _approachingZone[reminder.id] = false;
        }
      }
    }

    // Google Maps-style live perimeter navigation / guidance notification
    if (reminders.isNotEmpty) {
      Reminder? closest;
      double minEdge = double.infinity;
      String statusTag = 'Outside Perimeter';

      for (final r in reminders) {
        final dist = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          r.latitude,
          r.longitude,
        );
        final edge = (dist - r.radius) < 0.0 ? 0.0 : (dist - r.radius);
        if (edge < minEdge) {
          minEdge = edge;
          closest = r;
          if (dist <= r.radius) {
            statusTag = 'Inside Perimeter';
          } else if (dist <= r.radius * 1.5) {
            statusTag = 'Approaching Spot';
          } else {
            statusTag = 'Outside Perimeter';
          }
        }
      }

      if (closest != null) {
        unawaited(NotificationService.instance.updateLivePerimeterGuidanceNotification(
          activeSpotTitle: closest.title,
          statusTag: statusTag,
          edgeDistanceMeters: minEdge,
          totalActiveSpots: reminders.length,
        ));
      }
    } else {
      unawaited(NotificationService.instance.cancelLiveGuidanceNotification());
    }

    _previousPosition = position;
  }

  /// Runs route-aware / weather-aware / multi-condition checks for a
  /// reminder that just entered its geofence. Returns false if any check
  /// says "not yet".
  Future<bool> _passesIntelligentGates(Reminder reminder, Position position) async {
    // --- Feature 2: Route-Intelligent Reminders ---
    if (reminder.routeAware) {
      final approaching = RouteIntelligenceService.isApproaching(
        current: position,
        previous: _previousPosition,
        destLat: reminder.latitude,
        destLng: reminder.longitude,
      );
      if (!approaching) return false;
    }

    WeatherReading? weather;
    final needsWeather = reminder.weatherAware ||
        reminder.conditions.any((c) =>
            c.type.name == 'weatherIsRain' || c.type.name == 'weatherIsClear');
    if (needsWeather) {
      weather = await _weatherService.getCurrentWeather(reminder.latitude, reminder.longitude);
    }

    // --- Feature 4: Weather-Contextual Reminders ---
    // "Delay" outdoor-style reminders in bad weather rather than notifying
    // right away — modeled here as simply withholding the trigger; the UI
    // layer can re-offer it on the next geofence re-entry or via the
    // missed-reminder flow.
    if (reminder.weatherAware &&
        weather != null &&
        (weather.condition == WeatherCondition.rain ||
            weather.condition == WeatherCondition.storm)) {
      return false;
    }

    // --- Feature 3: Multi-Condition Reminders ---
    if (reminder.hasConditions) {
      final needsApproaching =
          reminder.conditions.any((c) => c.type.name == 'approachingDestination');
      final isApproaching = needsApproaching
          ? RouteIntelligenceService.isApproaching(
              current: position,
              previous: _previousPosition,
              destLat: reminder.latitude,
              destLng: reminder.longitude,
            )
          : null;

      final passes = IntelligenceService.evaluateConditions(
        reminder.conditions,
        now: DateTime.now(),
        weather: weather?.condition,
        isApproaching: isApproaching,
        activity: _lastActivity,
      );
      if (!passes) return false;
    }

    return true;
  }
}
