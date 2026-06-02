import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/place_info.dart';

class PlaceService {
  static const _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const _overpassBase = 'https://overpass-api.de/api/interpreter';
  static const _wikimediaBase = 'https://en.wikipedia.org/api/rest_v1';
  static const _headers = {'User-Agent': 'Mapku Flutter App'};

  /// Ambil info lengkap tempat dari koordinat yang di-tap
  static Future<PlaceInfo?> getPlaceInfo(LatLng point) async {
    try {
      // 1. Reverse geocode dulu untuk nama & alamat dasar
      final revUrl = Uri.parse(
        '$_nominatimBase/reverse'
        '?lat=${point.latitude}&lon=${point.longitude}'
        '&format=json&addressdetails=1&extratags=1&namedetails=1',
      );
      final revRes = await http.get(revUrl, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (revRes.statusCode != 200) return null;

      final revData = jsonDecode(revRes.body);
      final osmId = revData['osm_id']?.toString() ?? '';
      final osmType = revData['osm_type']?.toString() ?? '';
      final extratags = revData['extratags'] as Map<String, dynamic>? ?? {};
      final address = revData['address'] as Map<String, dynamic>? ?? {};

      // Tentukan nama tampilan
      final name = revData['name']?.toString().isNotEmpty == true
          ? revData['name'].toString()
          : _buildNameFromAddress(address);

      // Alamat singkat
      final shortAddress = _buildShortAddress(address);

      // Kategori dari type
      final category = _categoryFromType(revData['type']?.toString() ?? '',
          revData['class']?.toString() ?? '');

      // Ambil detail tambahan dari extratags
      final phone = extratags['phone']?.toString() ?? extratags['contact:phone']?.toString();
      final website = extratags['website']?.toString() ?? extratags['contact:website']?.toString();
      final openingHours = extratags['opening_hours']?.toString();

      // 2. Coba ambil detail OSM via Overpass jika ada OSM ID
      String? overpassPhone = phone;
      String? overpassWebsite = website;
      String? overpassHours = openingHours;

      if (osmId.isNotEmpty && osmType.isNotEmpty) {
        try {
          final osmTypeShort = osmType == 'node' ? 'node' : osmType == 'way' ? 'way' : 'relation';
          final query = '[out:json];$osmTypeShort($osmId);out tags;';
          final ovRes = await http.post(
            Uri.parse(_overpassBase),
            body: 'data=${Uri.encodeComponent(query)}',
          ).timeout(const Duration(seconds: 8));

          if (ovRes.statusCode == 200) {
            final ovData = jsonDecode(ovRes.body);
            final elements = ovData['elements'] as List?;
            if (elements != null && elements.isNotEmpty) {
              final tags = elements[0]['tags'] as Map<String, dynamic>? ?? {};
              overpassPhone ??= tags['phone']?.toString() ?? tags['contact:phone']?.toString();
              overpassWebsite ??= tags['website']?.toString() ?? tags['contact:website']?.toString();
              overpassHours ??= tags['opening_hours']?.toString();
            }
          }
        } catch (_) {}
      }

      // 3. Coba ambil foto & ringkasan dari Wikipedia (untuk tempat terkenal)
      String? wikiSummary;
      String? wikiImageUrl;

      // ignore: unused_local_variable
      final wikiTitle = extratags['wikipedia']?.toString() ??
          extratags['wikidata']?.toString();

      // Coba cari berdasarkan nama di Wikipedia
      final searchName = name.length > 3 ? name : null;
      if (searchName != null) {
        try {
          final wikiSearchUrl = Uri.parse(
            'https://en.wikipedia.org/w/api.php'
            '?action=query&list=search&srsearch=${Uri.encodeComponent(searchName)}'
            '&format=json&srlimit=1',
          );
          final wikiSearchRes = await http.get(wikiSearchUrl, headers: _headers)
              .timeout(const Duration(seconds: 6));

          if (wikiSearchRes.statusCode == 200) {
            final wikiSearchData = jsonDecode(wikiSearchRes.body);
            final searchResults = wikiSearchData['query']?['search'] as List?;
            if (searchResults != null && searchResults.isNotEmpty) {
              final pageTitle = searchResults[0]['title']?.toString() ?? '';
              if (pageTitle.isNotEmpty) {
                // Ambil summary
                final summaryUrl = Uri.parse(
                  '$_wikimediaBase/page/summary/${Uri.encodeComponent(pageTitle)}',
                );
                final summaryRes = await http.get(summaryUrl, headers: _headers)
                    .timeout(const Duration(seconds: 6));

                if (summaryRes.statusCode == 200) {
                  final summaryData = jsonDecode(summaryRes.body);
                  final extract = summaryData['extract']?.toString() ?? '';
                  if (extract.isNotEmpty && extract.length > 30) {
                    wikiSummary = extract.length > 200
                        ? '${extract.substring(0, 200)}...'
                        : extract;
                  }
                  wikiImageUrl = summaryData['thumbnail']?['source']?.toString();
                }
              }
            }
          }
        } catch (_) {}
      }

      return PlaceInfo(
        name: name,
        address: shortAddress,
        category: category,
        phone: overpassPhone,
        website: overpassWebsite,
        openingHours: overpassHours,
        wikiSummary: wikiSummary,
        wikiImageUrl: wikiImageUrl,
        lat: point.latitude,
        lon: point.longitude,
      );
    } catch (e) {
      return null;
    }
  }

  static String _buildNameFromAddress(Map<String, dynamic> addr) {
    return addr['amenity']?.toString() ??
        addr['shop']?.toString() ??
        addr['tourism']?.toString() ??
        addr['building']?.toString() ??
        addr['road']?.toString() ??
        addr['suburb']?.toString() ??
        addr['city']?.toString() ??
        'Lokasi ini';
  }

  static String _buildShortAddress(Map<String, dynamic> addr) {
    final parts = <String>[];
    final road = addr['road']?.toString();
    final suburb = addr['suburb']?.toString() ?? addr['neighbourhood']?.toString();
    final city = addr['city']?.toString() ?? addr['town']?.toString() ?? addr['village']?.toString();
    final state = addr['state']?.toString();

    if (road != null) parts.add(road);
    if (suburb != null) parts.add(suburb);
    if (city != null) parts.add(city);
    if (state != null && parts.length < 3) parts.add(state);

    return parts.isEmpty ? 'Alamat tidak tersedia' : parts.join(', ');
  }

  static String _categoryFromType(String type, String osmClass) {
    final map = {
      'restaurant': '🍽️ Restoran',
      'cafe': '☕ Kafe',
      'fast_food': '🍔 Fast Food',
      'hospital': '🏥 Rumah Sakit',
      'pharmacy': '💊 Apotek',
      'school': '🏫 Sekolah',
      'university': '🎓 Universitas',
      'mosque': '🕌 Masjid',
      'church': '⛪ Gereja',
      'bank': '🏦 Bank',
      'atm': '🏧 ATM',
      'fuel': '⛽ SPBU',
      'supermarket': '🛒 Supermarket',
      'hotel': '🏨 Hotel',
      'park': '🌳 Taman',
      'parking': '🅿️ Parkir',
      'police': '👮 Polisi',
      'fire_station': '🚒 Pemadam',
      'cinema': '🎬 Bioskop',
      'mall': '🏬 Mall',
      'airport': '✈️ Bandara',
      'bus_station': '🚌 Terminal Bus',
      'train_station': '🚆 Stasiun',
      'residential': '🏘️ Perumahan',
      'commercial': '🏪 Komersial',
      'industrial': '🏭 Industri',
    };

    return map[type] ?? map[osmClass] ?? '📍 Tempat';
  }
}