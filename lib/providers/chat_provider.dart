import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message.dart';
import '../api/openrouter_client.dart';
import '../services/database_service.dart';
import '../services/analytics_service.dart';

class ChatProvider with ChangeNotifier {
  final OpenRouterClient _api = OpenRouterClient();
  final List<ChatMessage> _messages = [];
  final List<String> _debugLogs = [];
  List<Map<String, String>> _availableModels = [];
  String? _currentModel;
  String _balance = '\$0.00';
  bool _isLoading = false;

  void _log(String message) {
    _debugLogs.add('${DateTime.now()}: $message');
    debugPrint(message);
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<Map<String, String>> get availableModels => _availableModels;
  String? get currentModel => _currentModel;
  String get balance => _balance;
  bool get isLoading => _isLoading;

  ChatProvider() {
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    try {
      _log('Initializing provider...');
      await _loadModels();
      _log('Models loaded: $_availableModels');
      await _loadBalance();
      _log('Balance loaded: $_balance');
      await _loadHistory();
      _log('History loaded: ${_messages.length} messages');
    } catch (e, stackTrace) {
      _log('Error initializing provider: $e');
      _log('Stack trace: $stackTrace');
    }
  }

  Future<void> _loadModels() async {
    try {
      _availableModels = await _api.getModels();
      if (_availableModels.isNotEmpty && _currentModel == null) {
        _currentModel = _availableModels[0]['id'];
      }
      notifyListeners();
    } catch (e) {
      _log('Error loading models: $e');
    }
  }

  Future<void> _loadBalance() async {
    try {
      _balance = await _api.getBalance();
      notifyListeners();
    } catch (e) {
      _log('Error loading balance: $e');
    }
  }

  final DatabaseService _db = DatabaseService();
  final AnalyticsService _analytics = AnalyticsService();

  Future<void> _loadHistory() async {
    try {
      final messages = await _db.getMessages();
      _messages.clear();
      _messages.addAll(messages);
      notifyListeners();
    } catch (e) {
      _log('Error loading history: $e');
    }
  }

  Future<void> _saveMessage(ChatMessage message) async {
    try {
      await _db.saveMessage(message);
    } catch (e) {
      _log('Error saving message: $e');
    }
  }

  Future<void> sendMessage(String content, {bool trackAnalytics = true}) async {
    if (content.trim().isEmpty || _currentModel == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Ensure proper encoding of the message
      content = utf8.decode(utf8.encode(content));

      // Add user message
      final userMessage = ChatMessage(
        content: content,
        isUser: true,
        modelId: _currentModel,
      );
      _messages.add(userMessage);
      notifyListeners();

      // Save user message
      await _saveMessage(userMessage);

      final startTime = DateTime.now();

      // Send to API
      final response = await _api.sendMessage(content, _currentModel!);
      _log('API Response: $response');

      final responseTime =
          DateTime.now().difference(startTime).inMilliseconds / 1000;

      if (response.containsKey('error')) {
        // Add error message
        final errorMessage = ChatMessage(
          content: utf8.decode(utf8.encode('Error: ${response['error']}')),
          isUser: false,
          modelId: _currentModel,
        );
        _messages.add(errorMessage);
        await _saveMessage(errorMessage);
      } else if (response.containsKey('choices') &&
          response['choices'] is List &&
          response['choices'].isNotEmpty &&
          response['choices'][0] is Map &&
          response['choices'][0].containsKey('message') &&
          response['choices'][0]['message'] is Map &&
          response['choices'][0]['message'].containsKey('content')) {
        // Add AI response
        final aiContent = utf8.decode(utf8.encode(
          response['choices'][0]['message']['content'] as String,
        ));
        final tokens = response['usage']?['total_tokens'] as int? ?? 0;

        if (trackAnalytics) {
          _analytics.trackMessage(
            model: _currentModel!,
            messageLength: content.length,
            responseTime: responseTime,
            tokensUsed: tokens,
          );
        }

        final aiMessage = ChatMessage(
          content: aiContent,
          isUser: false,
          modelId: _currentModel,
          tokens: tokens,
        );
        _messages.add(aiMessage);
        await _saveMessage(aiMessage);

        // Update balance after successful message
        await _loadBalance();
      } else {
        throw Exception('Invalid API response format');
      }
    } catch (e) {
      _log('Error sending message: $e');
      final errorMessage = ChatMessage(
        content: utf8.decode(utf8.encode('Error: $e')),
        isUser: false,
        modelId: _currentModel,
      );
      _messages.add(errorMessage);
      await _saveMessage(errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCurrentModel(String modelId) {
    _currentModel = modelId;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _messages.clear();
    await _db.clearHistory();
    _analytics.clearData();
    notifyListeners();
  }

  Future<String> exportLogs() async {
    final directory = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName =
        'chat_logs_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.txt';
    final file = File('${directory.path}/$fileName');

    final buffer = StringBuffer();
    buffer.writeln('=== Debug Logs ===\n');
    for (final log in _debugLogs) {
      buffer.writeln(log);
    }

    buffer.writeln('\n=== Chat Logs ===\n');
    buffer.writeln('Generated: ${now.toString()}\n');

    for (final message in _messages) {
      buffer.writeln('${message.isUser ? "User" : "AI"} (${message.modelId}):');
      buffer.writeln(message.content);
      if (message.tokens != null) {
        buffer.writeln('Tokens: ${message.tokens}');
      }
      buffer.writeln('Time: ${message.timestamp}');
      buffer.writeln('---\n');
    }

    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> exportMessagesAsJson() async {
    final directory = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName =
        'chat_history_${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.json';
    final file = File('${directory.path}/$fileName');

    final List<Map<String, dynamic>> messagesJson =
        _messages.map((message) => message.toJson()).toList();

    await file.writeAsString(jsonEncode(messagesJson));
    return file.path;
  }

  Future<Map<String, dynamic>> exportHistory() async {
    final dbStats = await _db.getStatistics();
    final analyticsStats = _analytics.getStatistics();
    final sessionData = _analytics.exportSessionData();
    final modelEfficiency = _analytics.getModelEfficiency();
    final responseTimeStats = _analytics.getResponseTimeStats();
    final messageLengthStats = _analytics.getMessageLengthStats();

    return {
      'database_stats': dbStats,
      'analytics_stats': analyticsStats,
      'session_data': sessionData,
      'model_efficiency': modelEfficiency,
      'response_time_stats': responseTimeStats,
      'message_length_stats': messageLengthStats,
    };
  }
}
