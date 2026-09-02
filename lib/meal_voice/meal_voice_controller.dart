import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../features/customer/presentation/providers/cart_provider.dart';
import '../features/customer/presentation/providers/kitchen_provider.dart';
import 'meal_voice_service.dart';
import 'meal_voice_state.dart';
import 'meal_voice_command.dart';
import 'meal_voice_command_parser.dart';
import 'meal_voice_tts_service.dart';
import 'meal_voice_order_handler.dart';

/// Provider-based controller for MEAL voice engine.
///
/// Manages the full voice workflow:
/// Wake word → Listen → Parse → Search → Confirm → Add to cart
class MealVoiceController extends ChangeNotifier {
  final MealVoiceService _service = MealVoiceService.instance;
  final MealVoiceTtsService _tts = MealVoiceTtsService();
  late final MealVoiceCommandParser _parser;
  MealVoiceOrderHandler? _orderHandler;

  // State
  MealVoiceState _state = MealVoiceState.idle;
  MealVoiceState get state => _state;

  bool _isListening = false;
  bool get isListening => _isListening;

  bool _microphoneAvailable = false;
  bool get microphoneAvailable => _microphoneAvailable;

  bool _permissionGranted = false;
  bool get permissionGranted => _permissionGranted;

  bool _ttsAvailable = false;
  bool get ttsAvailable => _ttsAvailable;

  // Transcription & command
  String _lastTranscript = '';
  String get lastTranscript => _lastTranscript;

  MealVoiceCommand? _lastCommand;
  MealVoiceCommand? get lastCommand => _lastCommand;

  String _ttsResponse = '';
  String get ttsResponse => _ttsResponse;

  // Search result
  SearchResult? _searchResult;
  SearchResult? get searchResult => _searchResult;

  // Confirmation
  bool _awaitingConfirmation = false;
  bool get awaitingConfirmation => _awaitingConfirmation;
  int _pendingQuantity = 1;

  // Timing
  Timer? _confirmationTimeout;
  static const _confirmationTimeoutDuration = Duration(seconds: 10);

  // Logs
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  // Events
  StreamSubscription<MealVoiceEvent>? _eventSubscription;

  // User name for personalized greetings
  String _userName = '';
  set userName(String name) => _userName = name;

  /// Initialize the controller.
  Future<void> initialize({
    KitchenProvider? kitchenProvider,
    CartProvider? cartProvider,
    MealVoiceCommandParser? parser,
  }) async {
    _parser = parser ?? RegexMealVoiceCommandParser();

    if (kitchenProvider != null && cartProvider != null) {
      _orderHandler = MealVoiceOrderHandler(
        kitchenProvider: kitchenProvider,
        cartProvider: cartProvider,
      );
    }

    await _service.initialize();
    _eventSubscription = _service.events.listen(_onEvent);

    _microphoneAvailable = await _service.isMicrophoneAvailable();
    _permissionGranted = await Permission.microphone.isGranted;

    _ttsAvailable = await _tts.initialize();

    _addLog('Engine initialized (parser: ${_parser.parserName}, TTS: $_ttsAvailable)');
    notifyListeners();
  }

  /// Handle events from the voice engine.
  void _onEvent(MealVoiceEvent event) {
    switch (event) {
      case WakeWordDetected():
        _handleWakeWordDetected(event.timestamp);
        break;
      case EngineStateChanged():
        _state = event.newState;
        _isListening = event.newState == MealVoiceState.listeningForWakeWord;
        break;
      case EngineError():
        _handleError(event.message);
        break;
      case MicrophonePermissionResult():
        _permissionGranted = event.granted;
        break;
      case SpeechTranscriptionReceived():
        if (event.isFinal) {
          _handleTranscription(event.transcript);
        } else {
          _lastTranscript = event.transcript;
        }
        break;
      case CommandParsed():
        break;
      case SearchResultEvent():
        break;
      case CartOperationResult():
        break;
      case TtsSpeakingChanged():
        break;
      case ListeningTimeout():
        _handleListeningTimeout(event.reason);
        break;
      case EngineLog():
        _addLog(event.message);
        break;
    }
    notifyListeners();
  }

