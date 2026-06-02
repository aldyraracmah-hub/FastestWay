import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_info.dart';

class GeocodingService {
  static Future<String> reverseGeocode(LatLng point) =>
      RoutingService.reverseGeocode(point);

  static Future<LatLng?> searchPlace(String query) async {
    final results = await RoutingService.searchPlaces(query);
    return results.isNotEmpty ? results.first.latLng : null;
  }
}

class RoutingService {
  static const String _valhallaBase = 'https://valhalla1.openstreetmap.de';

  static Future<RouteInfo?> getRouteWithWaypoints(
  List<LatLng> stops, {
  String mode = 'shortcut',
}) async {
  if (stops.length < 2) return null;
  try {
    double useHighways;
    double useTolls = 0.0;
    if (mode == 'shortcut') {
      useHighways = 0.0;
    } else if (mode == 'fastest') {
      useHighways = 0.5;
    } else {
      useHighways = 1.0;
      useTolls = 1.0;
    }

    final locations = stops
        .map((s) => {'lon': s.longitude, 'lat': s.latitude})
        .toList();

    final body = jsonEncode({
      'locations': locations,
      'costing': 'auto',
      'costing_options': {
        'auto': {'use_highways': useHighways, 'use_tolls': useTolls, 'top_speed': 80}
      },
      'directions_options': {'language': 'id-ID', 'units': 'kilometers'},
    });

    final response = await http.post(
      Uri.parse('$_valhallaBase/route'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data['trip'] == null) return null;

    final legs = data['trip']['legs'] as List;
    final allPoints = <LatLng>[];
    double totalDistance = 0;
    double totalDuration = 0;
    final instructions = <String>[];

    for (final leg in legs) {
      allPoints.addAll(_decodePolyline(leg['shape'] as String));
      final summary = leg['summary'];
      totalDistance += (summary['length'] as num).toDouble() * 1000;
      totalDuration += (summary['time'] as num).toDouble();
      for (final m in (leg['maneuvers'] as List)) {
        final text = m['instruction']?.toString() ?? '';
        if (text.isNotEmpty) instructions.add(text);
      }
    }

    return RouteInfo(
      points: allPoints,
      distanceMeters: totalDistance,
      durationSeconds: totalDuration,
      instructions: instructions,
    );
  } catch (e) {
    return null;
  }
}

  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    final factor = 1.0 / pow(10, 6);
    while (index < encoded.length) {
      int shift = 0, result = 0, byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(lat * factor, lng * factor));
    }
    return points;
  }

  /// Search places using Nominatim
  static Future<List<SearchResult>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=5&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'Mapku Flutter App'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as List;
      return data.map((e) => SearchResult.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Reverse geocode a coordinate to address
  static Future<String> reverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${point.latitude}&lon=${point.longitude}'
        '&format=json',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'Mapku Flutter App'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return 'Lokasi tidak diketahui';

      final data = jsonDecode(response.body);
      return data['display_name'] ?? 'Lokasi tidak diketahui';
    } catch (e) {
      return 'Lokasi tidak diketahui';
    }
  }
}