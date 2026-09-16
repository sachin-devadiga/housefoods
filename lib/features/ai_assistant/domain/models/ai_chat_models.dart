class AiToolCall {
  final String toolName;
  final Map<String, dynamic> parameters;

  AiToolCall({required this.toolName, required this.parameters});

  factory AiToolCall.fromJson(Map<String, dynamic> json) {
    return AiToolCall(
      toolName: json['tool_name'] ?? '',
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'tool_name': toolName,
        'parameters': parameters,
      };
}

class AiToolResult {
  final String toolName;
  final Map<String, dynamic> result;

  AiToolResult({required this.toolName, required this.result});

  factory AiToolResult.fromJson(Map<String, dynamic> json) {
    return AiToolResult(
      toolName: json['tool_name'] ?? '',
      result: Map<String, dynamic>.from(json['result'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'tool_name': toolName,
        'result': result,
      };
}

class AiChatMessage {
  final String id;
  final String role;
  final String text;
  final List<AiToolCall> toolCalls;
  final List<AiToolResult> toolResults;
  final DateTime timestamp;

  AiChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.toolCalls = const [],
    this.toolResults = const [],
    required this.timestamp,
  });

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      id: json['id'] ?? '',
      role: json['role'] ?? 'user',
      text: json['text'] ?? '',
      toolCalls: (json['tool_calls'] as List<dynamic>?)
              ?.map((e) => AiToolCall.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      toolResults: (json['tool_results'] as List<dynamic>?)
              ?.map((e) => AiToolResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'text': text,
        'tool_calls': toolCalls.map((e) => e.toJson()).toList(),
        'tool_results': toolResults.map((e) => e.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
      };
}

class AiChatResponse {
  final String responseText;
  final List<AiToolCall> toolCalls;
  final List<AiToolResult> toolResults;

  AiChatResponse({
    required this.responseText,
    this.toolCalls = const [],
    this.toolResults = const [],
  });

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    return AiChatResponse(
      responseText: json['response_text'] ?? json['message'] ?? '',
      toolCalls: (json['tool_calls'] as List<dynamic>?)
              ?.map((e) => AiToolCall.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      toolResults: (json['tool_results'] as List<dynamic>?)
              ?.map((e) => AiToolResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