  /// Handle wake word detection — start command listening.
  void _handleWakeWordDetected(DateTime timestamp) {
    _addLog('Wake word detected');
    _state = MealVoiceState.wakeDetected;
    notifyListeners();

    // Start command capture
    _startCommandCapture();
  }

  /// Start command capture after wake word.
  Future<void> _startCommandCapture() async {
    _state = MealVoiceState.listeningToUser;
    _lastTranscript = '';
    _lastCommand = null;
    _searchResult = null;
    notifyListeners();

    // Speak greeting
    final greeting = _userName.isNotEmpty
        ? 'Hi $_userName, how can I help you?'
        : 'Hi, how can I help you?';

    await _tts.speak(greeting);
    _addLog('Greeting spoken');

    // Start native command capture
    await _service.startCommandCapture();
    _addLog('Listening for command...');
  }

  /// Handle speech transcription from native STT.
  void _handleTranscription(String transcript) {
    if (transcript.trim().isEmpty) {
      _handleListeningTimeout('Empty transcription');
      return;
    }

    _lastTranscript = transcript;
    _addLog('Transcript: "$transcript"');

    // Check if we're awaiting confirmation
    if (_awaitingConfirmation) {
      _handleConfirmationResponse(transcript);
      return;
    }

    // Parse the command
    _parseAndProcess(transcript);
  }

  /// Parse the transcription and process the command.
  Future<void> _parseAndProcess(String transcript) async {
    _state = MealVoiceState.parsingCommand;
    notifyListeners();

    final command = _parser.parse(transcript);
    _lastCommand = command;
    _addLog('Parsed: ${command.intent.name} | ${command.items.length} item(s)');

    // Handle unknown intent
    if (command.intent == MealVoiceIntent.unknown) {
      _handleUnknownCommand();
      return;
    }

    // Handle confirmation commands
    if (command.intent == MealVoiceIntent.confirm || command.intent == MealVoiceIntent.cancel) {
      if (_awaitingConfirmation) {
        _handleConfirmationResponse(transcript);
      } else {
        _handleUnknownCommand();
      }
      return;
    }

    // Handle add/remove commands
    if (command.isAdd || command.isRemove) {
      await _searchAndConfirm(command);
    } else {
      _handleUnknownCommand();
    }
  }

  /// Search for items and prepare confirmation.
  Future<void> _searchAndConfirm(MealVoiceCommand command) async {
    if (_orderHandler == null) {
      _handleError('Cart integration not available');
      return;
    }

    if (command.items.isEmpty) {
      _handleError('No items found in your command. Please try again.');
      return;
    }

    _state = MealVoiceState.searchingMenu;
    notifyListeners();

    // Process first item (single-item for now, multi-item in future)
    final item = command.items.first;
    _addLog('Searching for: ${item.itemName}');

    final result = await _orderHandler!.searchItem(
      itemName: item.itemName,
      restaurantName: command.businessName,
    );

    if (result == null) {
      _handleItemNotFound(item.itemName);
      return;
    }

    _searchResult = result;
    _pendingQuantity = item.quantity;

    _addLog('Found: ${result.menuItem.name} from ${result.kitchen.name} — ₹${result.menuItem.price}');

    // Check cart compatibility — order handler will handle conflict in addToCart

    // Generate confirmation message
    final price = result.menuItem.price;
    final qty = item.quantity;
    final itemName = result.menuItem.name;
    final kitchenName = result.kitchen.name;
    final total = price * qty;

    final confirmMsg = qty > 1
        ? 'I found $qty $itemName from $kitchenName for ₹$total. Would you like me to add it to your cart?'
        : 'I found $itemName from $kitchenName for ₹$price. Would you like me to add it to your cart?';

    _ttsResponse = confirmMsg;
    _state = MealVoiceState.confirmationRequired;
    _awaitingConfirmation = true;
    notifyListeners();

    // Speak confirmation
    await _tts.speak(confirmMsg);
    _addLog('Confirmation spoken');

    // Start confirmation timeout
    _startConfirmationTimeout();
  }

