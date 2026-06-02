import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/place_info.dart';

/// ── CHANGED vs original ──
/// Added [onSaveFavorite] optional callback.
/// Added ⭐ star button in the header row.
class PlaceInfoSheet extends StatelessWidget {
  final PlaceInfo place;
  final VoidCallback onSetOrigin;
  final VoidCallback onSetDestination;
  final VoidCallback onClose;
  final VoidCallback? onSaveFavorite; // NEW

  const PlaceInfoSheet({
    super.key,
    required this.place,
    required this.onSetOrigin,
    required this.onSetDestination,
    required this.onClose,
    this.onSaveFavorite, // NEW
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
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (place.wikiImageUrl != null) _WikiImage(url: place.wikiImageUrl!),
                  const SizedBox(height: 12),

                  // Kategori badge + star button row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF22D3EE).withValues(alpha: 0.3)),
                        ),
                        child: Text(place.category,
                            style: const TextStyle(
                                color: Color(0xFF22D3EE),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
                      // ── NEW: Save to favorites ──
                      if (onSaveFavorite != null)
                        GestureDetector(
                          onTap: onSaveFavorite,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_border,
                                    color: Color(0xFFFBBF24), size: 14),
                                SizedBox(width: 4),
                                Text('Simpan',
                                    style: TextStyle(
                                        color: Color(0xFFFBBF24),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Text(place.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.2)),
                  const SizedBox(height: 6),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(place.address,
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 12, height: 1.4)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      final coords =
                          '${place.lat.toStringAsFixed(6)}, ${place.lon.toStringAsFixed(6)}';
                      Clipboard.setData(ClipboardData(text: coords));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Koordinat disalin!'),
                          duration: Duration(seconds: 1),
                          backgroundColor: Color(0xFF22D3EE),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${place.lat.toStringAsFixed(5)}, ${place.lon.toStringAsFixed(5)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  ),

                  if (place.openingHours != null)
                    _InfoRow(
                        icon: Icons.access_time_rounded,
                        color: const Color(0xFF4ADE80),
                        label: place.openingHours!),
                  if (place.phone != null)
                    _InfoRow(
                        icon: Icons.phone_outlined,
                        color: const Color(0xFF60A5FA),
                        label: place.phone!),
                  if (place.website != null)
                    _InfoRow(
                        icon: Icons.language_outlined,
                        color: const Color(0xFFA78BFA),
                        label: place.website!,
                        isUrl: true),

                  if (place.wikiSummary != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Text('📖', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 6),
                            Text('Wikipedia',
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 6),
                          Text(place.wikiSummary!,
                              style: TextStyle(
                                  color: Colors.grey[300], fontSize: 12, height: 1.5)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.trip_origin,
                          label: 'Set Asal',
                          color: const Color(0xFF4ADE80),
                          onTap: () {
                            Navigator.pop(context);
                            onSetOrigin();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.location_on,
                          label: 'Set Tujuan',
                          color: const Color(0xFFF87171),
                          onTap: () {
                            Navigator.pop(context);
                            onSetDestination();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WikiImage extends StatelessWidget {
  final String url;
  const _WikiImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url, height: 160, width: double.infinity, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF22D3EE))),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isUrl;

  const _InfoRow({
    required this.icon, required this.color, required this.label, this.isUrl = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(label,
                  style: TextStyle(
                    color: isUrl ? const Color(0xFF60A5FA) : Colors.grey[300],
                    fontSize: 13,
                    decoration: isUrl ? TextDecoration.underline : null,
                    decorationColor: const Color(0xFF60A5FA),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}