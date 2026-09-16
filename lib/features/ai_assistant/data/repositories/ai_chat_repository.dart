import 'package:dio/dio.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/models/ai_chat_models.dart';

class AiChatRepository {
  final ApiService _apiService;
  final LocationService _locationService;

  AiChatRepository({
    required ApiService apiService,
    LocationService? locationService,
  })  : _apiService = apiService,
        _locationService = locationService ?? LocationService();

  Future<AiChatResponse> sendMessage({
    required String message,
    required List<AiChatMessage> conversationHistory,
  }) async {
    double? lat;
    double? lng;

    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
      }
    } catch (_) {}

    final historyJson = conversationHistory
        .map((m) => {
              'role': m.role,
              'content': m.text,
            })
        .toList();

    final body = <String, dynamic>{
      'message': message,
      'conversation_history': historyJson,
    };

    if (lat != null && lng != null) {
      body['location'] = {'latitude': lat, 'longitude': lng};
    }

    try {
      final response = await _apiService.post(
        '/api/auth/ai/chat/',
        body: body,
      );

      return AiChatResponse.fromJson(response);
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      throw ApiException(
        e.message ?? 'Network error',
        e.response?.statusCode ?? 0,
      );
    } catch (e) {
      throw ApiException('Unexpected error: $e', 0);
    }
  }
}
