import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'token_service.dart';

class MapApiService {
  final TokenService _tokenService;

  MapApiService({TokenService? tokenService})
      : _tokenService = tokenService ?? TokenService();

  Future<Map<String, dynamic>> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final token = await _tokenService.getAccessToken();
    final uri = Uri.parse('${AppConstants.apiBaseUrl}${AppConstants.mapRouteEndpoint}').replace(
      queryParameters: {
        'start_lat': startLat.toString(),
        'start_lng': startLng.toString(),
        'end_lat': endLat.toString(),
        'end_lng': endLng.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }

    final body = response.body.isNotEmpty
        ? json.decode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};
    final message = body['error'] as String? ?? 'Failed to fetch route';
    throw MapApiException(message, response.statusCode);
  }

  Future<Map<String, dynamic>> getRouteDirect({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$startLng,$startLat;$endLng,$endLat'
      '?overview=full&geometries=geojson',
    );

    final response = await http.get(uri, headers: {'Content-Type': 'application/json'});

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok' || (data['routes'] as List?)?.isEmpty == true) {
        throw MapApiException('No route found', 404);
      }
      final route = (data['routes'] as List)[0] as Map<String, dynamic>;
      final distanceKm = ((route['distance'] as num) / 1000).toStringAsFixed(2);
      final durationMin = ((route['duration'] as num) / 60).toStringAsFixed(1);
      final coords = (route['geometry'] as Map<String, dynamic>)['coordinates'] as List;
      final routeCoords = coords.map((c) => [(c[1] as num).toDouble(), (c[0] as num).toDouble()]).toList();
      return {
        'distance': double.parse(distanceKm),
        'duration': double.parse(durationMin),
        'route': routeCoords,
      };
    }

    throw MapApiException('Routing service error', response.statusCode);
  }
}

class MapApiException implements Exception {
  final String message;
  final int statusCode;
  MapApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
