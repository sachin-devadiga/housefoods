import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/location_service.dart';
import '../providers/kitchen_provider.dart';
import 'kitchen_details_screen.dart';

class KitchenMapScreen extends StatefulWidget {
  const KitchenMapScreen({super.key});

  @override
  State<KitchenMapScreen> createState() => _KitchenMapScreenState();
}

class _KitchenMapScreenState extends State<KitchenMapScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  final LocationService _locationService = LocationService();
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null && mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (e) {
      debugPrint("Map Location Error: $e");
    }
  }

  Set<Marker> _createMarkers(KitchenProvider provider) {
    return provider.kitchens.map((kitchen) {
      return Marker(
        markerId: MarkerId(kitchen.id),
        position: LatLng(kitchen.latitude, kitchen.longitude),
        infoWindow: InfoWindow(
          title: kitchen.name,
          snippet: "${kitchen.rating} ★ • ${provider.getDistanceTo(kitchen.id)?.toStringAsFixed(1) ?? '?'} km away",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => KitchenDetailsScreen(kitchen: kitchen)),
            );
          },
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final kitchenProvider = Provider.of<KitchenProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kitchens Near You"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _userLocation == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: _userLocation!,
                zoom: 14.0,
              ),
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              markers: _createMarkers(kitchenProvider),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              compassEnabled: true,
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context),
        backgroundColor: AppTheme.primaryColor,
        label: const Text("List View", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.list, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
