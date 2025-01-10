import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenRouterClient {
  final String? apiKey;
  final String? baseUrl;
  final Map<String, String> headers;

  static final OpenRouterClient _instance = OpenRouterClient._internal();

  factory OpenRouterClient() {
    return _instance;
  }

  OpenRouterClient._internal()
      : apiKey = dotenv.env['OPENROUTER_API_KEY'],
        baseUrl = dotenv.env['BASE_URL'],
        headers = {
          'Authorization': 'Bearer ${dotenv.env['OPENROUTER_API_KEY']}',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'http://localhost:3000',
          'X-Title': 'AI Chat Flutter',
        } {
    _initializeClient();
  }

  void _initializeClient() {
    try {
      if (kDebugMode) {
        print('Initializing OpenRouterClient...');
        print('Base URL: $baseUrl');
      }

      if (apiKey == null) {
        throw Exception('OpenRouter API key not found in .env');
      }
      if (baseUrl == null) {
        throw Exception('BASE_URL not found in .env');
      }

      if (kDebugMode) {
        print('OpenRouterClient initialized successfully');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error initializing OpenRouterClient: $e');
        print('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  Future<List<Map<String, String>>> getModels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/models'),
        headers: headers,
      );

      if (kDebugMode) {
        print('Models response status: ${response.statusCode}');
        print('Models response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final modelsData = json.decode(response.body);
        if (modelsData['data'] != null) {
          return (modelsData['data'] as List)
              .map((model) => {
                    'id': model['id'] as String,
                    'name': model['name'] as String,
                  })
              .toList();
        }
        throw Exception('Invalid API response format');
      } else {
        // Return default models if API is unavailable
        return [
          {'id': 'deepseek-coder', 'name': 'DeepSeek'},
          {'id': 'claude-3-sonnet', 'name': 'Claude 3.5 Sonnet'},
          {'id': 'gpt-3.5-turbo', 'name': 'GPT-3.5 Turbo'},
        ];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting models: $e');
      }
      // Return default models on error
      return [
        {'id': 'deepseek-coder', 'name': 'DeepSeek'},
        {'id': 'claude-3-sonnet', 'name': 'Claude 3.5 Sonnet'},
        {'id': 'gpt-3.5-turbo', 'name': 'GPT-3.5 Turbo'},
      ];
    }
  }

  Future<Map<String, dynamic>> sendMessage(String message, String model) async {
    try {
      final data = {
        'model': model,
        'messages': [
          {'role': 'user', 'content': message}
        ],
        'max_tokens': int.parse(dotenv.env['MAX_TOKENS'] ?? '1000'),
        'temperature': double.parse(dotenv.env['TEMPERATURE'] ?? '0.7'),
        'stream': false,
      };

      if (kDebugMode) {
        print('Sending message to API: ${json.encode(data)}');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: headers,
        body: json.encode(data),
      );

      if (kDebugMode) {
        print('Message response status: ${response.statusCode}');
        print('Message response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        return responseData;
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        return {
          'error': errorData['error']?['message'] ?? 'Unknown error occurred'
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
      return {'error': e.toString()};
    }
  }

  Future<String> getBalance() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/credits'),
        headers: headers,
      );

      if (kDebugMode) {
        print('Balance response status: ${response.statusCode}');
        print('Balance response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['data'] != null) {
          final credits = data['data']['total_credits'] ?? 0;
          final usage = data['data']['total_usage'] ?? 0;
          return '\$${(credits - usage).toStringAsFixed(2)}';
        }
      }
      return '\$0.00';
    } catch (e) {
      if (kDebugMode) {
        print('Error getting balance: $e');
      }
      return 'Error';
    }
  }
}
