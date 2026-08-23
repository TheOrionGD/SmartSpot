/// The kind of context signal a [ReminderCondition] checks.
///
/// This is what powers "Multi-Condition Reminders" — e.g. "remind me at
/// College AND after 8 AM AND if it's raining" is three [ReminderCondition]
/// entries, all of which must pass for the reminder to actually fire.
enum ConditionType {
  timeAfter,
  timeBefore,
  dayOfWeek,
  weatherIsRain,
  weatherIsClear,
  approachingDestination,
  activityIs,
}

/// Matches [ActivityRecognitionService]'s [UserActivity] enum by name so a
/// condition can be stored/compared without importing the services layer
/// from the models layer.
enum RequiredActivity { stationary, walking, running, cycling, driving }

/// One clause in a reminder's multi-condition trigger rule. A reminder with
/// conditions only notifies when ALL of its conditions evaluate true, in
/// addition to the normal geofence enter/exit check.
class ReminderCondition {
  final ConditionType type;

  /// For [ConditionType.timeAfter] / [timeBefore]: minutes since midnight
  /// (e.g. 8:00 AM = 480).
  final int? minutesSinceMidnight;

  /// For [ConditionType.dayOfWeek]: DateTime weekday convention,
  /// Monday = 1 ... Sunday = 7.
  final int? weekday;

  /// For [ConditionType.activityIs].
  final RequiredActivity? activity;

  const ReminderCondition({
    required this.type,
    this.minutesSinceMidnight,
    this.weekday,
    this.activity,
  });

  factory ReminderCondition.timeAfter(int hour, [int minute = 0]) =>
      ReminderCondition(
        type: ConditionType.timeAfter,
        minutesSinceMidnight: hour * 60 + minute,
      );

  factory ReminderCondition.timeBefore(int hour, [int minute = 0]) =>
      ReminderCondition(
        type: ConditionType.timeBefore,
        minutesSinceMidnight: hour * 60 + minute,
      );

  factory ReminderCondition.onDay(int weekday) =>
      ReminderCondition(type: ConditionType.dayOfWeek, weekday: weekday);

  factory ReminderCondition.rain() =>
      const ReminderCondition(type: ConditionType.weatherIsRain);

  factory ReminderCondition.clear() =>
      const ReminderCondition(type: ConditionType.weatherIsClear);

  factory ReminderCondition.approaching() =>
      const ReminderCondition(type: ConditionType.approachingDestination);

  factory ReminderCondition.activityIs(RequiredActivity activity) =>
      ReminderCondition(type: ConditionType.activityIs, activity: activity);

  String get label {
    switch (type) {
      case ConditionType.timeAfter:
        return 'After ${_hhmm(minutesSinceMidnight!)}';
      case ConditionType.timeBefore:
        return 'Before ${_hhmm(minutesSinceMidnight!)}';
      case ConditionType.dayOfWeek:
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return 'On ${names[(weekday! - 1) % 7]}';
      case ConditionType.weatherIsRain:
        return 'If raining';
      case ConditionType.weatherIsClear:
        return 'If clear weather';
      case ConditionType.approachingDestination:
        return "Only if I'm heading there";
      case ConditionType.activityIs:
        return 'While ${activity!.name}';
    }
  }

  static String _hhmm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  // --- Compact serialization: "type:payload" joined with ';' at the model
  // level (see Reminder.toMap). Kept dependency-free from sqflite/json. ---

  String encode() {
    switch (type) {
      case ConditionType.timeAfter:
        return 'timeAfter:$minutesSinceMidnight';
      case ConditionType.timeBefore:
        return 'timeBefore:$minutesSinceMidnight';
      case ConditionType.dayOfWeek:
        return 'dayOfWeek:$weekday';
      case ConditionType.weatherIsRain:
        return 'weatherIsRain';
      case ConditionType.weatherIsClear:
        return 'weatherIsClear';
      case ConditionType.approachingDestination:
        return 'approaching';
      case ConditionType.activityIs:
        return 'activityIs:${activity!.name}';
    }
  }

  static ReminderCondition? decode(String raw) {
    final parts = raw.split(':');
    final tag = parts.first;
    switch (tag) {
      case 'timeAfter':
        return ReminderCondition(
          type: ConditionType.timeAfter,
          minutesSinceMidnight: int.tryParse(parts.elementAt(1)),
        );
      case 'timeBefore':
        return ReminderCondition(
          type: ConditionType.timeBefore,
          minutesSinceMidnight: int.tryParse(parts.elementAt(1)),
        );
      case 'dayOfWeek':
        return ReminderCondition(
          type: ConditionType.dayOfWeek,
          weekday: int.tryParse(parts.elementAt(1)),
        );
      case 'weatherIsRain':
        return ReminderCondition.rain();
      case 'weatherIsClear':
        return ReminderCondition.clear();
      case 'approaching':
        return ReminderCondition.approaching();
      case 'activityIs':
        final match = RequiredActivity.values
            .where((a) => a.name == parts.elementAt(1))
            .toList();
        if (match.isEmpty) return null;
        return ReminderCondition.activityIs(match.first);
      default:
        return null;
    }
  }

  static String encodeList(List<ReminderCondition> conditions) =>
      conditions.map((c) => c.encode()).join(';');

  static List<ReminderCondition> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(';')
        .where((s) => s.isNotEmpty)
        .map(ReminderCondition.decode)
        .whereType<ReminderCondition>()
        .toList();
  }
}
