import 'package:geolocator/geolocator.dart';
import '../models/reminder.dart';
import '../models/reminder_condition.dart';
import '../models/location_visit.dart';
import 'database_service.dart';
import 'adaptive_service.dart';
import 'context_signals_service.dart';
import 'api_service.dart';

/// A predictive "smart suggestion" surfaced on the home screen — e.g.
/// "You usually shop here on Saturdays. Create a grocery reminder?"
class SmartSuggestion {
  final String title;
  final String message;
  final double latitude;
  final double longitude;
  final String? locationName;
  final ReminderCategory category;

  const SmartSuggestion({
    required this.title,
    required this.message,
    required this.latitude,
    required this.longitude,
    this.locationName,
    required this.category,
  });
}

/// A "you keep missing this" prompt with a suggested new time.
class MissedReminderSuggestion {
  final Reminder reminder;
  final String message;
  final DateTime suggestedDateTime;

  const MissedReminderSuggestion({
    required this.reminder,
    required this.message,
    required this.suggestedDateTime,
  });
}

/// One line of the personalized productivity insight panel.
class Insight {
  final String text;
  final String emoji;
  const Insight(this.text, {this.emoji = '💡'});
}

/// Feature hub: this is the "CONTEXT-AWARE ENGINE" from the project's
/// enhancement doc — predictive suggestions (1), multi-condition
/// evaluation (3), intelligent priority (7), location learning (11),
/// relevance scoring (12), notification ranking (13), missed-reminder
/// prediction + smart rescheduling (16/17), and personalized insights (15)
/// all live here so the rest of the app has one place to ask "what should
/// happen next?" instead of scattering heuristics across screens.
class IntelligenceService {
  IntelligenceService._();
  static final IntelligenceService instance = IntelligenceService._();

  final DatabaseService _db = DatabaseService();

  // --- Feature 11 — Location Learning ------------------------------------

  /// Records a visit so future pattern analysis has data to work with.
  /// Call this whenever the user enters a reminder's geofence, or lingers
  /// near a spot the map screen resolved a name for.
  Future<void> recordVisit({
    required double latitude,
    required double longitude,
    String? locationName,
    ReminderCategory? category,
  }) async {
    final visit = LocationVisit(
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      category: category?.name,
      timestamp: DateTime.now(),
    );
    await _db.recordVisit(visit);
    try {
      await ApiService.instance.logVisit(visit);
    } catch (e) {
      // Background sync, suppress network errors
    }
  }

