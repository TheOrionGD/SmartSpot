import 'package:geolocator/geolocator.dart';

/// Feature 9 — Activity-Aware Reminders.
///
/// Rather than pulling in a separate sensor/activity-recognition plugin,
/// this classifies movement using the `speed` field geolocator already
/// reports on every [Position] update — no new native permissions needed.
/// It's a coarse but genuinely functional classifier (thresholds are in
/// m/s), good enough to drive radius/trigger-timing decisions.
enum UserActivity { stationary, walking, running, cycling, driving }

class ActivityRecognitionService {
  ActivityRecognitionService._();
  static final ActivityRecognitionService instance = ActivityRecognitionService._();

  // Small rolling window so a single noisy GPS sample doesn't flip the
  // classification back and forth.
  final List<double> _recentSpeeds = [];
  static const _windowSize = 5;

  UserActivity classify(Position position) {
    // Ignore clearly-invalid speed readings (some devices report negative
    // or absurd values when accuracy is poor).
    final speed = position.speed.isFinite && position.speed >= 0 ? position.speed : 0.0;
    _recentSpeeds.add(speed);
    if (_recentSpeeds.length > _windowSize) _recentSpeeds.removeAt(0);

    final avg = _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
    return _fromSpeed(avg);
  }

  UserActivity _fromSpeed(double mps) {
    final kph = mps * 3.6;
    if (kph < 1.0) return UserActivity.stationary;
    if (kph < 7) return UserActivity.walking;
    if (kph < 15) return UserActivity.running;
    if (kph < 25) return UserActivity.cycling;
    return UserActivity.driving;
  }

  void reset() => _recentSpeeds.clear();
}

/// Feature 8 — Adaptive Reminder Radius.
///
/// A fixed 100 m geofence is fine on foot but far too small at driving
/// speed — the phone can blow past it between GPS samples. This scales the
/// user's configured [baseRadius] up based on their current activity, so
/// fast-moving users still get a fair warning distance.
class AdaptiveRadiusService {
  AdaptiveRadiusService._();

  static const Map<UserActivity, double> _minimumRadius = {
    UserActivity.stationary: 50,
    UserActivity.walking: 100,
    UserActivity.running: 150,
    UserActivity.cycling: 250,
    UserActivity.driving: 500,
  };

  /// Returns the effective radius to use for geofence evaluation: the
  /// larger of the user's configured [baseRadius] and the activity's
  /// minimum sane radius. A user-set 800 m radius is never shrunk; a
  /// 100 m radius while driving is bumped up to 500 m.
  static double effectiveRadius({
    required double baseRadius,
    required UserActivity activity,
    double? currentSpeedMps,
  }) {
    var floor = _minimumRadius[activity] ?? baseRadius;

    // On a highway (fast + driving), extend further still — a 500 m
    // geofence at 100+ km/h still only gives ~15 seconds of warning.
    if (activity == UserActivity.driving &&
        currentSpeedMps != null &&
        currentSpeedMps * 3.6 > 80) {
      floor = 1000;
    }

    return baseRadius > floor ? baseRadius : floor;
  }
}

/// Location-tracking accuracy/interval tier, chosen dynamically to balance
/// timely geofence triggers against battery drain.
enum LocationTier { lowPower, normal, highAccuracy }

/// Feature 10 — Intelligent Battery Optimization.
///
/// Continuous high-accuracy GPS is the single biggest battery cost a
/// location app can impose. This picks a tracking tier from the user's
/// current activity and their distance to the nearest active reminder:
/// stationary/far away → low-power infrequent updates; moving → normal;
/// close to a destination → high-accuracy so the geofence trigger is
/// precise. [GeofenceLocationService] reads this to decide how often/
/// precisely to poll.
class BatteryOptimizationService {
  BatteryOptimizationService._();

  static LocationTier chooseTier({
    required UserActivity activity,
    required double distanceToNearestReminderMeters,
  }) {
    if (distanceToNearestReminderMeters <= 300) {
      return LocationTier.highAccuracy;
    }
    if (activity == UserActivity.stationary) {
      return LocationTier.lowPower;
    }
    return LocationTier.normal;
  }

  static ({LocationAccuracy accuracy, int distanceFilter, Duration interval}) settingsFor(
    LocationTier tier,
  ) {
    switch (tier) {
      case LocationTier.lowPower:
        return (
          accuracy: LocationAccuracy.low,
          distanceFilter: 50,
          interval: const Duration(seconds: 60),
        );
      case LocationTier.normal:
        return (
          accuracy: LocationAccuracy.medium,
          distanceFilter: 25,
          interval: const Duration(seconds: 20),
        );
      case LocationTier.highAccuracy:
        return (
          accuracy: LocationAccuracy.high,
          distanceFilter: 8,
          interval: const Duration(seconds: 10),
        );
    }
  }
}
