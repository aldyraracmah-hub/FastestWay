import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_info.dart';
import '../models/map_tile_config.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../services/place_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import '../services/share_location_service.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/route_info_sheet.dart';
import '../widgets/place_info_sheet.dart';
import '../widgets/favorite_sheet.dart';
import '../widgets/nearby_sheet.dart';
import '../widgets/map_extras.dart';
import '../widgets/waypoint_routing.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  LatLng? _userLocation;
  LatLng? _originPoint;
  LatLng? _destinationPoint;
  RouteInfo? _routeInfo;
  String _routeMode = 'shortcut';

  bool _loadingLocation = false;
  bool _loadingRoute = false;
  bool _loadingPlace = false;
  bool _showSearchPanel = false;
  bool _isNavigating = false;

  LatLng? _tappedPoint;
  StreamSubscription? _locationStream;
  Future<void> showSaveFavoriteDialog({

  required BuildContext context,
  required String name,
  required String address,
  required double lat,
  required double lon,

}) async {

  ScaffoldMessenger.of(context).showSnackBar(

    SnackBar(

      content: Text(
        '$name saved to favorites',
      ),

      backgroundColor:
      const Color(0xFFD6BFA7),
    ),
  );
}

  static const LatLng _defaultCenter = LatLng(-2.5, 118.0);
  double _currentZoom = 5.0;

  late final AnimationController _animController;

  MapTileConfig _tileConfig = MapTileConfig.standard;
  bool _isDarkMode = true;
  final DistanceMeasureController _distanceMeasure = DistanceMeasureController();
  bool _ttsEnabled = true;
  final WaypointController _waypointController = WaypointController();
  bool _addingWaypoint = false;
  int _lastSpokenStep = -1;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadPreferences();
    _getUserLocation();
  }

  Future<void> _loadPreferences() async {
    final dark = await StorageService.isDarkMode();
    final mapType = await StorageService.getMapType();
    if (mounted) {
      setState(() {
        _isDarkMode = dark;
        _tileConfig = MapTileConfig.byKey(mapType);
      });
    }
  }

  @override
  void dispose() {
    _locationStream?.cancel();
    _animController.dispose();
    _distanceMeasure.dispose();
    _waypointController.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    setState(() => _loadingLocation = true);
    final loc = await LocationService.getCurrentLocation();
    if (loc != null && mounted) {
      setState(() {
        _userLocation = loc;
        _loadingLocation = false;
      });
      _animateToLocation(loc, zoom: 15.0);
    } else {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _animateToLocation(LatLng loc, {double zoom = 15.0}) {
    _mapController.move(loc, zoom);
    setState(() => _currentZoom = zoom);
  }

  // FIX: Ganti getRoute (tidak ada) → getRouteWithWaypoints dengan 2 stops
  Future<void> _calculateRoute() async {
    if (_originPoint == null || _destinationPoint == null) return;
    setState(() => _loadingRoute = true);

    final route = await RoutingService.getRouteWithWaypoints(
      [_originPoint!, _destinationPoint!],
      mode: _routeMode,
    );

    if (mounted) {
      setState(() {
        _routeInfo = route;
        _loadingRoute = false;
        _lastSpokenStep = -1;
      });
      if (route != null) {
        _fitRouteBounds(route.points);
        _showRouteSheet();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Gagal mendapatkan rute. Cek koneksi internet.'),
            ]),
            backgroundColor: const Color(0xFFF87171),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _fitRouteBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLon = points.first.longitude, maxLon = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat - 0.01, minLon - 0.01),
          LatLng(maxLat + 0.01, maxLon + 0.01),
        ),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  void _showRouteSheet() {
    if (_routeInfo == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isScrollControlled: true,
      builder: (_) => RouteInfoSheet(
        routeInfo: _routeInfo!,
        onClose: () => Navigator.pop(context),
        onStartNavigation: () {
          Navigator.pop(context);
          setState(() => _isNavigating = true);
          if (_routeInfo!.instructions.isNotEmpty) {
            TtsService.instance.speak(
              'Navigasi dimulai. ${_routeInfo!.instructions.first}',
            );
            _lastSpokenStep = 0;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Icon(Icons.navigation_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Navigasi dimulai! Ikuti rute di peta.'),
              ]),
              backgroundColor: const Color(0xFF22D3EE),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          _startLiveTracking();
        },
      ),
    );
  }

  void _startLiveTracking() {
    _locationStream?.cancel();
    _locationStream = LocationService.getLocationStream().listen((pos) {
      if (!mounted) return;
      setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
      if (_isNavigating) {
        _mapController.move(_userLocation!, 17.0);
        _checkAndSpeakNextInstruction();
      }
    });
  }

  void _checkAndSpeakNextInstruction() {
    if (_routeInfo == null || _userLocation == null) return;
    final instructions = _routeInfo!.instructions;
    if (instructions.isEmpty) return;

    final nextStep = _lastSpokenStep + 1;
    if (nextStep >= instructions.length) return;

    final points = _routeInfo!.points;
    if (points.isEmpty) return;

    double minDist = double.infinity;
    int closestIdx = 0;
    for (int i = 0; i < points.length; i++) {
      final d = const Distance().as(
        LengthUnit.Meter, _userLocation!, points[i],
      );
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }

    final stepIndex = (closestIdx / points.length * instructions.length)
        .floor()
        .clamp(0, instructions.length - 1);

    if (stepIndex > _lastSpokenStep) {
      _lastSpokenStep = stepIndex;
      TtsService.instance.speakInstruction(instructions[stepIndex], step: stepIndex);
    }
  }

  void _onMapTap(TapPosition tap, LatLng latlng) async {
    if (_distanceMeasure.isActive) {
      _distanceMeasure.onMapTap(latlng);
      return;
    }

    if (_addingWaypoint) {
      final label = await RoutingService.reverseGeocode(latlng);
      _waypointController.addStop(Waypoint(
        label: label.split(', ').first,
        latLng: latlng,
      ));
      setState(() => _addingWaypoint = false);
      _showWaypointSheet();
      return;
    }

    if (_showSearchPanel) return;

    setState(() {
      _tappedPoint = latlng;
      _loadingPlace = true;
    });

    final placeInfo = await PlaceService.getPlaceInfo(latlng);

    if (!mounted) return;
    setState(() => _loadingPlace = false);

    if (placeInfo != null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        isScrollControlled: true,
        builder: (_) => PlaceInfoSheet(
          place: placeInfo,
          onClose: () {
            Navigator.pop(context);
            setState(() => _tappedPoint = null);
          },
          onSetOrigin: () {
            setState(() {
              _originPoint = latlng;
              _tappedPoint = null;
            });
            if (_destinationPoint != null) _calculateRoute();
          },
          onSetDestination: () {
            setState(() {
              _destinationPoint = latlng;
              _tappedPoint = null;
            });
            if (_originPoint != null) _calculateRoute();
          },
          onSaveFavorite: () => showSaveFavoriteDialog(

            context: context,

            name: placeInfo.name,

            address: placeInfo.address,

            lat: placeInfo.lat,

            lon: placeInfo.lon,
          ),
        ),
      ).whenComplete(() {
        if (mounted) setState(() => _tappedPoint = null);
      });
    } else {
      setState(() => _tappedPoint = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Info lokasi tidak tersedia'),
          backgroundColor: const Color(0xFF374151),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _onMapLongPress(TapPosition tap, LatLng latlng) async {
    if (_distanceMeasure.isActive) return;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tandai Lokasi',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                '${latlng.latitude.toStringAsFixed(5)}, ${latlng.longitude.toStringAsFixed(5)}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DialogBtn(
                      label: 'Set Asal',
                      icon: Icons.trip_origin,
                      color: const Color(0xFF4ADE80),
                      onTap: () => Navigator.pop(ctx, 'origin'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DialogBtn(
                      label: 'Set Tujuan',
                      icon: Icons.location_on,
                      color: const Color(0xFFF87171),
                      onTap: () => Navigator.pop(ctx, 'destination'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Batal', style: TextStyle(color: Colors.grey[500])),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == 'origin') {
      setState(() => _originPoint = latlng);
    } else if (action == 'destination') setState(() => _destinationPoint = latlng);

    if (_originPoint != null && _destinationPoint != null) _calculateRoute();
  }

  void _clearRoute() {
    setState(() {
      _originPoint = null;
      _destinationPoint = null;
      _routeInfo = null;
      _isNavigating = false;
      _tappedPoint = null;
    });
    _locationStream?.cancel();
    TtsService.instance.stop();
  }

  void _showFavorites() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FavoritesSheet(
        onNavigateTo: (latLng, name) {
          setState(() => _destinationPoint = latLng);
          _animateToLocation(latLng, zoom: 15);
          if (_originPoint == null && _userLocation != null) {
            setState(() => _originPoint = _userLocation);
          }
          if (_originPoint != null) _calculateRoute();
        },
      ),
    );
  }

  void _showNearby() {
    final loc = _userLocation;
    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lokasi kamu belum diketahui'),
          backgroundColor: const Color(0xFF374151),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => NearbySheet(
        userLocation: loc,
        onNavigateTo: (latLng, name) {
          setState(() {
            _destinationPoint = latLng;
            _originPoint ??= loc;
          });
          _calculateRoute();
        },
        onShowOnMap: (latLng) => _animateToLocation(latLng, zoom: 16),
      ),
    );
  }

  // FIX: Pindahkan _showWaypointSheet ke level class, bukan di dalam method lain
  void _showWaypointSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => WaypointSheet(
        controller: _waypointController,
        routeMode: _routeMode,
        onRouteCalculated: (route) {
          setState(() => _routeInfo = route);
          _fitRouteBounds(route.points);
          _showRouteSheet();
        },
        onAddWaypoint: () {
          setState(() => _addingWaypoint = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Tap lokasi di peta untuk menambah titik singgah'),
              backgroundColor: const Color(0xFF22D3EE),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      ),
    );
  }

  void _showMapTypePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MapTypePickerSheet(
        currentKey: _tileConfig.key,
        onSelected: (tile) {
          setState(() => _tileConfig = tile);
        },
      ),
    );
  }

  void _toggleTheme() async {
    final newDark = !_isDarkMode;
    await StorageService.setDarkMode(newDark);
    setState(() {
      _isDarkMode = newDark;
      if (_tileConfig.key == 'standard' && newDark) {
        _tileConfig = MapTileConfig.dark;
      } else if (_tileConfig.key == 'dark' && !newDark) {
        _tileConfig = MapTileConfig.standard;
      }
    });
    await StorageService.setMapType(_tileConfig.key);
  }

  void _saveSearchHistory(SearchResult result) {
    StorageService.addSearchHistory(
      SearchHistoryItem(
        displayName: result.displayName,
        lat: result.lat,
        lon: result.lon,
        searchedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9);
    final cardColor = _isDarkMode ? const Color(0xFF1A1F2E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // ── MAP ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? _defaultCenter,
              initialZoom: _currentZoom,
              onTap: _onMapTap,
              onLongPress: _onMapLongPress,
              onMapEvent: (event) {
                if (event is MapEventMove) {
                  setState(() => _currentZoom = event.camera.zoom);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _tileConfig.urlTemplate,
                userAgentPackageName: _tileConfig.userAgent,
                maxZoom: _tileConfig.maxZoom.toDouble(),
              ),
              if (_routeInfo != null)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _routeInfo!.points,
                    color: const Color(0xFF22D3EE),
                    strokeWidth: 5.0,
                    borderColor: Colors.white.withValues(alpha: 0.3),
                    borderStrokeWidth: 1.5,
                  ),
                ]),
              // Distance measure line
              if (_distanceMeasure.isActive &&
                  _distanceMeasure.pointA != null &&
                  _distanceMeasure.pointB != null)
                AnimatedBuilder(
                  animation: _distanceMeasure,
                  builder: (_, __) => PolylineLayer<Object>(polylines: [
                    Polyline(
                      points: [_distanceMeasure.pointA!, _distanceMeasure.pointB!],
                      color: const Color(0xFFFBBF24),
                      strokeWidth: 2.5,
                    ),
                  ]),
                ),
              MarkerLayer(markers: [
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 50,
                    height: 50,
                    child: _UserLocationMarker(),
                  ),
                if (_originPoint != null)
                  Marker(
                    point: _originPoint!,
                    width: 40,
                    height: 40,
                    child: const _PinMarker(
                        color: Color(0xFF4ADE80), icon: Icons.trip_origin),
                  ),
                if (_destinationPoint != null)
                  Marker(
                    point: _destinationPoint!,
                    width: 40,
                    height: 50,
                    child: const _DestinationMarker(),
                  ),
                if (_tappedPoint != null)
                  Marker(
                    point: _tappedPoint!,
                    width: 40,
                    height: 40,
                    child: const _TappedMarker(),
                  ),
                if (_distanceMeasure.isActive && _distanceMeasure.pointA != null)
                  Marker(
                    point: _distanceMeasure.pointA!,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                if (_distanceMeasure.isActive && _distanceMeasure.pointB != null)
                  Marker(
                    point: _distanceMeasure.pointB!,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                // FIX: Waypoint markers — cast i ke int untuk String.fromCharCode
                ..._waypointController.stops.asMap().entries.map((e) {
                  final i = e.key;
                  final stop = e.value;
                  final isFirst = i == 0;
                  final isLast = i == _waypointController.stops.length - 1;
                  final color = isFirst
                      ? const Color(0xFF4ADE80)
                      : isLast
                          ? const Color(0xFFF87171)
                          : const Color(0xFFFBBF24);
                  return Marker(
                    point: stop.latLng,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + i), // i sudah int dari asMap()
                          style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                }),
              ]),
            ],
          ),

          // ── LOADING PLACE OVERLAY ──
          if (_loadingPlace)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3), blurRadius: 12)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF22D3EE)),
                      ),
                      const SizedBox(width: 10),
                      Text('Mengambil info lokasi...',
                          style: TextStyle(
                              color: _isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),

          // ── TOP SEARCH PANEL ──
          SafeArea(
            child: AnimatedSlide(
              offset:
                  _showSearchPanel ? Offset.zero : const Offset(0, -0.05),
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_showSearchPanel) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ModeChip(
                              label: '🛤️ Pintas',
                              mode: 'shortcut',
                              selected: _routeMode == 'shortcut',
                              onTap: () => setState(() {
                                    _routeMode = 'shortcut';
                                    if (_routeInfo != null) _calculateRoute();
                                  })),
                          const SizedBox(width: 6),
                          _ModeChip(
                              label: '⚡ Tercepat',
                              mode: 'fastest',
                              selected: _routeMode == 'fastest',
                              onTap: () => setState(() {
                                    _routeMode = 'fastest';
                                    if (_routeInfo != null) _calculateRoute();
                                  })),
                          const SizedBox(width: 6),
                          _ModeChip(
                              label: '🛣️ Tol',
                              mode: 'toll',
                              selected: _routeMode == 'toll',
                              onTap: () => setState(() {
                                    _routeMode = 'toll';
                                    if (_routeInfo != null) _calculateRoute();
                                  })),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _TopSearchBar(
                        onTap: () =>
                            setState(() => _showSearchPanel = true),
                        hasRoute: _routeInfo != null,
                        onShowRoute: _showRouteSheet,
                        onClear: _clearRoute,
                        isDarkMode: _isDarkMode,
                      ),
                    ] else
                      _SearchPanel(
                        onOriginSelected: (result) {
                          setState(() => _originPoint = result.latLng);
                          _saveSearchHistory(result);
                          if (_destinationPoint != null) _calculateRoute();
                        },
                        onDestinationSelected: (result) {
                          setState(
                              () => _destinationPoint = result.latLng);
                          _saveSearchHistory(result);
                          _animateToLocation(result.latLng, zoom: 14);
                          if (_originPoint != null) _calculateRoute();
                        },
                        onClose: () =>
                            setState(() => _showSearchPanel = false),
                        isDarkMode: _isDarkMode,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── LOADING ROUTE ──
          if (_loadingRoute)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF22D3EE)),
                    ),
                    const SizedBox(width: 12),
                    Text('Mencari rute...',
                        style: TextStyle(
                            color: _isDarkMode
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),

          // ── DISTANCE MEASURE BAR ──
          Positioned(
            bottom: 100,
            left: 0,
            right: 80,
            child: DistanceMeasureBar(
              controller: _distanceMeasure,
              onStop: () => setState(() => _distanceMeasure.stop()),
            ),
          ),

          // ── BOTTOM RIGHT BUTTONS ──
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isNavigating) ...[
                  _MapButton(
                    icon: _ttsEnabled
                        ? Icons.volume_up
                        : Icons.volume_off,
                    isAccent: _ttsEnabled,
                    isDarkMode: _isDarkMode,
                    onTap: () {
                      setState(() {
                        _ttsEnabled = !_ttsEnabled;
                        TtsService.instance.isEnabled = _ttsEnabled;
                        if (!_ttsEnabled) TtsService.instance.stop();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22D3EE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.navigation_rounded,
                            color: Color(0xFF0D1117), size: 14),
                        SizedBox(width: 4),
                        Text('Navigasi',
                            style: TextStyle(
                                color: Color(0xFF0D1117),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
                _MapButton(
                  icon: Icons.share_location,
                  tooltip: 'Bagikan Lokasi',
                  isDarkMode: _isDarkMode,
                  onTap: () {
                    if (_userLocation == null) return;
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => ShareLocationSheet(
                        location: _userLocation!,
                        locationLabel: 'Lokasi saya via Mapku',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.alt_route,
                  isAccent: _waypointController.count > 0,
                  isDarkMode: _isDarkMode,
                  onTap: () {
                    if (_originPoint != null &&
                        _waypointController.count == 0) {
                      _waypointController.setOrigin(
                          Waypoint(label: 'Asal', latLng: _originPoint!));
                    }
                    if (_destinationPoint != null &&
                        _waypointController.count < 2) {
                      _waypointController.setDestination(Waypoint(
                          label: 'Tujuan', latLng: _destinationPoint!));
                    }
                    _showWaypointSheet();
                  },
                  tooltip: 'Rute Multi-Stop',
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.add,
                  isDarkMode: _isDarkMode,
                  onTap: () {
                    final z = (_currentZoom + 1).clamp(1.0, 19.0);
                    _mapController.move(
                        _mapController.camera.center, z);
                    setState(() => _currentZoom = z);
                  },
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.remove,
                  isDarkMode: _isDarkMode,
                  onTap: () {
                    final z = (_currentZoom - 1).clamp(1.0, 19.0);
                    _mapController.move(
                        _mapController.camera.center, z);
                    setState(() => _currentZoom = z);
                  },
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: _loadingLocation
                      ? Icons.hourglass_empty
                      : Icons.my_location,
                  isAccent: true,
                  isDarkMode: _isDarkMode,
                  onTap: _loadingLocation ? null : _getUserLocation,
                ),
              ],
            ),
          ),

          // ── BOTTOM LEFT FEATURE BUTTONS ──
          Positioned(
            bottom: 24,
            left: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapButton(
                  icon: Icons.place,
                  isDarkMode: _isDarkMode,
                  onTap: _showNearby,
                  tooltip: 'Tempat Terdekat',
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.star_outline,
                  isDarkMode: _isDarkMode,
                  onTap: _showFavorites,
                  tooltip: 'Favorit',
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.straighten,
                  isAccent: _distanceMeasure.isActive,
                  isDarkMode: _isDarkMode,
                  onTap: () {
                    if (_distanceMeasure.isActive) {
                      _distanceMeasure.stop();
                    } else {
                      _distanceMeasure.start();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                              'Tap 2 titik di peta untuk mengukur jarak'),
                          backgroundColor:
                              const Color(0xFFFBBF24).withValues(alpha: 0.9),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                  tooltip: 'Ukur Jarak',
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.layers_outlined,
                  isDarkMode: _isDarkMode,
                  onTap: _showMapTypePicker,
                  tooltip: 'Tipe Peta',
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: _isDarkMode
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_round,
                  isDarkMode: _isDarkMode,
                  onTap: _toggleTheme,
                  tooltip: _isDarkMode ? 'Mode Terang' : 'Mode Gelap',
                ),
              ],
            ),
          ),

          // ── HINT ──
          if (!_showSearchPanel &&
              _originPoint == null &&
              _destinationPoint == null &&
              !_loadingPlace &&
              !_distanceMeasure.isActive)
            Positioned(
              bottom: 24,
              left: 100,
              right: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_outlined,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tap lokasi untuk info • Tekan lama untuk set rute',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
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

class _TopSearchBar extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasRoute;
  final VoidCallback onShowRoute;
  final VoidCallback onClear;
  final bool isDarkMode;

  const _TopSearchBar({
    required this.onTap,
    required this.hasRoute,
    required this.onShowRoute,
    required this.onClear,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDarkMode ? const Color(0xFF1A1F2E) : Colors.white;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF22D3EE), size: 20),
                  const SizedBox(width: 10),
                  Text('Cari tempat atau alamat...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
        if (hasRoute) ...[
          const SizedBox(width: 8),
          _MapButton(
              icon: Icons.info_outline,
              isAccent: true,
              isDarkMode: isDarkMode,
              onTap: onShowRoute),
          const SizedBox(width: 8),
          _MapButton(
              icon: Icons.close,
              isDanger: true,
              isDarkMode: isDarkMode,
              onTap: onClear),
        ],
      ],
    );
  }
}

class _SearchPanel extends StatelessWidget {
  final Function(SearchResult) onOriginSelected;
  final Function(SearchResult) onDestinationSelected;
  final VoidCallback onClose;
  final bool isDarkMode;

  const _SearchPanel({
    required this.onOriginSelected,
    required this.onDestinationSelected,
    required this.onClose,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDarkMode ? const Color(0xFF1A1F2E) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Cari Rute',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.trip_origin,
                    color: Color(0xFF4ADE80), size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: SearchBarWidget(
                      hint: 'Dari mana?',
                      onLocationSelected: onOriginSelected)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
            child: Row(
                children: List.generate(
                    4,
                    (_) => Container(
                          width: 1.5,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 1),
                          decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(1)),
                        ))),
          ),
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                    color: const Color(0xFFF87171).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.location_on,
                    color: Color(0xFFF87171), size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: SearchBarWidget(
                      hint: 'Ke mana?',
                      onLocationSelected: onDestinationSelected)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final bool isAccent;
  final bool isDanger;
  final bool isDarkMode;
  final VoidCallback? onTap;
  final String? tooltip;

  const _MapButton({
    required this.icon,
    this.isAccent = false,
    this.isDanger = false,
    this.isDarkMode = true,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = isDarkMode ? const Color(0xFF1A1F2E) : Colors.white;
    Color iconColor =
        isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;

    if (isAccent) {
      bgColor = const Color(0xFF22D3EE).withValues(alpha: 0.15);
      iconColor = const Color(0xFF22D3EE);
    } else if (isDanger) {
      bgColor = const Color(0xFFF87171).withValues(alpha: 0.15);
      iconColor = const Color(0xFFF87171);
    }

    final btn = Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final String mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF22D3EE)
              : const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF22D3EE)
                : Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0xFF22D3EE).withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected
                ? const Color(0xFF0D1117)
                : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

class _TappedMarker extends StatelessWidget {
  const _TappedMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFBBF24), width: 2),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.4),
              blurRadius: 8)
        ],
      ),
      child: const Icon(Icons.place, color: Color(0xFFFBBF24), size: 14),
    );
  }
}

class _UserLocationMarker extends StatefulWidget {
  @override
  State<_UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<_UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _anim = Tween(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) =>
          Stack(alignment: Alignment.center, children: [
        Container(
          width: 40 * _anim.value,
          height: 40 * _anim.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF22D3EE)
                .withValues(alpha: 0.25 * (1 - _anim.value)),
          ),
        ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF22D3EE),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.5),
                  blurRadius: 8)
            ],
          ),
        ),
      ]),
    );
  }
}

class _PinMarker extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _PinMarker({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF87171),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFF87171).withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: const Icon(Icons.location_on, color: Colors.white, size: 18),
      ),
      Container(width: 2, height: 8, color: const Color(0xFFF87171)),
    ]);
  }
}

class _DialogBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DialogBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}