import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../utils/permission_helper.dart';

enum GeofenceState {
  inside,
  approaching,
  outside,
  locationUnavailable,
}

/// Dynamic, 100% data-driven real-time location provider.
/// Subscribes to hardware GPS updates, calculates geographic distances,
/// evaluates geofence states mathematically, and formats distance units.
class LiveLocationProvider extends ChangeNotifier {
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _hasPermission = false;
  String? _errorMessage;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;
  String? get errorMessage => _errorMessage;

  ll.LatLng? get currentLatLng => _currentPosition != null
      ? ll.LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      : null;

  Timer? _pollingTimer;

  LiveLocationProvider() {
    initLocationStream();
  }

  Future<void> initLocationStream() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final granted = await PermissionHelper.hasLocationPermission();
      _hasPermission = granted;

      if (!granted) {
        _isLoading = false;
        _errorMessage = 'Location permission disabled';
        notifyListeners();
        return;
      }

      // Fetch initial fix immediately
      try {
        _currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        _isLoading = false;
        notifyListeners();
      } catch (_) {
        // Fallback to last known position if immediate fix times out
        _currentPosition = await Geolocator.getLastKnownPosition();
        _isLoading = false;
        notifyListeners();
      }

      // High-frequency real-time location stream settings tuned per-platform
      late final LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'SmartSpot Location Active',
            notificationText: 'Tracking proximity to active reminder locations',
            enableWakeLock: true,
          ),
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );
      }

      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _currentPosition = position;
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (Object error) {
          _errorMessage = 'GPS Signal Error';
          _isLoading = false;
          notifyListeners();
        },
      );

      // Active 1-second periodic fallback to ensure real-time updates within seconds
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 2),
            ),
          );
          if (_currentPosition == null ||
              _currentPosition!.latitude != pos.latitude ||
              _currentPosition!.longitude != pos.longitude) {
            _currentPosition = pos;
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          }
        } catch (_) {}
      });
    } catch (e) {
      _errorMessage = 'Location Service Error';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manually force an immediate fresh GPS location fix
  Future<void> refreshLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 3),
        ),
      );
      _currentPosition = pos;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (_) {}
  }

  /// Calculates exact geographic distance in meters to target coordinates.
  double? calculateDistanceTo(double targetLat, double targetLng) {
    if (_currentPosition == null) return null;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      targetLat,
      targetLng,
    );
  }

  /// Calculates distance to the perimeter boundary edge in meters.
  /// Returns 0.0 if user is inside the perimeter, otherwise returns distance to the edge.
  double? calculateDistanceToPerimeterEdge(
      double targetLat, double targetLng, double radiusMeters) {
    final distToCenter = calculateDistanceTo(targetLat, targetLng);
    if (distToCenter == null) return null;
    final distToEdge = distToCenter - radiusMeters;
    return distToEdge < 0 ? 0.0 : distToEdge;
  }

  /// Mathematically evaluates geofence status from real-time coordinates.
  GeofenceState evaluateGeofenceState(
      double targetLat, double targetLng, double radiusMeters) {
    final distance = calculateDistanceTo(targetLat, targetLng);
    if (distance == null) return GeofenceState.locationUnavailable;

    if (distance <= radiusMeters) {
      return GeofenceState.inside;
    } else if (distance <= radiusMeters * 1.5) {
      return GeofenceState.approaching;
    } else {
      return GeofenceState.outside;
    }
  }

  /// Formats distance values dynamically (e.g., "350 m", "1.8 km") without hardcoded strings.
  String formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return '--';
    if (distanceMeters < 1000) {
      return '${distanceMeters.toInt()} m';
    } else {
      final km = distanceMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  Future<void> retryPermission(BuildContext context) async {
    final granted = await PermissionHelper.requestLocationPermission(context);
    if (granted) {
      initLocationStream();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
