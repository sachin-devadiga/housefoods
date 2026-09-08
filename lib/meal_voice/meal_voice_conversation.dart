import 'dart:convert';

/// A single turn in the conversation.
class ConversationTurn {
  final String role;
  final String content;
  final DateTime timestamp;

  ConversationTurn({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };

  factory ConversationTurn.fromJson(Map<String, dynamic> json) {
    return ConversationTurn(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }
}

/// An action requested by Gemini to be executed by the controller.
class VoiceAction {
  final String type;
  final Map<String, dynamic> params;

  VoiceAction({required this.type, this.params = const {}});

  factory VoiceAction.fromJson(Map<String, dynamic> json) {
    return VoiceAction(
      type: json['type'] as String? ?? 'none',
      params: Map<String, dynamic>.from(json)..remove('type'),
    );
  }

  String? get itemName => params['item_name'] as String?;
  int get quantity => (params['quantity'] as num?)?.toInt() ?? 1;
  String? get restaurant => params['restaurant'] as String?;
  String? get query => params['query'] as String?;
  String? get item => params['item'] as String?;

  bool get isSearchMenu => type == 'search_menu';
  bool get isAddToCart => type == 'add_to_cart';
  bool get isRemoveFromCart => type == 'remove_from_cart';
  bool get isClearCart => type == 'clear_cart';
  bool get isShowCart => type == 'show_cart';
  bool get isPlaceOrder => type == 'place_order';
  bool get isNone => type == 'none';

  @override
  String toString() => 'VoiceAction($type, $params)';
}

/// Parsed response from the conversational Gemini.
class ConversationalResponse {
  final String response;
  final List<VoiceAction> actions;

  ConversationalResponse({required this.response, this.actions = const []});

  factory ConversationalResponse.fromJson(Map<String, dynamic> json) {
    final actionsList = (json['actions'] as List?)
            ?.map((a) => VoiceAction.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];
    return ConversationalResponse(
      response: json['response'] as String? ?? '',
      actions: actionsList,
    );
  }
}

/// Manages conversation state for the MEAL voice assistant.
///
/// Maintains:
/// - last N user/assistant turns
/// - detected language
/// - current restaurant context
/// - latest search results
/// - cart snapshot
/// - pending confirmation context
class MealVoiceConversation {
  static const int maxHistory = 10;

  final List<ConversationTurn> _history = [];
  String _detectedLanguage = 'en-IN';
  String? _currentRestaurant;
  List<Map<String, dynamic>> _lastSearchResults = [];
  Map<String, dynamic>? _cartSnapshot;
  Map<String, dynamic>? _pendingConfirmation;

  List<ConversationTurn> get history => List.unmodifiable(_history);
  String get detectedLanguage => _detectedLanguage;
  String? get currentRestaurant => _currentRestaurant;
  List<Map<String, dynamic>> get lastSearchResults => List.unmodifiable(
      _lastSearchResults.map(Map<String, dynamic>.unmodifiable));
  Map<String, dynamic>? get cartSnapshot => _cartSnapshot;
  Map<String, dynamic>? get pendingConfirmation => _pendingConfirmation;

  /// Add a user turn to history.
  void addUserTurn(String text) {
    _history.add(ConversationTurn(role: 'user', content: text));
    _trimHistory();
  }

  /// Add an assistant turn to history.
  void addAssistantTurn(String text) {
    _history.add(ConversationTurn(role: 'model', content: text));
    _trimHistory();
  }

  /// Update detected language from STT.
  void setDetectedLanguage(String code) {
    if (code.isNotEmpty) _detectedLanguage = code;
  }

  /// Update current restaurant context.
  void setCurrentRestaurant(String? name) {
    _currentRestaurant = name;
  }

  /// Update search results context.
  void setSearchResults(List<Map<String, dynamic>> results) {
    _lastSearchResults = results.map(Map<String, dynamic>.from).toList();
  }

  /// Update cart snapshot.
  void setCartSnapshot(double total, int itemCount, List<String> itemNames) {
    _cartSnapshot = {
      'total': total,
      'item_count': itemCount,
      'items': itemNames,
    };
  }

  /// Set pending confirmation context (for yes/no flows).
  void setPendingConfirmation(Map<String, dynamic>? data) {
    _pendingConfirmation = data;
  }

  /// Build the conversation history array for Gemini API.
  List<Map<String, String>> buildGeminiHistory() {
    return _history
        .map((turn) => {'role': turn.role, 'content': turn.content})
        .toList();
  }

  /// Build context summary for the current turn.
  Map<String, dynamic> buildContext() {
    final ctx = <String, dynamic>{
      'detected_language': _detectedLanguage,
    };
    if (_currentRestaurant != null) {
      ctx['current_restaurant'] = _currentRestaurant;
    }
    if (_lastSearchResults.isNotEmpty) {
      ctx['last_search_results'] = _lastSearchResults;
    }
    if (_cartSnapshot != null) {
      ctx['cart'] = _cartSnapshot;
    }
    if (_pendingConfirmation != null) {
      ctx['pending_confirmation'] = _pendingConfirmation;
    }
    return ctx;
  }

  /// Reset conversation (new session).
  void reset() {
    _history.clear();
    _detectedLanguage = 'en-IN';
    _currentRestaurant = null;
    _lastSearchResults.clear();
    _cartSnapshot = null;
    _pendingConfirmation = null;
  }

  void _trimHistory() {
    while (_history.length > maxHistory) {
      _history.removeAt(0);
    }
  }

  /// Serialize for debugging.
  String toJsonString() {
    return jsonEncode({
      'history': _history.map((t) => t.toJson()).toList(),
      'language': _detectedLanguage,
      'restaurant': _currentRestaurant,
      'search_results': _lastSearchResults.length,
      'cart': _cartSnapshot,
    });
  }
}
