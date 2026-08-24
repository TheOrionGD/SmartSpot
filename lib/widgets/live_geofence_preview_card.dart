import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../providers/live_location_provider.dart';
import '../screens/live_map_screen.dart';
import '../utils/app_theme.dart';
import '../utils/app_motion.dart';

/// Embedded real-time live location & geofence preview card.
/// 100% data-driven: renders live GPS position, reminder destination,
/// dynamic geofence radius circle, calculated distance, and geofence state.
class LiveGeofencePreviewCard extends StatelessWidget {
  final Reminder reminder;
  final bool isInteractive;
  final VoidCallback? onTapExpand;

  const LiveGeofencePreviewCard({
    super.key,
    required this.reminder,
    this.isInteractive = true,
    this.onTapExpand,
  });

  Color _getStatusColor(GeofenceState state) {
    switch (state) {
      case GeofenceState.inside:
        return AppColors.sage;
      case GeofenceState.approaching:
        return AppColors.warning;
      case GeofenceState.outside:
        return AppColors.primary;
      case GeofenceState.locationUnavailable:
        return AppColors.error;
    }
  }

  String _getStatusLabel(GeofenceState state) {
    switch (state) {
      case GeofenceState.inside:
        return 'INSIDE PERIMETER';
      case GeofenceState.approaching:
        return 'APPROACHING';
      case GeofenceState.outside:
        return 'OUTSIDE GEOFENCE';
      case GeofenceState.locationUnavailable:
        return 'GPS SIGNAL';
    }
  }

  IconData _getStatusIcon(GeofenceState state) {
    switch (state) {
      case GeofenceState.inside:
        return Icons.verified_rounded;
      case GeofenceState.approaching:
        return Icons.near_me_rounded;
      case GeofenceState.outside:
        return Icons.my_location_rounded;
      case GeofenceState.locationUnavailable:
        return Icons.location_off_rounded;
    }
  }

  void _openFullLiveMap(BuildContext context) {
    if (onTapExpand != null) {
      onTapExpand!();
      return;
    }
    Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => LiveMapScreen(reminder: reminder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final animate = AppMotion.shouldAnimate(context);
    final locationProvider = context.watch<LiveLocationProvider>();

    final destPos = ll.LatLng(reminder.latitude, reminder.longitude);
    final userPos = locationProvider.currentLatLng;
    final distanceMeters = locationProvider.calculateDistanceTo(reminder.latitude, reminder.longitude);
    final geofenceState = locationProvider.evaluateGeofenceState(reminder.latitude, reminder.longitude, reminder.radius);
    final statusColor = _getStatusColor(geofenceState);
    final formattedDistance = locationProvider.formatDistance(distanceMeters);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Location Title & Geofence Status Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.locationName ?? '${reminder.latitude.toStringAsFixed(4)}, ${reminder.longitude.toStringAsFixed(4)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Dist: $formattedDistance',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•  Radius: ${reminder.radius.toInt()}m',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Live Status Pill
                AnimatedContainer(
                  duration: animate ? AppMotion.component : Duration.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(geofenceState),
                        size: 12,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusLabel(geofenceState),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Embedded Interactive Mini Live Map Preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            child: SizedBox(
              height: 135,
              width: double.infinity,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: destPos,
                      initialZoom: 14.2,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none, // Gesture interactions handled on tap
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.smartspot.app',
                        maxZoom: 19,
                      ),

                      // Dynamic Geofence Radius Circle
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: destPos,
                            radius: reminder.radius,
                            useRadiusInMeter: true,
                            color: AppColors.primary.withValues(alpha: 0.18),
                            borderColor: AppColors.primary,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),

                      // Map Markers: Destination Pin + Live User Marker
                      MarkerLayer(
                        markers: [
                          // Destination Marker Pin
                          Marker(
                            point: destPos,
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),

                          // Live User Position Marker (if GPS available)
                          if (userPos != null)
                            Marker(
                              point: userPos,
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.sage,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.sage.withValues(alpha: 0.5),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
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

                  // Overlay Tap Handler to Launch Full Live Map Screen
                  if (isInteractive)
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openFullLiveMap(context),
                          child: Container(
                            alignment: Alignment.bottomRight,
                            padding: const EdgeInsets.all(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Expand Map',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
