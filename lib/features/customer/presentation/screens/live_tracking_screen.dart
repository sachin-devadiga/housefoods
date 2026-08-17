import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/order_model.dart';
import '../widgets/daily_feedback_dialog.dart';

class LiveTrackingScreen extends StatefulWidget {
  final OrderModel order;

  const LiveTrackingScreen({super.key, required this.order});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final ApiService _api = ApiService(baseUrl: AppConstants.apiBaseUrl);
  final LocationService _locationService = LocationService();
  final Completer<GoogleMapController> _mapController = Completer();
  String _currentStatus = '';
  bool _feedbackPrompted = false;
  Timer? _pollTimer;
  LatLng? _currentPosition;
  LatLng? _kitchenPosition;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
    _loadLocations();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchStatus());
  }

  Future<void> _loadLocations() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          _markers.add(Marker(
            markerId: const MarkerId('current_location'),
            position: _currentPosition!,
            infoWindow: const InfoWindow(title: 'Your Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ));
        });
        _fitMapBounds();
      }
    } catch (_) {
      debugPrint('Failed to get current location');
    }

    if (widget.order.kitchenId.isNotEmpty) {
      try {
        final data = await _api.get('${AppConstants.kitchensEndpoint}${widget.order.kitchenId}/');
        final lat = data['latitude'];
        final lng = data['longitude'];
        if (lat != null && lng != null) {
          final kitchenLatLng = LatLng(double.parse(lat.toString()), double.parse(lng.toString()));
          setState(() {
            _kitchenPosition = kitchenLatLng;
            _markers.add(Marker(
              markerId: const MarkerId('kitchen'),
              position: kitchenLatLng,
              infoWindow: InfoWindow(title: widget.order.kitchenName),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            ));
          });
          _fitMapBounds();
        }
      } catch (_) {
        debugPrint('Failed to load kitchen location');
      }
    }

    if (_currentPosition == null && _kitchenPosition != null) {
      _mapController.future.then((c) => c.animateCamera(CameraUpdate.newLatLngZoom(_kitchenPosition!, 14)));
    }
  }

  void _fitMapBounds() {
    if (_currentPosition != null && _kitchenPosition != null) {
      final bounds = _boundsContaining([_currentPosition!, _kitchenPosition!]);
      _mapController.future.then((controller) {
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      });
    } else if (_currentPosition != null) {
      _mapController.future.then((controller) {
        controller.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 15));
      });
    }
  }

  LatLngBounds _boundsContaining(List<LatLng> points) {
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  Future<void> _fetchStatus() async {
    try {
      final data = await _api.get('${AppConstants.orderStatusEndpoint}/${widget.order.id}/');
      final status = data['delivery_status'] as String? ?? data['status'] as String? ?? _currentStatus;
      if (status != _currentStatus) {
        setState(() => _currentStatus = status);
      }
      if ((status == 'delivered' || status == 'Delivered') && !_feedbackPrompted) {
        _feedbackPrompted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showFeedbackDialog());
      }
    } catch (_) {}
  }

  void _showFeedbackDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DailyFeedbackDialog(
        orderId: widget.order.id,
        date: DateTime.now(),
        mealName: widget.order.mealType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Track Daily Meal"),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentPosition ?? _kitchenPosition ?? const LatLng(28.6139, 77.2090),
                zoom: 14,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }
                _fitMapBounds();
              },
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKitchenInfo(),
                    const Divider(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Delivery Status",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (_currentStatus == 'delivered' || _currentStatus == 'Delivered')
                          TextButton.icon(
                            onPressed: _showFeedbackDialog,
                            icon: const Icon(Icons.star_outline, size: 16),
                            label: const Text("Rate Meal", style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildStepper(_currentStatus),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKitchenInfo() {
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: const Icon(Icons.restaurant, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.order.kitchenName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "Meal: ${widget.order.mealType.toUpperCase()}",
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepper(String status) {
    final normalizedStatus = status.toLowerCase();
    final List<Map<String, dynamic>> steps = [
      {"title": "Order Active", "keys": ["active"], "icon": Icons.check_circle},
      {"title": "Preparing your meal", "keys": ["preparing", "ready_for_delivery"], "icon": Icons.soup_kitchen},
      {"title": "Out for delivery", "keys": ["picked_up", "out for delivery"], "icon": Icons.delivery_dining},
      {"title": "Delivered", "keys": ["delivered"], "icon": Icons.home},
    ];

    int currentStepIndex = 0;
    for (int i = 0; i < steps.length; i++) {
      final keys = steps[i]['keys'] as List<String>;
      if (keys.any((k) => k == normalizedStatus)) {
        currentStepIndex = i;
        break;
      }
    }

    return Column(
      children: List.generate(steps.length, (index) {
        bool isCompleted = index <= currentStepIndex;
        bool isCurrent = index == currentStepIndex;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(
                  steps[index]['icon'],
                  color: isCompleted ? AppTheme.secondaryColor : Colors.grey[300],
                ),
                if (index != steps.length - 1)
                  Container(
                    width: 2,
                    height: 40,
                    color: isCompleted ? AppTheme.secondaryColor : Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    steps[index]['title'],
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted ? Colors.black : Colors.grey,
                    ),
                  ),
                  if (isCurrent)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _getStatusDescription(normalizedStatus),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'active': return "Your subscription is confirmed.";
      case 'preparing':
      case 'ready_for_delivery': return "Chef is preparing your healthy meal.";
      case 'picked_up':
      case 'out for delivery': return "Our partner is on the way to your door.";
      case 'delivered': return "Enjoy your meal! See you tomorrow.";
      default: return "Processing your order...";
    }
  }
}
