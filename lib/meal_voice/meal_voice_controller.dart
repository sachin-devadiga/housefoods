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
/// FIX #5: State guard prevents wake word during active workflow.
/// FIX #6: Cart conflict uses clearCart before re-adding.
/// FIX #9: Multi-item processing for ALL items.
/// FIX #11: Kitchens list snapshot before iteration.
/// FIX #3: Confirmation safety — no cart modification before YES.
/// FIX #8: Duplicate event protection via _isProcessing flag.
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

  // Search results — supports multi-item
  final List<SearchResult> _searchResults = [];
  List<SearchResult> get searchResults => List.unmodifiable(_searchResults);

  // Items that failed to find
  final List<String> _notFoundItems = [];
  List<String> get notFoundItems => List.unmodifiable(_notFoundItems);

  // Confirmation
  bool _awaitingConfirmation = false;
  bool get awaitingConfirmation => _awaitingConfirmation;
  List<MealVoiceItem> _pendingItems = [];
  bool _pendingCartConflictClear = false;

  // Timing
  Timer? _confirmationTimeout;
  static const _confirmationTimeoutDuration = Duration(seconds: 10);

  // Duplicate protection (#8)
  bool _isProcessing = false;

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
    _eventSubscription?.cancel();
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
        // FIX #5: Guard — ignore wake word if already in active workflow
        if (_state != MealVoiceState.idle &&
            _state != MealVoiceState.listeningForWakeWord &&
            _state != MealVoiceState.stopped &&
            _state != MealVoiceState.error) {
          _addLog('Wake word ignored — active workflow (${_state.name})');
          return;
        }
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
          notifyListeners();
        }
        break;
      case CommandParsed():
      case SearchResultEvent():
      case CartOperationResult():
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
    _isProcessing = false; // Reset processing guard
    notifyListeners();
    _startCommandCapture();
  }

  /// Start command capture after wake word.
  Future<void> _startCommandCapture() async {
    _state = MealVoiceState.listeningToUser;
    _lastTranscript = '';
    _lastCommand = null;
    _searchResults.clear();
    _notFoundItems.clear();
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

    // FIX #8: Duplicate event protection
    if (_isProcessing) {
      _addLog('Already processing — ignoring duplicate transcription');
      return;
    }

    _parseAndProcess(transcript);
  }

  /// Parse the transcription and process the command.
  Future<void> _parseAndProcess(String transcript) async {
    _isProcessing = true;
    _state = MealVoiceState.parsingCommand;
    notifyListeners();

    final command = _parser.parse(transcript);
    _lastCommand = command;
    _addLog('Parsed: ${command.intent.name} | ${command.items.length} item(s)');

    // Handle unknown intent
    if (command.intent == MealVoiceIntent.unknown) {
      _isProcessing = false;
      _handleUnknownCommand();
      return;
    }

    // Handle confirmation/cancel intents
    if (command.intent == MealVoiceIntent.confirm || command.intent == MealVoiceIntent.cancel) {
      _isProcessing = false;
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
      _isProcessing = false;
      _handleUnknownCommand();
    }
  }

  /// Search for ALL items and prepare confirmation.
  Future<void> _searchAndConfirm(MealVoiceCommand command) async {
    if (_orderHandler == null) {
      _isProcessing = false;
      _handleError('Cart integration not available');
      return;
    }

    if (command.items.isEmpty) {
      _isProcessing = false;
      _handleError('No items found in your command. Please try again.');
      return;
    }

    _state = MealVoiceState.searchingMenu;
    notifyListeners();

    _searchResults.clear();
    _notFoundItems.clear();

    // FIX #9: Process ALL items, not just the first
    for (final item in command.items) {
      _addLog('Searching for: ${item.itemName} (qty: ${item.quantity})');

      final result = await _orderHandler!.searchItem(
        itemName: item.itemName,
        restaurantName: command.businessName,
      );

      if (result != null) {
        _searchResults.add(result);
        _addLog('Found: ${result.menuItem.name} from ${result.kitchen.name} — ₹${result.menuItem.price}');
      } else {
        _notFoundItems.add(item.itemName);
        _addLog('Not found: ${item.itemName}');
      }
    }

    _pendingItems = command.items;
    _isProcessing = false;

    // All items not found
    if (_searchResults.isEmpty) {
      final names = _notFoundItems.join(' or ');
      _handleItemNotFound(names);
      return;
    }

    // Partial items found
    if (_notFoundItems.isNotEmpty) {
      _searchResults.first; // At least one found
      final foundNames = _searchResults.map((r) => r.menuItem.name).join(', ');
      final missingNames = _notFoundItems.join(', ');
      final msg = 'I found $foundNames, but I couldn\'t find $missingNames. '
          'Would you like me to add only the items I found?';
      _ttsResponse = msg;
      _state = MealVoiceState.confirmationRequired;
      _awaitingConfirmation = true;
      notifyListeners();
      await _tts.speak(msg);
      _startConfirmationTimeout();
      return;
    }

    // All items found — generate confirmation
    await _generateConfirmation(command);
  }

  /// Generate confirmation message for found items.
  Future<void> _generateConfirmation(MealVoiceCommand command) async {
    if (_searchResults.isEmpty) return;

    // Check cart compatibility
    final firstKitchen = _searchResults.first.kitchen;
    bool hasConflict = false;

    if (_orderHandler != null && !_orderHandler!.isCartEmpty) {
      // Check if any search result kitchen differs from cart kitchen
      for (final result in _searchResults) {
        // The order handler will check cart compatibility on add
        // For now, just note the potential conflict
      }
    }

    // Build confirmation message
    final items = _pendingItems;
    final results = _searchResults;

    if (results.length == 1) {
      final result = results.first;
      final item = items.first;
      final price = result.menuItem.price;
      final qty = item.quantity;
      final total = price * qty;
      final name = result.menuItem.name;
      final kitchen = result.kitchen.name;

      _ttsResponse = qty > 1
          ? 'I found $qty $name from $kitchen for ₹$total. Would you like me to add it to your cart?'
          : 'I found $name from $kitchen for ₹$price. Would you like me to add it to your cart?';
    } else {
      double total = 0;
      for (int i = 0; i < results.length; i++) {
        final result = results[i];
        final item = i < items.length ? items[i] : items.last;
        total += result.menuItem.price * item.quantity;
      }
      final names = results.map((r) => r.menuItem.name).join(', ');
      _ttsResponse = 'I found $names. Total is ₹$total. Would you like me to add these to your cart?';
    }

    _ttsResponse = _ttsResponse;
    _state = MealVoiceState.confirmationRequired;
    _awaitingConfirmation = true;
    notifyListeners();

    await _tts.speak(_ttsResponse);
    _addLog('Confirmation spoken');
    _startConfirmationTimeout();
  }

  /// Handle the user's confirmation response.
  void _handleConfirmationResponse(String transcript) {
    _confirmationTimeout?.cancel();

    final response = _parser.parseConfirmation(transcript);
    _addLog('Confirmation: ${response.name}');

    switch (response) {
      case MealVoiceConfirmation.yes:
        if (_pendingCartConflictClear) {
          _handleCartConflictConfirmed();
        } else {
          _addAllToCart();
        }
        break;
      case MealVoiceConfirmation.no:
        _handleUserDenied();
        break;
      case MealVoiceConfirmation.timeout:
      case MealVoiceConfirmation.unknown:
        // Re-ask
        _handleConfirmationUnknown(transcript);
        break;
    }
  }

  /// Add ALL pending items to cart.
  Future<void> _addAllToCart() async {
    if (_searchResults.isEmpty || _orderHandler == null) {
      _handleError('No item to add');
      return;
    }

    _state = MealVoiceState.addingToCart;
    _awaitingConfirmation = false;
    _pendingCartConflictClear = false;
    notifyListeners();

    int addedCount = 0;
    int failedCount = 0;
    double addedTotal = 0;

    for (int i = 0; i < _searchResults.length; i++) {
      final result = _searchResults[i];
      final item = i < _pendingItems.length ? _pendingItems[i] : _pendingItems.last;

      final addResult = await _orderHandler!.addToCart(
        searchResult: result,
        quantity: item.quantity,
      );

      switch (addResult) {
        case CartAddResult.success:
          addedCount++;
          addedTotal += result.menuItem.price * item.quantity;
          break;
        case CartAddResult.cartConflict:
          // FIX #6: Ask user to clear cart, then re-add
          await _handleCartConflict();
          return;
        case CartAddResult.itemUnavailable:
          _addLog('Item unavailable: ${result.menuItem.name}');
          failedCount++;
          break;
        default:
          _addLog('Failed to add: ${result.menuItem.name}');
          failedCount++;
          break;
      }
    }

    // Report results
    if (addedCount > 0 && failedCount == 0) {
      final total = _orderHandler!.cartTotal;
      final count = _orderHandler!.cartItemCount;
      final msg = addedCount == _searchResults.length
          ? 'Added to your cart. Your cart total is ₹$total with $count item${count > 1 ? 's' : ''}.'
          : 'Added $addedCount item${addedCount > 1 ? 's' : ''} to your cart. Total is ₹$total.';
      _ttsResponse = msg;
      _state = MealVoiceState.commandSuccess;
      _addLog(msg);
      await _tts.speak(msg);
    } else if (addedCount > 0) {
      final total = _orderHandler!.cartTotal;
      _ttsResponse = 'Added $addedCount item${addedCount > 1 ? 's' : ''}, but $failedCount item${failedCount > 1 ? 's' : ''} could not be added. Cart total is ₹$total.';
      _state = MealVoiceState.commandSuccess;
      _addLog(_ttsResponse!);
      await _tts.speak(_ttsResponse!);
    } else {
      _handleError('Could not add any items to your cart. Please try again.');
      return;
    }

    // Return to wake-word listening
    _returnToWakeWordListening();
  }

  /// FIX #6: Handle cart conflict — ask user to clear cart.
  Future<void> _handleCartConflict() async {
    _pendingCartConflictClear = true;
    _ttsResponse = 'Your cart already contains items from another restaurant. '
        'Would you like me to clear the cart and add these items?';
    _state = MealVoiceState.confirmationRequired;
    _awaitingConfirmation = true;
    notifyListeners();
    await _tts.speak(_ttsResponse!);
    _startConfirmationTimeout();
  }

  /// FIX #6: User confirmed clearing cart — clear and re-add.
  Future<void> _handleCartConflictConfirmed() async {
    _awaitingConfirmation = false;
    _pendingCartConflictClear = false;

    _addLog('Clearing cart due to conflict');
    await _orderHandler!.clearCart();

    // Now add all items
    int addedCount = 0;
    double addedTotal = 0;

    for (int i = 0; i < _searchResults.length; i++) {
      final result = _searchResults[i];
      final item = i < _pendingItems.length ? _pendingItems[i] : _pendingItems.last;

      final addResult = await _orderHandler!.addToCart(
        searchResult: result,
        quantity: item.quantity,
      );

      if (addResult == CartAddResult.success) {
        addedCount++;
        addedTotal += result.menuItem.price * item.quantity;
      }
    }

    if (addedCount > 0) {
      final total = _orderHandler!.cartTotal;
      final count = _orderHandler!.cartItemCount;
      _ttsResponse = 'Cart cleared and items added. Your cart total is ₹$total with $count item${count > 1 ? 's' : ''}.';
      _state = MealVoiceState.commandSuccess;
      _addLog(_ttsResponse!);
      await _tts.speak(_ttsResponse!);
    } else {
      _handleError('Could not add items after clearing cart.');
      return;
    }

    _returnToWakeWordListening();
  }

  /// Handle user denying the confirmation.
  void _handleUserDenied() {
    _awaitingConfirmation = false;
    _pendingCartConflictClear = false;
    _ttsResponse = 'No problem. Say "Hi MEAL" when you\'re ready.';
    _state = MealVoiceState.userDenied;
    _addLog('User denied');
    _returnToWakeWordListening();
  }

  /// Handle unknown/unrecognized command.
  void _handleUnknownCommand() {
    _ttsResponse = 'Sorry, I didn\'t understand that. You can say things like '
        '"Order one chicken biryani" or "Add two burgers".';
    _state = MealVoiceState.commandUnknown;
    _addLog('Unknown command');
    _speakAndReturn(_ttsResponse!);
  }

  /// Handle item not found in search.
  void _handleItemNotFound(String itemName) {
    _ttsResponse = 'Sorry, I couldn\'t find "$itemName" in any available restaurant. '
        'Would you like to try something else?';
    _state = MealVoiceState.commandError;
    _addLog('Item not found: $itemName');
    _speakAndReturn(_ttsResponse!);
  }

  /// Handle listening timeout (no speech after wake word).
  void _handleListeningTimeout(String reason) {
    _awaitingConfirmation = false;
    _pendingCartConflictClear = false;
    _confirmationTimeout?.cancel();

    if (_state == MealVoiceState.confirmationRequired) {
      _ttsResponse = 'Timed out. Say "Hi MEAL" to try again.';
    } else {
      _ttsResponse = 'I didn\'t hear you. Say "Hi MEAL" when you\'re ready.';
    }

    _addLog('Timeout: $reason');
    _speakAndReturn(_ttsResponse!);
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
    // Don't restart timeout — just re-listen
    _speakAndReturn(_ttsResponse!);
  }

  /// Handle general errors.
  void _handleError(String message) {
    _awaitingConfirmation = false;
    _pendingCartConflictClear = false;
    _confirmationTimeout?.cancel();
    _ttsResponse = 'Sorry, something went wrong. $message';
    _state = MealVoiceState.commandError;
    _addLog('Error: $message');
    _speakAndReturn(_ttsResponse!);
  }

  /// Speak a message and return to wake-word listening.
  Future<void> _speakAndReturn(String message) async {
    _isProcessing = false;
    await _tts.speak(message);
    _returnToWakeWordListening();
  }

  /// Return to wake-word listening state.
  void _returnToWakeWordListening() {
    _awaitingConfirmation = false;
    _pendingCartConflictClear = false;
    _confirmationTimeout?.cancel();
    _searchResults.clear();
    _notFoundItems.clear();
    _pendingItems = [];
    _isProcessing = false;

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

  Future<void> startListening() async {
    if (!_permissionGranted) {
      await requestPermission();
      if (!_permissionGranted) return;
    }

    _ttsResponse = '';
    _lastTranscript = '';
    _lastCommand = null;
    _searchResults.clear();
    _notFoundItems.clear();

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

  Future<void> stopListening() async {
    _confirmationTimeout?.cancel();
    await _tts.stop();
    await _service.stopListening();
    _isListening = false;
    _awaitingConfirmation = false;
    _isProcessing = false;
    _state = MealVoiceState.stopped;
    _lastTranscript = 'Stopped';
    _addLog('Stopped');
    notifyListeners();
  }

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
