import 'package:flutter/foundation.dart';
import '../models/favorite_location.dart';
import '../services/api_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService.instance;
  List<FavoriteLocation> _favorites = [];
  bool _isLoading = false;

  List<FavoriteLocation> get favorites => List.unmodifiable(_favorites);
  bool get isLoading => _isLoading;
  bool get isEmpty => _favorites.isEmpty;

  FavoritesProvider() {
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    _isLoading = true;
    notifyListeners();
    try {
      final remote = await _apiService.fetchFavorites();
      if (remote.isNotEmpty) {
        _favorites = remote;
      }
    } catch (e) {
      debugPrint('Skipping remote favorites fetch: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFavorite(FavoriteLocation location) async {
    _favorites.add(location);
    notifyListeners();
    try {
      await _apiService.createFavorite(location);
    } catch (e) {
      debugPrint('Failed to sync favorite to backend: $e');
    }
  }

  Future<void> removeFavorite(String id) async {
    _favorites.removeWhere((f) => f.id == id);
    notifyListeners();
    try {
      await _apiService.deleteFavorite(id);
    } catch (e) {
      debugPrint('Failed to delete favorite on backend: $e');
    }
  }
}
