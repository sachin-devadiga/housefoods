import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class ApiService {
  late Dio _dio;
  final List<String> _candidateUrls;
  int _current = 0;

  ApiService({required String baseUrl, String? token})
      : _candidateUrls = _buildCandidates(baseUrl) {
    _dio = _createDio(baseUrl);
    _dio.interceptors.add(ApiInterceptor());
    if (token != null && token.isNotEmpty) {
      setToken(token);
    }
  }

  static List<String> _buildCandidates(String preferred) {
    final list = <String>[preferred, ...AppConstants.apiBaseUrlCandidates];
    return list.toSet().toList();
  }

  Dio _createDio(String url) {
    return Dio(BaseOptions(
      baseUrl: url,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  Future<bool> _probe(String url) async {
    try {
      final probe = Dio(BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
      ));
      final resp = await probe.get('/api/auth/kitchen-categories/',
          options: Options(
              validateStatus: (status) =>
                  status != null && status < 500 && status != 404));
      return resp.statusCode != null && resp.statusCode! < 500;
    } catch (_) {
      return false;
    }
  }

  void _useBaseUrl(String url) {
    final oldToken = _dio.options.headers['Authorization'];
    _dio = _createDio(url);
    _dio.interceptors.add(ApiInterceptor());
    if (oldToken != null) {
      _dio.options.headers['Authorization'] = oldToken;
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
    return _run(() => _dio.get(
          endpoint,
          queryParameters: queryParams,
        ));
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    return _run(() => _dio.post(
          endpoint,
          data: body,
          queryParameters: queryParams,
        ));
  }

  Future<Map<String, dynamic>> _run(Future<Response> Function() fn) async {
    DioException? lastError;

    Future<Map<String, dynamic>> attempt() async {
      final response = await fn();
      return _handleResponse(response);
    }

    try {
      return await attempt();
    } on DioException catch (e) {
      if (e.type != DioExceptionType.connectionError &&
          e.type != DioExceptionType.connectionTimeout &&
          e.type != DioExceptionType.receiveTimeout &&
          e.type != DioExceptionType.sendTimeout) {
        throw _handleDioError(e);
      }
      lastError = e;
    }

    for (var i = 0; i < _candidateUrls.length; i++) {
      if (i == _current) continue;
      final candidate = _candidateUrls[i];
      if (!await _probe(candidate)) continue;
      _current = i;
      _useBaseUrl(candidate);
      try {
        return await attempt();
      } on DioException catch (e2) {
        lastError = e2;
      }
    }
    throw _handleDioError(lastError!);
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
          errorData.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      return ApiException(message, e.response!.statusCode ?? 0);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Request timed out', 0);
      case DioExceptionType.connectionError:
        final target = e.requestOptions.baseUrl + e.requestOptions.path;
        return ApiException(
            'No internet connection (failed: $target - ${e.message})', 0);
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
