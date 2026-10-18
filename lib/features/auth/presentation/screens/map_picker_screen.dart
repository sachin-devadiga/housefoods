import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/geocoding_service.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final GeocodingService _geocodingService = GeocodingService();

  LatLng? _currentCenter;
  String _pickedAddress = "Locating...";
  bool _isLocating = true;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _setInitialLocation() async {
    final result = await _locationService.getCurrentLocation();
    if (!mounted) return;
    if (result.isGranted) {
      final pos = result.position!;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentCenter = latLng;
      });
      _mapController.move(latLng, 16.0);
      _updateAddress(latLng);
    } else {
      debugPrint("Initial location unavailable: ${result.status} ${result.reason}");
      setState(() => _isLocating = false);
    }
  }

  Future<void> _updateAddress(LatLng position) async {
    if (!mounted) return;
    setState(() => _isLocating = true);
    final address = await _geocodingService.getAddressFromCoords(position);
    if (mounted) {
      setState(() {
        _pickedAddress = address;
        _isLocating = false;
      });
    }
  }

  Future<void> _goToMyLocation() async {
    final result = await _locationService.getCurrentLocation();
    if (!result.isGranted) {
      debugPrint("My location unavailable: ${result.status} ${result.reason}");
      return;
    }
    final pos = result.position!;
    final latLng = LatLng(pos.latitude, pos.longitude);
    _mapController.move(latLng, 16.0);
    if (mounted) setState(() => _currentCenter = latLng);
    _updateAddress(latLng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Delivery Location"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _currentCenter == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentCenter!,
                    initialZoom: 16.0,
                    onPositionChanged: (position, hasGesture) {
                      _currentCenter = position.center;
                    },
                    onMapEvent: (event) {
                      if (event is MapEventMoveEnd) {
                        _updateAddress(_currentCenter!);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.mealin.app',
                      tileProvider: NetworkTileProvider(
                        headers: {'User-Agent': 'Mealin/1.0 (contact@mealin.in)'},
                        silenceExceptions: true,
                      ),
                    ),
                  ],
                ),
                // Fixed Central Pin
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 35),
                    child: Icon(
                      Icons.location_on,
                      size: 45,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 220,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: _goToMyLocation,
                    child: const Icon(Icons.my_location, color: Colors.black),
                  ),
                ),
                _buildAddressCard(),
              ],
            ),
    );
  }

  Widget _buildAddressCard() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  const Text("SELECT ADDRESS",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  if (_isLocating)
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _pickedAddress,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLocating || _currentCenter == null
                    ? null
                    : () {
                        Navigator.pop(context, {
                          'address': _pickedAddress,
                          'lat': _currentCenter!.latitude,
                          'lng': _currentCenter!.longitude,
                        });
                      },
                child: const Text("Confirm Location"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}