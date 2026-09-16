import 'dart:async';

/// Abstract voice engine interface for the MEAL voice assistant.
///
/// Both Gemini Live and Legacy Sarvam engines implement this interface,
/// allowing the controller to swap engines without changing workflow logic.
abstract class MealVoiceEngine {
  /// Engine name for logging.
  String get engineName;

  /// Whether the engine is currently active.
  bool get isActive;

  /// Initialize the engine with configuration.
  Future<bool> initialize({
    required String backendUrl,
    required String authToken,
    required void Function(String log) onLog,
    required void Function(MealVoiceEngineEvent event) onEvent,
  });

  /// Start listening for user audio input.
  /// For Gemini Live: sends audio to the live session.
  /// For Legacy: uses native SpeechRecognizer.
  Future<void> startListening();

  /// Stop listening.
  Future<void> stopListening();

  /// Send text input to the engine (for typed commands).
  Future<void> sendText(String text);

  /// Send raw audio data to the engine (PCM 16-bit, 16kHz).
  Future<void> sendAudio(List<int> audioData);

  /// Send a function call response back to the engine.
  Future<void> sendFunctionResponse(String callId, Map<String, dynamic> response);

  /// Disconnect and clean up the engine.
  Future<void> disconnect();

  /// Dispose all resources.
  void dispose();
}

/// Events emitted by voice engines.
sealed class MealVoiceEngineEvent {}

/// Engine connected and ready.
class EngineConnected extends MealVoiceEngineEvent {
  final String engineName;
  EngineConnected({required this.engineName});
}

/// Engine disconnected.
class EngineDisconnected extends MealVoiceEngineEvent {
  final String reason;
  EngineDisconnected({required this.reason});
}

/// Transcription received from user speech.
class EngineTranscription extends MealVoiceEngineEvent {
  final String text;
  final bool isFinal;
  EngineTranscription({required this.text, this.isFinal = false});
}

/// AI response received (text to speak).
class EngineResponse extends MealVoiceEngineEvent {
  final String text;
  EngineResponse({required this.text});
}

/// Function call requested by the AI.
class EngineFunctionCall extends MealVoiceEngineEvent {
  final String name;
  final Map<String, dynamic> args;
  EngineFunctionCall({required this.name, required this.args});
}

/// Audio data to play (TTS output).
class EngineAudioOutput extends MealVoiceEngineEvent {
  final List<int> audioData;
  EngineAudioOutput({required this.audioData});
}

/// Engine error.
class EngineErrorEvent extends MealVoiceEngineEvent {
  final String message;
  final bool recoverable;
  EngineErrorEvent({required this.message, this.recoverable = true});
}

/// Engine state changed.
class EngineStateChangedEvent extends MealVoiceEngineEvent {
  final String newState;
  EngineStateChangedEvent({required this.newState});
}
