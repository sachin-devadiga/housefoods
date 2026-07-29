import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/map_provider.dart';

class MapScreen extends StatefulWidget {
  final LatLng? initialDestination;
  const MapScreen({super.key, this.initialDestination});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MapProvider>();
      provider.getCurrentLocation();
      if (widget.initialDestination != null) {
        provider.setDestination(widget.initialDestination!);
      }
    });
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    context.read<MapProvider>().setDestination(point);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () => context.read<MapProvider>().getCurrentLocation(),
            tooltip: 'Refresh location',
          ),
        ],
      ),
      body: Consumer<MapProvider>(
        builder: (context, provider, child) {
          return Stack(
            children: [
              _buildMap(provider),
              if (provider.state == MapScreenState.loadingLocation)
                const Center(child: CircularProgressIndicator()),
              if (provider.state == MapScreenState.error)
                _buildErrorOverlay(provider),
              _buildBottomPanel(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(MapProvider provider) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: provider.currentLocation ?? const LatLng(20.5937, 78.9629),
        initialZoom: 15.0,
        onTap: _onMapTap,
        onMapReady: () {
          if (provider.currentLocation != null) {
            _mapController.move(provider.currentLocation!, 15.0);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.housefoods.app',
        ),
        if (provider.currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: provider.currentLocation!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 1),
                    ],
                  ),
                  child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        if (provider.destination != null)
          MarkerLayer(
            markers: [
              Marker(
                point: provider.destination!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 1),
                    ],
                  ),
                  child: const Icon(Icons.location_on, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        if (provider.routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: provider.routePoints,
                color: AppTheme.primaryColor,
                strokeWidth: 5.0,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildErrorOverlay(MapProvider provider) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.errorMessage ?? 'An error occurred',
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    provider.clearError();
                    provider.getCurrentLocation();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 36),
                  ),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(MapProvider provider) {
    if (provider.destination == null) {
      return Positioned(
        bottom: 16,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
          ),
          child: const Text(
            'Tap on the map to set a destination',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.state == MapScreenState.loadingRoute)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (provider.routePoints.isNotEmpty && provider.distanceKm != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _infoChip(Icons.straighten, '${provider.distanceKm!.toStringAsFixed(1)} km'),
                  _infoChip(Icons.access_time, '${provider.durationMin!.toStringAsFixed(0)} min'),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.state == MapScreenState.loadingRoute
                        ? null
                        : () => provider.fetchRoute(),
                    icon: const Icon(Icons.route, size: 18),
                    label: Text(provider.routePoints.isEmpty ? 'Get Route' : 'Recalculate'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => provider.clearRoute(),
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  tooltip: 'Clear destination',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.secondaryColor),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
