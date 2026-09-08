import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/customer/presentation/providers/cart_provider.dart';
import '../features/customer/presentation/providers/kitchen_provider.dart';
import '../core/services/voice_order_security_service.dart';
import 'meal_voice_service.dart';
import 'meal_voice_state.dart';
import 'meal_voice_command.dart';
import 'meal_voice_command_parser.dart';
import 'meal_voice_gemini_parser.dart';
import 'meal_voice_parser_factory.dart';
import 'meal_voice_tts_service.dart';
import 'meal_voice_order_handler.dart';
import 'sarvam_stt_service.dart';
import 'sarvam_tts_service.dart';
import 'meal_voice_settings.dart';
import 'meal_voice_response_generator.dart';

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
  final SarvamSTTService _sarvamSTT = SarvamSTTService();
  final SarvamTTSService _sarvamTTS = SarvamTTSService();
  final MealVoiceResponseGenerator _responseGen = MealVoiceResponseGenerator();
  MealVoiceCommandParser? _parser;
  MealVoiceOrderHandler? _orderHandler;
  VoiceOrderSecurityService? _securityService;

  // User settings (language, speaker, AI key)
  MealVoiceSettings? _settings;
  MealVoiceSettings? get settings => _settings;

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

  bool _sarvamAvailable = false;
  bool get sarvamAvailable => _sarvamAvailable;

  bool get awaitingAuthorization => _state == MealVoiceState.awaitingAuthorization;
  bool get awaitingFinalConfirmation => _awaitingFinalConfirmation;

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

  // TTS/Microphone conflict guard
  bool _isSpeaking = false;

  // Voice authorization
  String? _authorizationToken;
  DateTime? _authorizationExpiry;
  bool _authorizationConsumed = false;
  bool _awaitingFinalConfirmation = false;

  /// Callback to show PIN dialog — set by the UI layer.
  Future<void> Function()? requestAuthorization;
  /// Callback to show "place order" confirmation — set by the UI layer.
  Future<bool> Function(String summary, double total)? requestFinalConfirmation;

  // Logs
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  // Events
  StreamSubscription<MealVoiceEvent>? _eventSubscription;

  // User name for personalized greetings
  String _userName = '';
  set userName(String name) => _userName = name;

  // Continuous listening mode (Sarvam mode)
  bool _continuousListening = false;

  // Consecutive STT failure counter — speaks error after N failures
  int _consecutiveSttFailures = 0;
  static const _maxConsecutiveFailures = 3;

  // Detected language from STT — used to reply in the same language
  String _detectedLanguage = 'en-IN';
  String get detectedLanguage => _detectedLanguage;

  // Battery optimization warning
  bool _batteryOptimizationWarning = false;
  bool get batteryOptimizationWarning => _batteryOptimizationWarning;

  /// Speak text — prefer device TTS (instant, works in background), fall back to Sarvam.
  /// Never throws — always tries both if available.
  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    _isSpeaking = true;
    try {
      // Try device TTS first — it's instant and works in background
      if (_ttsAvailable) {
        try {
          _addLog('TTS: Speaking via device TTS (${text.length} chars)');
          await _tts.speak(text);
          _addLog('TTS: Device TTS speak completed');
          return;
        } catch (e) {
          _addLog('TTS: Device TTS failed: $e — trying Sarvam');
        }
      }
      // Fallback to Sarvam TTS (slower, needs network)
      if (_sarvamAvailable) {
        try {
          final lang = _detectedLanguage.isNotEmpty ? _detectedLanguage : 'hi-IN';
          final speaker = _settings?.speaker ?? 'shruti';
          _addLog('TTS: Speaking via Sarvam (${text.length} chars, lang=$lang, speaker=$speaker)');
          final ok = await _sarvamTTS.speak(text, languageCode: lang, speaker: speaker);
          if (ok) {
            _addLog('TTS: Sarvam speak completed');
            return;
          } else {
            _addLog('TTS: Sarvam returned false');
          }
        } catch (e) {
          _addLog('TTS: Sarvam exception: $e');
        }
      }
      _addLog('TTS: No TTS available — response not spoken');
    } finally {
      _isSpeaking = false;
    }
  }

  /// Generate and speak a natural conversational response via Gemini.
  /// Falls back to [fallback] if Gemini is unavailable.
  Future<void> _respond({
    required String context,
    String details = '',
    required String fallback,
  }) async {
    try {
      final response = await _responseGen.respond(
        context: context,
        details: details,
        languageCode: _detectedLanguage,
      );
      _ttsResponse = response;
      await _speakAndReturn(response);
      return;
    } catch (e) {
      _addLog('ResponseGenerator failed: $e');
    }
    _ttsResponse = fallback;
    await _speakAndReturn(fallback);
  }

  /// Speak response and set state without returning to wake word.
  Future<void> _respondAndStay({
    required String context,
    String details = '',
    required String fallback,
    MealVoiceState? state,
  }) async {
    try {
      final response = await _responseGen.respond(
        context: context,
        details: details,
        languageCode: _detectedLanguage,
      );
      _ttsResponse = response;
      if (state != null) _state = state;
      await _speak(response);
      return;
    } catch (e) {
      _addLog('ResponseGenerator failed: $e');
    }
    _ttsResponse = fallback;
    if (state != null) _state = state;
    await _speak(fallback);
  }

  /// Initialize the controller.
  Future<void> initialize({
    KitchenProvider? kitchenProvider,
    CartProvider? cartProvider,
    VoiceOrderSecurityService? securityService,
    MealVoiceCommandParser? parser,
    MealVoiceSettings? settings,
  }) async {
    _securityService = securityService;
    _settings = settings ?? MealVoiceSettings();
    await _settings!.load();
    _parser = parser ?? MealVoiceParserFactory.getParser();

    // Initialize Gemini parser via backend proxy (key is on server)
    MealVoiceParserFactory.initializeGemini().then((available) {
      if (available) {
        _parser = MealVoiceParserFactory.getParser();
        _addLog('Gemini parser ready (backend proxy)');
        notifyListeners();
      }
    });

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

    // Initialize TTS — prefer Sarvam, fall back to flutter_tts
    final sarvamTtsOk = await _sarvamTTS.initialize();
    _addLog('Sarvam TTS init: ${sarvamTtsOk ? "OK" : "FAILED"}');
    _ttsAvailable = await _tts.initialize();
    _addLog('Device TTS init: ${_ttsAvailable ? "OK" : "FAILED"}');

    // Initialize STT — Sarvam cloud STT
    _sarvamAvailable = await _sarvamSTT.initialize();
    _addLog('Sarvam STT init: ${_sarvamAvailable ? "OK" : "FAILED"}');

    // Initialize response generator — Gemini-powered natural responses
    await _responseGen.initialize();
    _addLog('Response generator init: ${_responseGen.isAvailable ? "OK" : "FALLBACK"}');

    // Check battery optimization (Android only)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
        if (batteryStatus.isDenied) {
          _batteryOptimizationWarning = true;
          _addLog('Battery optimization is enabled — background voice may be unreliable');
        }
      } catch (_) {}
    }

    _addLog('Engine initialized (parser: ${_parser?.parserName ?? "unknown"}, TTS: $_ttsAvailable, Sarvam: $_sarvamAvailable)');
    notifyListeners();

    // Check for pending wake word from background notification
    _checkPendingWakeWord();
  }

  /// Check if native service saved a pending wake word while app was killed.
  /// If so, process it immediately (the event may have been lost).
  void _checkPendingWakeWord() {
    SharedPreferences.getInstance().then((prefs) {
      final pending = prefs.getBool('pending_wake_word') ?? false;
      if (pending) {
        prefs.remove('pending_wake_word');
        _addLog('Pending wake word found — processing');
        // Delay slightly to ensure engine is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleWakeWordDetected(DateTime.now());
        });
      }
    });
  }

  /// Handle events from the voice engine.
  void _onEvent(MealVoiceEvent event) {
    switch (event) {
      case WakeWordDetected():
        // FIX: Ignore wake word if TTS is playing (avoid self-interaction)
        if (_isSpeaking) {
          _addLog('Wake word ignored — TTS is speaking');
          return;
        }
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
        // FIX: Don't overwrite state when awaiting confirmation — engine is
        // being restarted in background for capture, but UI must stay on
        // confirmation state so user knows to say "Yes" or "No".
        if (_awaitingConfirmation || _awaitingFinalConfirmation) {
          _addLog('Engine state change ignored — awaiting confirmation');
          break;
        }
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
    _startCommandCapture().catchError((e) {
      _addLog('ERROR in _startCommandCapture: $e');
    });
  }

  /// Start command capture after wake word.
  Future<void> _startCommandCapture() async {
    _state = MealVoiceState.listeningToUser;
    _lastTranscript = '';
    _lastCommand = null;
    _searchResults.clear();
    _notFoundItems.clear();
    notifyListeners();

    // Speak greeting in detected language
    final hour = DateTime.now().hour;
    final lang = _detectedLanguage;
    final isNonLatin = lang.startsWith('hi') || lang.startsWith('bn') ||
        lang.startsWith('gu') || lang.startsWith('kn') || lang.startsWith('ml') ||
        lang.startsWith('mr') || lang.startsWith('od') || lang.startsWith('pa') ||
        lang.startsWith('ta') || lang.startsWith('te');

    String greeting;
    if (isNonLatin) {
      // Hindi/Indian languages — use Sarvam TTS for native greeting
      if (hour < 12) {
        greeting = _userName.isNotEmpty
            ? 'नमस्ते $_userName! आज क्या खाना चाहेंगे?'
            : 'नमस्ते! आज क्या ऑर्डर करना चाहेंगे?';
      } else if (hour < 17) {
        greeting = _userName.isNotEmpty
            ? 'नमस्ते $_userName! दोपहर का खाना क्या चाहिए?'
            : 'नमस्ते! आज क्या ऑर्डर करना चाहेंगे?';
      } else {
        greeting = _userName.isNotEmpty
            ? 'नमस्ते $_userName! शाम का खाना क्या चाहेंगे?'
            : 'नमस्ते! आज क्या ऑर्डर करना चाहेंगे?';
      }
    } else {
      // English
      String timeGreeting;
      if (hour < 12) {
        timeGreeting = 'Good morning';
      } else if (hour < 17) {
        timeGreeting = 'Good afternoon';
      } else {
        timeGreeting = 'Good evening';
      }
      greeting = _userName.isNotEmpty
          ? '$timeGreeting, $_userName! What would you like to eat?'
          : '$timeGreeting! What would you like to order?';
    }

    await _speak(greeting);
    _addLog('Greeting: $greeting (lang: $lang)');

    if (_sarvamAvailable) {
      // Sarvam path: destroy native engine to free mic for flutter_sound recording
      await _service.stopEngine();
      _addLog('Listening for command via Sarvam STT...');
      // Wait for mic to be fully released by SpeechRecognizer
      await Future.delayed(const Duration(milliseconds: 500));
      _captureWithSarvam();
    } else {
      // Native path: engine stays alive, switch to command capture mode
      _addLog('Listening for command via native STT...');
      await _service.startCommandCapture();
    }
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
  /// Uses Gemini if available, falls back to regex.
  Future<void> _parseAndProcess(String transcript) async {
    _isProcessing = true;
    _state = MealVoiceState.parsingCommand;
    notifyListeners();

    MealVoiceCommand command;

    // Try Gemini async parse (it will refresh token internally)
    final currentParser = _parser ?? MealVoiceParserFactory.getParser();
    if (currentParser is GeminiMealVoiceCommandParser) {
      _addLog('Parsing with Gemini...');
      command = await currentParser.parseAsync(transcript, languageCode: _detectedLanguage);
    } else {
      _addLog('Parsing with Regex...');
      command = currentParser.parse(transcript);
    }

    _lastCommand = command;
    _addLog('Parsed: ${command.intent.name} | ${command.items.length} item(s)');

    // Handle unknown intent
    if (command.intent == MealVoiceIntent.unknown) {
      _isProcessing = false;
      if (command.clarification != null && command.clarification!.isNotEmpty) {
        _ttsResponse = command.clarification!;
        _state = MealVoiceState.commandUnknown;
        _addLog('Clarification: ${command.clarification}');
        await _speakAndReturn(_ttsResponse);
      } else {
        _handleUnknownCommand();
      }
      return;
    }

    // Handle confirmation/cancel intents
    if (command.intent == MealVoiceIntent.confirm || command.intent == MealVoiceIntent.cancel) {
      _isProcessing = false;
      if (_awaitingFinalConfirmation) {
        _handleFinalConfirmationResponse(transcript);
      } else if (_awaitingConfirmation) {
        _handleConfirmationResponse(transcript);
      } else {
        _handleUnknownCommand();
      }
      return;
    }

    // Handle add/remove commands
    if (command.isAdd || command.isRemove) {
      await _searchAndConfirm(command);
    } else if (command.intent == MealVoiceIntent.clearCart) {
      _isProcessing = false;
      await _handleClearCart();
    } else if (command.intent == MealVoiceIntent.placeOrder) {
      _isProcessing = false;
      await _handlePlaceOrder();
    } else {
      _isProcessing = false;
      _handleUnknownCommand();
    }
  }

  /// Handle clear cart command.
  Future<void> _handleClearCart() async {
    if (_orderHandler == null) {
      _handleError('Cart is not connected right now.');
      return;
    }

    try {
      await _orderHandler!.clearCart();
      _state = MealVoiceState.commandSuccess;
      _addLog('Cart cleared via voice');
      await _respondAndStay(
        context: 'Cart was cleared successfully. Ask the user what they would like to order next.',
        fallback: 'Cart cleared. What would you like to order?',
        state: MealVoiceState.commandSuccess,
      );
      _returnToWakeWordListening();
    } catch (e) {
      _handleError('Failed to clear cart');
    }
  }

  /// Search for ALL items and prepare confirmation.
  Future<void> _searchAndConfirm(MealVoiceCommand command) async {
    if (_orderHandler == null) {
      _isProcessing = false;
      _handleError('Cart is not connected right now.');
      return;
    }

    if (command.items.isEmpty) {
      _isProcessing = false;
      _handleError('I didn\'t catch what you wanted. Please try again.');
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
      final foundNames = _searchResults.map((r) => r.menuItem.name).join(' and ');
      final missingNames = _notFoundItems.join(' and ');
      _state = MealVoiceState.confirmationRequired;
      _awaitingConfirmation = true;
      notifyListeners();
      await _respondAndStay(
        context: 'Some items were found and some were not. Ask if they want to add only the found items.',
        details: 'Found: $foundNames. Not found: $missingNames.',
        fallback: 'I found $foundNames, but I couldn\'t find $missingNames. Should I just add the ones I found?',
        state: MealVoiceState.confirmationRequired,
      );
      _startConfirmationTimeout();
      await _restartEngineForConfirmation();
      return;
    }

    // All items found — generate confirmation
    await _generateConfirmation(command);
  }

  /// Generate confirmation message for found items.
  Future<void> _generateConfirmation(MealVoiceCommand command) async {
    if (_searchResults.isEmpty) return;

    final items = _pendingItems;
    final results = _searchResults;

    String details;
    String fallbackMsg;
    if (results.length == 1) {
      final result = results.first;
      final item = items.first;
      final price = result.menuItem.price;
      final qty = item.quantity;
      final total = price * qty;
      final name = result.menuItem.name;
      final kitchen = result.kitchen.name;

      details = 'Item: $name, Restaurant: $kitchen, Price: ₹$price, Quantity: $qty, Total: ₹$total';
      fallbackMsg = qty > 1
          ? 'I found $qty ${name}s from $kitchen for ₹$total. Should I add them to your cart?'
          : 'I found $name from $kitchen for ₹$price. Want me to add it to your cart?';
    } else {
      double total = 0;
      for (int i = 0; i < results.length; i++) {
        final result = results[i];
        final item = i < items.length ? items[i] : items.last;
        total += result.menuItem.price * item.quantity;
      }
      final names = results.map((r) => r.menuItem.name).join(' and ');
      details = 'Items: $names, Total: ₹$total';
      fallbackMsg = 'I found $names for a total of ₹$total. Shall I add them all to your cart?';
    }

    _state = MealVoiceState.confirmationRequired;
    _awaitingConfirmation = true;
    notifyListeners();

    await _respondAndStay(
      context: 'Items were found on the menu. Present them to the user and ask if they want to add to cart.',
      details: details,
      fallback: fallbackMsg,
      state: MealVoiceState.confirmationRequired,
    );
    _addLog('Confirmation: $_ttsResponse');
    _startConfirmationTimeout();
    // Restart engine so it can capture user's Yes/No response
    await _restartEngineForConfirmation();
  }

  /// Handle the user's confirmation response.
  void _handleConfirmationResponse(String transcript) {
    _confirmationTimeout?.cancel();

    final response = (_parser ?? MealVoiceParserFactory.getParser()).parseConfirmation(transcript);
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
      _handleError('Nothing to add. Tell me what you\'d like!');
      return;
    }

    _state = MealVoiceState.addingToCart;
    _awaitingConfirmation = false;
    _pendingCartConflictClear = false;
    notifyListeners();

    int addedCount = 0;
    int failedCount = 0;

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
      final allAdded = addedCount == _searchResults.length;
      final itemNames = _searchResults.map((r) => r.menuItem.name).join(', ');
      _state = MealVoiceState.commandSuccess;
      await _respondAndStay(
        context: allAdded
            ? 'All items were successfully added to the cart. Tell the user what they have and the total, then ask if they want anything else.'
            : 'Some items were added to the cart. Tell the user what was added and ask if they want anything else.',
        details: 'Items added: $itemNames. Cart total: ₹$total. Cart count: $count.',
        fallback: allAdded
            ? 'All done! I\'ve added everything. You now have $count item${count > 1 ? 's' : ''} totalling ₹$total. Anything else?'
            : 'Added $addedCount item${addedCount > 1 ? 's' : ''} to your cart. Total is ₹$total. Need anything else?',
        state: MealVoiceState.commandSuccess,
      );
    } else if (addedCount > 0) {
      final total = _orderHandler!.cartTotal;
      await _respondAndStay(
        context: 'Some items were added but some failed. Inform the user and ask if they want to try something else.',
        details: 'Added: $addedCount, Failed: $failedCount. Cart total: ₹$total.',
        fallback: 'I managed to add $addedCount item${addedCount > 1 ? 's' : ''}, but $failedCount couldn\'t be added. Your cart total is ₹$total. Want to try something else?',
        state: MealVoiceState.commandSuccess,
      );
    } else {
      _handleError('Sorry, couldn\'t add that to your cart. Please try again.');
      return;
    }

    // Return to wake-word listening
    _returnToWakeWordListening();
  }

  /// FIX #6: Handle cart conflict — ask user to clear cart.
  Future<void> _handleCartConflict() async {
    _pendingCartConflictClear = true;
    _state = MealVoiceState.confirmationRequired;
    _awaitingConfirmation = true;
    notifyListeners();
    await _respondAndStay(
      context: 'The cart has items from a different restaurant. Ask the user if they want to clear the cart first before adding new items.',
      fallback: 'Your cart has items from a different restaurant. I\'ll need to clear those first. Is that okay?',
      state: MealVoiceState.confirmationRequired,
    );
    _startConfirmationTimeout();
    await _restartEngineForConfirmation();
  }

  /// FIX #6: User confirmed clearing cart — clear and re-add.
  Future<void> _handleCartConflictConfirmed() async {
    _awaitingConfirmation = false;
    _pendingCartConflictClear = false;

    _addLog('Clearing cart due to conflict');
    await _orderHandler!.clearCart();

    // Now add all items
    int addedCount = 0;

    for (int i = 0; i < _searchResults.length; i++) {
      final result = _searchResults[i];
      final item = i < _pendingItems.length ? _pendingItems[i] : _pendingItems.last;

      final addResult = await _orderHandler!.addToCart(
        searchResult: result,
        quantity: item.quantity,
      );

      if (addResult == CartAddResult.success) {
        addedCount++;
      }
    }

    if (addedCount > 0) {
      final total = _orderHandler!.cartTotal;
      final count = _orderHandler!.cartItemCount;
      _state = MealVoiceState.commandSuccess;
      await _respondAndStay(
        context: 'Cart was cleared and items were added. Tell the user what they have and the total, then ask if they want anything else.',
        details: 'Cart count: $count. Total: ₹$total.',
        fallback: 'Done! Cart cleared and items added. You now have $count item${count > 1 ? 's' : ''} totalling ₹$total. Anything else?',
        state: MealVoiceState.commandSuccess,
      );
    } else {
      _handleError('Hmm, something went wrong after clearing the cart.');
      return;
    }

    _returnToWakeWordListening();
  }

  /// Handle user denying the confirmation.
  void _handleUserDenied() {
    _awaitingConfirmation = false;
    _pendingCartConflictClear = false;
    _state = MealVoiceState.userDenied;
    _addLog('User denied');
    _respond(
      context: 'The user declined the order or said no. Be friendly and let them know they can come back anytime.',
      fallback: 'No worries! Just say "Hi MEAL" whenever you\'re ready to order.',
    );
  }

  /// Handle unknown/unrecognized command.
  void _handleUnknownCommand() {
    _state = MealVoiceState.commandUnknown;
    _addLog('Unknown command');
    _respond(
      context: 'The voice command was not understood. Give helpful examples of what they can say, like ordering food, removing items, etc.',
      fallback: 'Sorry, I didn\'t quite get that. You can say things like "Add one chicken biryani" or "Remove the coke".',
    );
  }

  /// Handle item not found in search.
  void _handleItemNotFound(String itemName) {
    _state = MealVoiceState.commandError;
    _addLog('Item not found: $itemName');
    _respond(
      context: 'The item the user requested was not found on any menu. Suggest trying something else.',
      details: 'Item not found: $itemName',
      fallback: 'Hmm, I couldn\'t find "$itemName" on any menu right now. Would you like to try something else?',
    );
  }

  /// Handle listening timeout (no speech after wake word).
  void _handleListeningTimeout(String reason) {
    _awaitingConfirmation = false;
    _pendingCartConflictClear = false;
    _confirmationTimeout?.cancel();

    if (_state == MealVoiceState.confirmationRequired) {
      _respond(
        context: 'The user did not respond during a yes/no confirmation. Remind them to say yes or no.',
        fallback: 'I didn\'t hear you. Say "yes" or "no", or say "Hi MEAL" to start fresh.',
      );
    } else {
      _respond(
        context: 'The user did not say anything after the greeting. Remind them to say Hi MEAL when ready.',
        fallback: 'I didn\'t catch that. Just say "Hi MEAL" when you\'re ready to order.',
      );
    }

    _addLog('Timeout: $reason');
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
    _addLog('Unknown confirmation: $transcript');
    _respond(
      context: 'The user gave an unclear yes/no response. Gently ask them to say yes or no.',
      fallback: 'Sorry, I didn\'t understand. Please say "yes" or "no".',
    );
  }

  /// Handle general errors.
  Future<void> _handleError(String message) async {
    _awaitingConfirmation = false;
    _pendingCartConflictClear = false;
    _confirmationTimeout?.cancel();
    _isProcessing = false;

    // Provide user-friendly messages for common errors
    String contextMsg;
    String fallbackMsg;
    if (message.contains('SocketException') || message.contains('Network') || message.contains('timeout')) {
      contextMsg = 'There is a network connectivity issue. Ask the user to check their internet connection.';
      fallbackMsg = 'I\'m having trouble connecting. Please check your connection and try again.';
    } else if (message.contains('permission')) {
      contextMsg = 'Microphone permission is not granted. Ask the user to enable it in settings.';
      fallbackMsg = 'I need microphone permission. Please allow it in settings.';
    } else {
      contextMsg = 'An error occurred. Tell the user something went wrong and suggest trying again.';
      fallbackMsg = 'Oops, something went wrong. Please try again.';
    }

    _state = MealVoiceState.commandError;
    _addLog('Error: $message');
    await _respondAndStay(
      context: contextMsg,
      details: 'Error details: $message',
      fallback: fallbackMsg,
      state: MealVoiceState.commandError,
    );
  }

  /// Speak a message and return to wake-word listening.
  Future<void> _speakAndReturn(String message) async {
    _isProcessing = false;
    await _speak(message);
    _returnToWakeWordListening();
  }

  /// Restart native engine for listening to confirmation response (Yes/No).
  /// Only needed when Sarvam path destroyed the engine.
  Future<void> _restartEngineForConfirmation() async {
    if (!_sarvamAvailable) return; // Native path: engine is still alive
    _addLog('Restarting engine for confirmation...');
    try {
      await _service.startListening();
      // Brief delay for engine to initialize, then switch to command capture
      await Future.delayed(const Duration(milliseconds: 400));
      await _service.startCommandCapture();
      _addLog('Engine restarted for confirmation listening');
    } catch (e) {
      _addLog('Failed to restart engine for confirmation: $e');
    }
  }

  /// Handle "place order" voice command — requires authorization.
  Future<void> _handlePlaceOrder() async {
    if (_orderHandler == null || _orderHandler!.isCartEmpty) {
      _respond(
        context: 'The user wants to place an order but the cart is empty. Ask them to add items first.',
        fallback: 'Your cart is empty. Tell me what you\'d like to order first!',
      );
      return;
    }

    final total = _orderHandler!.cartTotal;
    final itemCount = _orderHandler!.cartItemCount;

    // Check if authorization is still valid
    if (_authorizationToken != null &&
        _authorizationExpiry != null &&
        DateTime.now().isBefore(_authorizationExpiry!) &&
        !_authorizationConsumed) {
      // Already authorized — ask final confirmation
      await _askFinalConfirmation(total, itemCount);
      return;
    }

    // Need authorization — request PIN
    _state = MealVoiceState.awaitingAuthorization;
    notifyListeners();

    await _respondAndStay(
      context: 'The order total and item count need to be confirmed. Ask the user for their Voice PIN to complete the order.',
      details: 'Total: ₹$total. Items: $itemCount.',
      fallback: 'Your order comes to ₹$total for $itemCount item${itemCount > 1 ? 's' : ''}. I\'ll need your Voice PIN to confirm.',
      state: MealVoiceState.awaitingAuthorization,
    );

    // Request PIN via callback
    if (requestAuthorization != null) {
      await requestAuthorization!();
    }
  }

  /// Called after PIN verification succeeds.
  void onAuthorizationGranted(String token, int expiresIn) {
    _authorizationToken = token;
    _authorizationExpiry = DateTime.now().add(Duration(seconds: expiresIn));
    _authorizationConsumed = false;

    final total = _orderHandler?.cartTotal ?? 0;
    final itemCount = _orderHandler?.cartItemCount ?? 0;

    _addLog('Voice authorization granted, expires in ${expiresIn}s');
    _state = MealVoiceState.authorized;
    notifyListeners();

    // Start final confirmation
    _startFinalConfirmation(total, itemCount);
  }

  /// Called after PIN verification fails.
  void onAuthorizationFailed(String error) {
    _state = MealVoiceState.commandError;
    _addLog('Authorization failed: $error');
    notifyListeners();
    _respond(
      context: 'PIN verification failed. Tell the user it didn\'t work and suggest trying again.',
      details: 'Error: $error',
      fallback: 'PIN verification didn\'t work. $error',
    );
  }

  /// Start final confirmation after authorization.
  Future<void> _startFinalConfirmation(double total, int itemCount) async {
    _awaitingFinalConfirmation = true;
    _state = MealVoiceState.awaitingFinalConfirmation;
    notifyListeners();

    await _respondAndStay(
      context: 'PIN was verified successfully. Ask the user if they want to place the order now.',
      details: 'Total: ₹$total. Items: $itemCount.',
      fallback: 'PIN verified! Shall I place the order for ₹$total?',
      state: MealVoiceState.awaitingFinalConfirmation,
    );
    _startConfirmationTimeout();
    await _restartEngineForConfirmation();
  }

  /// Ask final confirmation via callback.
  Future<void> _askFinalConfirmation(double total, int itemCount) async {
    _awaitingFinalConfirmation = true;
    _state = MealVoiceState.awaitingFinalConfirmation;
    notifyListeners();

    await _respondAndStay(
      context: 'The user already has valid authorization. Ask if they want to place the order now.',
      details: 'Total: ₹$total. Items: $itemCount.',
      fallback: 'Your order comes to ₹$total. Should I go ahead and place it?',
      state: MealVoiceState.awaitingFinalConfirmation,
    );
    _startConfirmationTimeout();
    await _restartEngineForConfirmation();
  }

  /// Handle final yes/no after authorization.
  void _handleFinalConfirmationResponse(String transcript) {
    _confirmationTimeout?.cancel();
    final response = (_parser ?? MealVoiceParserFactory.getParser()).parseConfirmation(transcript);
    _addLog('Final confirmation: ${response.name}');

    switch (response) {
      case MealVoiceConfirmation.yes:
        _placeOrder();
        break;
      case MealVoiceConfirmation.no:
        _authorizationToken = null;
        _authorizationExpiry = null;
        _handleUserDenied();
        break;
      case MealVoiceConfirmation.timeout:
      case MealVoiceConfirmation.unknown:
        _handleConfirmationUnknown(transcript);
        break;
    }
  }

  /// Actually place the order.
  /// Note: Razorpay payment requires the app UI. Voice ordering adds items
  /// to the cart and then the user must complete checkout in the app.
  Future<void> _placeOrder() async {
    if (_authorizationToken == null) {
      _handleError('Authorization expired. Please verify your PIN again.');
      return;
    }

    _awaitingFinalConfirmation = false;
    _state = MealVoiceState.placingOrder;
    notifyListeners();

    try {
      // Consume the authorization token
      await _securityService?.consumeAuthorization(_authorizationToken!);
      _authorizationConsumed = true;

      final total = _orderHandler?.cartTotal ?? 0;
      final itemCount = _orderHandler?.cartItemCount ?? 0;

      _ttsResponse = 'Your cart has $itemCount item${itemCount > 1 ? 's' : ''} '
          'totalling $total rupees. '
          'Please open the app to complete payment and place your order.';
      _state = MealVoiceState.commandSuccess;
      _addLog('Order authorized via voice — cart ready for checkout');
      await _speak(_ttsResponse);

      // Reset authorization
      _authorizationToken = null;
      _authorizationExpiry = null;

      _returnToWakeWordListening();
    } catch (e) {
      _handleError('Oops, couldn\'t authorize the order. Let\'s try again.');
    }
  }

  /// Return to wake-word listening state.
  void _returnToWakeWordListening() {
    _awaitingConfirmation = false;
    _awaitingFinalConfirmation = false;
    _pendingCartConflictClear = false;
    _confirmationTimeout?.cancel();
    _searchResults.clear();
    _notFoundItems.clear();
    _pendingItems = [];
    _isProcessing = false;

    // Both calls needed to handle both paths:
    // - restartWakeWordListening(): works if engine is alive (native command capture path)
    // - startListening(): creates new engine if it was destroyed (Sarvam path)
    // If engine is alive, startListening() is a no-op (startVoiceService returns "already running")
    // If engine is null, restartWakeWordListening() is a no-op (?.safe call)
    _service.restartWakeWordListening();
    _service.startListening();
    _state = MealVoiceState.listeningForWakeWord;
    _isListening = true;
    _lastTranscript = 'Listening for "Hi MEAL"...';
    _addLog('Ready for next command');
    notifyListeners();
  }

  /// Add a log entry.
  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _logs.add('[$timestamp] $message');
    if (_logs.length > 50) _logs.removeAt(0);
  }

  /// Check if a transcript contains a wake word variation.
  /// Uses regex to handle punctuation, mispronunciation, and Sarvam quirks.
  static bool _isWakeWord(String lowerTranscript) {
    final cleaned = lowerTranscript.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
    // Match: hi/hey/hello/ok/start + optional noise + meal/meel/meil/me all
    final patterns = [
      RegExp(r'\bhi\b.*?\bmeal\b'),
      RegExp(r'\bhey\b.*?\bmeal\b'),
      RegExp(r'\bhello\b.*?\bmeal\b'),
      RegExp(r'\bok\b.*?\bmeal\b'),
      RegExp(r'\bstart\b.*?\bmeal\b'),
      RegExp(r'\bhi\b.*?\bmeel\b'),
      RegExp(r'\bhey\b.*?\bmeel\b'),
      RegExp(r'\bhi\b.*?\bmeil\b'),
      RegExp(r'\bhey\b.*?\bmeil\b'),
      RegExp(r'\bhimeal\b'),
      RegExp(r'\bheymeal\b'),
    ];
    for (final pattern in patterns) {
      if (pattern.hasMatch(cleaned)) return true;
    }
    // Fallback: check raw string for simple matches
    const simplePhrases = [
      'hi meal', 'hey meal', 'hello meal', 'ok meal', 'start meal',
      'hi meel', 'hey meel', 'hi meil', 'hey meil',
      'himeal', 'heymeal', 'hellomeal', 'okmeal', 'startmeal',
    ];
    for (final phrase in simplePhrases) {
      if (cleaned.contains(phrase)) return true;
    }
    return false;
  }

  /// Reset voice authorization (e.g., after cart changes significantly).
  void resetAuthorization() {
    _authorizationToken = null;
    _authorizationExpiry = null;
    _authorizationConsumed = false;
    _addLog('Authorization reset');
    notifyListeners();
  }

  /// Check if current authorization is still valid.
  bool get isAuthorized =>
      _authorizationToken != null &&
      _authorizationExpiry != null &&
      DateTime.now().isBefore(_authorizationExpiry!) &&
      !_authorizationConsumed;

  /// Request battery optimization exemption (Android only).
  Future<void> requestBatteryOptimizationExemption() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final status = await Permission.ignoreBatteryOptimizations.request();
        if (status.isGranted) {
          _batteryOptimizationWarning = false;
          _addLog('Battery optimization exemption granted');
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  // ─── Public API ───

  Future<void> requestPermission() async {
    _state = MealVoiceState.initializing;
    _lastTranscript = 'Requesting permission...';
    notifyListeners();

    final status = await Permission.microphone.request();
    if (status.isGranted) {
      _permissionGranted = true;
      _lastTranscript = 'Permission granted';
      _state = MealVoiceState.idle;
    } else if (status.isPermanentlyDenied) {
      _permissionGranted = false;
      _lastTranscript = 'Microphone permission permanently denied. Please enable it in Settings.';
      _state = MealVoiceState.error;
      _addLog('Microphone permission permanently denied');
    } else {
      _permissionGranted = false;
      _lastTranscript = 'Microphone permission denied';
      _state = MealVoiceState.error;
      _addLog('Microphone permission denied');
    }
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
    _consecutiveSttFailures = 0;

    final started = await _service.startListening();
    if (started) {
      _isListening = true;
      _state = MealVoiceState.listeningForWakeWord;
      _lastTranscript = 'Listening for "Hi MEAL"...';
      _addLog('Native engine started for wake word detection');
    } else {
      _lastTranscript = 'Failed to start voice engine';
      _ttsResponse = 'Voice recognition is not available on this device.';
      _state = MealVoiceState.error;
      _addLog('Failed to start native engine');
    }
    notifyListeners();
  }

  /// Capture speech using Sarvam cloud STT.
  /// Records audio then sends to backend proxy for transcription.
  /// Max recording: 12 seconds hard limit.
  Future<void> _captureWithSarvam() async {
    FlutterSoundRecorder? recorder;
    String? audioPath;
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _addLog('STT: Microphone permission denied');
        _handleError('Microphone permission denied');
        return;
      }

      _addLog('STT: Starting recording...');

      recorder = FlutterSoundRecorder();
      await recorder.openRecorder();
      final tempDir = await getTemporaryDirectory();
      audioPath = '${tempDir.path}/sarvam_capture.wav';

      // Small delay to let audio session fully initialize (flutter_sound race condition)
      await Future.delayed(const Duration(milliseconds: 300));

      await recorder.startRecorder(
        toFile: audioPath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );

      _lastTranscript = 'Listening...';
      notifyListeners();

      // Wait 12 seconds for user to speak — simple, always works
      _addLog('STT: Recording for 12s...');
      await Future.delayed(const Duration(seconds: 12));

      // Stop recorder — wrapped in try-catch so we always proceed
      try {
        await recorder.stopRecorder();
      } catch (e) {
        _addLog('STT: stopRecorder error (non-fatal): $e');
      }
      try {
        await recorder.closeRecorder();
      } catch (e) {
        _addLog('STT: closeRecorder error (non-fatal): $e');
      }
      recorder = null;

      _addLog('STT: Audio captured, sending to backend proxy...');

      // Send to STT via backend
      final sttLang = _settings?.sttLanguageCode;
      final transcript = await _sarvamSTT.transcribeFile(audioPath, languageCode: sttLang ?? 'auto');
      final sttError = _sarvamSTT.lastError;

      // Clean up audio file
      try {
        await File(audioPath).delete();
      } catch (_) {}
      audioPath = null;

      if (transcript != null && transcript.transcript.trim().isNotEmpty) {
        _consecutiveSttFailures = 0; // Reset on success
        final lowerTranscript = transcript.transcript.trim().toLowerCase();
        _addLog('STT: "${transcript.transcript}" (lang: ${transcript.languageCode})');
        // Store detected language for TTS responses
        if (transcript.languageCode != null && transcript.languageCode!.isNotEmpty) {
          _detectedLanguage = transcript.languageCode!;
          _addLog('Language detected: $_detectedLanguage');
          // Set device TTS language to match detected language
          if (_ttsAvailable) {
            try {
              await _tts.setLanguage(_detectedLanguage);
            } catch (_) {}
          }
        }
        // Check for wake word in Sarvam mode
        if (_isWakeWord(lowerTranscript)) {
          _addLog('Wake word detected in transcript: "${transcript.transcript}"');
          _handleWakeWordDetected(DateTime.now());
        } else {
          _handleTranscription(transcript.transcript);
        }
      } else {
        _consecutiveSttFailures++;
        final errorDetail = sttError ?? 'empty transcript';
        _addLog('STT failed ($_consecutiveSttFailures/$_maxConsecutiveFailures): $errorDetail');

        if (_consecutiveSttFailures >= _maxConsecutiveFailures) {
          _consecutiveSttFailures = 0;
          _handleError('Speech recognition is not working. $errorDetail');
          return;
        }

        if (_continuousListening) {
          _lastTranscript = 'Listening... (attempt ${_consecutiveSttFailures + 1})';
          notifyListeners();
          _captureWithSarvam();
        } else {
          _lastTranscript = 'No speech detected. Tap mic to try again.';
          _state = MealVoiceState.idle;
          _isListening = false;
          notifyListeners();
        }
      }
    } catch (e) {
      // Always clean up recorder
      if (recorder != null) {
        try { await recorder.stopRecorder(); } catch (_) {}
        try { await recorder.closeRecorder(); } catch (_) {}
      }
      if (audioPath != null) {
        try { await File(audioPath).delete(); } catch (_) {}
      }
      _addLog('STT: Recording exception: $e');
      _handleError('Recording failed: $e');
    }
  }

  Future<void> stopListening() async {
    _continuousListening = false;
    _confirmationTimeout?.cancel();
    await _tts.stop();
    await _sarvamTTS.stop();
    await _service.stopListening();
    _isListening = false;
    _awaitingConfirmation = false;
    _isProcessing = false;
    _state = MealVoiceState.stopped;
    _lastTranscript = 'Stopped. Tap START MEAL to begin.';
    _addLog('Stopped');
    notifyListeners();
  }

  /// Called when app resumes from background.
  void onAppResumed() {
    _addLog('App resumed');
    // Re-initialize TTS services — tokens may have expired in background
    _reinitTts();
    if (_state != MealVoiceState.stopped && !_isListening) {
      _addLog('Restarting voice listener');
      startListening();
    }
  }

  /// Re-initialize TTS tokens when app comes to foreground.
  Future<void> _reinitTts() async {
    try {
      await _sarvamTTS.initialize();
      _ttsAvailable = await _tts.initialize();
      _addLog('TTS re-initialized on resume');
    } catch (e) {
      _addLog('TTS re-init error: $e');
    }
  }

  /// Called when app goes to background.
  void onAppPaused() {
    _addLog('App paused — native engine continues in foreground service');
    // Do NOT stop listening — the foreground service keeps the native engine running
    // This allows wake word detection even when the app is in background
  }

  /// Reset all user-specific state. Call on logout.
  void resetUserState() {
    _userName = '';
    _authorizationToken = null;
    _authorizationExpiry = null;
    _authorizationConsumed = false;
    _awaitingConfirmation = false;
    _awaitingFinalConfirmation = false;
    _pendingCartConflictClear = false;
    _isProcessing = false;
    _isSpeaking = false;
    _continuousListening = false;
    _searchResults.clear();
    _notFoundItems.clear();
    _pendingItems = [];
    _confirmationTimeout?.cancel();
    _logs.clear();
    _addLog('User state reset');
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
    _sarvamSTT.dispose();
    _sarvamTTS.dispose();
    super.dispose();
  }
}
