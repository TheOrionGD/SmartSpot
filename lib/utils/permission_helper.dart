import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'app_theme.dart';

/// Centralized helper for requesting runtime permissions with a friendly
/// rationale shown *before* the system dialog, and a graceful path to the
/// device settings screen if the person has permanently denied access.
class PermissionHelper {
  PermissionHelper._();

  /// Shows a rationale dialog, then requests location permission via
  /// Geolocator (which also nudges the user to enable location services).
  /// Returns true if permission was granted (while-in-use or always).
  static Future<bool> requestLocationPermission(BuildContext context) async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      return true;
    }

    if (!context.mounted) return false;

    final shouldProceed = await _showRationale(
      context: context,
      icon: Icons.location_on,
      title: 'Location Access Needed',
      message:
      'SmartSpot needs your location to place reminders on the map and '
          'to detect when you enter or leave a reminder zone. We only use '
          'this to trigger your reminders — nothing is shared.',
    );
    if (!shouldProceed || !context.mounted) return false;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        _showOpenSettingsDialog(
          context,
          title: 'Location Services Off',
          message: 'Please turn on Location/GPS for your device to continue.',
          onOpenSettings: Geolocator.openLocationSettings,
        );
      }
      return false;
    }

    permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied) {
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        _showOpenSettingsDialog(
          context,
          title: 'Location Permission Blocked',
          message:
          "You've permanently denied location access. Please enable it "
              "manually in app settings to use location-based reminders.",
          onOpenSettings: Geolocator.openAppSettings,
        );
      }
      return false;
    }

    return true;
  }

  /// Shows a rationale dialog, then requests notification permission
  /// (relevant on Android 13+ and iOS). Returns true if granted.
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    var status = await Permission.notification.status;

    if (status.isGranted) return true;

    if (!context.mounted) return false;

    final shouldProceed = await _showRationale(
      context: context,
      icon: Icons.notifications_active,
      title: 'Enable Notifications',
      message:
      "SmartSpot uses notifications to alert you the moment you arrive "
          "at or leave a reminder location. Without this, reminders won't "
          "be able to reach you.",
    );
    if (!shouldProceed || !context.mounted) return false;

    status = await Permission.notification.request();

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        _showOpenSettingsDialog(
          context,
          title: 'Notifications Blocked',
          message:
          "You've permanently denied notifications. Please enable them "
              "manually in app settings so reminders can reach you.",
          onOpenSettings: () async {
            await openAppSettings();
          },
        );
      }
      return false;
    }

    return status.isGranted;
  }

  /// Requests "Allow all the time" background location access. Must be
  /// called *after* foreground (while-in-use) location is already granted —
  /// Android 10+ refuses to let an app ask for both in the same dialog, and
  /// will silently ignore/deny a combined request. Without this, geofence
  /// monitoring only works while the app is open in the foreground.
  static Future<bool> requestBackgroundLocationPermission(
      BuildContext context) async {
    final hasForeground = await hasLocationPermission();
    if (!hasForeground) return false;

    var status = await Permission.locationAlways.status;
    if (status.isGranted) return true;

    if (!context.mounted) return false;

    final shouldProceed = await _showRationale(
      context: context,
      icon: Icons.my_location_rounded,
      title: 'Allow Location "All the Time"',
      message:
      'To notify you the moment you arrive or leave, SmartSpot needs '
          'location access even when the app is closed. On the next '
          'screen, please choose "Allow all the time".',
    );
    if (!shouldProceed || !context.mounted) return false;

    status = await Permission.locationAlways.request();

    if (status.isPermanentlyDenied || status.isDenied) {
      if (context.mounted) {
        _showOpenSettingsDialog(
          context,
          title: 'Background Location Needed',
          message:
          'Please enable "Allow all the time" location access in app '
              'settings so reminders can trigger while SmartSpot is in the '
              'background.',
          onOpenSettings: () async => openAppSettings(),
        );
      }
      return false;
    }

    return status.isGranted;
  }

  /// Checks (without prompting) whether background ("always") location is granted.
  static Future<bool> hasBackgroundLocationPermission() async {
    final status = await Permission.locationAlways.status;
    return status.isGranted;
  }

  /// Checks (without prompting) whether location access is currently granted.
  static Future<bool> hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Checks (without prompting) whether notification access is currently granted.
  static Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  static Future<bool> _showRationale({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void _showOpenSettingsDialog(
      BuildContext context, {
        required String title,
        required String message,
        required Future<void> Function() onOpenSettings,
      }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onOpenSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}