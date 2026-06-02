import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ─────────────────────────────────────────────────────────────
//  TrafficService
//
//  Estimasi kemacetan tanpa API berbayar menggunakan:
//  1. Waktu & hari (rush hour heuristic)
//  2. Overpass: hitung kepadatan jalan di area bbox
//  3. Road type scoring (jalan besar = rawan macet)
//
//  Tidak ada data real-time kemacetan gratis yang akurat,
//  tapi pendekatan ini memberikan estimasi yang realistis
//  untuk kota-kota di Indonesia.
// ─────────────────────────────────────────────────────────────

enum TrafficLevel { lancar, sedang, padat, sangatPadat }

class TrafficInfo {
  final TrafficLevel level;
  final String label;
  final Color color;
  final String emoji;
  final String description;
  final double speedFactor; // pengali estimasi waktu (1.0 = normal)

  const TrafficInfo({
    required this.level,
    required this.label,
    required this.color,
    required this.emoji,
    required this.description,
    required this.speedFactor,
  });

  static const lancar = TrafficInfo(
    level: TrafficLevel.lancar,
    label: 'Lancar',
    color: Color(0xFF4ADE80),
    emoji: '🟢',
    description: 'Lalu lintas normal, tidak ada hambatan',
    speedFactor: 1.0,
  );

  static const sedang = TrafficInfo(
    level: TrafficLevel.sedang,
    label: 'Sedang',
    color: Color(0xFFFBBF24),
    emoji: '🟡',
    description: 'Ada sedikit kepadatan, waktu bisa lebih lama',
    speedFactor: 1.3,
  );

  static const padat = TrafficInfo(
    level: TrafficLevel.padat,
    label: 'Padat',
    color: Color(0xFFF97316),
    emoji: '🟠',
    description: 'Kemacetan cukup parah, antisipasi keterlambatan',
    speedFactor: 1.7,
  );

  static const sangatPadat = TrafficInfo(
    level: TrafficLevel.sangatPadat,
    label: 'Sangat Padat',
    color: Color(0xFFF87171),
    emoji: '🔴',
    description: 'Macet total! Pertimbangkan rute alternatif',
    speedFactor: 2.5,
  );
}

class TrafficService {
  static const _overpass = 'https://overpass-api.de/api/interpreter';

  // ── Rush hour schedule (Indonesia) ──────────────────────────
  // Pagi: 06:30–09:00
  // Siang: 11:30–13:30
  // Sore: 16:30–19:30
  static bool _isRushHour(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final totalMinutes = hour * 60 + minute;

    // Pagi
    if (totalMinutes >= 390 && totalMinutes <= 540) return true;
    // Siang
    if (totalMinutes >= 690 && totalMinutes <= 810) return true;
    // Sore/malam
    if (totalMinutes >= 990 && totalMinutes <= 1170) return true;

    return false;
  }

  static bool _isWeekend(DateTime time) {
    return time.weekday == DateTime.saturday || time.weekday == DateTime.sunday;
  }

  /// Estimasi level kemacetan berdasarkan:
  /// - Waktu sekarang (rush hour)
  /// - Kepadatan jalan di area (via Overpass)
  /// - Tipe jalan di rute
  static Future<TrafficInfo> getTrafficLevel(
    LatLng from,
    LatLng to, {
    DateTime? time,
  }) async {
    final now = time ?? DateTime.now();
    final isRush = _isRushHour(now);
    final isWeekend = _isWeekend(now);

    // Base score: 0 = lancar, 100 = sangat padat
    double score = 20; // base

    // Rush hour boost
    if (isRush && !isWeekend) score += 40;
    if (isRush && isWeekend) score += 20; // weekend rush lebih rendah
    if (!isRush && !isWeekend) score += 0;

    // Malam hari (22:00–05:00) = lancar
    if (now.hour >= 22 || now.hour <= 5) score -= 15;

    // Hitung kepadatan jalan di bbox rute via Overpass
    try {
      final roadDensity = await _getRoadDensity(from, to);
      score += roadDensity * 20; // density 0-1 → +0 to +20
    } catch (_) {
      // fallback ke waktu saja
    }

    // Sedikit randomisasi biar tidak statis
    final jitter = (math.Random().nextDouble() - 0.5) * 10;
    score = (score + jitter).clamp(0, 100);

    // Map score ke level
    if (score < 25) return TrafficInfo.lancar;
    if (score < 50) return TrafficInfo.sedang;
    if (score < 75) return TrafficInfo.padat;
    return TrafficInfo.sangatPadat;
  }

