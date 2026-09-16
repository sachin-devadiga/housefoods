import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'meal_voice_engine.dart';

/// Gemini Live voice engine for the MEAL voice assistant.
///
/// Uses native Kotlin WebSocket connection to Google's Gemini Multimodal Live API.
/// The backend provides session config (API key, model, tools) via REST endpoint.
/// The API key is fetched per-session and never stored in the APK.
class GeminiLiveEngine implements MealVoiceEngine {
  static const _methodChannel = MethodChannel('com.mealin/gemini_live');
  static const _eventChannel = EventChannel('com.mealin/gemini_live_events');

  @override
  String get engineName => 'GeminiLive';

  @override
  bool get isActive => _isActive;

  bool _isActive = false;
  bool _isInitialized = false;
  StreamSubscription? _eventSubscription;
  final _eventController = StreamController<MealVoiceEngineEvent>.broadcast();

  String _backendUrl = '';
  String _authToken = '';
  void Function(String)? _onLog;
  void Function(MealVoiceEngineEvent)? _onEvent;

  Stream<MealVoiceEngineEvent> get events => _eventController.stream;

  @override
  Future<bool> initialize({
    required String backendUrl,
    required String authToken,
    required void Function(String log) onLog,
    required void Function(MealVoiceEngineEvent event) onEvent,
  }) async {
    _backendUrl = backendUrl;
    _authToken = authToken;
    _onLog = onLog;
    _onEvent = onEvent;

    if (_isInitialized) return true;

    try {
      _eventSubscription?.cancel();
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _onNativeEvent,
        onError: (error) {
          _log('Event stream error: $error');
        },
      );

      _isInitialized = true;
      _log('GeminiLive engine initialized');
      return true;
    } catch (e) {
      _log('GeminiLive init failed: $e');
      return false;
    }
  }

  @override
  Future<void> startListening() async {
    if (_isActive) {
      _log('Already active — skipping');
      return;
    }

    _log('Fetching Gemini Live session config from backend...');

    try {
      // Fetch session config from backend
      final config = await _fetchSessionConfig();
      if (config == null) {
        _log('Failed to fetch session config');
        _onEvent?.call(EngineErrorEvent(
          message: 'Could not connect to Gemini Live. Falling back.',
          recoverable: true,
        ));
        return;
      }

      _log('Session config received, connecting to Gemini Live...');
      _onEvent?.call(EngineStateChangedEvent(newState: 'connecting'));

      // Connect via native Kotlin engine
      final result = await _methodChannel.invokeMethod<bool>('connect', config);
      if (result == true) {
        _isActive = true;
        _log('GeminiLive connected');
      } else {
        _log('GeminiLive connection failed');
        _onEvent?.call(EngineErrorEvent(
          message: 'Failed to connect to Gemini Live',
          recoverable: true,
        ));
      }
    } catch (e) {
      _log('GeminiLive start error: $e');
      _onEvent?.call(EngineErrorEvent(
        message: 'Gemini Live error: $e',
        recoverable: true,
      ));
    }
  }

  @override
  Future<void> stopListening() async {
    if (!_isActive) return;
    _log('Stopping GeminiLive...');
    try {
      await _methodChannel.invokeMethod('disconnect');
    } catch (e) {
      _log('Stop error: $e');
    }
    _isActive = false;
  }

  @override
  Future<void> sendText(String text) async {
    if (!_isActive) return;
    try {
      await _methodChannel.invokeMethod('sendText', {'text': text});
      _log('Text sent: $text');
    } catch (e) {
      _log('Send text error: $e');
    }
  }

  @override
  Future<void> sendAudio(List<int> audioData) async {
    if (!_isActive) return;
    try {
      await _methodChannel.invokeMethod('sendAudio', {'audio': audioData});
    } catch (e) {
      _log('Send audio error: $e');
    }
  }

  @override
  Future<void> sendFunctionResponse(String callId, Map<String, dynamic> response) async {
    if (!_isActive) return;
    try {
      await _methodChannel.invokeMethod('sendFunctionResponse', {
        'callId': callId,
        'response': response,
      });
      _log('Function response sent for $callId');
    } catch (e) {
      _log('Send function response error: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    _isActive = false;
    try {
      await _methodChannel.invokeMethod('disconnect');
    } catch (e) {
      _log('Disconnect error: $e');
    }
    _log('GeminiLive disconnected');
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _isActive = false;
    _isInitialized = false;
  }

  /// Fetch Gemini Live session config from backend.
  Future<Map<String, dynamic>?> _fetchSessionConfig() async {
    try {
      final uri = Uri.parse('$_backendUrl/api/auth/voice/gemini-live-session/');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _log('Session config: model=${data['model']}, voice=${data['voice']}');
        return data;
      } else {
        _log('Session config HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _log('Session config fetch failed: $e');
      return null;
    }
  }

  /// Handle events from the native Kotlin Gemini Live engine.
  void _onNativeEvent(dynamic event) {
    if (event is! Map) return;

    final type = event['type'] as String?;
    final data = event['data'];

    switch (type) {
      case 'connected':
        _log('GeminiLive connected');
        _onEvent?.call(EngineConnected(engineName: 'GeminiLive'));
        break;

      case 'disconnected':
        final reason = data?.toString() ?? 'Unknown';
        _log('GeminiLive disconnected: $reason');
        _isActive = false;
        _onEvent?.call(EngineDisconnected(reason: reason));
        break;

      case 'transcription':
        if (data is Map) {
          final text = data['text'] as String? ?? '';
          final isFinal = data['isFinal'] as bool? ?? false;
          _onEvent?.call(EngineTranscription(text: text, isFinal: isFinal));
        }
        break;

      case 'response':
        final text = data?.toString() ?? '';
        _log('GeminiLive response: ${text.substring(0, text.length > 100 ? 100 : text.length)}...');
        _onEvent?.call(EngineResponse(text: text));
        break;

      case 'functionCall':
        if (data is Map) {
          final name = data['name'] as String? ?? '';
          final args = Map<String, dynamic>.from(data['args'] ?? {});
          _log('Function call: $name($args)');
          _onEvent?.call(EngineFunctionCall(name: name, args: args));
        }
        break;

      case 'audioOutput':
        if (data is List) {
          _onEvent?.call(EngineAudioOutput(audioData: Uint8List.fromList(data.cast<int>())));
        }
        break;

      case 'error':
        final message = data?.toString() ?? 'Unknown error';
        _log('GeminiLive error: $message');
        _onEvent?.call(EngineErrorEvent(message: message));
        break;

      case 'state':
        final state = data?.toString() ?? 'unknown';
        _log('GeminiLive state: $state');
        _onEvent?.call(EngineStateChangedEvent(newState: state));
        break;

      case 'log':
        _log('Native: ${data?.toString() ?? ""}');
        break;
    }
  }

  void _log(String message) {
    _onLog?.call('[GeminiLive] $message');
  }
}
