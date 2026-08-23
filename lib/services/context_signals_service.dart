import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Feature 2 — Route-Intelligent Reminders.
///
/// A reminder shouldn't fire just because the user is physically close to
/// it; it should fire because the user is actually heading toward it.
/// This compares the device's current movement bearing against the bearing
/// from the device to the destination — if they're roughly aligned, the
/// user is "approaching"; if they're opposed, they're moving away and the
/// notification should be withheld even inside the geofence.
class RouteIntelligenceService {
  RouteIntelligenceService._();

  /// Returns true if [current] represents movement toward
  /// ([destLat], [destLng]) rather than away from it.
  ///
  /// [previous] is the last known position (used to derive the user's
  /// heading). If the user is effectively stationary (no reliable heading —
  /// GPS `speed` below the noise floor, or `heading` unavailable) this
  /// conservatively returns true, since "not moving away" is the safer
  /// default for a reminder that would otherwise fire anyway.
  static bool isApproaching({
    required Position current,
    Position? previous,
    required double destLat,
    required double destLng,
    double minSpeedMps = 0.6, // ~2.2 km/h — below this we treat GPS heading as noise
  }) {
    final movementBearing = _movementBearing(current, previous);
    if (movementBearing == null) return true; // not enough signal — don't block

    final bearingToDestination = Geolocator.bearingBetween(
      current.latitude,
      current.longitude,
      destLat,
      destLng,
    );

    final delta = _angleDelta(movementBearing, bearingToDestination);
    // Within 90 degrees of "straight at it" counts as approaching; beyond
    // that the user's heading is pointing away from the destination.
    return delta.abs() <= 90;
  }

  static double? _movementBearing(Position current, Position? previous) {
    // Prefer the device's own compass/GPS heading when it's confident
    // (Android/iOS report -1 or NaN when unavailable).
    if (current.heading >= 0 &&
        current.heading <= 360 &&
        current.speed >= 0.6) {
      return current.heading;
    }
    if (previous == null) return null;
    final moved = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    if (moved < 8) return null; // too little movement to trust a bearing
    return Geolocator.bearingBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
  }

  static double _angleDelta(double a, double b) {
    var d = (a - b) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }
}

enum WeatherCondition { clear, cloudy, rain, storm, snow, unknown }

class WeatherReading {
  final WeatherCondition condition;
  final double temperatureC;
  final String summary;
  const WeatherReading(this.condition, this.temperatureC, this.summary);
}

/// Feature 4 — Weather-Contextual Reminders.
///
/// Uses Open-Meteo (https://open-meteo.com), a free weather API that needs
/// no API key, so this works out of the box without any secrets config.
class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  WeatherReading? _cached;
  DateTime? _cachedAt;
  double? _cachedLat, _cachedLng;

  Future<WeatherReading?> getCurrentWeather(double lat, double lng) async {
    // Cache for 10 minutes / ~1km move to avoid hammering the API on every
    // geofence evaluation tick.
    if (_cached != null &&
        _cachedAt != null &&
        _cachedLat != null &&
        _cachedLng != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 10) &&
        Geolocator.distanceBetween(_cachedLat!, _cachedLng!, lat, lng) < 1000) {
      return _cached;
    }

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return _cached;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>?;
      if (current == null) return _cached;

      final code = (current['weather_code'] as num?)?.toInt() ?? -1;
      final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 0.0;
      final reading = WeatherReading(_codeToCondition(code), temp, _codeToSummary(code));

      _cached = reading;
      _cachedAt = DateTime.now();
      _cachedLat = lat;
      _cachedLng = lng;
      return reading;
    } catch (e) {
      debugPrint('WeatherService: fetch failed ($e)');
      return _cached; // fall back to last known reading rather than blocking
    }
  }

  /// WMO weather codes, per Open-Meteo's docs.
  WeatherCondition _codeToCondition(int code) {
    if (code == 0 || code == 1) return WeatherCondition.clear;
    if (code == 2 || code == 3 || (code >= 45 && code <= 48)) return WeatherCondition.cloudy;
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return WeatherCondition.rain;
    if (code >= 95 && code <= 99) return WeatherCondition.storm;
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) return WeatherCondition.snow;
    return WeatherCondition.unknown;
  }

  String _codeToSummary(int code) {
    switch (_codeToCondition(code)) {
      case WeatherCondition.clear:
        return 'Clear skies';
      case WeatherCondition.cloudy:
        return 'Cloudy / foggy';
      case WeatherCondition.rain:
        return 'Rain expected';
      case WeatherCondition.storm:
        return 'Thunderstorms';
      case WeatherCondition.snow:
        return 'Snow';
      case WeatherCondition.unknown:
        return 'Unknown conditions';
    }
  }
}

/// Feature 5 — Traffic-Aware Reminder Timing.
///
/// This app has no paid traffic-data subscription (Google Directions /
/// TomTom Traffic API etc. all require billing + an API key), so instead of
/// silently faking live congestion data, this estimates a "leave earlier"
/// buffer from distance + a time-of-day speed profile: rush-hour windows
/// assume a slower average speed than off-peak. Swap [_averageSpeedKph] for
/// a real traffic API call if/when one is wired in — the rest of the app
/// only depends on [estimateTravelBuffer]'s return shape, not on how the
/// number was produced.
class TrafficEstimationService {
  TrafficEstimationService._();

  static ({Duration estimatedTravelTime, Duration suggestedBuffer, bool isPeakHour})
      estimateTravelBuffer({
    required double distanceMeters,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final isPeak = _isPeakHour(now);
    final speedKph = _averageSpeedKph(isPeak);

    final hours = (distanceMeters / 1000) / speedKph;
    final travelTime = Duration(seconds: (hours * 3600).round());

    // Buffer: 20% of travel time during peak hours (min 5 min), otherwise none.
    final buffer = isPeak
        ? Duration(seconds: math.max(300, (travelTime.inSeconds * 0.2).round()))
        : Duration.zero;

    return (estimatedTravelTime: travelTime, suggestedBuffer: buffer, isPeakHour: isPeak);
  }

  static bool _isPeakHour(DateTime t) {
    final isWeekday = t.weekday >= DateTime.monday && t.weekday <= DateTime.friday;
    if (!isWeekday) return false;
    final minutes = t.hour * 60 + t.minute;
    final morningPeak = minutes >= 8 * 60 && minutes <= 10 * 60 + 30;
    final eveningPeak = minutes >= 17 * 60 && minutes <= 20 * 60;
    return morningPeak || eveningPeak;
  }

  static double _averageSpeedKph(bool isPeak) => isPeak ? 18 : 32;
}
