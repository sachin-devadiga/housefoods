import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/location_service.dart';
import '../providers/kitchen_provider.dart';
import '../../domain/models/kitchen_model.dart';
import 'kitchen_details_screen.dart';

class KitchenMapScreen extends StatefulWidget {
  const KitchenMapScreen({super.key});

  @override
  State<KitchenMapScreen> createState() => _KitchenMapScreenState();
}

class _KitchenMapScreenState extends State<KitchenMapScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();

  /// Fallback centre so the map still renders tiles when there is no fix yet.
  static const LatLng _fallbackCentre = LatLng(20.5937, 78.9629);

  LatLng? _userLocation;
  LocationStatus _locationStatus = LocationStatus.granted;
  String? _locationError;
  bool _locating = true;
  bool _showNearbyOnly = false;
  static const double _nearbyRadiusKm = 1.2;

  @override
  void initState() {
    super.initState();
    _requestLocation();
    final provider = context.read<KitchenProvider>();
    if (provider.kitchens.isEmpty) {
      provider.fetchKitchens();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });

    final result = await _locationService.getCurrentLocation();
    if (!mounted) return;

    setState(() {
      _locating = false;
      _locationStatus = result.status;
      _locationError = result.reason;
      if (result.isGranted) {
        _userLocation = LatLng(
          result.position!.latitude,
          result.position!.longitude,
        );
      }
    });

    if (result.isGranted) _centreOnUser();
  }

  void _centreOnUser() {
    final target = _userLocation;
    if (target == null) return;
    _mapController.move(target, 15.5);
  }

  Future<void> _recoverLocation() async {
    // deniedForever can only be undone from the OS settings screen; every other
    // failure state is worth one more in-app attempt first.
    if (_locationStatus == LocationStatus.deniedForever ||
        _locationStatus == LocationStatus.serviceDisabled) {
      final opened = _locationStatus == LocationStatus.deniedForever
          ? await _locationService.openAppSettings()
          : await _locationService.openLocationSettings();
      if (!opened && mounted) {
        setState(() {
          _locationError = 'Could not open settings. Enable location manually.';
        });
      }
      return;
    }
    await _requestLocation();
  }

  LatLng get _centre => _userLocation ?? _fallbackCentre;

  double _distanceTo(KitchenModel kitchen) {
    final user = _userLocation;
    if (user == null) return double.infinity;
    return _locationService.calculateDistance(
      user.latitude,
      user.longitude,
      kitchen.latitude,
      kitchen.longitude,
    );
  }

  List<KitchenModel> _sortedKitchens(KitchenProvider provider) {
    final list = List<KitchenModel>.from(provider.kitchens);
    if (_userLocation != null) {
      list.sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
    }
    return list;
  }

  List<KitchenModel> _nearbyKitchens(KitchenProvider provider) {
    return _sortedKitchens(provider)
        .where((k) => _distanceTo(k) <= _nearbyRadiusKm)
        .toList();
  }

  List<Marker> _createMarkers(KitchenProvider provider) {
    final kitchens =
        _showNearbyOnly ? _nearbyKitchens(provider) : provider.kitchens;
    return kitchens.map((kitchen) {
      final dist = _distanceTo(kitchen);
      final isNearby = dist <= _nearbyRadiusKm;
      return Marker(
        point: LatLng(kitchen.latitude, kitchen.longitude),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showKitchenInfo(kitchen, dist),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on,
                color: isNearby ? Colors.green : Colors.orange,
                size: 36,
              ),
              if (isNearby)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                  child: Text(
                    '${dist.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showKitchenInfo(KitchenModel kitchen, double dist) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kitchen.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${kitchen.rating} ★', style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(
              dist.isFinite
                  ? '${dist.toStringAsFixed(2)} km away'
                  : 'Distance unavailable',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => KitchenDetailsScreen(kitchen: kitchen)),
                  );
                },
                child: const Text('View Kitchen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker? _buildUserMarker() {
    final point = _userLocation;
    // Null (not a placeholder) when there is no fix, so no blue dot is
    // painted on the fallback centre and mistaken for the user.
    if (point == null) return null;

    return Marker(
      point: point,
      width: 22,
      height: 22,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationBanner(KitchenProvider provider) {
    if (_locating) {
      return _banner(
        message: 'Finding your location...',
        icon: Icons.my_location,
        busy: true,
      );
    }
    if (_userLocation != null) {
      final count = _nearbyKitchens(provider).length;
      return _banner(
        message: count > 0
            ? 'Showing kitchens nearest to you ($count within ${_nearbyRadiusKm.toStringAsFixed(1)} km)'
            : 'Location on - no kitchens within ${_nearbyRadiusKm.toStringAsFixed(1)} km yet',
        icon: Icons.check_circle,
        color: Colors.green,
        action: TextButton(
          onPressed: _centreOnUser,
          child: const Text('Recenter'),
        ),
      );
    }

    final label = switch (_locationStatus) {
      LocationStatus.serviceDisabled => 'Location is off. Turn it on to see kitchens near you.',
      LocationStatus.denied => 'Location permission needed to show kitchens near you.',
      LocationStatus.deniedForever =>
        'Location is blocked. Allow it in Settings to see kitchens near you.',
      LocationStatus.unsupported =>
        'Location is not available on this device.',
      _ => _locationError ?? 'Could not get your location.',
    };

    return _banner(
      message: label,
      icon: Icons.location_disabled,
      color: Colors.deepOrange,
      action: TextButton(
        onPressed: _recoverLocation,
        child: Text(
          _locationStatus == LocationStatus.serviceDisabled ? 'Settings' : 'Enable',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      onTap: _recoverLocation,
    );
  }

  Widget _banner({
    required String message,
    required IconData icon,
    Color? color,
    bool busy = false,
    Widget? action,
    VoidCallback? onTap,
  }) {
    final bg = color ?? AppTheme.primaryColor;
    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              else
                Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13.5, height: 1.3),
                ),
              ),
              if (action != null) action,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kitchenProvider = Provider.of<KitchenProvider>(context);
    final nearby = _nearbyKitchens(kitchenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kitchens Near You"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showNearbyOnly ? Icons.filter_alt : Icons.filter_alt_outlined),
            tooltip: _showNearbyOnly ? 'Show all' : 'Nearby only (≤1.2 km)',
            onPressed: () => setState(() => _showNearbyOnly = !_showNearbyOnly),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLocationBanner(kitchenProvider),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _centre,
                    initialZoom: _userLocation != null ? 15.5 : 11.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.mealin.app',
                      // Mutatable map on purpose: TileLayer injects its own
                      // User-Agent into this map and a `const` literal throws
                      // "Cannot modify unmodifiable map" at build time.
                      tileProvider: NetworkTileProvider(
                        headers: {
                          'User-Agent': 'Mealin/1.0 (contact@mealin.in)'
                        },
                        silenceExceptions: true,
                      ),
                    ),
                    MarkerLayer(markers: [
                      if (_buildUserMarker() != null) _buildUserMarker()!,
                      ..._createMarkers(kitchenProvider),
                    ]),
                    RichAttributionWidget(
                      attributions: const [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 12,
                  bottom: nearby.isNotEmpty ? 232 : 12,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter',
                    backgroundColor: Colors.white,
                    onPressed: _userLocation != null
                        ? _centreOnUser
                        : _recoverLocation,
                    tooltip: 'My location',
                    child: Icon(
                      _userLocation != null
                          ? Icons.my_location
                          : Icons.location_searching,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                if (nearby.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(
                              children: [
                                const Icon(Icons.restaurant, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Nearby kitchens (≤${_nearbyRadiusKm.toStringAsFixed(1)} km): ${nearby.length}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: nearby.length,
                              itemBuilder: (context, index) {
                                final k = nearby[index];
                                final d = _distanceTo(k);
                                return ListTile(
                                  dense: true,
                                  leading:
                                      const Icon(Icons.location_on, color: Colors.green),
                                  title: Text(k.name),
                                  subtitle: Text('${k.rating} ★'),
                                  trailing: Text('${d.toStringAsFixed(2)} km'),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            KitchenDetailsScreen(kitchen: k)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'list',
        onPressed: () => Navigator.pop(context),
        backgroundColor: AppTheme.primaryColor,
        label: const Text("List View", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.list, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
