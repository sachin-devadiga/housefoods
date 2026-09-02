import 'meal_voice_command.dart';

/// MEAL Voice Engine States — Full workflow state machine.
enum MealVoiceState {
  /// Engine not initialized.
  idle,

  /// Engine initializing, requesting permissions.
  initializing,

  /// Listening for wake word "Hi MEAL".
  listeningForWakeWord,

  /// Wake word detected — transitioning to command listening.
  wakeDetected,

  /// Listening to user's spoken command after wake word.
  listeningToUser,

  /// Converting speech to text (STT processing).
  processingSpeech,

  /// Parsing transcribed text into structured command.
  parsingCommand,

  /// Searching MEALIN backend for matching items.
  searchingMenu,

  /// Awaiting user confirmation before adding to cart.
  confirmationRequired,

  /// Adding item(s) to cart via CartProvider.
  addingToCart,

  /// Command completed successfully — returning to wake-word mode.
  commandSuccess,

  /// Command could not be understood.
  commandUnknown,

  /// An error occurred during command processing.
  commandError,

  /// User denied the confirmation.
  userDenied,

  /// Engine stopped.
  stopped,

  /// An error occurred (permission, hardware, etc).
  error,
}

/// Events emitted by the MEAL voice engine.
sealed class MealVoiceEvent {
  const MealVoiceEvent();
}

/// Wake word "Hi MEAL" was detected.
class WakeWordDetected extends MealVoiceEvent {
  final DateTime timestamp;
  const WakeWordDetected({required this.timestamp});
}

/// Engine state changed.
class EngineStateChanged extends MealVoiceEvent {
  final MealVoiceState newState;
  const EngineStateChanged({required this.newState});
}

/// An error occurred.
class EngineError extends MealVoiceEvent {
  final String message;
  final String? code;
  const EngineError({required this.message, this.code});
}

/// Microphone permission result.
class MicrophonePermissionResult extends MealVoiceEvent {
  final bool granted;
  final bool permanentlyDenied;
  const MicrophonePermissionResult({
    required this.granted,
    this.permanentlyDenied = false,
  });
}

/// Engine log message.
class EngineLog extends MealVoiceEvent {
  final String message;
  final String level;
  const EngineLog({required this.message, this.level = 'info'});
}

/// Speech-to-text transcription received from native.
class SpeechTranscriptionReceived extends MealVoiceEvent {
  final String transcript;
  final bool isFinal;
  const SpeechTranscriptionReceived({
    required this.transcript,
    this.isFinal = true,
  });
}

/// Parsed command result.
class CommandParsed extends MealVoiceEvent {
  final MealVoiceCommand command;
  const CommandParsed({required this.command});
}

/// Search result for a menu item.
class SearchResultEvent extends MealVoiceEvent {
  final String? itemName;
  final String? kitchenName;
  final double? price;
  final bool found;
  final String? message;
  const SearchResultEvent({
    this.itemName,
    this.kitchenName,
    this.price,
    required this.found,
    this.message,
  });
}

/// Cart operation result.
class CartOperationResult extends MealVoiceEvent {
  final bool success;
  final String message;
  final double? cartTotal;
  const CartOperationResult({
    required this.success,
    required this.message,
    this.cartTotal,
  });
}

/// TTS speaking state changed.
class TtsSpeakingChanged extends MealVoiceEvent {
  final bool isSpeaking;
  const TtsSpeakingChanged({required this.isSpeaking});
}

/// Listening timeout occurred.
class ListeningTimeout extends MealVoiceEvent {
  final String reason;
  const ListeningTimeout({required this.reason});
}
