/// A single "you were here" sample, logged whenever the user enters a
/// reminder's geofence or lingers near a frequently-visited spot. This is
/// the raw material for [IntelligenceService]'s pattern analysis: frequent
/// locations, predictive suggestions, and per-category insights.
class LocationVisit {
  final int? id;
  final double latitude;
  final double longitude;
  final String? locationName;
  final String? category; // ReminderCategory name, if known
  final DateTime timestamp;

  LocationVisit({
    this.id,
    required this.latitude,
    required this.longitude,
    this.locationName,
    this.category,
    required this.timestamp,
  });

  int get weekday => timestamp.weekday; // Monday = 1 ... Sunday = 7
  int get hour => timestamp.hour;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'category': category,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LocationVisit.fromMap(Map<String, dynamic> map) {
    return LocationVisit(
      id: map['id'] as int?,
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      locationName: map['locationName'],
      category: map['category'],
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}
