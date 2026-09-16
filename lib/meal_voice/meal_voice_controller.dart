import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/customer/presentation/providers/cart_provider.dart';
import '../features/customer/presentation/providers/kitchen_provider.dart';
import '../core/services/voice_order_security_service.dart';
import '../core/constants/app_constants.dart';
import '../core/services/token_service.dart';
import 'meal_voice_service.dart';
import 'meal_voice_state.dart';
import 'meal_voice_conversation.dart';
import 'meal_voice_conversational_brain.dart';
import 'meal_voice_tts_service.dart';
import 'meal_voice_order_handler.dart';
import 'sarvam_stt_service.dart';
import 'sarvam_tts_service.dart';
import 'meal_voice_settings.dart';
import 'engines/meal_voice_engine.dart';
import 'engines/gemini_live_engine.dart';

/// Conversational controller for the MEAL voice engine.
///
/// Architecture: User speech → Sarvam STT → Gemini brain (with context) →
/// natural response + actions → validate & execute actions → TTS response.
class MealVoiceController extends ChangeNotifier {
  final MealVoiceService _service = MealVoiceService.instance;
  final MealVoiceTtsService _tts = MealVoiceTtsService();
  final SarvamSTTService _sarvamSTT = SarvamSTTService();
  final SarvamTTSService _sarvamTTS = SarvamTTSService();
  final MealVoiceConversationalBrain _brain = MealVoiceConversationalBrain();
  final MealVoiceConversation _conversation = MealVoiceConversation();
  final GeminiLiveEngine _geminiLiveEngine = GeminiLiveEngine();
  MealVoiceOrderHandler? _orderHandler;
  VoiceOrderSecurityService? _securityService;

  /// Active engine: 'legacy' or 'gemini_live'
  String _activeEngine = 'legacy';
  String get activeEngine => _activeEngine;

  /// Gemini Live connection state
  bool _geminiLiveConnected = false;
  bool get geminiLiveConnected => _geminiLiveConnected;

  /// Gemini Live fallback: if true, use legacy engine
  bool _useGeminiLive = false;
  bool get useGeminiLive => _useGeminiLive;

  MealVoiceSettings? _settings;
  MealVoiceSettings? get settings => _settings;

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
  final bool _awaitingConfirmation = false;
  bool get awaitingConfirmation => _awaitingConfirmation;

  String _lastTranscript = '';
  String get lastTranscript => _lastTranscript;

  String _ttsResponse = '';
  String get ttsResponse => _ttsResponse;

  String? _lastCommand;
  String? get lastCommand => _lastCommand;

  // Search results — kept for UI display
  final List<SearchResult> _searchResults = [];
  List<SearchResult> get searchResults => List.unmodifiable(_searchResults);

  // Items that failed to find
  final List<String> _notFoundItems = [];
  List<String> get notFoundItems => List.unmodifiable(_notFoundItems);

  bool _isProcessing = false;
  bool _isSpeaking = false;

  String? _authorizationToken;
  DateTime? _authorizationExpiry;
  bool _authorizationConsumed = false;
  bool _awaitingFinalConfirmation = false;

  Future<void> Function()? requestAuthorization;
  Future<bool> Function(String summary, double total)? requestFinalConfirmation;

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  StreamSubscription<MealVoiceEvent>? _eventSubscription;

  String _userName = '';
  set userName(String name) => _userName = name;

  String _detectedLanguage = 'en-IN';
  String get detectedLanguage => _detectedLanguage;

  bool _batteryOptimizationWarning = false;
  bool get batteryOptimizationWarning => _batteryOptimizationWarning;

