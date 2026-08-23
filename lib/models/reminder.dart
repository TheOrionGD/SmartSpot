import 'package:intl/intl.dart';
import 'reminder_condition.dart';

enum ReminderCategory {
  shopping,
  home,
  office,
  college,
  health,
  travel,
}

enum ReminderPriority {
  low,
  medium,
  high,
}

/// How a location-based reminder repeats. A recurring reminder's geofence
/// only "counts" on days that match its schedule (see [Reminder.isDueOn]),
/// and — once completed — is automatically reset back to pending the next
/// time a scheduled day rolls around (see [Reminder.shouldResetFor]),
/// instead of staying checked off forever.
enum ReminderRepeatType {
  once,
  daily,
  weekdays,
  weekends,
  weekly,
  custom,
}

class Reminder {
  final String id;
  final String title;
  final String? description;
  final double latitude;
  final double longitude;
  final String? locationName;
  final double radius;
  final ReminderCategory category;
  final ReminderPriority priority;
  final DateTime createdAt;
  final DateTime? dueDate;
  bool isCompleted;
  bool isArchived;
  final bool notifyOnEnter;
  final bool notifyOnExit;
  final bool routeAware;
  final bool weatherAware;
  // Advanced/intelligent-engine fields ---------------------------------
  /// Extra AND-combined trigger conditions (time, day, weather, route,
  /// activity) evaluated on top of the geofence check. See
  /// [ReminderCondition] and `MultiConditionEngine`.
  final List<ReminderCondition> conditions;
  /// How many times this reminder was left uncompleted the last time its
  /// due window passed. Powers "missed reminder" prediction/rescheduling.
  final int missedCount;
  /// IDs of other reminders that must be completed before this one is
  /// considered active (see `IntelligenceService.dependenciesSatisfied`).
  final List<String> dependsOn;
  /// When true, the geofence radius is recalculated at runtime from the
  /// user's current movement speed instead of using [radius] verbatim.
  final bool adaptiveRadius;
  final ReminderRepeatType repeatType;
  // Weekday numbers using DateTime's convention: Monday = 1 ... Sunday = 7.
  // Used by `weekly` (expected to hold exactly one day) and `custom`
  // (any subset of days). Ignored for once/daily/weekdays/weekends.
  final Set<int> repeatDays;
  // The last time this reminder was marked complete. Only meaningful for
  // recurring reminders — it's what lets the app tell "completed today,
  // stay checked off" apart from "completed on a previous occurrence,
  // time to reset" (see `shouldResetFor`).
  final DateTime? lastCompletedAt;

