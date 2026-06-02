import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/nearby_service.dart';

class NearbySheet extends StatefulWidget {
  final LatLng userLocation;
  final Function(LatLng, String) onNavigateTo;
  final Function(LatLng) onShowOnMap;

  const NearbySheet({
    super.key,
    required this.userLocation,
    required this.onNavigateTo,
    required this.onShowOnMap,
  });

  @override
  State<NearbySheet> createState() => _NearbySheetState();
}

class _NearbySheetState extends State<NearbySheet> {
  String _selectedCategory = 'restaurant';
  List<NearbyPlace> _places = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() => _loading = true);
    final places = await NearbyService.getNearby(
      widget.userLocation,
      categoryKey: _selectedCategory,
    );
    if (mounted) setState(() { _places = places; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
      ),
      child: Column(
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
            child: Row(
              children: [
                const Text('🔍', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Text('Tempat Terdekat',
                    style: TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('radius 1.5 km',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),

          // Category chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: NearbyService.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = NearbyService.categories[i];
                final selected = cat['key'] == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat['key'] as String);
                    _loadPlaces();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF22D3EE).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF22D3EE)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat['emoji'] as String,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          cat['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? const Color(0xFF22D3EE)
                                : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 16, color: Color(0xFF252B3D)),

          // Results
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF22D3EE)),
                        SizedBox(height: 12),
                        Text('Mencari tempat terdekat...',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  )
                : _places.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off, size: 48, color: Colors.grey[700]),
                            const SizedBox(height: 12),
                            Text('Tidak ditemukan dalam radius 1.5 km',
                                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _places.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1, color: Color(0xFF252B3D), indent: 64,
                        ),
                        itemBuilder: (context, i) {
                          final place = _places[i];
                          return ListTile(
                            leading: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22D3EE).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(place.emoji,
                                    style: const TextStyle(fontSize: 20)),
                              ),
                            ),
                            title: Text(place.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4ADE80).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    place.distanceText,
                                    style: const TextStyle(
                                        color: Color(0xFF4ADE80),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (place.address != null) ...[
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      place.address!,
                                      style: TextStyle(
                                          color: Colors.grey[600], fontSize: 10),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Show on map
                                IconButton(
                                  icon: const Icon(Icons.map_outlined,
                                      color: Color(0xFF22D3EE), size: 18),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    widget.onShowOnMap(place.latLng);
                                  },
                                ),
                                // Navigate
                                IconButton(
                                  icon: const Icon(Icons.directions,
                                      color: Color(0xFF4ADE80), size: 18),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    widget.onNavigateTo(place.latLng, place.name);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}