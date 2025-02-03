import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/openrouter_client.dart';
import '../services/database_service.dart';
import 'chat_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _apiKeyController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _hasAuth = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    setState(() => _isLoading = true);
    
    final client = OpenRouterClient();
    final hasAuth = await client.loadSavedAuth();
    
    setState(() {
      _hasAuth = hasAuth;
      _isLoading = false;
    });
  }

  Future<void> _handleApiKeySubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiKey = _apiKeyController.text.trim();
    final client = OpenRouterClient();
    
    try {
      final success = await client.initialize(apiKey);
      if (success) {
        if (!mounted) return;
        
        // Получаем сгенерированный PIN из базы
        final dbService = DatabaseService();
        final authData = await dbService.getAuthData();
        
        // Показываем PIN пользователю
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('PIN-код создан'),
            content: Text(
              'Ваш PIN-код для входа: ${authData?['pin_code']}\n\n'
              'Пожалуйста, сохраните его.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Неверный ключ API или недостаточно средств';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePinSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final pin = _pinController.text.trim();
    final client = OpenRouterClient();
    
    try {
      final isValid = await client.verifyPin(pin);
      if (isValid) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      } else {
        setState(() {
          _errorMessage = 'Неверный PIN-код';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleReset() async {
    setState(() => _isLoading = true);
    
    final client = OpenRouterClient();
    await client.resetAuth();
    
    setState(() {
      _hasAuth = false;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_hasAuth ? 'Вход' : 'Авторизация'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_hasAuth) ...[
                TextFormField(
                  controller: _pinController,
                  decoration: const InputDecoration(
                    labelText: 'Введите PIN-код',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите PIN-код';
                    }
                    if (value.length != 4) {
                      return 'PIN-код должен состоять из 4 цифр';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _handlePinSubmit,
                  child: const Text('Войти'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _handleReset,
                  child: const Text('Сбросить ключ'),
                ),
              ] else ...[
                TextFormField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Введите ключ API',
                    border: OutlineInputBorder(),
                    helperText: 'Поддерживаются ключи OpenRouter и VSEGPT',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите ключ API';
                    }
                    if (!value.startsWith('sk-or-')) {
                      return 'Неверный формат ключа';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _handleApiKeySubmit,
                  child: const Text('Продолжить'),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _pinController.dispose();
    super.dispose();
  }
}
