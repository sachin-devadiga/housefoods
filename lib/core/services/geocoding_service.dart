import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

class GeocodingService {
  Geocoding? _geocoding;

  Geocoding? get _instance {
    // `Geocoding()` constructs the platform implementation immediately. On
    // platforms where the geocoding plugin is not registered (Linux desktop,
    // or a device with no system geocoder) that constructor throws a null-check
    // error, so build it lazily and treat an unavailable platform as "no
    // geocoder" rather than crashing the screen that asked for an address.
    return _geocoding ??= _tryCreate();
  }

  Geocoding? _tryCreate() {
    try {
      return Geocoding();
    } catch (_) {
      return null;
    }
  }

  /// In-memory cache keyed by rounded coordinates. Reverse geocoding is a
  /// slow platform call and the user rarely moves more than a few hundred
  /// metres between screen opens, so this avoids a repeat lookup per rebuild.
  String? _cachedLabel;
  String? _cachedForKey;

  /// A short, human-scale locality name ("Koramangala, Bengaluru").
  ///
  /// Deliberately coarse: the app only needs enough to tell the user where
  /// "deliver to" currently points, not a full postal address. Returns null
  /// when nothing resolves so callers can fall back rather than showing
  /// "Address not found" as if it were a place name.
  Future<String?> getShortLabel(LatLng position) async {
    final key = '${position.latitude.round()}:${position.longitude.round()}';
    if (_cachedForKey == key && _cachedLabel != null) return _cachedLabel;

    final geocoding = _instance;
    if (geocoding == null) return null;

    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return null;

      final p = placemarks.first;

      // Most specific first, deduped: on Android `name` is often a house
      // number or a street fragment, which is noise for a header label.
      final parts = <String?>[
        p.subLocality,
        p.locality,
        p.administrativeArea,
      ].where((e) => e != null && e.trim().isNotEmpty).toSet().toList();

      if (parts.isEmpty) return null;

      final label = parts.take(2).join(', ');
      _cachedForKey = key;
      _cachedLabel = label;
      return label;
    } catch (_) {
      // Reverse geocoding is best-effort. A failure must not break the
      // location flow, which already succeeded.
      return null;
    }
  }

  /// Translates GPS coordinates into a human-readable address
  Future<String> getAddressFromCoords(LatLng position) async {
    final geocoding = _instance;
    if (geocoding == null) return "Address not found";
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];

        // Constructing a detailed address string
        final address = [
          if (place.name != null && place.name != place.street) place.name,
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        return address.isNotEmpty ? address : "Address not found";
      }
      return "Address not found";
    } catch (e) {
      return "Error fetching address: $e";
    }
  }
}