  /// Handle the user's confirmation response.
  void _handleConfirmationResponse(String transcript) {
    _confirmationTimeout?.cancel();

    final response = _parser.parseConfirmation(transcript);
    _addLog('Confirmation: ${response.name}');

    switch (response) {
      case MealVoiceConfirmation.yes:
        _addToCart();
        break;
      case MealVoiceConfirmation.no:
        _handleUserDenied();
        break;
      case MealVoiceConfirmation.timeout:
      case MealVoiceConfirmation.unknown:
        _handleConfirmationUnknown(transcript);
        break;
    }
  }

  /// Add the pending item to cart.
  Future<void> _addToCart() async {
    if (_searchResult == null || _orderHandler == null) {
      _handleError('No item to add');
      return;
    }

    final handler = _orderHandler!;
    final searchResult = _searchResult!;

    _state = MealVoiceState.addingToCart;
    _awaitingConfirmation = false;
    notifyListeners();

    final result = await handler.addToCart(
      searchResult: searchResult,
      quantity: _pendingQuantity,
    );

    switch (result) {
      case CartAddResult.success:
        final total = handler.cartTotal;
        final count = handler.cartItemCount;
        final msg = 'Added to your cart. Your cart total is ₹$total with $count item${count > 1 ? 's' : ''}.';
        _ttsResponse = msg;
        _state = MealVoiceState.commandSuccess;
        _addLog(msg);
        await _tts.speak(msg);
        break;

      case CartAddResult.cartConflict:
        await _handleCartConflict();
        return;

      case CartAddResult.itemUnavailable:
        _ttsResponse = 'Sorry, that item is currently unavailable.';
        _state = MealVoiceState.commandError;
        _addLog('Item unavailable');
        await _tts.speak(_ttsResponse);
        break;

      case CartAddResult.networkError:
        _handleError('Network error. Please try again.');
        return;

      default:
        _handleError('Could not add item to cart. Please try again.');
        return;
    }

    // Return to wake-word listening
    _returnToWakeWordListening();
  }

  /// Handle cart conflict (items from different restaurant).
  Future<void> _handleCartConflict() async {
    _ttsResponse = 'Your cart already contains items from another restaurant. Would you like me to clear the cart and add this item?';
    _state = MealVoiceState.confirmationRequired;
    _awaitingConfirmation = true;
    notifyListeners();

    await _tts.speak(_ttsResponse);
    _startConfirmationTimeout();
  }

  /// Handle user denying the confirmation.
  void _handleUserDenied() {
    _awaitingConfirmation = false;
    _ttsResponse = 'No problem. Say "Hi MEAL" when you\'re ready.';
    _state = MealVoiceState.userDenied;
    _addLog('User denied');
    _returnToWakeWordListening();
  }

  /// Handle unknown/unrecognized command.
  void _handleUnknownCommand() {
    _ttsResponse = 'Sorry, I didn\'t understand that. You can say things like "Order one chicken biryani" or "Add two burgers".';
    _state = MealVoiceState.commandUnknown;
    _addLog('Unknown command');
    _speakAndReturn(_ttsResponse);
  }

  /// Handle item not found in search.
  void _handleItemNotFound(String itemName) {
    _ttsResponse = 'Sorry, I couldn\'t find "$itemName" in any available restaurant. Would you like to try something else?';
    _state = MealVoiceState.commandError;
    _addLog('Item not found: $itemName');
    _speakAndReturn(_ttsResponse);
  }