  Timer? _listeningTimeoutTimer;
  static const _listeningTimeoutDuration = Duration(seconds: 15);

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    _isSpeaking = true;
    try {
      if (_ttsAvailable) {
        try {
          _addLog('TTS: Speaking via device TTS (${text.length} chars)');
          await _tts.speak(text);
          _addLog('TTS: Device TTS speak completed');
          return;
        } catch (e) {
          _addLog('TTS: Device TTS failed: $e — trying Sarvam');
          try { await _tts.stop(); } catch (_) {}
        }
      }
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

  /// Initialize the controller.
  Future<void> initialize({
    KitchenProvider? kitchenProvider,
    CartProvider? cartProvider,
    VoiceOrderSecurityService? securityService,
    MealVoiceSettings? settings,
  }) async {
    _securityService = securityService;
    _settings = settings ?? MealVoiceSettings();
    await _settings!.load();

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

    final sarvamTtsOk = await _sarvamTTS.initialize();
    _addLog('Sarvam TTS init: ${sarvamTtsOk ? "OK" : "FAILED"}');
    _ttsAvailable = await _tts.initialize();
    _addLog('Device TTS init: ${_ttsAvailable ? "OK" : "FAILED"}');

    _sarvamAvailable = await _sarvamSTT.initialize();
    _addLog('Sarvam STT init: ${_sarvamAvailable ? "OK" : "FAILED"}');

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
        if (batteryStatus.isDenied) {
          _batteryOptimizationWarning = true;
          _addLog('Battery optimization is enabled — background voice may be unreliable');
        }
      } catch (_) {}
    }

    _addLog('Engine initialized (TTS: $_ttsAvailable, Sarvam: $_sarvamAvailable)');

    // Initialize Gemini Live engine preference
    final prefs = await SharedPreferences.getInstance();
    _useGeminiLive = prefs.getBool('use_gemini_live') ?? false;
    if (_useGeminiLive) {
      _addLog('Gemini Live enabled — initializing...');
      await _initGeminiLiveEngine();
    }

    notifyListeners();

