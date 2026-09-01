/// MEAL Voice Engine States
enum MealVoiceState {
  /// Engine not initialized
  idle,

  /// Engine initializing, requesting permissions
  initializing,

  /// Listening for wake word "Hi MEAL"
  listeningForWakeWord,

  /// Wake word detected
  wakeDetected,

  /// Listening to user speech after wake
  listeningToUser,

  /// Processing user intent
  processing,

  /// Speaking response via TTS
  speaking,

  /// An error occurred
  error,

  /// Engine stopped
  stopped,
}

/// Events emitted by the MEAL voice engine
sealed class MealVoiceEvent {
  const MealVoiceEvent();
}

/// Wake word "Hi MEAL" was detected
class WakeWordDetected extends MealVoiceEvent {
  final DateTime timestamp;
  const WakeWordDetected({required this.timestamp});
}

/// Engine state changed
class EngineStateChanged extends MealVoiceEvent {
  final MealVoiceState newState;
  const EngineStateChanged({required this.newState});
}

/// An error occurred
class EngineError extends MealVoiceEvent {
  final String message;
  final String? code;
  const EngineError({required this.message, this.code});
}

/// Microphone permission result
class MicrophonePermissionResult extends MealVoiceEvent {
  final bool granted;
  final bool permanentlyDenied;
  const MicrophonePermissionResult({
    required this.granted,
    this.permanentlyDenied = false,
  });
}

/// Engine log message
class EngineLog extends MealVoiceEvent {
  final String message;
  final String level; // 'info', 'warning', 'error', 'debug'
  const EngineLog({required this.message, this.level = 'info'});
}
