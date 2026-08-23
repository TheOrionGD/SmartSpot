import 'package:flutter_test/flutter_test.dart';
import 'package:smartspot/models/location_visit.dart';

void main() {
  group('LocationVisit Model Unit Tests', () {
    final now = DateTime(2026, 8, 23, 14, 30); // Sunday 2:30 PM

    test('serializes toMap and deserializes fromMap accurately', () {
      final visit = LocationVisit(
        id: 42,
        latitude: 12.9716,
        longitude: 77.5946,
        locationName: 'Physics Lab',
        category: 'college',
        timestamp: now,
      );

      expect(visit.weekday, DateTime.sunday);
      expect(visit.hour, 14);

      final map = visit.toMap();
      expect(map['id'], 42);
      expect(map['category'], 'college');

      final reconstructed = LocationVisit.fromMap(map);
      expect(reconstructed.id, visit.id);
      expect(reconstructed.latitude, visit.latitude);
      expect(reconstructed.longitude, visit.longitude);
      expect(reconstructed.locationName, visit.locationName);
      expect(reconstructed.category, visit.category);
    });
  });
}
