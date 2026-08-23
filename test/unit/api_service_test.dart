import 'package:flutter_test/flutter_test.dart';
import 'package:smartspot/services/api_service.dart';
import 'package:smartspot/models/reminder.dart';
import 'package:smartspot/models/favorite_location.dart';

void main() {
  group('ApiService Unit Tests', () {
    test('ApiService singleton instance is provided', () {
      expect(ApiService.instance, isNotNull);
    });

    test('ApiException formats message and status code correctly', () {
      const ex = ApiException('Server error', statusCode: 500);
      expect(ex.toString(), equals('Server error'));
      expect(ex.statusCode, equals(500));
    });

    test('Reminder serialization matches API expectations', () {
      final reminder = Reminder(
        id: 'rem-1',
        title: 'Library Study',
        description: 'Read Chapter 4',
        latitude: 12.9716,
        longitude: 77.5946,
        locationName: 'Campus Library',
        category: ReminderCategory.college,
        priority: ReminderPriority.high,
        radius: 100,
        createdAt: DateTime(2026, 8, 23),
      );

      final map = reminder.toMap();
      expect(map['id'], equals('rem-1'));
      expect(map['title'], equals('Library Study'));
      expect(map['latitude'], equals(12.9716));
      expect(map['longitude'], equals(77.5946));

      final deserialized = Reminder.fromMap(map);
      expect(deserialized.id, equals('rem-1'));
      expect(deserialized.title, equals('Library Study'));
    });

    test('FavoriteLocation model maps correctly for API requests', () {
      final fav = FavoriteLocation(
        id: 'fav-1',
        label: 'Dorm Block C',
        latitude: 12.972,
        longitude: 77.595,
        address: 'Room 302',
        icon: '🏠',
      );

      expect(fav.id, equals('fav-1'));
      expect(fav.label, equals('Dorm Block C'));
      expect(fav.latitude, equals(12.972));
      expect(fav.longitude, equals(77.595));
      expect(fav.address, equals('Room 302'));
      expect(fav.icon, equals('🏠'));
    });
  });
}
