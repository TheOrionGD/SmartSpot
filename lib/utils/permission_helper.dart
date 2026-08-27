import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'app_theme.dart';
import 'web_notification/web_notification.dart';

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
  /// (relevant on Android 13+, iOS, and Web browsers). Returns true if granted.
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    if (kIsWeb) {
      final alreadyGranted = await WebNotificationHelper.hasPermission();
      if (alreadyGranted) return true;

      if (!context.mounted) return false;

      final shouldProceed = await _showRationale(
        context: context,
        icon: Icons.notifications_active,
        title: 'Enable Notifications',
        message:
            "SmartSpot uses browser notifications to alert you the moment you arrive "
            "at or leave a reminder location.",
      );
      if (!shouldProceed || !context.mounted) return false;

      final granted = await WebNotificationHelper.requestPermission();
      if (!granted && context.mounted) {
        _showOpenSettingsDialog(
          context,
          title: 'Notifications Blocked',
          message:
              "Notifications are currently blocked by your browser. Please click the icon "
              "in your browser address bar (site settings) to allow notifications.",
          onOpenSettings: () async {},
        );
      }
      return granted;
    }

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

    // Also request exact alarm permission on Android 12+ so alarms can wake the device when closed
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final alarmStatus = await Permission.scheduleExactAlarm.status;
        if (!alarmStatus.isGranted) {
          await Permission.scheduleExactAlarm.request();
        }
      } catch (_) {}
    }

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
    if (kIsWeb) return true;

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
    if (kIsWeb) return true;
    final status = await Permission.locationAlways.status;
    return status.isGranted;
  }

  /// Checks (without prompting) whether location access is currently granted.
  static Future<bool> hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Requests exemption from battery optimizations on Android so background
  /// alarms and location tracking are not killed when the app is closed.
  static Future<bool> requestIgnoreBatteryOptimizations(BuildContext context) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;

    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return true;

    if (!context.mounted) return false;

    final shouldProceed = await _showRationale(
      context: context,
      icon: Icons.battery_charging_full_rounded,
      title: 'Unrestricted Background Battery',
      message:
          'To ensure reminder alarms trigger reliably when the app is closed or '
          'phone is locked, please allow SmartSpot to run without battery restrictions.',
    );
    if (!shouldProceed || !context.mounted) return false;

    final result = await Permission.ignoreBatteryOptimizations.request();
    return result.isGranted;
  }

  /// Requests all runtime permissions sequentially (Location, Background Location, Notifications).
  static Future<void> requestAll(BuildContext context) async {
    final hasLoc = await requestLocationPermission(context);
    if (hasLoc && context.mounted && !kIsWeb) {
      await requestBackgroundLocationPermission(context);
    }
    if (context.mounted) {
      await requestNotificationPermission(context);
    }
    if (context.mounted && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await requestIgnoreBatteryOptimizations(context);
    }
  }

  /// Checks (without prompting) whether notification access is currently granted.
  static Future<bool> hasNotificationPermission() async {
    if (kIsWeb) {
      return await WebNotificationHelper.hasPermission();
    }
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