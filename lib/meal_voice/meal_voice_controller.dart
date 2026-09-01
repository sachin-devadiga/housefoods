import 'dart:async';
import 'package:flutter/foundation.dart';
import 'meal_voice_service.dart';
import 'meal_voice_state.dart';

/// Provider-based controller for MEAL voice engine.
/// Manages state and exposes methods to UI.
class MealVoiceController extends ChangeNotifier {
  final MealVoiceService _service = MealVoiceService.instance;

  MealVoiceState _state = MealVoiceState.idle;
  MealVoiceState get state => _state;

  bool _isListening = false;
  bool get isListening => _isListening;

  bool _microphoneAvailable = false;
  bool get microphoneAvailable => _microphoneAvailable;

  bool _permissionGranted = false;
  bool get permissionGranted => _permissionGranted;

  DateTime? _lastWakeDetected;
  DateTime? get lastWakeDetected => _lastWakeDetected;

  String _lastEvent = 'None';
  String get lastEvent => _lastEvent;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  StreamSubscription<MealVoiceEvent>? _eventSubscription;

  /// Initialize the controller and subscribe to engine events
  Future<void> initialize() async {
    await _service.initialize();

    _eventSubscription = _service.events.listen(_onEvent);

    // Check microphone availability
    _microphoneAvailable = await _service.isMicrophoneAvailable();
    notifyListeners();
  }

  /// Handle events from the voice engine
  void _onEvent(MealVoiceEvent event) {
    switch (event) {
      case WakeWordDetected():
        _lastWakeDetected = event.timestamp;
        _lastEvent = 'HI MEAL DETECTED at ${event.timestamp.toIso8601String().substring(11, 19)}';
        _state = MealVoiceState.wakeDetected;
        debugPrint('[MEAL] Wake word detected: $_lastEvent');
        break;
      case EngineStateChanged():
        _state = event.newState;
        _isListening = event.newState == MealVoiceState.listeningForWakeWord;
        break;
      case EngineError():
        _errorMessage = event.message;
        _lastEvent = 'Error: ${event.message}';
        _state = MealVoiceState.error;
        break;
      case MicrophonePermissionResult():
        _permissionGranted = event.granted;
        break;
      case EngineLog():
        break;
    }
    notifyListeners();
  }

  /// Request microphone permission
  Future<void> requestPermission() async {
    _state = MealVoiceState.initializing;
    notifyListeners();

    _permissionGranted = await _service.requestMicrophonePermission();
    _lastEvent = _permissionGranted ? 'Permission granted' : 'Permission denied';
    _state = _permissionGranted ? MealVoiceState.idle : MealVoiceState.error;
    notifyListeners();
  }

  /// Start wake-word detection
  Future<void> startListening() async {
    _errorMessage = null;
    _lastEvent = 'Starting...';
    notifyListeners();

    final started = await _service.startListening();
    if (started) {
      _isListening = true;
      _state = MealVoiceState.listeningForWakeWord;
      _lastEvent = 'Listening for "Hi MEAL"';
    } else {
      _lastEvent = 'Failed to start';
      _state = MealVoiceState.error;
    }
    notifyListeners();
  }

  /// Stop wake-word detection
  Future<void> stopListening() async {
    final stopped = await _service.stopListening();
    if (stopped) {
      _isListening = false;
      _state = MealVoiceState.stopped;
      _lastEvent = 'Stopped';
    }
    notifyListeners();
  }

  /// Get detailed status from native service
  Future<Map<String, dynamic>> getStatus() async {
    return await _service.getStatus();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