    // Auto-start voice service if it was previously enabled (persists across app sessions)
    _autoStartVoiceIfNeeded();
    _checkPendingWakeWord();
  }

  /// Auto-start the voice engine if the user previously enabled it.
  /// This ensures voice stays on even after app restart.
  void _autoStartVoiceIfNeeded() async {
    try {
      final wasEnabled = await _service.isVoiceEnabledOnBoot();
      if (wasEnabled && !_isListening && _permissionGranted) {
        _addLog('Voice was enabled — auto-starting engine');
        Future.delayed(const Duration(milliseconds: 1000), () {
          startListening();
        });
      }
    } catch (e) {
      _addLog('Auto-start check failed: $e');
    }
  }

  void _checkPendingWakeWord() {
    SharedPreferences.getInstance().then((prefs) {
      final pending = prefs.getBool('pending_wake_word') ?? false;
      if (pending) {
        final command = prefs.getString('pending_command');
        prefs.remove('pending_wake_word');
        prefs.remove('pending_command');
        if (command != null && command.isNotEmpty) {
          _addLog('Pending command found: "$command" — processing directly');
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleTranscription(command);
          });
        } else {
          _addLog('Pending wake word found — listening for command');
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleWakeWordDetected(DateTime.now());
          });
        }
      }
    });
  }

  void _onEvent(MealVoiceEvent event) {
    switch (event) {
      case WakeWordDetected():
        if (_isSpeaking) {
          _addLog('Wake word ignored — TTS is speaking');
          return;
        }
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
        if (_awaitingFinalConfirmation) {
          _addLog('Engine state change ignored — awaiting final confirmation');
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

  void _handleWakeWordDetected(DateTime timestamp) {
    _addLog('Wake word detected');
    _state = MealVoiceState.wakeDetected;
    _isProcessing = false;
    _conversation.reset();
    notifyListeners();
    _startCommandCapture().catchError((e) {
      _addLog('ERROR in _startCommandCapture: $e');
    });
  }

  Future<void> _startCommandCapture() async {
    _state = MealVoiceState.listeningToUser;
    _lastTranscript = '';
    notifyListeners();

    final hour = DateTime.now().hour;
    final lang = _detectedLanguage;
    final isNonLatin = lang.startsWith('hi') || lang.startsWith('bn') ||
        lang.startsWith('gu') || lang.startsWith('kn') || lang.startsWith('ml') ||
        lang.startsWith('mr') || lang.startsWith('od') || lang.startsWith('pa') ||
        lang.startsWith('ta') || lang.startsWith('te');

    String greeting;
    if (isNonLatin) {
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

    _addLog('Greeting: $greeting (lang: $lang)');

    // Start command capture FIRST — do NOT wait for TTS (TTS may hang on some devices)
    _addLog('Starting native command capture...');
    await _service.startCommandCapture();

    // Speak greeting in parallel (non-blocking) — don't let TTS delay listening
    _speak(greeting).catchError((e) {
      _addLog('TTS greeting failed (non-fatal): $e');
    });
  }

  void _handleTranscription(String transcript) {
    if (transcript.trim().isEmpty) {
      _handleListeningTimeout('Empty transcription');
      return;
    }

    _lastTranscript = transcript;
    _addLog('Transcript: "$transcript"');

    if (_isProcessing) {
      _addLog('Already processing — ignoring duplicate transcription');
      return;
    }

    // Handle final confirmation (yes/no) directly — don't route through brain
    if (_awaitingFinalConfirmation) {
      _handleFinalConfirmationResponse(transcript);
      return;
    }

    _processConversationalTurn(transcript);
  }

  /// Handle final yes/no after authorization.
  void _handleFinalConfirmationResponse(String transcript) {
    _listeningTimeoutTimer?.cancel();
    final lower = transcript.toLowerCase().trim();

    final isYes = lower == 'yes' || lower == 'yeah' || lower == 'yep' ||
        lower == 'haan' || lower == 'हाँ' || lower.startsWith('yes') ||
        lower.startsWith('yeah') || lower.startsWith('sure') || lower.startsWith('haan');

    final isNo = lower == 'no' || lower == 'nope' || lower == 'nahi' || lower == 'नहीं' ||
        lower.startsWith('no') || lower.startsWith('nah');

    _addLog('Final confirmation: ${isYes ? "YES" : isNo ? "NO" : "UNKNOWN"} ($transcript)');

    if (isYes) {
      _placeOrder();
    } else if (isNo) {
      _authorizationToken = null;
      _authorizationExpiry = null;
      _awaitingFinalConfirmation = false;
      _ttsResponse = 'No worries! Just say "Hi MEAL" whenever you\'re ready to order.';
      _speakAndReturn(_ttsResponse);
    } else {
      _ttsResponse = 'Sorry, I didn\'t understand. Say "yes" to place the order or "no" to cancel.';
      _speakAndReturn(_ttsResponse);
    }
  }

  /// The core conversational turn processor.
  ///
  /// Sends user's speech to Gemini brain with full context, receives
  /// response + actions, validates and executes actions, then speaks.
  Future<void> _processConversationalTurn(String transcript) async {
    _isProcessing = true;
    _state = MealVoiceState.parsingCommand;
    notifyListeners();

    _listeningTimeoutTimer?.cancel();

    _conversation.addUserTurn(transcript);
    _conversation.setDetectedLanguage(_detectedLanguage);

    if (_orderHandler != null) {
      _conversation.setCartSnapshot(
        _orderHandler!.cartTotal,
        _orderHandler!.cartItemCount,
        [],
      );
    }

    _addLog('Brain: Sending to Gemini with context...');

    final response = await _brain.chat(
      userTranscript: transcript,
      conversation: _conversation,
    );

    if (response == null) {
      _addLog('Brain: Gemini returned null — network or parse error');
      _isProcessing = false;
      _handleError('I had trouble understanding that. Could you try again?');
      return;
    }

    _addLog('Brain: response="${response.response}", actions=${response.actions.length}');

    _conversation.addAssistantTurn(response.response);

    final responseLanguage = _detectResponseLanguage(response.response);
    if (responseLanguage.isNotEmpty) {
      _detectedLanguage = responseLanguage;
      if (_ttsAvailable) {
        try { await _tts.setLanguage(_detectedLanguage); } catch (_) {}
      }
    }

    _ttsResponse = response.response;

    for (final action in response.actions) {
      _addLog('Action: ${action.type} — ${action.params}');
      final actionSuccess = await _executeAction(action);
      if (!actionSuccess && action.type != 'none') {
        _addLog('Action ${action.type} failed or blocked');
      }
    }

    _isProcessing = false;

    final staysListening = response.actions.any((a) =>
        a.isAddToCart || a.isRemoveFromCart || a.isSearchMenu || a.isShowCart || a.isClearCart);

    if (_awaitingFinalConfirmation) {
      _state = MealVoiceState.awaitingFinalConfirmation;
    } else if (_state == MealVoiceState.awaitingAuthorization) {
      _state = MealVoiceState.awaitingAuthorization;
    } else if (staysListening) {
      _state = MealVoiceState.commandSuccess;
      await _speak(response.response);
      _startListeningForNextTurn();
    } else {
      _state = MealVoiceState.commandSuccess;
      await _speakAndReturn(response.response);
    }
  }

  /// Execute a single action returned by Gemini.
  /// Returns true if action was executed successfully.
  Future<bool> _executeAction(VoiceAction action) async {
    if (action.isNone) return true;

    if (action.isSearchMenu) {
      return _executeSearchMenu(action);
    } else if (action.isAddToCart) {
      return _executeAddToCart(action);
    } else if (action.isRemoveFromCart) {
      return _executeRemoveFromCart(action);
    } else if (action.isClearCart) {
      return _executeClearCart(action);
    } else if (action.isShowCart) {
      return _executeShowCart(action);
    } else if (action.isPlaceOrder) {
      return _executePlaceOrder(action);
    }
    return false;
  }

  Future<bool> _executeSearchMenu(VoiceAction action) async {
    if (_orderHandler == null) return false;
    final query = action.query ?? action.itemName ?? '';
    if (query.isEmpty) return false;

    _state = MealVoiceState.searchingMenu;
    _searchResults.clear();
    _notFoundItems.clear();
    notifyListeners();

    final result = await _orderHandler!.searchItem(
      itemName: query,
      restaurantName: action.restaurant,
    );

    if (result != null) {
      _searchResults.add(result);
      _conversation.setSearchResults([{
        'item_name': result.menuItem.name,
        'restaurant': result.kitchen.name,
        'price': result.menuItem.price,
        'available': result.menuItem.isAvailable,
      }]);
      _addLog('Search found: ${result.menuItem.name} from ${result.kitchen.name} — ₹${result.menuItem.price}');
      return true;
    } else {
      _notFoundItems.add(query);
      _addLog('Search: nothing found for "$query"');
      return false;
    }
  }

  Future<bool> _executeAddToCart(VoiceAction action) async {
    if (_orderHandler == null) return false;

    final itemName = action.itemName;
    if (itemName == null || itemName.isEmpty) return false;

    final restaurant = action.restaurant;

    _state = MealVoiceState.searchingMenu;
    notifyListeners();

    final searchResult = await _orderHandler!.searchItem(
      itemName: itemName,
      restaurantName: restaurant,
    );

    if (searchResult == null) {
      _addLog('AddToCart: item "$itemName" not found');
      return false;
    }

    final addResult = await _orderHandler!.addToCart(
      searchResult: searchResult,
      quantity: action.quantity,
    );

      switch (addResult) {
        case CartAddResult.success:
          _addLog('Added to cart: ${searchResult.menuItem.name} x${action.quantity}');
          return true;
        case CartAddResult.cartConflict:
          _addLog('Cart conflict — different restaurant');
          _ttsResponse = 'You have items from a different restaurant in your cart. Clear the cart first, or say "clear cart" to start fresh.';
          _state = MealVoiceState.confirmationRequired;
          notifyListeners();
          await _speak(_ttsResponse);
          await _restartEngineForConfirmation();
          return false;
        case CartAddResult.itemUnavailable:
          _ttsResponse = 'Sorry, ${searchResult.menuItem.name} is currently unavailable.';
          _addLog('Item unavailable: ${searchResult.menuItem.name}');
          return false;
        default:
          _ttsResponse = 'Sorry, I couldn\'t add that to your cart. Please try again.';
          _addLog('Failed to add to cart');
          return false;
      }
  }

  Future<bool> _executeRemoveFromCart(VoiceAction action) async {
    if (_orderHandler == null) return false;
    final item = action.item ?? action.itemName;
    if (item == null || item.isEmpty) return false;

    try {
      final result = await _orderHandler!.removeFromCart(
        itemName: item,
        quantity: action.quantity,
      );
      switch (result) {
        case CartRemoveResult.success:
          _addLog('Removed from cart: $item x${action.quantity}');
          return true;
        case CartRemoveResult.ambiguousItem:
          _ttsResponse = 'I found more than one matching item. Which one would you like to remove?';
          _addLog('RemoveFromCart ambiguous: $item');
          return false;
        default:
          _addLog('RemoveFromCart failed: $result');
          return false;
      }
    } catch (e) {
      _addLog('RemoveFromCart error: $e');
      return false;
    }
  }

  Future<bool> _executeClearCart(VoiceAction action) async {
    if (_orderHandler == null) return false;
    try {
      await _orderHandler!.clearCart();
      _addLog('Cart cleared via voice');
      return true;
    } catch (e) {
      _addLog('ClearCart error: $e');
      return false;
    }
  }

  Future<bool> _executeShowCart(VoiceAction action) async {
    if (_orderHandler == null) return false;
    final total = _orderHandler!.cartTotal;
    final count = _orderHandler!.cartItemCount;
    _addLog('Cart: $count items, total ₹$total');
    return true;
  }

  Future<bool> _executePlaceOrder(VoiceAction action) async {
    if (_orderHandler == null || _orderHandler!.isCartEmpty) {
      return false;
    }

    final total = _orderHandler!.cartTotal;
    final itemCount = _orderHandler!.cartItemCount;

    if (_authorizationToken != null &&
        _authorizationExpiry != null &&
        DateTime.now().isBefore(_authorizationExpiry!) &&
        !_authorizationConsumed) {
      await _askFinalConfirmation(total, itemCount);
      return true;
    }

    _state = MealVoiceState.awaitingAuthorization;
    notifyListeners();

    if (requestAuthorization != null) {
      await requestAuthorization!();
    }
    return true;
  }

  void _handleError(String message) {
    _awaitingFinalConfirmation = false;
    _isProcessing = false;

    String fallbackMsg;
    if (message.contains('SocketException') || message.contains('Network') || message.contains('timeout')) {
      fallbackMsg = 'I\'m having trouble connecting. Please check your connection and try again.';
    } else if (message.contains('permission')) {
      fallbackMsg = 'I need microphone permission. Please allow it in settings.';
    } else {
      fallbackMsg = 'Oops, something went wrong. Please try again.';
    }

    _state = MealVoiceState.commandError;
    _addLog('Error: $message');
    _ttsResponse = fallbackMsg;
    _speakAndReturn(fallbackMsg);
  }

  void _handleListeningTimeout(String reason) {
    _awaitingFinalConfirmation = false;
    _listeningTimeoutTimer?.cancel();

    _ttsResponse = 'I didn\'t catch that. Just say "Hi MEAL" when you\'re ready to order.';
    _addLog('Timeout: $reason');
    _speakAndReturn(_ttsResponse);
  }

  void _startListeningTimeout() {
    _listeningTimeoutTimer?.cancel();
    _listeningTimeoutTimer = Timer(_listeningTimeoutDuration, () {
      _handleListeningTimeout('Listening timeout');
    });
  }

  void _startListeningForNextTurn() {
    _startListeningTimeout();
    // ALWAYS use native STT — same SpeechRecognizer instance, no mic conflict
    _service.startCommandCapture();
  }

  Future<void> _speakAndReturn(String message) async {
    _isProcessing = false;
    await _speak(message);
    _returnToWakeWordListening();
  }

  Future<void> _restartEngineForConfirmation() async {
    _addLog('Restarting engine for confirmation...');
    try {
      // ALWAYS use native STT — swaps listener on same SpeechRecognizer
      await _service.startCommandCapture();
      _addLog('Engine restarted for confirmation listening');
    } catch (e) {
      _addLog('Failed to restart engine for confirmation: $e');
    }
  }

  void onAuthorizationGranted(String token, int expiresIn) {
    _authorizationToken = token;
    _authorizationExpiry = DateTime.now().add(Duration(seconds: expiresIn));
    _authorizationConsumed = false;

    final total = _orderHandler?.cartTotal ?? 0;
    final itemCount = _orderHandler?.cartItemCount ?? 0;

    _addLog('Voice authorization granted, expires in ${expiresIn}s');
    _state = MealVoiceState.authorized;
    notifyListeners();

    _startFinalConfirmation(total, itemCount);
  }

  void onAuthorizationFailed(String error) {
    _state = MealVoiceState.commandError;
    _addLog('Authorization failed: $error');
    notifyListeners();
    _ttsResponse = 'PIN verification didn\'t work. $error';
    _speakAndReturn(_ttsResponse);
  }

  Future<void> _startFinalConfirmation(double total, int itemCount) async {
    _awaitingFinalConfirmation = true;
    _state = MealVoiceState.awaitingFinalConfirmation;
    notifyListeners();

    _ttsResponse = 'PIN verified! Shall I place the order for ₹$total?';
    await _speak(_ttsResponse);
    _startListeningTimeout();
    await _restartEngineForConfirmation();
  }

  Future<void> _askFinalConfirmation(double total, int itemCount) async {
    _awaitingFinalConfirmation = true;
    _state = MealVoiceState.awaitingFinalConfirmation;
    notifyListeners();

    _ttsResponse = 'Your order comes to ₹$total. Should I go ahead and place it?';
    await _speak(_ttsResponse);
    _startListeningTimeout();
    await _restartEngineForConfirmation();
  }

  Future<void> _placeOrder() async {
    if (_authorizationToken == null) {
      _handleError('Authorization expired. Please verify your PIN again.');
      return;
    }

    _awaitingFinalConfirmation = false;
    _state = MealVoiceState.placingOrder;
    notifyListeners();

    try {
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

      _authorizationToken = null;
      _authorizationExpiry = null;

      _returnToWakeWordListening();
    } catch (e) {
      _handleError('Oops, couldn\'t authorize the order. Let\'s try again.');
    }
  }

  void _returnToWakeWordListening() {
    _awaitingFinalConfirmation = false;
    _listeningTimeoutTimer?.cancel();
    _isProcessing = false;

    _service.restartWakeWordListening();
    _state = MealVoiceState.listeningForWakeWord;
    _isListening = true;
    _lastTranscript = 'Listening for "Hi MEAL"...';
    _addLog('Ready for next command');
    notifyListeners();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _logs.add('[$timestamp] $message');
    if (_logs.length > 50) _logs.removeAt(0);
  }

  String _detectResponseLanguage(String text) {
    if (text.isEmpty) return '';
    if (text.contains(RegExp(r'[\u0C80-\u0CFF]'))) return 'kn-IN';
    if (text.contains(RegExp(r'[\u0900-\u097F]'))) return 'hi-IN';
    if (text.contains(RegExp(r'[\u0980-\u09FF]'))) return 'bn-IN';
    if (text.contains(RegExp(r'[\u0A80-\u0AFF]'))) return 'gu-IN';
    if (text.contains(RegExp(r'[\u0D00-\u0D7F]'))) return 'ml-IN';
    if (text.contains(RegExp(r'[\u0B00-\u0B7F]'))) return 'od-IN';
    if (text.contains(RegExp(r'[\u0A00-\u0A7F]'))) return 'pa-IN';
    if (text.contains(RegExp(r'[\u0B80-\u0BFF]'))) return 'ta-IN';
    if (text.contains(RegExp(r'[\u0C00-\u0C7F]'))) return 'te-IN';
    if (text.contains(RegExp(r'[\u0930-\u094F]'))) return 'mr-IN';
    if (text.contains(RegExp(r'[a-zA-Z]'))) return 'en-IN';
    return '';
  }

  Future<Map<String, dynamic>> getStatus() async {
    return await _service.getStatus();
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

    // Try Gemini Live if enabled and not connected
    if (_useGeminiLive && !_geminiLiveConnected) {
      _addLog('Attempting Gemini Live connection...');
      await _geminiLiveEngine.startListening();
      // Give it a moment to connect
      await Future.delayed(const Duration(seconds: 2));
      if (_geminiLiveConnected) {
        _addLog('Gemini Live connected — using live engine');
        _isListening = true;
        _state = MealVoiceState.listeningForWakeWord;
        _lastTranscript = 'Listening for "Hi MEAL"...';
        notifyListeners();
        return;
      }
      _addLog('Gemini Live not available — using legacy engine');
    }

    // Legacy engine (native SpeechRecognizer)
    final started = await _service.startListening();
    if (started) {
      _isListening = true;
      _state = MealVoiceState.listeningForWakeWord;
      _lastTranscript = 'Listening for "Hi MEAL"...';
      _addLog('Native engine started for wake word detection');
      _activeEngine = 'legacy';
    } else {
      _lastTranscript = 'Failed to start voice engine';
      _ttsResponse = 'Voice recognition is not available on this device.';
      _state = MealVoiceState.error;
      _addLog('Failed to start native engine');
    }
    notifyListeners();
  }

  Future<void> stopListening() async {
    _listeningTimeoutTimer?.cancel();
    await _tts.stop();
    await _sarvamTTS.stop();
    await _service.stopListening();
    _isListening = false;
    _state = MealVoiceState.stopped;
    _lastTranscript = 'Stopped. Tap START MEAL to begin.';
    _addLog('Stopped');
    notifyListeners();
  }

  void onAppResumed() {
    _addLog('App resumed');
    _reinitTts();
    if (_state != MealVoiceState.stopped && !_isListening) {
      _addLog('Restarting voice listener');
      startListening();
    }
  }

  Future<void> _reinitTts() async {
    try {
      await _sarvamTTS.initialize();
      _ttsAvailable = await _tts.initialize();
      _addLog('TTS re-initialized on resume');
    } catch (e) {
      _addLog('TTS re-init error: $e');
    }
  }

  void onAppPaused() {
    _addLog('App paused — native engine continues in foreground service');
  }

  void resetUserState() {
    _userName = '';
    _authorizationToken = null;
    _authorizationExpiry = null;
    _authorizationConsumed = false;
    _isProcessing = false;
    _isSpeaking = false;
    _conversation.reset();
    _logs.clear();
    _addLog('User state reset');
    notifyListeners();
  }

  void resetAuthorization() {
    _authorizationToken = null;
    _authorizationExpiry = null;
    _authorizationConsumed = false;
    _addLog('Authorization reset');
    notifyListeners();
  }

  bool get isAuthorized =>
      _authorizationToken != null &&
      _authorizationExpiry != null &&
      DateTime.now().isBefore(_authorizationExpiry!) &&
      !_authorizationConsumed;

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

  /// Initialize the Gemini Live engine.
  Future<void> _initGeminiLiveEngine() async {
    try {
      final tokenService = TokenService();
      final token = await tokenService.getAccessToken();
      if (token == null || token.isEmpty) {
        _addLog('Gemini Live: No auth token available');
        return;
      }

      final initialized = await _geminiLiveEngine.initialize(
        backendUrl: AppConstants.apiBaseUrl,
        authToken: token,
        onLog: (log) => _addLog(log),
        onEvent: _handleGeminiLiveEvent,
      );

      if (initialized) {
        _addLog('Gemini Live engine initialized successfully');
      } else {
        _addLog('Gemini Live engine init failed — using legacy');
        _useGeminiLive = false;
      }
    } catch (e) {
      _addLog('Gemini Live init error: $e — using legacy');
      _useGeminiLive = false;
    }
  }

  /// Handle events from the Gemini Live engine.
  void _handleGeminiLiveEvent(MealVoiceEngineEvent event) {
    switch (event) {
      case EngineConnected():
        _geminiLiveConnected = true;
        _activeEngine = 'gemini_live';
        _addLog('Gemini Live connected');
        notifyListeners();
        break;

      case EngineDisconnected():
        _geminiLiveConnected = false;
        _activeEngine = 'legacy';
        _addLog('Gemini Live disconnected: ${event.reason}');
        notifyListeners();
        break;

      case EngineTranscription():
        if (event.isFinal) {
          _handleTranscription(event.text);
        } else {
          _lastTranscript = event.text;
          notifyListeners();
        }
        break;

      case EngineResponse():
        _ttsResponse = event.text;
        _addLog('Gemini Live response: ${event.text.substring(0, event.text.length > 100 ? 100 : event.text.length)}');
        // Parse the response for actions (if JSON format)
        _processGeminiLiveResponse(event.text);
        break;

      case EngineFunctionCall():
        _handleGeminiLiveFunctionCall(event.name, event.args);
        break;

      case EngineErrorEvent():
        _addLog('Gemini Live error: ${event.message}');
        if (event.recoverable) {
          // Fall back to legacy engine
          _useGeminiLive = false;
          _activeEngine = 'legacy';
          _addLog('Falling back to legacy engine');
        }
        notifyListeners();
        break;

      case EngineStateChangedEvent():
        _addLog('Gemini Live state: ${event.newState}');
        break;

      case EngineAudioOutput():
        // Audio is handled natively by Kotlin
        break;
    }
  }

  /// Handle a function call from Gemini Live.
  void _handleGeminiLiveFunctionCall(String name, Map<String, dynamic> args) {
    _addLog('Gemini Live function call: $name($args)');

    // Convert to VoiceAction and execute
    final action = VoiceAction(
      type: name,
      params: Map<String, dynamic>.from(args),
    );

    _executeAction(action).then((success) {
      // Send response back to Gemini Live
      _geminiLiveEngine.sendFunctionResponse('', {
        'success': success,
        'message': success ? 'Action executed' : 'Action failed',
      });
    });
  }

  /// Process a Gemini Live text response for actions.
  void _processGeminiLiveResponse(String text) {
    try {
      var cleaned = text.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      if (cleaned.startsWith('{')) {
        final json = Map<String, dynamic>.from(
          const JsonDecoder().convert(cleaned) as Map,
        );
        final responseText = json['response'] as String? ?? text;
        _ttsResponse = responseText;

        final actions = (json['actions'] as List?)?.map((a) {
          return VoiceAction.fromJson(Map<String, dynamic>.from(a as Map));
        }).toList() ?? [];

        if (actions.isNotEmpty) {
          for (final action in actions) {
            _executeAction(action);
          }
        }
      }
    } catch (_) {
      // Not JSON — use as-is
      _ttsResponse = text;
    }

    // Speak the response
    final staysListening = _ttsResponse.isNotEmpty;
    if (staysListening) {
      _state = MealVoiceState.commandSuccess;
      _speak(_ttsResponse);
    }
    notifyListeners();
  }

  /// Toggle between Gemini Live and legacy engine.
  Future<void> toggleEngine() async {
    _useGeminiLive = !_useGeminiLive;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_gemini_live', _useGeminiLive);

    if (_useGeminiLive) {
      _addLog('Switching to Gemini Live engine');
      await _initGeminiLiveEngine();
    } else {
      _addLog('Switching to legacy engine');
      await _geminiLiveEngine.disconnect();
      _geminiLiveConnected = false;
      _activeEngine = 'legacy';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _listeningTimeoutTimer?.cancel();
    _tts.dispose();
    _sarvamSTT.dispose();
    _sarvamTTS.dispose();
    _geminiLiveEngine.dispose();
    super.dispose();
  }
}
