import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/reminder.dart';
import '../providers/reminder_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../utils/permission_helper.dart';
import '../utils/app_theme.dart';
import '../utils/app_translations.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _locationGranted;
  bool? _notificationGranted;
  bool _testingNotification = false;

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatus();
  }

  Future<void> _refreshPermissionStatus() async {
    final location = await PermissionHelper.hasLocationPermission();
    final notification = await PermissionHelper.hasNotificationPermission();
    if (mounted) {
      setState(() {
        _locationGranted = location;
        _notificationGranted = notification;
      });
    }
  }

  Future<void> _onNotificationsToggle(bool value, SettingsProvider settings) async {
    if (value) {
      final granted = await PermissionHelper.requestNotificationPermission(context);
      if (!granted) return;
    }
    await settings.setNotificationsEnabled(value);
    _refreshPermissionStatus();
  }

  Future<void> _onBackgroundMonitoringToggle(bool value, SettingsProvider settings) async {
    if (value) {
      final granted = await PermissionHelper.requestLocationPermission(context);
      if (!granted) return;
    }
    await settings.setBackgroundMonitoring(value);
    _refreshPermissionStatus();
  }

  Future<void> _pickQuietHoursStart(SettingsProvider settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.quietHoursStart,
      helpText: 'Quiet hours start',
    );
    if (picked != null) await settings.setQuietHoursStart(picked);
  }

  Future<void> _pickQuietHoursEnd(SettingsProvider settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.quietHoursEnd,
      helpText: 'Quiet hours end',
    );
    if (picked != null) await settings.setQuietHoursEnd(picked);
  }

  void _showExportDialog(int reminderCount) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.file_download_outlined, color: AppColors.primary, size: 36),
        title: const Text('Export Data'),
        content: Text(
          reminderCount == 0
              ? "You don't have any reminders to export yet."
              : 'This will export $reminderCount reminder(s) as a JSON backup file '
                  'you can save or share.\n\n(File export will be enabled once the '
                  'storage layer is wired.)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.file_upload_outlined, color: AppColors.primary, size: 36),
        title: const Text('Import Data'),
        content: const Text(
          'Restore reminders from a previously exported JSON backup file.\n\n'
          '(File picking + import will be enabled once the storage layer '
          'is wired.)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reminderCount = context.watch<ReminderProvider>().allReminders.length;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _sectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined, color: AppColors.primary),
            title: const Text('Enable Notifications'),
            subtitle: const Text('Get alerted when you enter or leave a reminder zone'),
            value: settings.notificationsEnabled,
            onChanged: (value) => _onNotificationsToggle(value, settings),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined, color: AppColors.primary),
            title: const Text('Sound'),
            value: settings.soundEnabled,
            onChanged: settings.notificationsEnabled
                ? (value) => settings.setSoundEnabled(value)
                : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration, color: AppColors.primary),
            title: const Text('Vibration'),
            value: settings.vibrationEnabled,
            onChanged: settings.notificationsEnabled
                ? (value) => settings.setVibrationEnabled(value)
                : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dynamic_feed_outlined, color: AppColors.primary),
            title: const Text('Bundle Nearby Reminders'),
            subtitle: const Text(
              'Group multiple reminders that trigger together into one notification',
            ),
            value: settings.bundleNotifications,
            onChanged: settings.notificationsEnabled
                ? (value) => settings.setBundleNotifications(value)
                : null,
          ),
          const Divider(),
          _sectionHeader('Quiet Hours'),
          SwitchListTile(
            secondary: const Icon(Icons.bedtime_outlined, color: AppColors.primary),
            title: const Text('Enable Quiet Hours'),
            subtitle: const Text('Silence geofence notifications during a set time window'),
            value: settings.quietHoursEnabled,
            onChanged: (value) => settings.setQuietHoursEnabled(value),
          ),
          ListTile(
            enabled: settings.quietHoursEnabled,
            leading: const Icon(Icons.nightlight_outlined, color: AppColors.primary),
            title: const Text('Starts at'),
            trailing: Text(
              settings.quietHoursStart.format(context),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: settings.quietHoursEnabled
                ? () => _pickQuietHoursStart(settings)
                : null,
          ),
          ListTile(
            enabled: settings.quietHoursEnabled,
            leading: const Icon(Icons.wb_sunny_outlined, color: AppColors.primary),
            title: const Text('Ends at'),
            trailing: Text(
              settings.quietHoursEnd.format(context),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: settings.quietHoursEnabled
                ? () => _pickQuietHoursEnd(settings)
                : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.priority_high, color: AppColors.primary),
            title: const Text('Allow High-Priority to Break Through'),
            subtitle: const Text(
              'High-priority reminders still notify you during quiet hours',
            ),
            value: settings.allowHighPriorityDuringQuietHours,
            onChanged: settings.quietHoursEnabled
                ? (value) => settings.setAllowHighPriorityDuringQuietHours(value)
                : null,
          ),
          const Divider(),
          _sectionHeader('Location'),
          SwitchListTile(
            secondary: const Icon(Icons.my_location, color: AppColors.primary),
            title: const Text('Background Monitoring'),
            subtitle: const Text('Keep checking your location to trigger geofences'),
            value: settings.backgroundMonitoring,
            onChanged: (value) => _onBackgroundMonitoringToggle(value, settings),
          ),
          ListTile(
            leading: const Icon(Icons.radar, color: AppColors.primary),
            title: const Text('Default Geofence Radius'),
            subtitle: Text('${settings.defaultRadius.toInt()} meters'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: settings.defaultRadius,
              min: 50,
              max: 1000,
              divisions: 19,
              label: '${settings.defaultRadius.toInt()} m',
              onChanged: (value) => settings.setDefaultRadius(value),
            ),
          ),
          const Divider(),
          _sectionHeader('App Permissions'),
          ListTile(
            leading: Icon(
              Icons.location_on_outlined,
              color: _locationGranted == true ? AppColors.success : Colors.grey,
            ),
            title: const Text('Location'),
            subtitle: Text(_locationGranted == null
                ? 'Checking…'
                : _locationGranted!
                    ? 'Allowed'
                    : 'Not allowed — tap to enable'),
            trailing: _locationGranted == true
                ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                : const Icon(Icons.chevron_right),
            onTap: () async {
              await PermissionHelper.requestLocationPermission(context);
              _refreshPermissionStatus();
            },
          ),
          ListTile(
            leading: Icon(
              Icons.notifications_none,
              color: _notificationGranted == true ? AppColors.success : Colors.grey,
            ),
            title: const Text('Notifications'),
            subtitle: Text(_notificationGranted == null
                ? 'Checking…'
                : _notificationGranted!
                    ? 'Allowed'
                    : 'Not allowed — tap to enable'),
            trailing: _notificationGranted == true
                ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                : const Icon(Icons.chevron_right),
            onTap: () async {
              await PermissionHelper.requestNotificationPermission(context);
              _refreshPermissionStatus();
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_applications_outlined, color: AppColors.primary),
            title: const Text('Open Device App Settings'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openAppSettings(),
          ),
          const Divider(),
          _sectionHeader('Data & Backup'),
          ListTile(
            leading: const Icon(Icons.file_download_outlined, color: AppColors.primary),
            title: const Text('Export Reminders'),
            subtitle: Text('$reminderCount reminder(s) stored locally'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showExportDialog(reminderCount),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined, color: AppColors.primary),
            title: const Text('Import Reminders'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showImportDialog,
          ),
          const Divider(),
          _sectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (mode) {
                if (mode != null) settings.setThemeMode(mode);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language, color: AppColors.primary),
            title: Text(AppTranslations.tr(context, 'language')),
            trailing: DropdownButton<String>(
              value: AppTranslations.supportedLanguages.contains(settings.language)
                  ? settings.language
                  : 'English',
              underline: const SizedBox(),
              items: AppTranslations.supportedLanguages
                  .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                  .toList(),
              onChanged: (value) {
                if (value != null) settings.setLanguage(value);
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.motion_photos_off_outlined, color: AppColors.primary),
            title: const Text('Reduce Motion'),
            subtitle: const Text('Minimize large scale and translation animations'),
            value: settings.reducedMotion,
            onChanged: (value) => settings.setReducedMotion(value),
          ),
          const Divider(),
          _buildTestNotificationSection(context),
          const Divider(),
          _sectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App Version'),
            subtitle: Text('1.0.0'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Test Phone Notifications & Vibration ─────────────────────────────────

  Widget _buildTestNotificationSection(BuildContext context) {
    final reminders = context.read<ReminderProvider>().allReminders;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Test Phone Notifications & Vibration'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Tap any button below to fire a real phone notification with its vibration pattern. Useful to verify sound & vibration settings.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
        const SizedBox(height: 8),
        _testTile(
          icon: Icons.my_location_rounded,
          iconColor: const Color(0xFF5B5FEF),
          label: 'Active Watch',
          subtitle: 'Type 1 — SmartSpot is watching your location',
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            setState(() => _testingNotification = true);
            try {
              await NotificationService.instance
                  .updateLivePerimeterGuidanceNotification(
                activeSpotTitle: 'Demo Spot',
                statusTag: 'Going Towards Perimeter',
                edgeDistanceMeters: 142,
                totalActiveSpots: reminders.isEmpty ? 1 : reminders.length,
              );
              messenger.showSnackBar(const SnackBar(
                content: Text('📍 Active Watch notification sent!'),
                duration: Duration(seconds: 2),
              ));
            } finally {
              if (mounted) setState(() => _testingNotification = false);
            }
          },
        ),
        _testTile(
          icon: Icons.radar_rounded,
          iconColor: const Color(0xFFF59E0B),
          label: 'Perimeter Alerts',
          subtitle: 'Type 2 — Going Towards / Inside / Going Away From Perimeter',
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            setState(() => _testingNotification = true);
            try {
              final demoReminder = reminders.isNotEmpty
                  ? reminders.first
                  : _demoReminder();
              // Fire all 3 perimeter states in sequence
              await NotificationService.instance.showApproachingNotification(
                reminder: demoReminder,
                edgeDistanceMeters: 78,
              );
              await Future.delayed(const Duration(milliseconds: 600));
              await NotificationService.instance.showGeofenceNotification(
                reminder: demoReminder,
                isEnter: true,
              );
              await Future.delayed(const Duration(milliseconds: 600));
              await NotificationService.instance.showGeofenceNotification(
                reminder: demoReminder,
                isEnter: false,
                edgeDistanceMeters: 55,
              );
              messenger.showSnackBar(const SnackBar(
                content: Text('🎯 3 Perimeter notifications sent!'),
                duration: Duration(seconds: 2),
              ));
            } finally {
              if (mounted) setState(() => _testingNotification = false);
            }
          },
        ),
        _testTile(
          icon: Icons.task_alt_rounded,
          iconColor: const Color(0xFF10B981),
          label: 'Task Status',
          subtitle: 'Type 3 — Task Completed & Task Pending',
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            setState(() => _testingNotification = true);
            try {
              final demoReminder = reminders.isNotEmpty
                  ? reminders.first
                  : _demoReminder();
              await NotificationService.instance.showTaskCompletedNotification(
                reminder: demoReminder,
              );
              await Future.delayed(const Duration(milliseconds: 500));
              await NotificationService.instance.showTaskPendingNotification(
                reminder: demoReminder,
              );
              messenger.showSnackBar(const SnackBar(
                content: Text('✅ Task status notifications sent!'),
                duration: Duration(seconds: 2),
              ));
            } finally {
              if (mounted) setState(() => _testingNotification = false);
            }
          },
        ),
        _testTile(
          icon: Icons.bar_chart_rounded,
          iconColor: const Color(0xFF8B5CF6),
          label: 'Data Summary',
          subtitle: 'Type 4 — Active & Remaining Reminders Overview',
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final provider = context.read<ReminderProvider>();
            setState(() => _testingNotification = true);
            try {
              await provider.showRemindersSummaryNotification();
              messenger.showSnackBar(const SnackBar(
                content: Text('📊 Summary notification sent!'),
                duration: Duration(seconds: 2),
              ));
            } finally {
              if (mounted) setState(() => _testingNotification = false);
            }
          },
        ),
        if (_testingNotification)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _testTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
      trailing: Icon(Icons.notifications_active_rounded,
          color: iconColor, size: 20),
      onTap: _testingNotification ? null : onTap,
    );
  }

  /// Fallback demo [Reminder] used when no real reminders exist yet.
  Reminder _demoReminder() => Reminder(
        id: 'demo_test',
        title: 'Demo Reminder',
        latitude: 12.9716,
        longitude: 77.5946,
        locationName: 'Demo Location',
        radius: 150,
        category: ReminderCategory.shopping,
        priority: ReminderPriority.medium,
        createdAt: DateTime.now(),
      );
}
