import 'dart:async';
import 'package:flutter/services.dart';
import 'meal_voice_state.dart';

/// Flutter-side service for MEAL voice wake-word detection.
///
/// Communicates with Android native [MealVoiceService] via
/// MethodChannel (commands) and EventChannel (events).
class MealVoiceService {
  static const _methodChannel = MethodChannel('com.mealin/voice_method');
  static const _eventChannel = EventChannel('com.mealin/voice_events');

  static MealVoiceService? _instance;
  static MealVoiceService get instance => _instance ??= MealVoiceService._();
  MealVoiceService._();

  StreamSubscription? _eventSubscription;
  final _eventController = StreamController<MealVoiceEvent>.broadcast();

  MealVoiceState _currentState = MealVoiceState.idle;
  MealVoiceState get currentState => _currentState;

  bool _isInitialized = false;

  /// Stream of events from the native voice engine
  Stream<MealVoiceEvent> get events => _eventController.stream;

  /// Initialize the service and start listening for native events
  Future<void> initialize() async {
    if (_isInitialized) return;

    _log('Initializing MEAL voice service');

    // Set up event stream from native side
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _onNativeEvent,
      onError: (error) {
        _log('Event stream error: $error', level: 'error');
        _eventController.add(EngineError(message: 'Event stream error: $error'));
      },
    );

    // Set up method call handler for native → Flutter calls
    _methodChannel.setMethodCallHandler(_onMethodCall);

    _isInitialized = true;
    _log('MEAL voice service initialized');
  }

  /// Handle method calls from native side
  Future<dynamic> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'wakeWordDetected':
        final timestamp = call.arguments as int?;
        _log('Wake word detected from native');
        _eventController.add(WakeWordDetected(
          timestamp: timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.now(),
        ));
        break;
      case 'stateChanged':
        final stateIndex = call.arguments as int;
        final newState = MealVoiceState.values[stateIndex];
        _currentState = newState;
        _eventController.add(EngineStateChanged(newState: newState));
        break;
      case 'error':
        final message = call.arguments as String? ?? 'Unknown error';
        _log('Native error: $message', level: 'error');
        _eventController.add(EngineError(message: message));
        break;
      case 'log':
        final message = call.arguments as String? ?? '';
        _log('Native: $message');
        break;
    }
  }

  /// Parse event from native EventChannel
  void _onNativeEvent(dynamic event) {
    if (event is Map) {
      final type = event['type'] as String?;
      switch (type) {
        case 'wakeWordDetected':
          _log('Wake word detected');
          _eventController.add(WakeWordDetected(
            timestamp: DateTime.now(),
          ));
          break;
        case 'stateChanged':
          final stateIndex = event['state'] as int? ?? 0;
          final newState = MealVoiceState.values[stateIndex];
          _currentState = newState;
          _eventController.add(EngineStateChanged(newState: newState));
          break;
        case 'error':
          final message = event['message'] as String? ?? 'Unknown error';
          _log('Error: $message', level: 'error');
          _eventController.add(EngineError(message: message));
          break;
      }
    }
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    try {
      _log('Requesting microphone permission');
      final result = await _methodChannel.invokeMethod<bool>('requestMicrophonePermission');
      final granted = result ?? false;
      _log('Microphone permission: ${granted ? "granted" : "denied"}');
      return granted;
    } catch (e) {
      _log('Permission request failed: $e', level: 'error');
      return false;
    }
  }

  /// Start the wake-word detection service
  Future<bool> startListening() async {
    try {
      _log('Starting wake-word detection');
      final result = await _methodChannel.invokeMethod<bool>('startListening');
      if (result == true) {
        _currentState = MealVoiceState.listeningForWakeWord;
        _eventController.add(EngineStateChanged(
          newState: MealVoiceState.listeningForWakeWord,
        ));
        _log('Wake-word detection started');
        return true;
      }
      _log('Failed to start listening', level: 'warning');
      return false;
    } catch (e) {
      _log('Start listening failed: $e', level: 'error');
      return false;
    }
  }

  /// Stop the wake-word detection service
  Future<bool> stopListening() async {
    try {
      _log('Stopping wake-word detection');
      final result = await _methodChannel.invokeMethod<bool>('stopListening');
      if (result == true) {
        _currentState = MealVoiceState.stopped;
        _eventController.add(EngineStateChanged(
          newState: MealVoiceState.stopped,
        ));
        _log('Wake-word detection stopped');
        return true;
      }
      return false;
    } catch (e) {
      _log('Stop listening failed: $e', level: 'error');
      return false;
    }
  }

  /// Check if microphone is available
  Future<bool> isMicrophoneAvailable() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isMicrophoneAvailable');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get current service status
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getStatus');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Log a message with level
  void _log(String message, {String level = 'info'}) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    print('[MEAL][$timestamp][$level] $message');
  }

  /// Dispose resources
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
    _isInitialized = false;
  }
}
