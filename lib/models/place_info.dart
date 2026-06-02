class PlaceInfo {
  final String name;
  final String address;
  final String category;
  final String? phone;
  final String? website;
  final String? openingHours;
  final String? wikiSummary;
  final String? wikiImageUrl;
  final double lat;
  final double lon;

  PlaceInfo({
    required this.name,
    required this.address,
    required this.category,
    this.phone,
    this.website,
    this.openingHours,
    this.wikiSummary,
    this.wikiImageUrl,
    required this.lat,
    required this.lon,
  });
}