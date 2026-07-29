import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeocodingService {
  final Geocoding _geocoding = Geocoding();

  /// Translates GPS coordinates into a human-readable address
  Future<String> getAddressFromCoords(LatLng position) async {
    try {
      List<Placemark> placemarks = await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Constructing a detailed address string
        String address = [
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
