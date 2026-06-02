import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/storage_service.dart';

/// Bottom sheet that lists saved favorite places.
/// [onNavigateTo] is called when the user wants to go there.
class FavoritesSheet extends StatefulWidget {
  final Function(LatLng, String) onNavigateTo;

  const FavoritesSheet({super.key, required this.onNavigateTo});

  @override
  State<FavoritesSheet> createState() => _FavoritesSheetState();
}

class _FavoritesSheetState extends State<FavoritesSheet> {
  List<FavoritePlace> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favs = await StorageService.getFavorites();
    if (mounted) setState(() { _favorites = favs; _loading = false; });
  }

  Future<void> _delete(String id) async {
    await StorageService.removeFavorite(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Text('Favorit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )),
                const Spacer(),
                if (_favorites.isNotEmpty)
                  Text('${_favorites.length} lokasi',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF252B3D)),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF22D3EE),
              ),
            )
          else if (_favorites.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.bookmark_border, size: 48, color: Colors.grey[700]),
                  const SizedBox(height: 12),
                  Text('Belum ada lokasi favorit',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                  const SizedBox(height: 6),
                  Text('Tap ⭐ di info lokasi untuk menyimpan',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _favorites.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFF252B3D), indent: 60),
                itemBuilder: (context, i) {
                  final fav = _favorites[i];
                  return ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(fav.icon, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                    title: Text(fav.name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(fav.address,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.grey[600], size: 18),
                      onPressed: () => _delete(fav.id),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onNavigateTo(fav.latLng, fav.name);
                    },
                  );
                },
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

/// Utility to show the save-favorite dialog from PlaceInfoSheet.
Future<void> showSaveFavoriteDialog(
  BuildContext context, {
  required String name,
  required String address,
  required double lat,
  required double lon,
}) async {
  final icons = ['📍', '🏠', '🏢', '🏫', '🍽️', '☕', '🛒', '🏥', '⛽', '⭐'];
  String selectedIcon = icons.first;
  final nameController = TextEditingController(text: name);

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      return Dialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Simpan Favorit',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 14),
              // Icon picker
              Wrap(
                spacing: 8, runSpacing: 8,
                children: icons.map((icon) {
                  final sel = icon == selectedIcon;
                  return GestureDetector(
                    onTap: () => setSt(() => selectedIcon = icon),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFFFBBF24).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? const Color(0xFFFBBF24) : Colors.transparent,
                        ),
                      ),
                      child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              // Name field
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Nama lokasi',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Batal', style: TextStyle(color: Colors.grey[500])),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text(
  'Simpan',
  style: TextStyle(fontWeight: FontWeight.bold),
),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }),
  );

  if (saved == true) {
    final fav = FavoritePlace(
      id: '${lat}_$lon',
      name: nameController.text.trim().isNotEmpty ? nameController.text.trim() : name,
      address: address,
      icon: selectedIcon,
      lat: lat,
      lon: lon,
      savedAt: DateTime.now(),
    );
    await StorageService.addFavorite(fav);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${fav.icon} ${fav.name} disimpan ke favorit!'),
          backgroundColor: const Color(0xFFFBBF24).withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}