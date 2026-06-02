import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Tile cache stub: no-op implementation to avoid native ObjectBox dependency.
/// Keeps the same public API so other code compiles.
class TileCacheService {
  static Future<void> init() async {}
  static TileProvider get cachedTileProvider => NetworkTileProvider();
  static Future<void> downloadRegion({
    required dynamic bounds,
    required dynamic tileConfig,
    int minZoom = 10,
    int maxZoom = 16,
    void Function(double progress, int downloaded, int total)? onProgress,
    VoidCallback? onComplete,
    VoidCallback? onError,
  }) async {
    // no-op: offline downloads disabled when flutter_map_tile_caching is removed
    onError?.call();
  }
  static Future<double> getCacheSizeMB() async => 0;
  static Future<int> getTileCount() async => 0;
  static Future<void> clearCache() async {}
}