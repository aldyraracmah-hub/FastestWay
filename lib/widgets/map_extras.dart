import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_tile_config.dart';
import '../services/storage_service.dart';

// ─────────────────────────────────────────────────────────────
//  Map Type Picker Bottom Sheet
// ─────────────────────────────────────────────────────────────

class MapTypePickerSheet extends StatelessWidget {
  final String currentKey;
  final Function(MapTileConfig) onSelected;

  const MapTypePickerSheet({
    super.key,
    required this.currentKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text('🗺️', style: TextStyle(fontSize: 18)),
                SizedBox(width: 8),
                Text('Tipe Peta',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, 20 + MediaQuery.of(context).padding.bottom),
            child: Row(
              children: MapTileConfig.all.map((tile) {
                final selected = tile.key == currentKey;
                return Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await StorageService.setMapType(tile.key);
                      onSelected(tile);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF22D3EE).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF22D3EE)
                              : Colors.white.withValues(alpha: 0.08),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tile.emoji,
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 6),
                          Text(
                            tile.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? const Color(0xFF22D3EE)
                                  : Colors.grey[400],
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(height: 4),
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22D3EE),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Distance Measure Overlay + Controller
// ─────────────────────────────────────────────────────────────

/// State controller — hold this in your MapScreen state.
class DistanceMeasureController extends ChangeNotifier {
  bool _active = false;
  LatLng? pointA;
  LatLng? pointB;

  bool get isActive => _active;

  double? get distanceMeters {
    if (pointA == null || pointB == null) return null;
    return const Distance().as(LengthUnit.Meter, pointA!, pointB!);
  }

  String? get distanceText {
    final d = distanceMeters;
    if (d == null) return null;
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(2)} km';
    return '${d.toInt()} m';
  }

  void start() {
    _active = true;
    pointA = null;
    pointB = null;
    notifyListeners();
  }

  void stop() {
    _active = false;
    pointA = null;
    pointB = null;
    notifyListeners();
  }

  /// Returns true if both points are set after this tap.
  bool onMapTap(LatLng point) {
    if (!_active) return false;
    if (pointA == null) {
      pointA = point;
    } else if (pointB == null) {
      pointB = point;
    } else {
      // Reset and start over
      pointA = point;
      pointB = null;
    }
    notifyListeners();
    return true;
  }
}

/// Floating result card shown while distance-measure is active.
class DistanceMeasureBar extends StatelessWidget {
  final DistanceMeasureController controller;
  final VoidCallback onStop;

  const DistanceMeasureBar({
    super.key,
    required this.controller,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isActive) return const SizedBox.shrink();

        String status;
        if (controller.pointA == null) {
          status = 'Tap titik pertama di peta';
        } else if (controller.pointB == null) {
          status = 'Tap titik kedua di peta';
        } else {
          status = '📏 ${controller.distanceText ?? '-'}';
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('📏', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ukur Jarak',
                      style: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      status,
                      style: TextStyle(color: Colors.grey[300], fontSize: 13),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onStop,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.close, size: 14, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}