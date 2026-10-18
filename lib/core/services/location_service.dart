import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Why a location request ended the way it did.
///
/// The previous implementation threw on every failure path and the map screen
/// swallowed those throws, so a denied permission was indistinguishable from a
/// missing GPS fix: both produced a silent fallback to a hard-coded centre and
/// no prompt. Callers now branch on this instead.
enum LocationStatus {
  granted,
  serviceDisabled,
  denied,
  deniedForever,
  failed,
  unsupported,
}

class LocationResult {
  final LocationStatus status;
  final Position? position;
  final String? reason;

  const LocationResult._(this.status, {this.position, this.reason});

  const LocationResult.granted(Position position)
      : this._(LocationStatus.granted, position: position);

  const LocationResult.serviceDisabled()
      : this._(LocationStatus.serviceDisabled,
            reason: 'Location services are turned off.');

  const LocationResult.denied()
      : this._(LocationStatus.denied,
            reason: 'Location permission was declined.');

  const LocationResult.deniedForever()
      : this._(LocationStatus.deniedForever,
            reason: 'Location permission is blocked. Enable it in Settings.');

  const LocationResult.failed(String reason)
      : this._(LocationStatus.failed, reason: reason);

  const LocationResult.unsupported()
      : this._(LocationStatus.unsupported,
            reason: 'Location is not available on this platform.');

  bool get isGranted => status == LocationStatus.granted && position != null;

  /// True when re-requesting will not show a system dialog, so the only way
  /// forward is the app's settings screen.
  bool get needsSettings => status == LocationStatus.deniedForever;
}

class LocationService {
  /// Resolves the current position, never throws.
  ///
  /// Order matters: permission is checked and requested BEFORE the service
  /// toggle. Checking `isLocationServiceEnabled` first returned early with an
  /// error whenever GPS was off, which meant the permission dialog never
  /// appeared on those devices.
  Future<LocationResult> getCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.denied();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.deniedForever();
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.serviceDisabled();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationResult.granted(position);
    } on TimeoutException {
      return const LocationResult.failed(
        'Timed out getting a location fix. Try again outdoors.',
      );
    } catch (e) {
      return LocationResult.failed(e.toString());
    }
  }

  /// Only meaningful once a permission dialog has been shown and declined.
  /// `deniedForever` can only be recovered through app settings.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Calculates distance between two coordinates in Kilometers
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    final distanceInMeters =
        Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    return distanceInMeters / 1000; // Convert to KM
  }
}
