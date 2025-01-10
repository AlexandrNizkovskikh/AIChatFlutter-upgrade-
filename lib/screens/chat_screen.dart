import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';

class ErrorBoundary extends StatelessWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          return child;
        } catch (error, stackTrace) {
          debugPrint('Error in ErrorBoundary: $error');
          debugPrint('Stack trace: $stackTrace');
          return Container(
            padding: const EdgeInsets.all(12),
            color: Colors.red,
            child: Text(
              'Error: $error',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          );
        }
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: message.isUser
                  ? const Color(0xFF1A73E8)
                  : const Color(0xFF424242),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              message.cleanContent,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 13,
                locale: const Locale('ru', 'RU'),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                color: Colors.white54,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message.cleanContent));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Текст скопирован',
                          style: TextStyle(fontSize: 12)),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                tooltip: 'Копировать текст',
              ),
              if (!message.isUser)
                IconButton(
                  icon: const Icon(Icons.code, size: 16),
                  color: Colors.white54,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Оригинальный текст скопирован',
                            style: TextStyle(fontSize: 12)),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  tooltip: 'Копировать оригинал',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatefulWidget {
  final void Function(String) onSubmitted;

  const _MessageInput({required this.onSubmitted});

  @override
  _MessageInputState createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  final _controller = TextEditingController();
  bool _isComposing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    _controller.clear();
    setState(() {
      _isComposing = false;
    });
    widget.onSubmitted(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: (String text) {
                setState(() {
                  _isComposing = text.trim().isNotEmpty;
                });
              },
              onSubmitted: _isComposing ? _handleSubmitted : null,
              decoration: const InputDecoration(
                hintText: 'Введите сообщение...',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, size: 20),
            color: _isComposing ? Colors.blue : Colors.grey,
            onPressed:
                _isComposing ? () => _handleSubmitted(_controller.text) : null,
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  double _calculateCost(String modelId, int tokens) {
    final Map<String, double> modelCosts = {
      'deepseek/deepseek-chat': 0.0014,
      'anthropic/claude-3-sonnet': 0.015,
      'gpt-3.5-turbo': 0.002,
      'gpt-4': 0.06,
      'mistral-7b': 0.0001,
      'mixtral-8x7b': 0.0002,
      'llama-2': 0.0001,
    };

    double costPer1000Tokens = 0.001;

    if (modelCosts.containsKey(modelId)) {
      costPer1000Tokens = modelCosts[modelId]!;
    } else {
      for (var entry in modelCosts.entries) {
        if (modelId.toLowerCase().contains(entry.key.toLowerCase())) {
          costPer1000Tokens = entry.value;
          break;
        }
      }
    }

    return (tokens / 1000) * costPer1000Tokens;
  }

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: _buildAppBar(context),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _buildMessagesList(),
              ),
              _buildInputArea(context),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF262626),
      toolbarHeight: 48,
      title: Row(
        children: [
          _buildModelSelector(context),
          const Spacer(),
          _buildBalanceDisplay(context),
          _buildMenuButton(context),
        ],
      ),
    );
  }

  Widget _buildModelSelector(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return SizedBox(
          width: MediaQuery.of(context).size.width * 0.4,
          child: DropdownButton<String>(
            value: chatProvider.currentModel,
            hint: const Text(
              'Выберите модель',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            dropdownColor: const Color(0xFF333333),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            isExpanded: true,
            underline: Container(
              height: 1,
              color: Colors.blue,
            ),
            onChanged: (String? newValue) {
              if (newValue != null) {
                chatProvider.setCurrentModel(newValue);
              }
            },
            items: chatProvider.availableModels
                .map<DropdownMenuItem<String>>((Map<String, String> model) {
              return DropdownMenuItem<String>(
                value: model['id'],
                child: Text(
                  model['name'] ?? '',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildBalanceDisplay(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            'Баланс: ${chatProvider.balance}',
            style: const TextStyle(
              color: Color(0xFF33CC33),
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
      color: const Color(0xFF333333),
      onSelected: (String choice) async {
        final chatProvider = context.read<ChatProvider>();
        switch (choice) {
          case 'export':
            final path = await chatProvider.exportMessagesAsJson();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('История сохранена в: $path',
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.green,
                ),
              );
            }
            break;
          case 'logs':
            final path = await chatProvider.exportLogs();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Логи сохранены в: $path',
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.green,
                ),
              );
            }
            break;
          case 'clear':
            _showClearHistoryDialog(context);
            break;
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'export',
          height: 40,
          child: Text('Экспорт истории',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'logs',
          height: 40,
          child: Text('Скачать логи',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'clear',
          height: 40,
          child: Text('Очистить историю',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          reverse: false,
          itemCount: chatProvider.messages.length,
          itemBuilder: (context, index) {
            final message = chatProvider.messages[index];
            return _MessageBubble(message: message);
          },
        );
      },
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      color: const Color(0xFF262626),
      child: Row(
        children: [
          Expanded(
            child: _MessageInput(
              onSubmitted: (String text) {
                if (text.trim().isNotEmpty) {
                  context.read<ChatProvider>().sendMessage(text);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      color: const Color(0xFF262626),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            context: context,
            icon: Icons.save,
            label: 'Сохранить',
            color: const Color(0xFF1A73E8),
            onPressed: () async {
              final path =
                  await context.read<ChatProvider>().exportMessagesAsJson();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('История сохранена в: $path',
                        style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
          _buildActionButton(
            context: context,
            icon: Icons.analytics,
            label: 'Аналитика',
            color: const Color(0xFF33CC33),
            onPressed: () => _showAnalyticsDialog(context),
          ),
          _buildActionButton(
            context: context,
            icon: Icons.delete,
            label: 'Очистить',
            color: const Color(0xFFCC3333),
            onPressed: () => _showClearHistoryDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
        ),
      ),
    );
  }

  void _showAnalyticsDialog(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Статистика',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Всего сообщений: ${chatProvider.messages.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  'Баланс: ${chatProvider.balance}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Использование по моделям:',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...chatProvider.messages
                    .fold<Map<String, Map<String, dynamic>>>(
                      {},
                      (map, msg) {
                        if (msg.modelId != null) {
                          if (!map.containsKey(msg.modelId)) {
                            map[msg.modelId!] = {
                              'count': 0,
                              'tokens': 0,
                            };
                          }
                          map[msg.modelId]!['count'] =
                              map[msg.modelId]!['count']! + 1;
                          if (msg.tokens != null) {
                            map[msg.modelId]!['tokens'] =
                                map[msg.modelId]!['tokens']! + msg.tokens!;
                          }
                        }
                        return map;
                      },
                    )
                    .entries
                    .map((entry) => Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Сообщений: ${entry.value['count']}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              if (entry.value['tokens'] > 0) ...[
                                Text(
                                  'Токенов: ${entry.value['tokens']}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                                Text(
                                  'Примерная стоимость: \$${_calculateCost(entry.key, entry.value['tokens'] as int).toStringAsFixed(4)}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть', style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: const Text(
            'Очистить историю',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          content: const Text(
            'Вы уверены? Это действие нельзя отменить.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена', style: TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: () {
                context.read<ChatProvider>().clearHistory();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Очистить',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}