  Reminder({
    required this.id,
    required this.title,
    this.description,
    required this.latitude,
    required this.longitude,
    this.locationName,
    this.radius = 100,
    this.category = ReminderCategory.shopping,
    this.priority = ReminderPriority.medium,
    required this.createdAt,
    this.dueDate,
    this.isCompleted = false,
    this.isArchived = false,
    this.notifyOnEnter = true,
    this.notifyOnExit = false,
    this.routeAware = false,
    this.weatherAware = false,
    List<ReminderCondition>? conditions,
    this.missedCount = 0,
    List<String>? dependsOn,
    this.adaptiveRadius = false,
    this.repeatType = ReminderRepeatType.once,
    Set<int>? repeatDays,
    this.lastCompletedAt,
  })  : repeatDays = repeatDays ?? const {},
        conditions = conditions ?? const [],
        dependsOn = dependsOn ?? const [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'radius': radius,
      'category': category.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
      'isArchived': isArchived ? 1 : 0,
      'notifyOnEnter': notifyOnEnter ? 1 : 0,
      'notifyOnExit': notifyOnExit ? 1 : 0,
      'routeAware': routeAware ? 1 : 0,
      'weatherAware': weatherAware ? 1 : 0,
      'conditions': ReminderCondition.encodeList(conditions),
      'missedCount': missedCount,
      'dependsOn': dependsOn.join(','),
      'adaptiveRadius': adaptiveRadius ? 1 : 0,
      'repeatType': repeatType.name,
      'repeatDays': repeatDays.join(','),
      'lastCompletedAt': lastCompletedAt?.toIso8601String(),
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      locationName: map['locationName'],
      radius: (map['radius'] ?? 100.0).toDouble(),
      category: ReminderCategory.values.firstWhere(
            (e) => e.toString().split('.').last == map['category'],
        orElse: () => ReminderCategory.shopping,
      ),
      priority: ReminderPriority.values.firstWhere(
            (e) => e.toString().split('.').last == map['priority'],
        orElse: () => ReminderPriority.medium,
      ),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      isCompleted: (map['isCompleted'] ?? 0) == 1,
      isArchived: (map['isArchived'] ?? 0) == 1,
      notifyOnEnter: (map['notifyOnEnter'] ?? 1) == 1,
      notifyOnExit: (map['notifyOnExit'] ?? 0) == 1,
      routeAware: (map['routeAware'] ?? 0) == 1,
      weatherAware: (map['weatherAware'] ?? 0) == 1,
      conditions: ReminderCondition.decodeList(map['conditions'] as String?),
      missedCount: (map['missedCount'] ?? 0) as int,
      dependsOn: (map['dependsOn'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      adaptiveRadius: (map['adaptiveRadius'] ?? 0) == 1,
      repeatType: ReminderRepeatType.values.firstWhere(
        (e) => e.name == map['repeatType'],
        orElse: () => ReminderRepeatType.once,
      ),
      repeatDays: (map['repeatDays'] as String? ?? '')
          .split(',')
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .toSet(),
      lastCompletedAt: map['lastCompletedAt'] != null
          ? DateTime.tryParse(map['lastCompletedAt'])
          : null,
    );
  }

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    double? latitude,
    double? longitude,
    String? locationName,
    double? radius,
    ReminderCategory? category,
    ReminderPriority? priority,
    DateTime? createdAt,
    DateTime? dueDate,
    bool? isCompleted,
    bool? isArchived,
    bool? notifyOnEnter,
    bool? notifyOnExit,
    bool? routeAware,
    bool? weatherAware,
    List<ReminderCondition>? conditions,
    int? missedCount,
    List<String>? dependsOn,
    bool? adaptiveRadius,
    ReminderRepeatType? repeatType,
    Set<int>? repeatDays,
    DateTime? lastCompletedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      radius: radius ?? this.radius,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      isArchived: isArchived ?? this.isArchived,
      notifyOnEnter: notifyOnEnter ?? this.notifyOnEnter,
      notifyOnExit: notifyOnExit ?? this.notifyOnExit,
      routeAware: routeAware ?? this.routeAware,
      weatherAware: weatherAware ?? this.weatherAware,
      conditions: conditions ?? this.conditions,
      missedCount: missedCount ?? this.missedCount,
      dependsOn: dependsOn ?? this.dependsOn,
      adaptiveRadius: adaptiveRadius ?? this.adaptiveRadius,
      repeatType: repeatType ?? this.repeatType,
      repeatDays: repeatDays ?? this.repeatDays,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
    );
  }

  bool get hasConditions => conditions.isNotEmpty;
  bool get hasDependencies => dependsOn.isNotEmpty;

  String get categoryEmoji {
    switch (category) {
      case ReminderCategory.shopping:
        return '🛒';
      case ReminderCategory.home:
        return '🏠';
      case ReminderCategory.office:
        return '💼';
      case ReminderCategory.college:
        return '🎓';
      case ReminderCategory.health:
        return '💊';
      case ReminderCategory.travel:
        return '🚗';
    }
  }

  String get priorityColor {
    switch (priority) {
      case ReminderPriority.low:
        return 'blue';
      case ReminderPriority.medium:
        return 'orange';
      case ReminderPriority.high:
        return 'red';
    }
  }

  String get formattedDate {
    if (dueDate == null) return 'No due date';
    return DateFormat('MMM dd, yyyy').format(dueDate!);
  }

  bool get isRecurring => repeatType != ReminderRepeatType.once;

  /// True if this reminder's geofence should be considered "live" on
  /// [date] — i.e. whether entering/exiting its zone on that day should
  /// count as a trigger at all. Non-recurring reminders are always due.
  bool isDueOn(DateTime date) {
    switch (repeatType) {
      case ReminderRepeatType.once:
      case ReminderRepeatType.daily:
        return true;
      case ReminderRepeatType.weekdays:
        return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
      case ReminderRepeatType.weekends:
        return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
      case ReminderRepeatType.weekly:
      case ReminderRepeatType.custom:
        return repeatDays.contains(date.weekday);
    }
  }

  /// True if a recurring reminder was completed on a previous occurrence
  /// and should be reset back to pending as of [date] — i.e. it's
  /// recurring, currently marked complete, due today, and wasn't already
  /// completed today. Non-recurring reminders never reset.
  bool shouldResetFor(DateTime date) {
    if (!isRecurring || !isCompleted) return false;
    if (!isDueOn(date)) return false;
    if (lastCompletedAt == null) return true;
    final last = lastCompletedAt!;
    return !(last.year == date.year && last.month == date.month && last.day == date.day);
  }

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Human-readable repeat schedule, e.g. "Weekdays", "Every Mon", or
  /// "Mon, Wed, Fri" for a custom schedule.
  String get repeatLabel {
    switch (repeatType) {
      case ReminderRepeatType.once:
        return 'Once';
      case ReminderRepeatType.daily:
        return 'Every day';
      case ReminderRepeatType.weekdays:
        return 'Weekdays';
      case ReminderRepeatType.weekends:
        return 'Weekends';
      case ReminderRepeatType.weekly:
        return repeatDays.isEmpty
            ? 'Weekly'
            : 'Every ${_dayNames[(repeatDays.first - 1) % 7]}';
      case ReminderRepeatType.custom:
        if (repeatDays.isEmpty) return 'Custom';
        final sorted = repeatDays.toList()..sort();
        return sorted.map((d) => _dayNames[(d - 1) % 7]).join(', ');
    }
  }
}