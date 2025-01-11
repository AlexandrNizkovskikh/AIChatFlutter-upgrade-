// Импорт библиотеки для работы с JSON
import 'dart:convert';
// Импорт HTTP клиента
import 'package:http/http.dart' as http;
// Импорт основных классов Flutter
import 'package:flutter/foundation.dart';
// Импорт пакета для работы с .env файлами
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Класс клиента для работы с API OpenRouter
class OpenRouterClient {
  // API ключ для авторизации
  final String? apiKey;
  // Базовый URL API
  final String? baseUrl;
  // Заголовки HTTP запросов
  final Map<String, String> headers;

  // Единственный экземпляр класса (Singleton)
  static final OpenRouterClient _instance = OpenRouterClient._internal();

  // Фабричный метод для получения экземпляра
  factory OpenRouterClient() {
    return _instance;
  }

  // Приватный конструктор для реализации Singleton
  OpenRouterClient._internal()
      : apiKey =
            dotenv.env['OPENROUTER_API_KEY'], // Получение API ключа из .env
        baseUrl = dotenv.env['BASE_URL'], // Получение базового URL из .env
        headers = {
          'Authorization':
              'Bearer ${dotenv.env['OPENROUTER_API_KEY']}', // Заголовок авторизации
          'Content-Type': 'application/json', // Указание типа контента
          'HTTP-Referer': 'http://localhost:3000', // Заголовок Referer
          'X-Title': 'AI Chat Flutter', // Название приложения
        } {
    // Инициализация клиента
    _initializeClient();
  }

  // Метод инициализации клиента
  void _initializeClient() {
    try {
      if (kDebugMode) {
        print('Initializing OpenRouterClient...');
        print('Base URL: $baseUrl');
      }

      // Проверка наличия API ключа
      if (apiKey == null) {
        throw Exception('OpenRouter API key not found in .env');
      }
      // Проверка наличия базового URL
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

  // Метод получения списка доступных моделей
  Future<List<Map<String, String>>> getModels() async {
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
                    'name': model['name'] as String,
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
        'max_tokens': int.parse(dotenv.env['MAX_TOKENS'] ??
            '1000'), // Максимальное количество токенов
        'temperature': double.parse(
            dotenv.env['TEMPERATURE'] ?? '0.7'), // Температура генерации
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
        Uri.parse('$baseUrl/credits'),
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
          final credits = data['data']['total_credits'] ?? 0; // Общие кредиты
          final usage =
              data['data']['total_usage'] ?? 0; // Использованные кредиты
          return '\$${(credits - usage).toStringAsFixed(2)}'; // Расчет доступного баланса
        }
      }
      return '\$0.00'; // Возвращение нулевого баланса по умолчанию
    } catch (e) {
      if (kDebugMode) {
        print('Error getting balance: $e');
      }
      return 'Error'; // Возвращение ошибки в случае исключения
    }
  }
}
