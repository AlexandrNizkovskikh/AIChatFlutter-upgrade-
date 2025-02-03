// Import JSON library
import 'dart:convert';
// Import HTTP client
import 'package:http/http.dart' as http;
// Import Flutter core classes
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';

// Класс клиента для работы с API OpenRouter и VSEGPT
class OpenRouterClient {
  String? apiKey;
  String? baseUrl;
  Map<String, String> headers = {
    'Content-Type': 'application/json',
    'X-Title': 'AI Chat Flutter',
  };
  String? provider;

  static final OpenRouterClient _instance = OpenRouterClient._internal();
  
  factory OpenRouterClient() {
    return _instance;
  }

  OpenRouterClient._internal();

  // Метод инициализации клиента с API ключом
  Future<bool> initialize(String apiKey) async {
    try {
      this.apiKey = apiKey;
      
      // Определяем провайдера по формату ключа
      provider = apiKey.startsWith('sk-or-vv-') ? 'vsegpt' : 'openrouter';
      baseUrl = provider == 'vsegpt' 
          ? 'https://api.vsegpt.ru:6070/v1'
          : 'https://openrouter.ai/api/v1';
      
      // Обновляем заголовки с новым ключом
      headers['Authorization'] = 'Bearer $apiKey';

      // Проверяем баланс для валидации ключа
      final balance = await getBalance();
      if (balance == 'Error') {
        return false;
      }

      // Сохраняем данные в базу
      final dbService = DatabaseService();
      final authData = await dbService.getAuthData();
      
      if (authData == null) {
        // Генерируем случайный 4-значный PIN
        final pin = (1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString();
        await dbService.saveAuthData(apiKey, pin, provider!);
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing client: $e');
      }
      return false;
    }
  }

  // Метод загрузки сохраненных данных авторизации
  Future<bool> loadSavedAuth() async {
    try {
      final dbService = DatabaseService();
      final authData = await dbService.getAuthData();
      
      if (authData != null) {
        apiKey = authData['api_key'];
        provider = authData['provider'];
        baseUrl = provider == 'vsegpt'
            ? 'https://api.vsegpt.ru:6070/v1'
            : 'https://openrouter.ai/api/v1';
        headers['Authorization'] = 'Bearer $apiKey';
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading saved auth: $e');
      }
      return false;
    }
  }

  // Метод проверки PIN-кода
  Future<bool> verifyPin(String pin) async {
    try {
      final dbService = DatabaseService();
      final authData = await dbService.getAuthData();
      return authData != null && authData['pin_code'] == pin;
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying PIN: $e');
      }
      return false;
    }
  }

  // Метод сброса авторизации
  Future<void> resetAuth() async {
    try {
      final dbService = DatabaseService();
      await dbService.clearAuthData();
      apiKey = null;
      baseUrl = null;
      provider = null;
      headers.remove('Authorization');
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting auth: $e');
      }
    }
  }

  // Метод получения списка доступных моделей
  Future<List<Map<String, dynamic>>> getModels() async {
    try {
      // Выполнение GET запроса для получения моделей
      final response = await http.get(
        Uri.parse('$baseUrl/models'),
        headers: headers,
      );

      if (kDebugMode) {
        print('Models response status: ${response.statusCode}');
        print('Models response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        // Парсинг данных о моделях
        final modelsData = json.decode(response.body);
        if (modelsData['data'] != null) {
          return (modelsData['data'] as List)
              .map((model) => {
                    'id': model['id'] as String,
                    'name': (() {
                      try {
                        return utf8.decode((model['name'] as String).codeUnits);
                      } catch (e) {
                        // Remove invalid UTF-8 characters and try again
                        final cleaned = (model['name'] as String)
                            .replaceAll(RegExp(r'[^\x00-\x7F]'), '');
                        return utf8.decode(cleaned.codeUnits);
                      }
                    })(),
                    'pricing': {
                      'prompt': model['pricing']['prompt'] as String,
                      'completion': model['pricing']['completion'] as String,
                    },
                    'context_length': (model['context_length'] ??
                            model['top_provider']['context_length'] ??
                            0)
                        .toString(),
                  })
              .toList();
        }
        throw Exception('Invalid API response format');
      } else {
        // Возвращение моделей по умолчанию, если API недоступен
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
      // Возвращение моделей по умолчанию в случае ошибки
      return [
        {'id': 'deepseek-coder', 'name': 'DeepSeek'},
        {'id': 'claude-3-sonnet', 'name': 'Claude 3.5 Sonnet'},
        {'id': 'gpt-3.5-turbo', 'name': 'GPT-3.5 Turbo'},
      ];
    }
  }

  // Метод отправки сообщения через API
  Future<Map<String, dynamic>> sendMessage(String message, String model) async {
    try {
      // Подготовка данных для отправки
      final data = {
        'model': model, // Модель для генерации ответа
        'messages': [
          {'role': 'user', 'content': message} // Сообщение пользователя
        ],
        'max_tokens': 1000, // Максимальное количество токенов
        'temperature': 0.7, // Температура генерации
        'stream': false, // Отключение потоковой передачи
      };

      if (kDebugMode) {
        print('Sending message to API: ${json.encode(data)}');
      }

      // Выполнение POST запроса
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
        // Успешный ответ
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        return responseData;
      } else {
        // Обработка ошибки
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

  // Метод получения текущего баланса
  Future<String> getBalance() async {
    try {
      // Выполнение GET запроса для получения баланса
      final response = await http.get(
        Uri.parse(baseUrl?.contains('vsegpt.ru') == true
            ? '$baseUrl/balance'
            : '$baseUrl/credits'),
        headers: headers,
      );

      if (kDebugMode) {
        print('Balance response status: ${response.statusCode}');
        print('Balance response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        // Парсинг данных о балансе
        final data = json.decode(response.body);
        if (data != null && data['data'] != null) {
          if (baseUrl?.contains('vsegpt.ru') == true) {
            final credits =
                double.tryParse(data['data']['credits'].toString()) ??
                    0.0; // Доступно средств
            return '${credits.toStringAsFixed(2)}₽'; // Расчет доступного баланса
          } else {
            final credits = data['data']['total_credits'] ?? 0; // Общие кредиты
            final usage =
                data['data']['total_usage'] ?? 0; // Использованные кредиты
            return '\$${(credits - usage).toStringAsFixed(2)}'; // Расчет доступного баланса
          }
        }
      }
      return baseUrl?.contains('vsegpt.ru') == true
          ? '0.00₽'
          : '\$0.00'; // Возвращение нулевого баланса по умолчанию
    } catch (e) {
      if (kDebugMode) {
        print('Error getting balance: $e');
      }
      return 'Error'; // Возвращение ошибки в случае исключения
    }
  }

  // Метод форматирования цен
  String formatPricing(double pricing) {
    try {
      if (baseUrl?.contains('vsegpt.ru') == true) {
        return '${pricing.toStringAsFixed(3)}₽/K';
      } else {
        return '\$${(pricing * 1000000).toStringAsFixed(3)}/M';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error formatting pricing: $e');
      }
      return '0.00';
    }
  }
}