  /// Clusters recent visits within [clusterRadiusMeters] of each other and
  /// returns the ones visited at least [minVisits] times — i.e. the user's
  /// frequent places, independent of whether they've been saved as a
  /// favorite or turned into a reminder.
  Future<List<({double lat, double lng, String? name, int count})>> frequentLocations({
    int minVisits = 3,
    double clusterRadiusMeters = 150,
  }) async {
    final visits = await _db.getRecentVisits();
    final clusters = <({double lat, double lng, String? name, int count})>[];

    for (final v in visits) {
      final idx = clusters.indexWhere(
        (c) => Geolocator.distanceBetween(c.lat, c.lng, v.latitude, v.longitude) <=
            clusterRadiusMeters,
      );
      if (idx == -1) {
        clusters.add((lat: v.latitude, lng: v.longitude, name: v.locationName, count: 1));
      } else {
        final c = clusters[idx];
        clusters[idx] = (lat: c.lat, lng: c.lng, name: c.name ?? v.locationName, count: c.count + 1);
      }
    }

    return clusters.where((c) => c.count >= minVisits).toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  // --- Feature 1 — Predictive Reminder Engine -----------------------------

  /// Looks for a recurring pattern — same place, same weekday, visited
  /// repeatedly — that doesn't already have a matching reminder, and
  /// suggests creating one. This is intentionally simple pattern-matching
  /// (frequency counting) rather than a trained model: it's transparent,
  /// needs no training data pipeline, and is easy to demo/explain for a
  /// final-year project.
  Future<List<SmartSuggestion>> generatePredictiveSuggestions({
    required List<Reminder> existingReminders,
    int minOccurrences = 3,
    double clusterRadiusMeters = 150,
  }) async {
    final visits = await _db.getRecentVisits(days: 60);
    if (visits.isEmpty) return [];

    // Group by (place cluster, weekday).
    final groups = <String, List<LocationVisit>>{};
    final placeAnchors = <String, LocationVisit>{};

    for (final v in visits) {
      String? key;
      for (final anchorKey in placeAnchors.keys) {
        final anchor = placeAnchors[anchorKey]!;
        if (Geolocator.distanceBetween(anchor.latitude, anchor.longitude, v.latitude, v.longitude) <=
            clusterRadiusMeters) {
          key = anchorKey;
          break;
        }
      }
      key ??= '${v.latitude.toStringAsFixed(4)},${v.longitude.toStringAsFixed(4)}';
      placeAnchors.putIfAbsent(key, () => v);
      final groupKey = '$key|${v.weekday}';
      groups.putIfAbsent(groupKey, () => []).add(v);
    }

    final suggestions = <SmartSuggestion>[];
    for (final entry in groups.entries) {
      if (entry.value.length < minOccurrences) continue;
      final sample = entry.value.first;

      final alreadyCovered = existingReminders.any((r) =>
          Geolocator.distanceBetween(r.latitude, r.longitude, sample.latitude, sample.longitude) <=
          clusterRadiusMeters);
      if (alreadyCovered) continue;

      const dayNames = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
      ];
      final dayName = dayNames[(sample.weekday - 1) % 7];
      final category = _mostCommonCategory(entry.value) ?? ReminderCategory.shopping;
      final place = sample.locationName ?? 'this place';

      suggestions.add(SmartSuggestion(
        title: 'Smart Suggestion',
        message:
            "You've visited $place ${entry.value.length} times on ${dayName}s. Create a recurring reminder?",
        latitude: sample.latitude,
        longitude: sample.longitude,
        locationName: sample.locationName,
        category: category,
      ));
    }

    // Cap so the home screen isn't flooded.
    suggestions.sort((a, b) => a.title.compareTo(b.title));
    return suggestions.take(3).toList();
  }

