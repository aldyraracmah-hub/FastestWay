import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareLocationService {
  static String buildGoogleMapsLink(LatLng loc) {
    return 'https://maps.google.com/?q=${loc.latitude},${loc.longitude}';
  }

  static String buildOSMLink(LatLng loc) {
    return 'https://www.openstreetmap.org/?mlat=${loc.latitude}&mlon=${loc.longitude}&zoom=16';
  }

  static Future<void> shareToAny(LatLng loc, {String? label}) async {
    final link = buildGoogleMapsLink(loc);
    final text = label != null
        ? 'Lokasi saya: $label\n$link'
        : 'Lokasi saya sekarang:\n$link';
    await Share.share(text, subject: 'Lokasi Mapku');
  }

  static Future<void> shareToWhatsApp(LatLng loc, {String? label}) async {
  final link = buildGoogleMapsLink(loc);
  final text = Uri.encodeQueryComponent(  // ← fix di sini
    label != null ? 'Lokasi saya: $label\n$link' : 'Ini lokasi saya:\n$link',
  );
    final waUri = Uri.parse('whatsapp://send?text=$text');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri);
    } else {
      final webUri = Uri.parse('https://api.whatsapp.com/send?text=$text');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> copyLink(LatLng loc, BuildContext context) async {
    final link = buildGoogleMapsLink(loc);
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Link lokasi disalin!'),
          backgroundColor: const Color(0xFF22D3EE),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  static Future<void> openInGoogleMaps(LatLng loc) async {
    final uri = Uri.parse(buildGoogleMapsLink(loc));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class LiveLocationController extends ChangeNotifier {
  bool _isSharing = false;
  String? _shareId;
  Timer? _updateTimer;
  LatLng? _lastLocation;

  bool get isSharing => _isSharing;
  String? get shareId => _shareId;

  String? get shareLink => _shareId != null
      ? null // TODO: ganti dengan 'https://YOUR_DOMAIN/live/$_shareId'
      : null;

  void startSharing(LatLng initialLocation) {
    _isSharing = true;
    _shareId = _generateId();
    _lastLocation = initialLocation;
    _scheduleUpdates();
    notifyListeners();
  }

  void updateLocation(LatLng loc) {
    _lastLocation = loc;
    // TODO: upload koordinat ke backend di sini
  }

  void stopSharing() {
    _isSharing = false;
    _shareId = null;
    _updateTimer?.cancel();
    notifyListeners();
  }

  void _scheduleUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_lastLocation != null) updateLocation(_lastLocation!);
    });
  }

  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return now.toRadixString(36).toUpperCase();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

class ShareLocationSheet extends StatelessWidget {
  final LatLng location;
  final String? locationLabel;

  const ShareLocationSheet({
    super.key,
    required this.location,
    this.locationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final link = ShareLocationService.buildGoogleMapsLink(location);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Row(children: [
            Text('📡', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Bagikan Lokasi',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text(
            '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(children: [
              const Icon(Icons.link, color: Color(0xFF22D3EE), size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(link,
                    style: const TextStyle(color: Color(0xFF22D3EE), fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          const Divider(height: 1, color: Color(0xFF252B3D)),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(
              child: _ShareButton(
                emoji: '📋',
                label: 'Salin Link',
                color: const Color(0xFF22D3EE),
                onTap: () => ShareLocationService.copyLink(location, context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ShareButton(
                emoji: '💬',
                label: 'WhatsApp',
                color: const Color(0xFF4ADE80),
                onTap: () => ShareLocationService.shareToWhatsApp(
                    location, label: locationLabel),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _ShareButton(
                emoji: '🔗',
                label: 'Bagikan',
                color: const Color(0xFFA78BFA),
                onTap: () => ShareLocationService.shareToAny(
                    location, label: locationLabel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ShareButton(
                emoji: '🗺️',
                label: 'Buka Maps',
                color: const Color(0xFFFBBF24),
                onTap: () => ShareLocationService.openInGoogleMaps(location),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareButton({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}