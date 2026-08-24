import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../utils/permission_helper.dart';
import '../utils/app_theme.dart';

/// Result returned to the caller when a location is confirmed.
class PickedLocation {
  final double latitude;
  final double longitude;
  final String address;

  const PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

/// A single search suggestion returned by the Nominatim search API.
class _SearchResult {
  final String displayName;
  final double latitude;
  final double longitude;

  const _SearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  factory _SearchResult.fromJson(Map<String, dynamic> json) {
    return _SearchResult(
      displayName: json['display_name'] as String,
      latitude: double.parse(json['lat'] as String),
      longitude: double.parse(json['lon'] as String),
    );
  }
}

class MapScreen extends StatefulWidget {
  /// Optional starting point, e.g. when editing an existing reminder.
  final double? initialLatitude;
  final double? initialLongitude;

  const MapScreen({super.key, this.initialLatitude, this.initialLongitude});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const ll.LatLng _fallback = ll.LatLng(11.3410, 77.7172); // Erode, TN fallback

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  ll.LatLng _selectedPosition = _fallback;
  String _address = 'Move the map or tap to pick a location';
  bool _isLocating = false;
  bool _isResolvingAddress = false;

  List<_SearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPosition = ll.LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _resolveAddress(_selectedPosition);
    } else {
      _useCurrentLocation();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress(ll.LatLng position) async {
    setState(() => _isResolvingAddress = true);
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.name, p.street, p.locality, p.administrativeArea]
            .where((e) => e != null && e.isNotEmpty)
            .toSet()
            .toList();
        if (mounted) {
          setState(() {
            _address = parts.isNotEmpty
                ? parts.join(', ')
                : '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
          });
        }
        return;
      }
    } catch (_) {
      // Fallback for Web/Desktop where native geocoding is unsupported
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'lat': position.latitude.toString(),
          'lon': position.longitude.toString(),
          'format': 'json',
        });
        final response = await http.get(
          uri,
          headers: {'User-Agent': 'com.smartspot.app (SmartSpot Flutter app)'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final displayName = data['display_name'] as String?;
          if (displayName != null && displayName.isNotEmpty) {
            if (mounted) {
              setState(() {
                _address = displayName;
              });
            }
            return;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _address =
              '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        });
      }
    } finally {
      if (mounted) setState(() => _isResolvingAddress = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final granted = await PermissionHelper.requestLocationPermission(context);
      if (!granted) {
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final target = ll.LatLng(position.latitude, position.longitude);
      setState(() => _selectedPosition = target);
      _mapController.move(target, 16);
      await _resolveAddress(target);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get current location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Called continuously while the map moves/pans.
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _selectedPosition = camera.center;
  }

  /// flutter_map has no built-in "camera idle" callback, so we debounce
  /// address lookups: only resolve once the user's gesture ends.
  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
      _resolveAddress(_selectedPosition);
    }
  }

  /// Debounced text search — waits until the user pauses typing before
  /// hitting the network, so we don't fire a request per keystroke.
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPlaces(query);
    });
  }

  /// Queries OpenStreetMap's free Nominatim search API for places/shops
  /// matching [query]. No API key required.
  Future<void> _searchPlaces(String query) async {
    setState(() => _isSearching = true);
    try {
      // Biasing results loosely around the current map centre helps surface
      // nearby shops/places first when the query is generic (e.g. "pharmacy").
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'addressdetails': '0',
        'limit': '8',
        'viewbox':
        '${_selectedPosition.longitude - 0.3},${_selectedPosition.latitude + 0.3},'
            '${_selectedPosition.longitude + 0.3},${_selectedPosition.latitude - 0.3}',
        'bounded': '0',
      });

      final response = await http.get(
        uri,
        // Nominatim's usage policy requires a descriptive User-Agent.
        headers: {'User-Agent': 'com.smartspot.app (SmartSpot Flutter app)'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final results = data
            .map((e) => _SearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() => _searchResults = results);
      } else {
        if (mounted) setState(() => _searchResults = []);
      }
    } catch (_) {
      if (mounted) setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(_SearchResult result) {
    final target = ll.LatLng(result.latitude, result.longitude);
    setState(() {
      _selectedPosition = target;
      _address = result.displayName;
      _searchResults = [];
    });
    _searchController.text = result.displayName;
    _searchFocusNode.unfocus();
    _mapController.move(target, 17);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchResults = []);
    _searchFocusNode.unfocus();
  }

  void _confirmSelection() {
    Navigator.pop(
      context,
      PickedLocation(
        latitude: _selectedPosition.latitude,
        longitude: _selectedPosition.longitude,
        address: _address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition,
              initialZoom: 15,
              onPositionChanged: _onPositionChanged,
              onMapEvent: _onMapEvent,
              onTap: (_, __) => _searchFocusNode.unfocus(),
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.smartspot.app',
                maxZoom: 20,
                retinaMode: true, // serves sharp @2x tiles on high-density screens
              ),
            ],
          ),
          // Fixed centre pin — the map moves underneath it.
          const Padding(
            padding: EdgeInsets.only(bottom: 36),
            child: Icon(Icons.location_on_rounded, size: 44, color: AppColors.error),
          ),

          // --- Search bar + results dropdown ---
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(20),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search for a place or shop',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : (_searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                          : null),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: const Icon(Icons.place_outlined, color: AppColors.primary),
                          title: Text(
                            result.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5),
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          Positioned(
            right: 16,
            bottom: 160,
            child: FloatingActionButton(
              heroTag: 'current_location_fab',
              mini: true,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              onPressed: _isLocating ? null : _useCurrentLocation,
              child: _isLocating
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _isResolvingAddress
                              ? const Text('Locating address…')
                              : Text(
                            _address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _confirmSelection,
                            child: const Center(
                              child: Text(
                                'Confirm Location',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}