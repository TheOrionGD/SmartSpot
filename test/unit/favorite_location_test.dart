import 'package:flutter_test/flutter_test.dart';
import 'package:smartspot/models/favorite_location.dart';

void main() {
  group('FavoriteLocation Model Unit Tests', () {
    test('creates FavoriteLocation instance with default icon', () {
      const fav = FavoriteLocation(
        id: 'fav-1',
        label: 'Central Library',
        latitude: 12.9716,
        longitude: 77.5946,
        address: 'Main Gate, Campus',
      );

      expect(fav.id, 'fav-1');
      expect(fav.label, 'Central Library');
      expect(fav.latitude, 12.9716);
      expect(fav.longitude, 77.5946);
      expect(fav.address, 'Main Gate, Campus');
      expect(fav.icon, '📍');
    });
  });
}
