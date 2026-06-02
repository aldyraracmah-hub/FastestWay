import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────
//  Model: FavoritePlace
// ─────────────────────────────────────────────────────────────
class FavoritePlace {
  final String id;
  final String name;
  final String address;
  final String icon; // emoji icon
  final double lat;
  final double lon;
  final DateTime savedAt;

  FavoritePlace({
    required this.id,
    required this.name,
    required this.address,
    required this.icon,
    required this.lat,
    required this.lon,
    required this.savedAt,
  });

  LatLng get latLng => LatLng(lat, lon);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'icon': icon,
        'lat': lat,
        'lon': lon,
        'savedAt': savedAt.toIso8601String(),
      };

  factory FavoritePlace.fromJson(Map<String, dynamic> j) => FavoritePlace(
        id: j['id'],
        name: j['name'],
        address: j['address'],
        icon: j['icon'] ?? '📍',
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        savedAt: DateTime.tryParse(j['savedAt'] ?? '') ?? DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────────
//  Model: SearchHistoryItem
// ─────────────────────────────────────────────────────────────
class SearchHistoryItem {
  final String displayName;
  final double lat;
  final double lon;
  final DateTime searchedAt;

  SearchHistoryItem({
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.searchedAt,
  });

  LatLng get latLng => LatLng(lat, lon);

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'lat': lat,
        'lon': lon,
        'searchedAt': searchedAt.toIso8601String(),
      };

  factory SearchHistoryItem.fromJson(Map<String, dynamic> j) =>
      SearchHistoryItem(
        displayName: j['displayName'],
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        searchedAt: DateTime.tryParse(j['searchedAt'] ?? '') ?? DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────────
//  StorageService
// ─────────────────────────────────────────────────────────────
class StorageService {
  static const _keyFavorites = 'mapku_favorites';
  static const _keyHistory = 'mapku_search_history';
  static const _keyTheme = 'mapku_theme_dark';
  static const _keyMapType = 'mapku_map_type';
  static const int _maxHistory = 10;

  // ── Favorites ──────────────────────────────────────────────

  static Future<List<FavoritePlace>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyFavorites) ?? [];
    return raw
        .map((e) => FavoritePlace.fromJson(jsonDecode(e)))
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  static Future<void> addFavorite(FavoritePlace place) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    // Remove duplicate id if exists
    favorites.removeWhere((f) => f.id == place.id);
    favorites.insert(0, place);
    await prefs.setStringList(
      _keyFavorites,
      favorites.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }

  static Future<void> removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    favorites.removeWhere((f) => f.id == id);
    await prefs.setStringList(
      _keyFavorites,
      favorites.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }

  static Future<bool> isFavorite(double lat, double lon) async {
    final favorites = await getFavorites();
    return favorites.any(
      (f) => (f.lat - lat).abs() < 0.0001 && (f.lon - lon).abs() < 0.0001,
    );
  }

  // ── Search History ──────────────────────────────────────────

  static Future<List<SearchHistoryItem>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyHistory) ?? [];
    return raw.map((e) => SearchHistoryItem.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> addSearchHistory(SearchHistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getSearchHistory();
    // Remove duplicate
    history.removeWhere((h) => h.displayName == item.displayName);
    history.insert(0, item);
    // Keep only last N
    final trimmed = history.take(_maxHistory).toList();
    await prefs.setStringList(
      _keyHistory,
      trimmed.map((h) => jsonEncode(h.toJson())).toList(),
    );
  }

  static Future<void> clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistory);
  }

  // ── Theme ──────────────────────────────────────────────────

  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTheme) ?? true; // default dark
  }

  static Future<void> setDarkMode(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTheme, dark);
  }

  // ── Map Type ───────────────────────────────────────────────

  static Future<String> getMapType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMapType) ?? 'standard';
  }

  static Future<void> setMapType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMapType, type);
  }
}