  /// Hitung kepadatan jalan utama di bbox antara from–to
  /// Kembalikan nilai 0.0–1.0 (0 = sepi, 1 = sangat padat)
  static Future<double> _getRoadDensity(LatLng from, LatLng to) async {
    final minLat = math.min(from.latitude, to.latitude) - 0.02;
    final maxLat = math.max(from.latitude, to.latitude) + 0.02;
    final minLon = math.min(from.longitude, to.longitude) - 0.02;
    final maxLon = math.max(from.longitude, to.longitude) + 0.02;

    // Query jalan utama di area rute
    final query = '''
[out:json][timeout:10];
way["highway"~"^(primary|secondary|tertiary|trunk|motorway)\$"]
  ($minLat,$minLon,$maxLat,$maxLon);
out count;
''';

    final res = await http.post(
      Uri.parse(_overpass),
      body: 'data=${Uri.encodeComponent(query)}',
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) return 0.3;

    final data = jsonDecode(res.body);
    final count = (data['elements'] as List?)?.length ?? 0;

    // Normalisasi: 0–5 ways = sepi, 50+ ways = sangat padat
    return (count / 50.0).clamp(0.0, 1.0);
  }

  /// Hitung estimasi waktu dengan faktor kemacetan
  static Duration adjustedDuration(Duration base, TrafficInfo traffic) {
    return Duration(
      seconds: (base.inSeconds * traffic.speedFactor).round(),
    );
  }

  static String formatDuration(Duration d) {
    final minutes = d.inMinutes;
    if (minutes >= 60) {
      return '${d.inHours}j ${minutes % 60}m';
    }
    return '$minutes menit';
  }
}

// ─────────────────────────────────────────────────────────────
//  TrafficIndicator Widget
//
//  Tampilkan di dalam RouteInfoSheet atau di atas peta.
//  Otomatis load estimasi traffic saat pertama render.
// ─────────────────────────────────────────────────────────────
class TrafficIndicator extends StatefulWidget {
  final LatLng from;
  final LatLng to;
  final Duration baseDuration;

  const TrafficIndicator({
    super.key,
    required this.from,
    required this.to,
    required this.baseDuration,
  });

  @override
  State<TrafficIndicator> createState() => _TrafficIndicatorState();
}

class _TrafficIndicatorState extends State<TrafficIndicator> {
  TrafficInfo? _traffic;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await TrafficService.getTrafficLevel(widget.from, widget.to);
    if (mounted) setState(() { _traffic = info; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 10, height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF22D3EE)),
          ),
          const SizedBox(width: 6),
          Text('Cek kondisi jalan...',
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ]),
      );
    }

    if (_traffic == null) return const SizedBox.shrink();

    final adjusted = TrafficService.adjustedDuration(widget.baseDuration, _traffic!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _traffic!.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _traffic!.color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_traffic!.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text('Kondisi Jalan: ${_traffic!.label}',
              style: TextStyle(
                  color: _traffic!.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() { _loading = true; _load(); }),
            child: Icon(Icons.refresh, size: 14, color: _traffic!.color),
          ),
        ]),
        const SizedBox(height: 4),
        Text(_traffic!.description,
            style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.timer_outlined, size: 12, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            'Estimasi dengan kondisi sekarang: ',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          Text(
            TrafficService.formatDuration(adjusted),
            style: TextStyle(
                color: _traffic!.color,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TrafficBadge — compact versi untuk di header rute
// ─────────────────────────────────────────────────────────────
class TrafficBadge extends StatefulWidget {
  final LatLng from;
  final LatLng to;

  const TrafficBadge({super.key, required this.from, required this.to});

  @override
  State<TrafficBadge> createState() => _TrafficBadgeState();
}

class _TrafficBadgeState extends State<TrafficBadge> {
  TrafficInfo? _traffic;

  @override
  void initState() {
    super.initState();
    TrafficService.getTrafficLevel(widget.from, widget.to)
        .then((t) { if (mounted) setState(() => _traffic = t); });
  }

  @override
  Widget build(BuildContext context) {
    if (_traffic == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _traffic!.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _traffic!.color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(_traffic!.emoji, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 4),
        Text(_traffic!.label,
            style: TextStyle(
                color: _traffic!.color,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}