  /// Handle listening timeout (no speech after wake word).
  void _handleListeningTimeout(String reason) {
    _awaitingConfirmation = false;
    _confirmationTimeout?.cancel();

    if (_state == MealVoiceState.confirmationRequired) {
      _ttsResponse = 'Timed out. Say "Hi MEAL" to try again.';
    } else {
      _ttsResponse = 'I didn\'t hear you. Say "Hi MEAL" when you\'re ready.';
    }

    _addLog('Timeout: $reason');
    _speakAndReturn(_ttsResponse);
  }

  /// Handle confirmation timeout.
  void _startConfirmationTimeout() {
    _confirmationTimeout?.cancel();
    _confirmationTimeout = Timer(_confirmationTimeoutDuration, () {
      if (_awaitingConfirmation) {
        _handleListeningTimeout('Confirmation timeout');
      }
    });
  }

  /// Handle unknown confirmation response.
  void _handleConfirmationUnknown(String transcript) {
    _ttsResponse = 'Sorry, I didn\'t catch that. Please say "yes" or "no".';
    _addLog('Unknown confirmation: $transcript');
    _startConfirmationTimeout(); // Restart timeout
    _speakAndReturn(_ttsResponse);
  }

  /// Handle general errors.
  void _handleError(String message) {
    _awaitingConfirmation = false;
    _confirmationTimeout?.cancel();
    _ttsResponse = 'Sorry, something went wrong. $message';
    _state = MealVoiceState.commandError;
    _addLog('Error: $message');
    _speakAndReturn(_ttsResponse);
  }

  /// Speak a message and return to wake-word listening.
  Future<void> _speakAndReturn(String message) async {
    await _tts.speak(message);
    _returnToWakeWordListening();
  }

  /// Return to wake-word listening state.
  void _returnToWakeWordListening() {
    _awaitingConfirmation = false;
    _confirmationTimeout?.cancel();
    _searchResult = null;

    // Restart native wake-word detection
    _service.restartWakeWordListening();
    _state = MealVoiceState.listeningForWakeWord;
    _isListening = true;
    _addLog('Listening for "Hi MEAL"...');
    notifyListeners();
  }

  /// Add a log entry.
  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _logs.add('[$timestamp] $message');
    if (_logs.length > 50) _logs.removeAt(0);
  }

  // ─── Public API ───

  /// Request microphone permission.
  Future<void> requestPermission() async {
    _state = MealVoiceState.initializing;
    _lastTranscript = 'Requesting permission...';
    notifyListeners();

    final status = await Permission.microphone.request();
    _permissionGranted = status.isGranted;
    _lastTranscript = _permissionGranted ? 'Permission granted' : 'Permission denied';
    _state = _permissionGranted ? MealVoiceState.idle : MealVoiceState.error;
    notifyListeners();
  }

  /// Start wake-word detection.
  Future<void> startListening() async {
    if (!_permissionGranted) {
      await requestPermission();
      if (!_permissionGranted) return;
    }

    _ttsResponse = '';
    _lastTranscript = '';
    _lastCommand = null;
    _searchResult = null;

    final started = await _service.startListening();
    if (started) {
      _isListening = true;
      _state = MealVoiceState.listeningForWakeWord;
      _lastTranscript = 'Listening for "Hi MEAL"';
      _addLog('Started listening for wake word');
    } else {
      _lastTranscript = 'Failed to start';
      _state = MealVoiceState.error;
      _addLog('Failed to start listening');
    }
    notifyListeners();
  }

  /// Stop all voice activity.
  Future<void> stopListening() async {
    _confirmationTimeout?.cancel();
    await _tts.stop();
    await _service.stopListening();
    _isListening = false;
    _awaitingConfirmation = false;
    _state = MealVoiceState.stopped;
    _lastTranscript = 'Stopped';
    _addLog('Stopped');
    notifyListeners();
  }

  /// Get detailed status from native service.
  Future<Map<String, dynamic>> getStatus() async {
    return await _service.getStatus();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _confirmationTimeout?.cancel();
    _tts.dispose();
    super.dispose();
  }
}
