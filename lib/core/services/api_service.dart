import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  late final Dio _dio;
  final String baseUrl;

  ApiService({required this.baseUrl, String? token}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(ApiInterceptor());
    if (token != null && token.isNotEmpty) {
      setToken(token);
    }
  }

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearToken() {
    _dio.options.headers.remove('Authorization');
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: body,
        queryParameters: queryParams,
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.put(endpoint, data: body);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _dio.patch(endpoint, data: body);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<String> uploadFile(String endpoint, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filePath.split(Platform.pathSeparator).last),
    });
    try {
      final response = await _dio.post(endpoint, data: formData);
      final data = _handleResponse(response);
      final url = data['image_url'] ?? data['url'] ?? '';
      return url;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Map<String, dynamic> _handleResponse(Response response) {
    final data = response.data;
    if (data is List) {
      return {'data': data, 'status_code': response.statusCode};
    }
    if (data is Map<String, dynamic>) {
      if (data.containsKey('results') && !data.containsKey('data')) {
        data['data'] = data['results'];
      }
      return data;
    }
    return {'data': data, 'status_code': response.statusCode};
  }

  ApiException _handleDioError(DioException e) {
    if (e.response != null && e.response?.data is Map) {
      final errorData = e.response!.data as Map<String, dynamic>;
      final message = errorData['error'] as String? ??
          errorData['detail'] as String? ??
          'Something went wrong';
      return ApiException(message, e.response!.statusCode ?? 0);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Request timed out', 0);
      case DioExceptionType.connectionError:
        return ApiException('No internet connection', 0);
      default:
        return ApiException('Something went wrong', 0);
    }
  }

  void dispose() {
    _dio.close();
  }
}

class ApiInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        'API Error: ${err.response?.statusCode} ${err.requestOptions.path}',
      );
    }
    handler.next(err);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('API Request: ${options.method} ${options.path}');
    }
    handler.next(options);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
