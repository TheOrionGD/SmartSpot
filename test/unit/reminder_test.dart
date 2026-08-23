import 'package:flutter_test/flutter_test.dart';
import 'package:smartspot/models/reminder.dart';
import 'package:smartspot/models/reminder_condition.dart';

void main() {
  group('Reminder Model Unit Tests', () {
    final now = DateTime(2026, 8, 23, 10, 0);

    test('creates Reminder with default values', () {
      final reminder = Reminder(
        id: 'rem-1',
        title: 'Submit Lab Report',
        latitude: 12.9716,
        longitude: 77.5946,
        createdAt: now,
      );

      expect(reminder.id, 'rem-1');
      expect(reminder.title, 'Submit Lab Report');
      expect(reminder.category, ReminderCategory.shopping);
      expect(reminder.priority, ReminderPriority.medium);
      expect(reminder.isCompleted, false);
      expect(reminder.isArchived, false);
      expect(reminder.repeatType, ReminderRepeatType.once);
    });

    test('serializes toMap and deserializes fromMap accurately', () {
      final reminder = Reminder(
        id: 'rem-101',
        title: 'Buy Groceries',
        description: 'Milk, Eggs, Bread',
        latitude: 13.0827,
        longitude: 80.2707,
        locationName: 'Supermarket',
        radius: 200,
        category: ReminderCategory.shopping,
        priority: ReminderPriority.high,
        createdAt: now,
        dueDate: now.add(const Duration(days: 1)),
        isCompleted: false,
        isArchived: false,
        notifyOnEnter: true,
        notifyOnExit: false,
        routeAware: true,
        weatherAware: true,
        conditions: [ReminderCondition.rain()],
        missedCount: 1,
        dependsOn: ['rem-100'],
        adaptiveRadius: true,
        repeatType: ReminderRepeatType.weekdays,
        repeatDays: {1, 2, 3, 4, 5},
      );

      final map = reminder.toMap();
      expect(map['id'], 'rem-101');
      expect(map['category'], 'shopping');
      expect(map['priority'], 'high');
      expect(map['repeatType'], 'weekdays');

      final reconstructed = Reminder.fromMap(map);
      expect(reconstructed.id, reminder.id);
      expect(reconstructed.title, reminder.title);
      expect(reconstructed.description, reminder.description);
      expect(reconstructed.latitude, reminder.latitude);
      expect(reconstructed.longitude, reminder.longitude);
      expect(reconstructed.category, reminder.category);
      expect(reconstructed.priority, reminder.priority);
      expect(reconstructed.routeAware, true);
      expect(reconstructed.weatherAware, true);
      expect(reconstructed.adaptiveRadius, true);
      expect(reconstructed.conditions.length, 1);
      expect(reconstructed.dependsOn, ['rem-100']);
    });

    test('isDueOn evaluates correctly for weekdays and weekends', () {
      final weekdayReminder = Reminder(
        id: 'rem-w',
        title: 'Campus Attendance',
        latitude: 12.0,
        longitude: 77.0,
        createdAt: now,
        repeatType: ReminderRepeatType.weekdays,
      );

      final monday = DateTime(2026, 8, 24); // Monday
      final sunday = DateTime(2026, 8, 30); // Sunday

      expect(weekdayReminder.isDueOn(monday), true);
      expect(weekdayReminder.isDueOn(sunday), false);
    });

    test('copyWith updates specified fields correctly', () {
      final original = Reminder(
        id: 'rem-1',
        title: 'Original Title',
        latitude: 10.0,
        longitude: 20.0,
        createdAt: now,
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        isCompleted: true,
      );

      expect(updated.id, 'rem-1');
      expect(updated.title, 'Updated Title');
      expect(updated.isCompleted, true);
      expect(updated.latitude, 10.0);
    });
  });
}
