import 'dart:async';
import 'package:flutter/services.dart';
import 'meal_voice_state.dart';

/// Flutter-side service for MEAL voice engine.
///
/// FIX #18: Removed duplicate event handling — all events come through EventChannel only.
/// FIX #19: Singleton resets properly after dispose.
/// FIX #20: Added bounds checking for state index.
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

  Stream<MealVoiceEvent> get events => _eventController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _log('Initializing MEAL voice service');

    // FIX #18: Single event stream from EventChannel only
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _onNativeEvent,
      onError: (error) {
        _log('Event stream error: $error', level: 'error');
        _eventController.add(EngineError(message: 'Event stream error: $error'));
      },
    );

    _isInitialized = true;
    _log('MEAL voice service initialized');
  }

  /// Parse events from native EventChannel.
  void _onNativeEvent(dynamic event) {
    if (event is Map) {
      final type = event['type'] as String?;
      final data = event['data'];
      switch (type) {
        case 'wakeWordDetected':
          _log('Wake word detected');
          _eventController.add(WakeWordDetected(timestamp: DateTime.now()));
          break;
        case 'stateChanged':
          final stateStr = data?.toString() ?? '0';
          final stateIndex = int.tryParse(stateStr) ?? 0;
          // FIX #20: Bounds check including negative
          if (stateIndex >= 0 && stateIndex < MealVoiceState.values.length) {
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
        case 'log':
          final message = data?.toString() ?? '';
          _log('Native: $message');
          break;
      }
    }
  }

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

  Future<bool> startListening() async {
    try {
      _log('Starting wake-word detection');
      final result = await _methodChannel.invokeMethod<bool>('startListening');
      if (result == true) {
        _currentState = MealVoiceState.listeningForWakeWord;
        _eventController.add(EngineStateChanged(newState: MealVoiceState.listeningForWakeWord));
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

  Future<bool> stopListening() async {
    try {
      _log('Stopping wake-word detection');
      final result = await _methodChannel.invokeMethod<bool>('stopListening');
      if (result == true) {
        _currentState = MealVoiceState.stopped;
        _eventController.add(EngineStateChanged(newState: MealVoiceState.stopped));
        _log('Wake-word detection stopped');
        return true;
      }
      return false;
    } catch (e) {
      _log('Stop listening failed: $e', level: 'error');
      return false;
    }
  }

  Future<bool> startCommandCapture() async {
    try {
      _log('Starting command capture');
      final result = await _methodChannel.invokeMethod<bool>('startCommandCapture');
      if (result == true) {
        _currentState = MealVoiceState.listeningToUser;
        _eventController.add(EngineStateChanged(newState: MealVoiceState.listeningToUser));
        _log('Command capture started');
        return true;
      }
      return false;
    } catch (e) {
      _log('Start command capture failed: $e', level: 'error');
      return false;
    }
  }

  Future<bool> stopCommandCapture() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopCommandCapture');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> restartWakeWordListening() async {
    try {
      _log('Restarting wake-word detection');
      final result = await _methodChannel.invokeMethod<bool>('restartWakeWordListening');
      if (result == true) {
        _currentState = MealVoiceState.listeningForWakeWord;
        _eventController.add(EngineStateChanged(newState: MealVoiceState.listeningForWakeWord));
        return true;
      }
      return false;
    } catch (e) {
      _log('Restart wake word failed: $e', level: 'error');
      return false;
    }
  }

  Future<bool> isMicrophoneAvailable() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isMicrophoneAvailable');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getStatus() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getStatus');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  void _log(String message, {String level = 'info'}) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    print('[MEAL][$timestamp][$level] $message');
  }

  /// FIX #19: Reset singleton on dispose so next access creates fresh instance.
  void dispose() {
    _eventSubscription?.cancel();
    if (!_eventController.isClosed) {
      _eventController.close();
    }
    _isInitialized = false;
    _instance = null;
  }
}
