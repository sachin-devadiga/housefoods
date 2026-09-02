import 'dart:async';
import 'package:flutter/services.dart';
import 'meal_voice_state.dart';

/// Flutter-side service for MEAL voice engine.
///
/// Communicates with Android native via MethodChannel (commands) and EventChannel (events).
/// Handles two-phase flow: wake word detection → command capture.
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

  /// Stream of events from the native voice engine.
  Stream<MealVoiceEvent> get events => _eventController.stream;

  /// Initialize the service and start listening for native events.
  Future<void> initialize() async {
    if (_isInitialized) return;

    _log('Initializing MEAL voice service');

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _onNativeEvent,
      onError: (error) {
        _log('Event stream error: $error', level: 'error');
        _eventController.add(EngineError(message: 'Event stream error: $error'));
      },
    );

    _methodChannel.setMethodCallHandler(_onMethodCall);

    _isInitialized = true;
    _log('MEAL voice service initialized');
  }

  /// Handle method calls from native side.
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
        if (stateIndex < MealVoiceState.values.length) {
          final newState = MealVoiceState.values[stateIndex];
          _currentState = newState;
          _eventController.add(EngineStateChanged(newState: newState));
        }
        break;
      case 'error':
        final message = call.arguments as String? ?? 'Unknown error';
        _log('Native error: $message', level: 'error');
        _eventController.add(EngineError(message: message));
        break;
      case 'commandTranscription':
        final text = call.arguments as String? ?? '';
        _log('Command transcription: $text');
        _eventController.add(SpeechTranscriptionReceived(transcript: text, isFinal: true));
        break;
      case 'speechPartial':
        final text = call.arguments as String? ?? '';
        _eventController.add(SpeechTranscriptionReceived(transcript: text, isFinal: false));
        break;
      case 'commandTimeout':
        final reason = call.arguments as String? ?? 'No speech detected';
        _log('Command timeout: $reason');
        _eventController.add(ListeningTimeout(reason: reason));
        break;
      case 'log':
        final message = call.arguments as String? ?? '';
        _log('Native: $message');
        break;
    }
  }

  /// Parse events from native EventChannel.
  void _onNativeEvent(dynamic event) {
    if (event is Map) {
      final type = event['type'] as String?;
      final data = event['data'];
      switch (type) {
        case 'wakeWordDetected':
          _log('Wake word detected');
          _eventController.add(WakeWordDetected(
            timestamp: DateTime.now(),
          ));
          break;
        case 'stateChanged':
          final stateStr = data?.toString() ?? '0';
          final stateIndex = int.tryParse(stateStr) ?? 0;
          if (stateIndex < MealVoiceState.values.length) {
            final newState = MealVoiceState.values[stateIndex];
            _currentState = newState;
            _eventController.add(EngineStateChanged(newState: newState));
          }
          break;
        case 'error':
          final message = data?.toString() ?? 'Unknown error';
          _log('Error: $message', level: 'error');
          _eventController.add(EngineError(message: message));
          break;
        case 'commandTranscription':
          final text = data?.toString() ?? '';
          _log('Command transcription: $text');
          _eventController.add(SpeechTranscriptionReceived(transcript: text, isFinal: true));
          break;
        case 'speechPartial':
          final text = data?.toString() ?? '';
          _eventController.add(SpeechTranscriptionReceived(transcript: text, isFinal: false));
          break;
        case 'commandTimeout':
          final reason = data?.toString() ?? 'No speech detected';
          _log('Command timeout: $reason');
          _eventController.add(ListeningTimeout(reason: reason));
          break;
      }
    }
  }

  /// Request microphone permission.
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

  /// Start wake-word detection (Phase 1).
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

  /// Stop wake-word detection.
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

  /// Start command capture mode (Phase 2 — after wake word).
  Future<bool> startCommandCapture() async {
    try {
      _log('Starting command capture');
      final result = await _methodChannel.invokeMethod<bool>('startCommandCapture');
      if (result == true) {
        _currentState = MealVoiceState.listeningToUser;
        _eventController.add(EngineStateChanged(
          newState: MealVoiceState.listeningToUser,
        ));
        _log('Command capture started');
        return true;
      }
      return false;
    } catch (e) {
      _log('Start command capture failed: $e', level: 'error');
      return false;
    }
  }

  /// Stop command capture and return to wake-word mode.
  Future<bool> stopCommandCapture() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopCommandCapture');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Restart wake-word listening after command processing.
  Future<bool> restartWakeWordListening() async {
    try {
      _log('Restarting wake-word detection');
      final result = await _methodChannel.invokeMethod<bool>('restartWakeWordListening');
      if (result == true) {
        _currentState = MealVoiceState.listeningForWakeWord;
        _eventController.add(EngineStateChanged(
          newState: MealVoiceState.listeningForWakeWord,
        ));
        return true;
      }
      return false;
    } catch (e) {
      _log('Restart wake word failed: $e', level: 'error');
      return false;
    }
  }

  /// Check if microphone is available.
  Future<bool> isMicrophoneAvailable() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isMicrophoneAvailable');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get current service status.
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getStatus');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Log a message with level.
  void _log(String message, {String level = 'info'}) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    print('[MEAL][$timestamp][$level] $message');
  }

  /// Dispose resources.
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
    _isInitialized = false;
  }
}
