// ═══════════════════════════════════════════════════════════════
//  BAGIAN 1: Update routing_service.dart
//
//  Tambahkan method getRouteWithWaypoints() di bawah getRoute().
//  Method lama tetap ada agar tidak breaking.
// ═══════════════════════════════════════════════════════════════

// Tambahkan di dalam class RoutingService:

/*
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
          'auto': {
            'use_highways': useHighways,
            'use_tolls': useTolls,
            'top_speed': 80,
          }
        },
        'directions_options': {
          'language': 'id-ID',
          'units': 'kilometers',
        },
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
        final shape = leg['shape'] as String;
        allPoints.addAll(_decodePolyline(shape));
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
*/

// ═══════════════════════════════════════════════════════════════
//  BAGIAN 2: WaypointSheet widget
//  File: lib/widgets/waypoint_sheet.dart
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_info.dart';
import '../services/routing_service.dart';

/// Model untuk satu titik singgah
class Waypoint {
  final String label;
  final LatLng latLng;

  Waypoint({required this.label, required this.latLng});
}

/// Controller waypoint — simpan di MapScreen state
class WaypointController extends ChangeNotifier {
  final List<Waypoint> _stops = [];

  List<Waypoint> get stops => List.unmodifiable(_stops);
  bool get hasRoute => _stops.length >= 2;
  int get count => _stops.length;

  void addStop(Waypoint wp) {
    _stops.add(wp);
    notifyListeners();
  }

  void removeStop(int index) {
    if (index >= 0 && index < _stops.length) {
      _stops.removeAt(index);
      notifyListeners();
    }
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _stops.removeAt(oldIndex);
    _stops.insert(newIndex, item);
    notifyListeners();
  }

  void clear() {
    _stops.clear();
    notifyListeners();
  }

  void setOrigin(Waypoint wp) {
    if (_stops.isEmpty) {
      _stops.add(wp);
    } else {
      _stops[0] = wp;
    }
    notifyListeners();
  }

  void setDestination(Waypoint wp) {
    if (_stops.length < 2) {
      _stops.add(wp);
    } else {
      _stops[_stops.length - 1] = wp;
    }
    notifyListeners();
  }

  Future<RouteInfo?> calculateRoute({String mode = 'shortcut'}) async {
    if (!hasRoute) return null;
    return RoutingService.getRouteWithWaypoints(
      _stops.map((s) => s.latLng).toList(),
      mode: mode,
    );
  }
}

/// Bottom sheet untuk kelola waypoint
class WaypointSheet extends StatefulWidget {
  final WaypointController controller;
  final String routeMode;
  final void Function(RouteInfo) onRouteCalculated;
  final VoidCallback onAddWaypoint; // callback untuk masuk mode pilih titik di peta

  const WaypointSheet({
    super.key,
    required this.controller,
    required this.routeMode,
    required this.onRouteCalculated,
    required this.onAddWaypoint,
  });

  @override
  State<WaypointSheet> createState() => _WaypointSheetState();
}

class _WaypointSheetState extends State<WaypointSheet> {
  bool _loading = false;

  Future<void> _calculate() async {
    if (!widget.controller.hasRoute) return;
    setState(() => _loading = true);
    final route = await widget.controller.calculateRoute(mode: widget.routeMode);
    if (mounted) {
      setState(() => _loading = false);
      if (route != null) {
        widget.onRouteCalculated(route);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gagal hitung rute. Cek koneksi.'),
            backgroundColor: const Color(0xFFF87171),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final stops = widget.controller.stops;
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1F2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(children: [
                  const Text('🛑', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text('Rute Multi-Stop',
                      style: TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (stops.isNotEmpty)
                    TextButton(
                      onPressed: () => widget.controller.clear(),
                      child: Text('Hapus Semua',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ),
                ]),
              ),

              const Divider(height: 1, color: Color(0xFF252B3D)),

              if (stops.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.route, size: 44, color: Colors.grey[700]),
                    const SizedBox(height: 12),
                    Text('Belum ada titik rute',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    const SizedBox(height: 6),
                    Text('Tap "+ Titik" untuk menambah titik singgah',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                  ]),
                )
              else
                Flexible(
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: stops.length,
                    onReorder: widget.controller.reorder,
                    itemBuilder: (context, i) {
                      final stop = stops[i];
                      final isFirst = i == 0;
                      final isLast = i == stops.length - 1;

                      Color dotColor;
                      String dotLabel;
                      if (isFirst) {
                        dotColor = const Color(0xFF4ADE80);
                        dotLabel = 'A';
                      } else if (isLast) {
                        dotColor = const Color(0xFFF87171);
                        dotLabel = String.fromCharCode(65 + i);
                      } else {
                        dotColor = const Color(0xFFFBBF24);
                        dotLabel = String.fromCharCode(65 + i);
                      }

                      return ListTile(
                        key: ValueKey(i),
                        leading: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: dotColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: dotColor, width: 1.5),
                          ),
                          child: Center(
                            child: Text(dotLabel,
                                style: TextStyle(color: dotColor,
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        title: Text(stop.label,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${stop.latLng.latitude.toStringAsFixed(4)}, '
                          '${stop.latLng.longitude.toStringAsFixed(4)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          // Drag handle
                          Icon(Icons.drag_handle, color: Colors.grey[600], size: 18),
                          const SizedBox(width: 4),
                          // Delete
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.grey[600], size: 16),
                            onPressed: () => widget.controller.removeStop(i),
                          ),
                        ]),
                      );
                    },
                  ),
                ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Add waypoint button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onAddWaypoint();
                      },
                      icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                      label: const Text('+ Titik Singgah',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF22D3EE),
                        side: const BorderSide(color: Color(0xFF22D3EE), width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Calculate route button
                  if (widget.controller.hasRoute)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _calculate,
                        icon: _loading
                            ? const SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.directions, size: 18),
                        label: Text(
                          _loading
                              ? 'Menghitung...'
                              : 'Hitung Rute (${stops.length} titik)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22D3EE),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}