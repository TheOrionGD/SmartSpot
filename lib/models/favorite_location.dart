/// A saved place the user visits often (e.g. "Home", "College Gate",
/// "Usual Supermarket") that can be quickly reused when creating a reminder.
///
/// NOTE: held in memory for now via FavoritesProvider — persist to SQLite
/// when wiring the backend tonight.
class FavoriteLocation {
  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final String? address;
  final String icon;

  const FavoriteLocation({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    this.address,
    this.icon = '📍',
  });
}
