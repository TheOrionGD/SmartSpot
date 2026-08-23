import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/favorite_location.dart';
import '../providers/favorites_provider.dart';
import '../utils/app_theme.dart';
import 'map_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  Future<void> _addFavorite(BuildContext context) async {
    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
    if (result == null) return;

    if (!context.mounted) return;

    final labelController = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Name this place'),
        content: TextField(
          controller: labelController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Home, College Gate, Usual Store',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, labelController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (label == null || label.isEmpty || !context.mounted) return;

    context.read<FavoritesProvider>().addFavorite(
          FavoriteLocation(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: label,
            latitude: result.latitude,
            longitude: result.longitude,
            address: result.address,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorite Locations')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addFavorite(context),
        child: const Icon(Icons.add_location_alt),
      ),
      body: Consumer<FavoritesProvider>(
        builder: (context, provider, child) {
          if (provider.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star_border, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No favorite locations yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Save places you visit often — like home, college, or your '
                      'go-to store — to pick them instantly when adding reminders.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: provider.favorites.length,
            itemBuilder: (context, index) {
              final fav = provider.favorites[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(fav.icon),
                  ),
                  title: Text(fav.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    fav.address ??
                        '${fav.latitude.toStringAsFixed(5)}, ${fav.longitude.toStringAsFixed(5)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    onPressed: () => provider.removeFavorite(fav.id),
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                      PickedLocation(
                        latitude: fav.latitude,
                        longitude: fav.longitude,
                        address: fav.address ?? fav.label,
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
