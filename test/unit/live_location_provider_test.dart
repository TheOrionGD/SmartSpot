import 'package:flutter_test/flutter_test.dart';
import 'package:smartspot/providers/live_location_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveLocationProvider Unit Tests', () {
    test('formatDistance formats meters and kilometers accurately', () {
      final provider = LiveLocationProvider();
      expect(provider.formatDistance(null), '--');
      expect(provider.formatDistance(0), '0 m');
      expect(provider.formatDistance(450), '450 m');
      expect(provider.formatDistance(1200), '1.2 km');
      expect(provider.formatDistance(5400), '5.4 km');
    });

    test('GeofenceState enum contains expected states', () {
      expect(GeofenceState.values.contains(GeofenceState.inside), true);
      expect(GeofenceState.values.contains(GeofenceState.approaching), true);
      expect(GeofenceState.values.contains(GeofenceState.outside), true);
      expect(GeofenceState.values.contains(GeofenceState.locationUnavailable), true);
    });
  });
}
