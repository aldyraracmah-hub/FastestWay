/// Map tile provider configurations.
/// All providers are free / open-access — no API key needed.
class MapTileConfig {
  final String key;
  final String label;
  final String emoji;
  final String urlTemplate;
  final String userAgent;
  final int maxZoom;

  const MapTileConfig({
    required this.key,
    required this.label,
    required this.emoji,
    required this.urlTemplate,
    this.userAgent = 'com.example.mapku',
    this.maxZoom = 19,
  });

  static const standard = MapTileConfig(
    key: 'standard',
    label: 'Standar',
    emoji: '🗺️',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  /// CartoDB Dark Matter — free, no key required
  static const dark = MapTileConfig(
    key: 'dark',
    label: 'Gelap',
    emoji: '🌑',
    urlTemplate:
        'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    userAgent: 'Mapku Flutter App',
    maxZoom: 20,
  );

  /// Esri World Imagery — free satellite, no key required
  static const satellite = MapTileConfig(
    key: 'satellite',
    label: 'Satelit',
    emoji: '🛰️',
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    userAgent: 'Mapku Flutter App',
    maxZoom: 18,
  );

  /// OpenTopoMap — terrain / topographic
  static const terrain = MapTileConfig(
    key: 'terrain',
    label: 'Terrain',
    emoji: '⛰️',
    urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
    userAgent: 'Mapku Flutter App',
    maxZoom: 17,
  );

  static const all = [standard, dark, satellite, terrain];

  static MapTileConfig byKey(String key) =>
      all.firstWhere((t) => t.key == key, orElse: () => standard);
}