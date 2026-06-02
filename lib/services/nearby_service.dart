import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NearbyPlace {
  final String name;
  final String category;
  final String emoji;
  final double lat;
  final double lon;
  final double distanceMeters;
  final String? address;

  NearbyPlace({
    required this.name,
    required this.category,
    required this.emoji,
    required this.lat,
    required this.lon,
    required this.distanceMeters,
    this.address,
  });

  LatLng get latLng => LatLng(lat, lon);

  String get distanceText {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.toInt()} m';
  }
}

const _nearbyCategories = [
  {
    'key': 'restaurant',
    'label': 'Restoran',
    'emoji': '🍽️',
    // tambah food_court, fast_food, warung
    'amenity': 'restaurant|fast_food|food_court|cafe',
  },
  {
    'key': 'cafe',
    'label': 'Kafe',
    'emoji': '☕',
    'amenity': 'cafe|juice_bar|bubble_tea',
  },
  {
    'key': 'hospital',
    'label': 'RS / Klinik',
    'emoji': '🏥',
    'amenity': 'hospital|clinic|doctors|dentist|health_post',
  },
  {
    'key': 'pharmacy',
    'label': 'Apotek',
    'emoji': '💊',
    'amenity': 'pharmacy|drug_store',
  },
  {
    'key': 'fuel',
    'label': 'SPBU',
    'emoji': '⛽',
    'amenity': 'fuel',
  },
  {
    'key': 'atm',
    'label': 'ATM',
    'emoji': '🏧',
    'amenity': 'atm|bank',
  },
  {
    'key': 'supermarket',
    'label': 'Minimarket',
    'emoji': '🛒',
    // minimarket adalah tag utama Indomaret/Alfamart di Indonesia
    'shop': 'supermarket|convenience|minimarket|grocery',
  },
  {
    'key': 'mosque',
    'label': 'Masjid',
    'emoji': '🕌',
    'amenity': 'place_of_worship',
    'religion': 'muslim', // dipakai di _buildQuery sekarang
  },
  {
    'key': 'hotel',
    'label': 'Hotel',
    'emoji': '🏨',
    'tourism': 'hotel|motel|guest_house|hostel',
  },
  {
    'key': 'school',
    'label': 'Sekolah',
    'emoji': '🏫',
    'amenity': 'school|kindergarten|college|university',
  },
];

class NearbyService {
  static const _overpass = 'https://overpass-api.de/api/interpreter';
  static const _defaultRadius = 1500;

  static List<Map<String, dynamic>> get categories => _nearbyCategories;

  static Future<List<NearbyPlace>> getNearby(
    LatLng center, {
    String categoryKey = 'restaurant',
    int radius = _defaultRadius,
  }) async {
    final cat = _nearbyCategories.firstWhere(
      (c) => c['key'] == categoryKey,
      orElse: () => _nearbyCategories.first,
    );

    final query = _buildQuery(center, cat, radius);

    try {
      final res = await http
          .post(
            Uri.parse(_overpass),
            body: 'data=${Uri.encodeComponent(query)}',
          )
          .timeout(const Duration(seconds: 25)); // naikkan timeout

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      final elements = data['elements'] as List? ?? [];

      // Deduplicate by name+koordinat (Overpass kadang return duplikat node+way)
      final seen = <String>{};
      final places = <NearbyPlace>[];

      for (final el in elements) {
        final tags = el['tags'] as Map<String, dynamic>? ?? {};
        final name = tags['name']?.toString();
        if (name == null || name.isEmpty) continue;

        double lat, lon;
        if (el['type'] == 'node') {
          lat = (el['lat'] as num).toDouble();
          lon = (el['lon'] as num).toDouble();
        } else if (el['center'] != null) {
          lat = (el['center']['lat'] as num).toDouble();
          lon = (el['center']['lon'] as num).toDouble();
        } else {
          continue;
        }

        // Skip duplikat (nama + koordinat dibulatkan)
        final key = '$name|${lat.toStringAsFixed(4)}|${lon.toStringAsFixed(4)}';
        if (seen.contains(key)) continue;
        seen.add(key);

        final dist = const Distance().as(
          LengthUnit.Meter,
          center,
          LatLng(lat, lon),
        );

        final street = tags['addr:street']?.toString();
        final city = tags['addr:city']?.toString();
        final addr = [street, city].whereType<String>().join(', ');

        places.add(NearbyPlace(
          name: name,
          category: cat['label'] as String,
          emoji: cat['emoji'] as String,
          lat: lat,
          lon: lon,
          distanceMeters: dist,
          address: addr.isNotEmpty ? addr : null,
        ));
      }

      places.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return places.take(30).toList(); // naikkan dari 20 → 30
    } catch (e) {
      return [];
    }
  }

  static String _buildQuery(
    LatLng center,
    Map<String, dynamic> cat,
    int radius,
  ) {
    final lat = center.latitude;
    final lon = center.longitude;
    final filters = <String>[];

    if (cat['amenity'] != null) {
      final values = (cat['amenity'] as String).split('|');
      final religion = cat['religion'] as String?;

      for (final v in values) {
        if (religion != null) {
          // Filter tambahan religion (untuk masjid)
          filters.add('node["amenity"="$v"]["religion"="$religion"](around:$radius,$lat,$lon);');
          filters.add('way["amenity"="$v"]["religion"="$religion"](around:$radius,$lat,$lon);');
        } else {
          filters.add('node["amenity"="$v"](around:$radius,$lat,$lon);');
          filters.add('way["amenity"="$v"](around:$radius,$lat,$lon);');
        }
      }
    }

    if (cat['shop'] != null) {
      final values = (cat['shop'] as String).split('|');
      for (final v in values) {
        // tambah way supaya bangunan minimarket juga ke-detect
        filters.add('node["shop"="$v"](around:$radius,$lat,$lon);');
        filters.add('way["shop"="$v"](around:$radius,$lat,$lon);');
      }
    }

    if (cat['tourism'] != null) {
      final values = (cat['tourism'] as String).split('|');
      for (final v in values) {
        filters.add('node["tourism"="$v"](around:$radius,$lat,$lon);');
        filters.add('way["tourism"="$v"](around:$radius,$lat,$lon);');
      }
    }

    if (filters.isEmpty) {
      filters.add('node["amenity"](around:$radius,$lat,$lon);');
    }

    // timeout dinaikkan jadi 25 detik sesuai http timeout
    return '[out:json][timeout:25];(${filters.join('')});out center tags;';
  }
}