  ReminderCategory? _mostCommonCategory(List<LocationVisit> visits) {
    final counts = <String, int>{};
    for (final v in visits) {
      if (v.category == null) continue;
      counts[v.category!] = (counts[v.category!] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final topName = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return ReminderCategory.values.where((c) => c.name == topName).firstOrNull;
  }

  // --- Feature 7 — Intelligent Reminder Priority --------------------------

  static const _urgentKeywords = [
    'submit', 'deadline', 'urgent', 'exam', 'due', 'pay', 'payment', 'bill',
    'interview', 'meeting', 'appointment', 'emergency', 'important', 'asap',
  ];
  static const _lowKeywords = [
    'snack', 'browse', 'casual', 'someday', 'maybe', 'watch', 'chill',
  ];

  /// Suggests a priority from the reminder's title/description text and how
  /// soon its due date is, so the user doesn't have to think about it
  /// manually every time (they can still override it).
  ReminderPriority suggestPriority(String title, {String? description, DateTime? dueDate}) {
    final text = '$title ${description ?? ''}'.toLowerCase();
    var score = 0;

    if (_urgentKeywords.any(text.contains)) score += 2;
    if (_lowKeywords.any(text.contains)) score -= 1;

    if (dueDate != null) {
      final hoursUntilDue = dueDate.difference(DateTime.now()).inHours;
      if (hoursUntilDue <= 24) {
        score += 2;
      } else if (hoursUntilDue <= 72) {
        score += 1;
      }
    }

    if (score >= 2) return ReminderPriority.high;
    if (score <= -1) return ReminderPriority.low;
    return ReminderPriority.medium;
  }

  // --- Feature 12 — Reminder Relevance Score -------------------------------

  /// A 0-100 score blending distance, priority, due-date urgency, and how
  /// often the reminder has been missed — higher means "show/act on this
  /// first". Used both to order the home list and to rank notifications.
  double relevanceScore(Reminder reminder, {Position? currentPosition}) {
    double score = 0;

    switch (reminder.priority) {
      case ReminderPriority.high:
        score += 40;
        break;
      case ReminderPriority.medium:
        score += 25;
        break;
      case ReminderPriority.low:
        score += 10;
        break;
    }

    if (reminder.dueDate != null) {
      final hours = reminder.dueDate!.difference(DateTime.now()).inHours;
      if (hours <= 0) {
        score += 25; // overdue
      } else if (hours <= 24) {
        score += 20;
      } else if (hours <= 72) {
        score += 10;
      }
    }

    if (currentPosition != null) {
      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        reminder.latitude,
        reminder.longitude,
      );
      if (distance <= reminder.radius) {
        score += 20;
      } else if (distance <= reminder.radius * 3) {
        score += 10;
      }
    }

    // A reminder that keeps getting missed is arguably more, not less,
    // relevant to surface prominently.
    score += (reminder.missedCount.clamp(0, 5)) * 2;

    return score.clamp(0, 100).toDouble();
  }

  List<Reminder> rankByRelevance(List<Reminder> reminders, {Position? currentPosition}) {
    final copy = [...reminders];
    copy.sort((a, b) => relevanceScore(b, currentPosition: currentPosition)
        .compareTo(relevanceScore(a, currentPosition: currentPosition)));
    return copy;
  }

  // --- Feature 13 — Intelligent Notification Ranking -----------------------

  /// Orders a batch of simultaneously-triggered reminders (e.g. arriving
  /// somewhere with 5 pending reminders) so the most urgent appears first
  /// in a bundled notification, instead of database/insertion order.
  List<Reminder> rankForNotification(List<Reminder> triggered) {
    final copy = [...triggered];
    copy.sort((a, b) {
      final priorityCompare = b.priority.index.compareTo(a.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      return relevanceScore(b).compareTo(relevanceScore(a));
    });
    return copy;
  }

  // --- Feature 14 — Reminder Dependency System -----------------------------

  bool dependenciesSatisfied(Reminder reminder, List<Reminder> all) {
    if (reminder.dependsOn.isEmpty) return true;
    for (final depId in reminder.dependsOn) {
      final dep = all.where((r) => r.id == depId).firstOrNull;
      if (dep == null) continue; // dangling reference — don't block forever
      if (!dep.isCompleted) return false;
    }
    return true;
  }

  // --- Feature 16/17 — Missed Reminder Prediction + Smart Rescheduling ----

  Future<List<MissedReminderSuggestion>> getMissedReminderSuggestions(
    List<Reminder> reminders, {
    int missThreshold = 2,
  }) async {
    final candidates = reminders.where((r) => r.missedCount >= missThreshold && !r.isCompleted);
    final visits = await _db.getRecentVisits();
    final results = <MissedReminderSuggestion>[];

    for (final reminder in candidates) {
      final nearbyVisits = visits.where((v) =>
          Geolocator.distanceBetween(v.latitude, v.longitude, reminder.latitude, reminder.longitude) <=
          200);

      DateTime suggested;
      if (nearbyVisits.isNotEmpty) {
        // Most common weekday+hour this place is actually visited.
        final counts = <String, int>{};
        for (final v in nearbyVisits) {
          counts['${v.weekday}|${v.hour}'] = (counts['${v.weekday}|${v.hour}'] ?? 0) + 1;
        }
        final topKey = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        final parts = topKey.split('|');
        final targetWeekday = int.parse(parts[0]);
        final targetHour = int.parse(parts[1]);

        final now = DateTime.now();
        var delta = targetWeekday - now.weekday;
        if (delta <= 0) delta += 7;
        final targetDate = now.add(Duration(days: delta));
        suggested = DateTime(targetDate.year, targetDate.month, targetDate.day, targetHour);
      } else {
        suggested = DateTime.now().add(const Duration(days: 1));
      }

      const dayNames = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
      ];
      final dayName = dayNames[(suggested.weekday - 1) % 7];
      final hourLabel = TimeOfDayLabel.format(suggested.hour);

      results.add(MissedReminderSuggestion(
        reminder: reminder,
        message:
            'You missed "${reminder.title}" ${reminder.missedCount} times. Reschedule for $dayName around $hourLabel?',
        suggestedDateTime: suggested,
      ));
    }

    return results;
  }

  // --- Feature 15 — Personalized Productivity Insights ---------------------

  Future<List<Insight>> generateInsights(List<Reminder> allReminders) async {
    final insights = <Insight>[];
    if (allReminders.isEmpty) return insights;

    final byCategory = <ReminderCategory, List<Reminder>>{};
    for (final r in allReminders) {
      byCategory.putIfAbsent(r.category, () => []).add(r);
    }

    final rates = <ReminderCategory, double>{};
    byCategory.forEach((cat, list) {
      final completed = list.where((r) => r.isCompleted).length;
      rates[cat] = list.isEmpty ? 0 : completed / list.length;
    });

    if (rates.length >= 2) {
      final sorted = rates.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final best = sorted.first;
      final worst = sorted.last;
      if (best.value - worst.value > 0.15) {
        insights.add(Insight(
          'You complete ${(best.value * 100).round()}% of your ${best.key.name} reminders '
          'but only ${(worst.value * 100).round()}% of your ${worst.key.name} ones.',
        ));
        insights.add(Insight(
          'Consider a larger radius or a better-timed reminder for ${worst.key.name}.',
          emoji: '📈',
        ));
      }
    }

    final missedTotal = allReminders.fold<int>(0, (sum, r) => sum + r.missedCount);
    if (missedTotal > 0) {
      insights.add(Insight(
        "You've missed $missedTotal reminder${missedTotal == 1 ? '' : 's'} recently — "
        'SmartSpot can suggest better times for the ones you keep missing.',
        emoji: '🔮',
      ));
    }

    final highPriorityPending = allReminders
        .where((r) => r.priority == ReminderPriority.high && !r.isCompleted)
        .length;
    if (highPriorityPending > 0) {
      insights.add(Insight(
        'You have $highPriorityPending high-priority reminder${highPriorityPending == 1 ? '' : 's'} still pending.',
        emoji: '🔴',
      ));
    }

    return insights;
  }

  // --- Feature 3 — Multi-Condition Reminders -------------------------------

  /// Evaluates every extra condition attached to a reminder (beyond the
  /// base geofence check). All conditions must pass (AND semantics) for
  /// the reminder to be allowed to trigger. Any signal the caller couldn't
  /// supply (e.g. no weather reading available yet) is treated as *not*
  /// blocking, so a transient API failure doesn't permanently suppress a
  /// reminder — it just skips that particular condition.
  static bool evaluateConditions(
    List<ReminderCondition> conditions, {
    required DateTime now,
    WeatherCondition? weather,
    bool? isApproaching,
    UserActivity? activity,
  }) {
    for (final condition in conditions) {
      final minutesNow = now.hour * 60 + now.minute;
      switch (condition.type) {
        case ConditionType.timeAfter:
          if (minutesNow < (condition.minutesSinceMidnight ?? 0)) return false;
          break;
        case ConditionType.timeBefore:
          if (minutesNow > (condition.minutesSinceMidnight ?? 24 * 60)) return false;
          break;
        case ConditionType.dayOfWeek:
          if (now.weekday != condition.weekday) return false;
          break;
        case ConditionType.weatherIsRain:
          if (weather != null &&
              weather != WeatherCondition.rain &&
              weather != WeatherCondition.storm) {
            return false;
          }
          break;
        case ConditionType.weatherIsClear:
          if (weather != null && weather != WeatherCondition.clear) return false;
          break;
        case ConditionType.approachingDestination:
          if (isApproaching == false) return false;
          break;
        case ConditionType.activityIs:
          // `activity` (UserActivity, from adaptive_service.dart) and
          // `condition.activity` (RequiredActivity, from the models layer —
          // kept separate so models/ doesn't depend on services/) are two
          // different enum types by design, so compare by name rather than
          // by identity/index.
          if (activity != null &&
              condition.activity != null &&
              activity.name != condition.activity!.name) {
            return false;
          }
          break;
      }
    }
    return true;
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Small formatting helper shared by the missed-reminder suggestion text.
class TimeOfDayLabel {
  static String format(int hour24) {
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final h12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$h12:00 $period';
  }
}
