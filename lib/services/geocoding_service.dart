import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Simple geocoding service for reverse geocoding and place search
class GeocodingService {
  static const String _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const Map<String, String> _headers = {
    'User-Agent': 'Mapku Flutter App'
  };

  /// Search for a place by name/query and return its coordinates
  static Future<LatLng?> searchPlace(String query) async {
    if (query.trim().isEmpty) return null;

    try {
      final url = Uri.parse(
        '$_nominatimBase/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=1',
      );
      final response = await http.get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) return null;

      final lat = double.tryParse(data[0]['lat'].toString());
      final lon = double.tryParse(data[0]['lon'].toString());

      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }

  /// Reverse geocode coordinates to get place name/address
  static Future<String> reverseGeocode(LatLng latlng) async {
    try {
      final url = Uri.parse(
        '$_nominatimBase/reverse'
        '?lat=${latlng.latitude}&lon=${latlng.longitude}'
        '&format=json&zoom=10&addressdetails=1',
      );
      final response = await http.get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return '${latlng.latitude.toStringAsFixed(4)}, ${latlng.longitude.toStringAsFixed(4)}';
      }

      final data = jsonDecode(response.body);
      final name = data['name']?.toString() ?? '';
      final address = data['address'] as Map<String, dynamic>? ?? {};

      // Build a readable address
      final city = address['city']?.toString() ?? 
                   address['town']?.toString() ?? 
                   address['village']?.toString() ?? '';
      final country = address['country']?.toString() ?? '';

      if (name.isNotEmpty) {
        if (city.isNotEmpty) return '$name, $city';
        return name;
      }

      if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
      if (city.isNotEmpty) return city;

      return '${latlng.latitude.toStringAsFixed(4)}, ${latlng.longitude.toStringAsFixed(4)}';
    } catch (_) {
      return '${latlng.latitude.toStringAsFixed(4)}, ${latlng.longitude.toStringAsFixed(4)}';
    }
  }
}