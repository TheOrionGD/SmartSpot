import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../providers/live_location_provider.dart';
import '../providers/reminder_provider.dart';
import '../utils/app_theme.dart';
import '../utils/app_motion.dart';

/// Full-screen interactive live map and real-time geofence preview.
/// 100% data-driven: dynamic camera viewport fitting user and destination,
/// live radius control slider with real-time perimeter resizing, and GPS tracking.
class LiveMapScreen extends StatefulWidget {
  final Reminder reminder;

  const LiveMapScreen({super.key, required this.reminder});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  late MapController _mapController;
  late double _currentRadius;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentRadius = widget.reminder.radius;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitViewport(ll.LatLng destPos, ll.LatLng? userPos) {
    if (userPos == null) {
      _mapController.move(destPos, 15);
      return;
    }

    final bounds = LatLngBounds(destPos, userPos);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(70),
      ),
    );
  }

  void _centerOnUser(ll.LatLng? userPos) {
    if (userPos != null) {
      _mapController.move(userPos, 16);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User location currently unavailable')),
      );
    }
  }

  void _centerOnDestination(ll.LatLng destPos) {
    _mapController.move(destPos, 16);
  }

  void _updateRadius(double newRadius) {
    setState(() => _currentRadius = newRadius);
    final updated = widget.reminder.copyWith(radius: newRadius);
    context.read<ReminderProvider>().updateReminder(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationProvider = context.watch<LiveLocationProvider>();
    final destPos = ll.LatLng(widget.reminder.latitude, widget.reminder.longitude);
    final userPos = locationProvider.currentLatLng;
    final distanceMeters = locationProvider.calculateDistanceTo(widget.reminder.latitude, widget.reminder.longitude);
    final geofenceState = locationProvider.evaluateGeofenceState(widget.reminder.latitude, widget.reminder.longitude, _currentRadius);
    final formattedDistance = locationProvider.formatDistance(distanceMeters);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reminder.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.aspect_ratio_rounded),
            tooltip: 'Fit Both',
            onPressed: () => _fitViewport(destPos, userPos),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Live FlutterMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: destPos,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.smartspot.app',
                maxZoom: 20,
              ),

              // Dynamic Geofence Radius Circle
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: destPos,
                    radius: _currentRadius,
                    useRadiusInMeter: true,
                    color: AppColors.primary.withValues(alpha: 0.18),
                    borderColor: AppColors.primary,
                    borderStrokeWidth: 2.5,
                  ),
                ],
              ),

              // Map Markers
              MarkerLayer(
                markers: [
                  // Destination Pin
                  Marker(
                    point: destPos,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),

                  // Live User Position Marker
                  if (userPos != null)
                    Marker(
                      point: userPos,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.sage,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sage.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Floating Action Buttons for Camera Controls
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'center_dest_fab',
                  backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: () => _centerOnDestination(destPos),
                  child: const Icon(Icons.place_rounded),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'center_user_fab',
                  backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                  foregroundColor: AppColors.sage,
                  onPressed: () => _centerOnUser(userPos),
                  child: const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
          ),

          // Bottom Control Card: Real-Time Live Data & Radius Control Slider
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.reminder.locationName ?? 'Destination',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Live Distance: $formattedDistance',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (geofenceState == GeofenceState.inside
                                  ? AppColors.sage
                                  : (geofenceState == GeofenceState.approaching
                                      ? AppColors.warning
                                      : AppColors.primary))
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (geofenceState == GeofenceState.inside
                                    ? AppColors.sage
                                    : (geofenceState == GeofenceState.approaching
                                        ? AppColors.warning
                                        : AppColors.primary))
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          geofenceState.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: geofenceState == GeofenceState.inside
                                ? AppColors.sage
                                : (geofenceState == GeofenceState.approaching
                                    ? AppColors.warning
                                    : AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Dynamic Perimeter Control Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Geofence Perimeter',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[500],
                            ),
                      ),
                      AnimatedCounterText(
                        value: _currentRadius,
                        formatter: (val) => '${val.toInt()} m',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      thumbColor: AppColors.primary,
                      overlayColor: AppColors.primary.withValues(alpha: 0.15),
                    ),
                    child: Slider(
                      value: _currentRadius,
                      min: 50,
                      max: 2000,
                      divisions: 39,
                      label: '${_currentRadius.toInt()}m',
                      onChanged: _updateRadius,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
