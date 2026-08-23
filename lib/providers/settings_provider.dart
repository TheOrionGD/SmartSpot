import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists app settings to disk via shared_preferences and notifies
/// listeners so the UI (Settings screen, MaterialApp's themeMode, and the
/// geofence monitoring binder) all stay in sync.
class SettingsProvider extends ChangeNotifier {
  static const _kNotifications = 'settings_notifications_enabled';
  static const _kSound = 'settings_sound_enabled';
  static const _kVibration = 'settings_vibration_enabled';
  static const _kBackgroundMonitoring = 'settings_background_monitoring';
  static const _kDefaultRadius = 'settings_default_radius';
  static const _kThemeMode = 'settings_theme_mode';
  static const _kLanguage = 'settings_language';
  static const _kQuietHoursEnabled = 'settings_quiet_hours_enabled';
  static const _kQuietHoursStart = 'settings_quiet_hours_start';
  static const _kQuietHoursEnd = 'settings_quiet_hours_end';
  static const _kAllowHighPriorityDuringQuietHours =
      'settings_allow_high_priority_during_quiet_hours';
  static const _kBundleNotifications = 'settings_bundle_notifications';

  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _backgroundMonitoring = true;
  double _defaultRadius = 200;
  ThemeMode _themeMode = ThemeMode.system;
  String _language = 'English';
  bool _isLoaded = false;

  bool _quietHoursEnabled = false;
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);
  bool _allowHighPriorityDuringQuietHours = true;
  bool _bundleNotifications = true;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get backgroundMonitoring => _backgroundMonitoring;
  double get defaultRadius => _defaultRadius;
  ThemeMode get themeMode => _themeMode;
  String get language => _language;

  bool get quietHoursEnabled => _quietHoursEnabled;
  TimeOfDay get quietHoursStart => _quietHoursStart;
  TimeOfDay get quietHoursEnd => _quietHoursEnd;
  bool get allowHighPriorityDuringQuietHours => _allowHighPriorityDuringQuietHours;
  bool get bundleNotifications => _bundleNotifications;

  /// True once the values have been read from disk. The geofence binder
  /// waits for this before deciding whether to start monitoring, so it
  /// doesn't briefly start with default values and then stop again.
  bool get isLoaded => _isLoaded;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool(_kNotifications) ?? true;
    _soundEnabled = prefs.getBool(_kSound) ?? true;
    _vibrationEnabled = prefs.getBool(_kVibration) ?? true;
    _backgroundMonitoring = prefs.getBool(_kBackgroundMonitoring) ?? true;
    _defaultRadius = prefs.getDouble(_kDefaultRadius) ?? 200;
    _language = prefs.getString(_kLanguage) ?? 'English';
    _themeMode = _themeModeFromString(prefs.getString(_kThemeMode) ?? 'system');

    _quietHoursEnabled = prefs.getBool(_kQuietHoursEnabled) ?? false;
    _quietHoursStart = _timeOfDayFromString(
        prefs.getString(_kQuietHoursStart) ?? '22:00');
    _quietHoursEnd = _timeOfDayFromString(
        prefs.getString(_kQuietHoursEnd) ?? '07:00');
    _allowHighPriorityDuringQuietHours =
        prefs.getBool(_kAllowHighPriorityDuringQuietHours) ?? true;
    _bundleNotifications = prefs.getBool(_kBundleNotifications) ?? true;

    _isLoaded = true;
    notifyListeners();
  }

  /// Parses a stored "HH:mm" (24-hour) string back into a [TimeOfDay].
  /// Falls back to midnight if the stored value is malformed.
  TimeOfDay _timeOfDayFromString(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return TimeOfDay(
      hour: hour.clamp(0, 23),
      minute: minute.clamp(0, 59),
    );
  }

  /// Formats a [TimeOfDay] as a zero-padded 24-hour "HH:mm" string for
  /// storage — deliberately locale-independent, unlike [TimeOfDay.format]
  /// which needs a [BuildContext] and can be 12-hour.
  String _timeOfDayToString(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kNotifications, value);
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kSound, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kVibration, value);
  }

  Future<void> setBackgroundMonitoring(bool value) async {
    _backgroundMonitoring = value;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kBackgroundMonitoring, value);
  }

  Future<void> setDefaultRadius(double value) async {
    _defaultRadius = value;
    notifyListeners();
    (await SharedPreferences.getInstance()).setDouble(_kDefaultRadius, value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    (await SharedPreferences.getInstance())
        .setString(_kThemeMode, _themeModeToString(mode));
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString(_kLanguage, value);
  }

  Future<void> setQuietHoursEnabled(bool value) async {
    _quietHoursEnabled = value;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kQuietHoursEnabled, value);
  }

  Future<void> setQuietHoursStart(TimeOfDay value) async {
    _quietHoursStart = value;
    notifyListeners();
    (await SharedPreferences.getInstance())
        .setString(_kQuietHoursStart, _timeOfDayToString(value));
  }

  Future<void> setQuietHoursEnd(TimeOfDay value) async {
    _quietHoursEnd = value;
    notifyListeners();
    (await SharedPreferences.getInstance())
        .setString(_kQuietHoursEnd, _timeOfDayToString(value));
  }

  Future<void> setAllowHighPriorityDuringQuietHours(bool value) async {
    _allowHighPriorityDuringQuietHours = value;
    notifyListeners();
    (await SharedPreferences.getInstance())
        .setBool(_kAllowHighPriorityDuringQuietHours, value);
  }

  Future<void> setBundleNotifications(bool value) async {
    _bundleNotifications = value;
    notifyListeners();
    (await SharedPreferences.getInstance())
        .setBool(_kBundleNotifications, value);
  }

  /// Returns true if [time] (defaults to the current wall-clock time) falls
  /// inside the configured quiet-hours window. Returns false immediately if
  /// quiet hours are disabled, or if start == end (a zero-length window is
  /// treated as "no window" rather than "always on" or "always off").
  ///
  /// Handles overnight windows correctly — e.g. 22:00 -> 07:00 wraps past
  /// midnight, unlike a naive `start <= now <= end` comparison.
  bool isWithinQuietHours([TimeOfDay? time]) {
    if (!_quietHoursEnabled) return false;

    final now = time ?? TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = _quietHoursStart.hour * 60 + _quietHoursStart.minute;
    final endMinutes = _quietHoursEnd.hour * 60 + _quietHoursEnd.minute;

    if (startMinutes == endMinutes) return false;

    if (startMinutes < endMinutes) {
      // Same-day window, e.g. 13:00 -> 15:00.
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else {
      // Overnight window, e.g. 22:00 -> 07:00.
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    }
  }
}
