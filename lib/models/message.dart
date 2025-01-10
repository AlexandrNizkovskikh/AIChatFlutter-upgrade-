import 'package:flutter/foundation.dart';

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? modelId;
  final int? tokens;

  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.modelId,
    this.tokens,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'modelId': modelId,
      'tokens': tokens,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    try {
      return ChatMessage(
        content: json['content'] as String,
        isUser: json['isUser'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
        modelId: json['modelId'] as String?,
        tokens: json['tokens'] as int?,
      );
    } catch (e) {
      debugPrint('Error decoding message: $e');
      return ChatMessage(
        content: json['content'] as String,
        isUser: json['isUser'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
        modelId: json['modelId'] as String?,
        tokens: json['tokens'] as int?,
      );
    }
  }

  // Очищенный текст для отображения в интерфейсе
  String get cleanContent {
    try {
      return content.trim();
    } catch (e) {
      debugPrint('Error cleaning message content: $e');
      return content;
    }
  }
}
