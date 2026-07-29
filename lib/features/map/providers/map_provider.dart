import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/map_api_service.dart';

enum MapScreenState { idle, loadingLocation, loadingRoute, error, ready }

class MapProvider extends ChangeNotifier {
  final MapApiService _mapApi;
  final ConnectivityService _connectivity;

  MapProvider({MapApiService? mapApiService, ConnectivityService? connectivityService})
      : _mapApi = mapApiService ?? MapApiService(),
        _connectivity = connectivityService ?? ConnectivityService();

  MapScreenState _state = MapScreenState.idle;
  MapScreenState get state => _state;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  LatLng? _currentLocation;
  LatLng? get currentLocation => _currentLocation;

  LatLng? _destination;
  LatLng? get destination => _destination;

  List<LatLng> _routePoints = [];
  List<LatLng> get routePoints => _routePoints;

  double? _distanceKm;
  double? get distanceKm => _distanceKm;

  double? _durationMin;
  double? get durationMin => _durationMin;

  Future<void> getCurrentLocation() async {
    _setState(MapScreenState.loadingLocation);
    _errorMessage = null;

    if (!_connectivity.isOnline) {
      _setError('No internet connection');
      return;
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _setError('GPS is disabled. Please enable location services.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _setError('Location permission denied');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _setError('Location permission permanently denied. Please grant it from settings.');
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _currentLocation = LatLng(position.latitude, position.longitude);
      _setState(MapScreenState.ready);
    } catch (e) {
      _setError('Failed to get location: $e');
    }
  }

  void setDestination(LatLng point) {
    _destination = point;
    _routePoints = [];
    _distanceKm = null;
    _durationMin = null;
    notifyListeners();
  }

  Future<void> fetchRoute() async {
    if (_currentLocation == null || _destination == null) return;

    _setState(MapScreenState.loadingRoute);
    _errorMessage = null;

    if (!_connectivity.isOnline) {
      _setError('No internet connection');
      return;
    }

    try {
      Map<String, dynamic> result;
      try {
        result = await _mapApi.getRoute(
          startLat: _currentLocation!.latitude,
          startLng: _currentLocation!.longitude,
          endLat: _destination!.latitude,
          endLng: _destination!.longitude,
        );
      } catch (_) {
        result = await _mapApi.getRouteDirect(
          startLat: _currentLocation!.latitude,
          startLng: _currentLocation!.longitude,
          endLat: _destination!.latitude,
          endLng: _destination!.longitude,
        );
      }

      _distanceKm = (result['distance'] as num).toDouble();
      _durationMin = (result['duration'] as num).toDouble();
      final rawRoute = result['route'] as List;
      _routePoints = rawRoute.map((point) {
        final coords = point as List;
        return LatLng((coords[0] as num).toDouble(), (coords[1] as num).toDouble());
      }).toList();

      _setState(MapScreenState.ready);
    } on MapApiException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch route: $e');
    }
  }

  void clearRoute() {
    _destination = null;
    _routePoints = [];
    _distanceKm = null;
    _durationMin = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setState(MapScreenState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _setState(MapScreenState.error);
  }
}
