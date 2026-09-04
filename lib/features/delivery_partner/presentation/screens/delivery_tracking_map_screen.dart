import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/map_api_service.dart';
import '../../../../core/theme/app_theme.dart';

class DeliveryTrackingMapScreen extends StatefulWidget {
  final dynamic deliveryId;
  final String kitchenName;
  final String deliveryAddress;
  final String status;
  final Map<String, dynamic>? delivery;

  const DeliveryTrackingMapScreen({
    super.key,
    required this.deliveryId,
    required this.kitchenName,
    required this.deliveryAddress,
    required this.status,
    this.delivery,
  });

  @override
  State<DeliveryTrackingMapScreen> createState() => _DeliveryTrackingMapScreenState();
}

class _DeliveryTrackingMapScreenState extends State<DeliveryTrackingMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final LocationService _locationService = LocationService();
  final ApiService _api = ApiService(baseUrl: AppConstants.apiBaseUrl);

  LatLng? _riderPosition;
  LatLng? _kitchenPosition;
  LatLng? _customerPosition;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Timer? _locationTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) => _updateRiderLocation());
  }

  Future<void> _updateRiderLocation() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        setState(() {
          _riderPosition = LatLng(pos.latitude, pos.longitude);
          _markers.removeWhere((m) => m.markerId.value == 'rider');
          _markers.add(Marker(
            markerId: const MarkerId('rider'),
            position: _riderPosition!,
            infoWindow: const InfoWindow(title: 'Your Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ));
        });
        // Send GPS to backend so customer can see rider location
        _sendLocationToBackend(pos.latitude, pos.longitude);
      }
    } catch (_) {}
  }

  void _sendLocationToBackend(double lat, double lng) async {
    try {
      await _api.post(
        AppConstants.riderLocationUpdateEndpoint,
        body: {'latitude': lat, 'longitude': lng},
      );
    } catch (_) {}
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);

    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        _riderPosition = LatLng(pos.latitude, pos.longitude);
        _markers.add(Marker(
          markerId: const MarkerId('rider'),
          position: _riderPosition!,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ));
      }
    } catch (_) {}

    final kitchenLat = widget.delivery?['kitchen_details']?['latitude'];
    final kitchenLng = widget.delivery?['kitchen_details']?['longitude'];
    if (kitchenLat != null && kitchenLng != null) {
      _kitchenPosition = LatLng(
        double.tryParse(kitchenLat.toString()) ?? 0,
        double.tryParse(kitchenLng.toString()) ?? 0,
      );
      _markers.add(Marker(
        markerId: const MarkerId('kitchen'),
        position: _kitchenPosition!,
        infoWindow: InfoWindow(title: widget.kitchenName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }

    final customerLat = widget.delivery?['delivery_lat'];
    final customerLng = widget.delivery?['delivery_lng'];
    if (customerLat != null && customerLng != null) {
      _customerPosition = LatLng(
        double.tryParse(customerLat.toString()) ?? 0,
        double.tryParse(customerLng.toString()) ?? 0,
      );
      _markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: _customerPosition!,
        infoWindow: InfoWindow(title: widget.deliveryAddress),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    } else if (_riderPosition != null) {
      _customerPosition = _riderPosition;
    }

    if (_kitchenPosition != null && _customerPosition != null) {
      await _fetchRoute(_kitchenPosition!, _customerPosition!);
      _fitBounds();
    } else if (_riderPosition != null) {
      _moveToPosition(_riderPosition!);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    try {
      final mapApi = MapApiService();
      final route = await mapApi.getRoute(
        startLat: start.latitude,
        startLng: start.longitude,
        endLat: end.latitude,
        endLng: end.longitude,
      );
      if (route['route'] != null) {
        final coords = (route['route'] as List).map((c) {
          if (c is List && c.length >= 2) {
            return LatLng(c[0].toDouble(), c[1].toDouble());
          }
          return null;
        }).whereType<LatLng>().toList();

        if (coords.isNotEmpty && mounted) {
          setState(() {
            _polylines.clear();
            _polylines.add(Polyline(
              polylineId: const PolylineId('route'),
              points: coords,
              color: AppTheme.primaryColor,
              width: 5,
            ));
          });
        }
      }
    } catch (_) {
      debugPrint('Route fetch failed, trying direct OSRM...');
      try {
        final mapApi = MapApiService();
        final route = await mapApi.getRouteDirect(
          startLat: start.latitude,
          startLng: start.longitude,
          endLat: end.latitude,
          endLng: end.longitude,
        );
        if (route['route'] != null) {
          final coords = (route['route'] as List).map((c) {
            if (c is List && c.length >= 2) {
              return LatLng(c[0].toDouble(), c[1].toDouble());
            }
            return null;
          }).whereType<LatLng>().toList();

          if (coords.isNotEmpty && mounted) {
            setState(() {
              _polylines.clear();
              _polylines.add(Polyline(
                polylineId: const PolylineId('route'),
                points: coords,
                color: AppTheme.primaryColor,
                width: 5,
              ));
            });
          }
        }
      } catch (_) {}
    }
  }

  void _fitBounds() {
    final points = <LatLng>[];
    if (_riderPosition != null) points.add(_riderPosition!);
    if (_kitchenPosition != null) points.add(_kitchenPosition!);
    if (_customerPosition != null) points.add(_customerPosition!);
    if (points.length < 2) return;

    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    _mapController.future.then((c) => c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80)));
  }

  void _moveToPosition(LatLng pos) {
    _mapController.future.then((c) => c.animateCamera(CameraUpdate.newLatLngZoom(pos, 15)));
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _riderPosition ?? const LatLng(28.6139, 77.2090);

    return Scaffold(
      appBar: AppBar(
        title: Text('Route to ${widget.status == 'assigned' ? 'Kitchen' : 'Customer'}'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              if (!_mapController.isCompleted) _mapController.complete(controller);
            },
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.restaurant, 'Pickup', widget.kitchenName, Colors.orange),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.location_on, 'Delivery', widget.deliveryAddress, AppTheme.primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ],
    );
  }
}
