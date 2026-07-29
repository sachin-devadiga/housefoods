import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/geocoding_service.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  final LocationService _locationService = LocationService();
  final GeocodingService _geocodingService = GeocodingService();
  
  LatLng? _currentPosition;
  String _pickedAddress = "Locating...";
  bool _isLocating = true;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  Future<void> _setInitialLocation() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        final latLng = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _currentPosition = latLng;
        });
        _updateAddress(latLng);
      }
    } catch (e) {
      debugPrint("Initial Location Error: $e");
      setState(() => _isLocating = false);
    }
  }

  Future<void> _updateAddress(LatLng position) async {
    setState(() => _isLocating = true);
    final address = await _geocodingService.getAddressFromCoords(position);
    if (mounted) {
      setState(() {
        _pickedAddress = address;
        _isLocating = false;
      });
    }
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
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!,
                    zoom: 16.0,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  onCameraMove: (position) {
                    _currentPosition = position.target;
                  },
                  onCameraIdle: () {
                    if (_currentPosition != null) {
                      _updateAddress(_currentPosition!);
                    }
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                // Fixed Central Pin
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 35), // Offset for pin point
                    child: Icon(
                      Icons.location_on,
                      size: 45,
                      color: AppTheme.primaryColor,
                    ),
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
                onPressed: _isLocating ? null : () {
                  Navigator.pop(context, {
                    'address': _pickedAddress,
                    'lat': _currentPosition!.latitude,
                    'lng': _currentPosition!.longitude,
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
