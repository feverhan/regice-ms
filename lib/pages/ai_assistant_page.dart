import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/inventory_item.dart';
import '../models/settings_data.dart';
import '../services/qwen_service.dart';

enum _AiMessageRole { user, assistant }

class _AiMessage {
  const _AiMessage({
    required this.role,
    required this.text,
    this.includeInContext = true,
    this.isStreaming = false,
    this.isError = false,
  });

  final _AiMessageRole role;
  final String text;
  final bool includeInContext;
  final bool isStreaming;
  final bool isError;

  _AiMessage copyWith({
    String? text,
    bool? includeInContext,
    bool? isStreaming,
    bool? isError,
  }) {
    return _AiMessage(
      role: role,
      text: text ?? this.text,
      includeInContext: includeInContext ?? this.includeInContext,
      isStreaming: isStreaming ?? this.isStreaming,
      isError: isError ?? this.isError,
    );
  }
}

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({
    super.key,
    required this.items,
    required this.settings,
    required this.qwenService,
  });

  final List<InventoryItem> items;
  final SettingsData settings;
  final QwenService qwenService;

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _streamSubscription;

  late List<_AiMessage> _messages;
  bool _sending = false;

  static const List<String> _promptPresets = <String>[
    '按现有食材安排一顿两人晚餐。',
    '优先用掉 3 天内到期的食材，给我两套做法。',
    '想吃低脂高蛋白，按库存给我一份菜单。',
  ];

  @override
  void initState() {
    super.initState();
    _messages = <_AiMessage>[
      const _AiMessage(
        role: _AiMessageRole.assistant,
        text: '我已经看过当前库存。直接告诉我人数、口味、忌口或可用时间，我会按现有食材帮你安排今天吃什么。',
        includeInContext: false,
      ),
    ];
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int get _expiringSoonCount => widget.items.where((item) => item.isExpiringSoon && !item.isExpired).length;

  int get _lowStockCount => widget.items.where((item) => item.isLowStock).length;

  List<String> get _priorityIngredients {
    final expiring = widget.items.where((item) => item.isExpiringSoon && !item.isExpired).take(4);
    final fallback = widget.items.take(4);
    final source = expiring.isNotEmpty ? expiring : fallback;
    return source.map((item) => item.name).where((name) => name.trim().isNotEmpty).toList();
  }

  Future<void> _sendPrompt([String? preset]) async {
    if (_sending) {
      return;
    }

    final prompt = (preset ?? _controller.text).trim();
    if (prompt.isEmpty) {
      _showSnack('先告诉我你的需求，我再开始帮你安排。');
      return;
    }

    final history = _buildConversationHistory();
    _controller.clear();
    setState(() {
      _sending = true;
      _messages = <_AiMessage>[
        ..._messages,
        _AiMessage(role: _AiMessageRole.user, text: prompt),
        const _AiMessage(role: _AiMessageRole.assistant, text: '', isStreaming: true),
      ];
    });
    _jumpToBottom();

    _streamSubscription = widget.qwenService
        .streamRecipeSuggestions(
          widget.items,
          widget.settings,
          prompt,
          history: history,
        )
        .listen(
          (chunk) {
            if (!mounted) {
              return;
            }
            setState(() {
              final lastIndex = _messages.length - 1;
              final last = _messages[lastIndex];
              _messages[lastIndex] = last.copyWith(
                text: '${last.text}$chunk',
                isStreaming: true,
              );
            });
            _jumpToBottom();
          },
          onError: (Object error) {
            if (!mounted) {
              return;
            }
            setState(() {
              final lastIndex = _messages.length - 1;
              final last = _messages[lastIndex];
              _messages[lastIndex] = last.copyWith(
                text: last.text.trim().isEmpty ? '这次没顺利完成：$error' : last.text,
                isStreaming: false,
                isError: true,
              );
              _sending = false;
            });
            _streamSubscription = null;
            _showSnack('这次回答被打断了，可以再试一次。');
          },
          onDone: () {
            if (!mounted) {
              return;
            }
            setState(() {
              final lastIndex = _messages.length - 1;
              final last = _messages[lastIndex];
              _messages[lastIndex] = last.copyWith(
                text: last.text.trim().isEmpty ? '这次没整理出可用内容，换个说法再试试。' : last.text,
                isStreaming: false,
              );
              _sending = false;
            });
            _streamSubscription = null;
            _jumpToBottom(animated: false);
          },
          cancelOnError: false,
        );
  }

  List<Map<String, String>> _buildConversationHistory() {
    final turns = _messages
        .where((message) => message.includeInContext && message.text.trim().isNotEmpty)
        .map(
          (message) => <String, String>{
            'role': message.role == _AiMessageRole.user ? 'user' : 'assistant',
            'content': message.text,
          },
        )
        .toList();

    if (turns.length <= 10) {
      return turns;
    }
    return turns.sublist(turns.length - 10);
  }

  Future<void> _stopStreaming() async {
    if (!_sending) {
      return;
    }

    await _streamSubscription?.cancel();
    _streamSubscription = null;

    if (!mounted) {
      return;
    }

    setState(() {
      final lastIndex = _messages.length - 1;
      final last = _messages[lastIndex];
      _messages[lastIndex] = last.copyWith(
        text: last.text.trim().isEmpty ? '这次回答已暂停。' : '${last.text}\n\n_本次回答已暂停_',
        isStreaming: false,
      );
      _sending = false;
    });
  }

  Future<void> _resetConversation() async {
    if (_sending) {
      await _stopStreaming();
      if (!mounted) {
        return;
      }
    }
    setState(() {
      _messages = <_AiMessage>[
        const _AiMessage(
          role: _AiMessageRole.assistant,
          text: '已开始新对话。告诉我人数、口味、忌口，或者想优先处理哪些食材，我就继续帮你安排。',
          includeInContext: false,
        ),
      ];
    });
  }

  void _jumpToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent + 72;
      if (!animated) {
        _scrollController.jumpTo(target);
        return;
      }
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priorityIngredients = _priorityIngredients;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EA),
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI 厨房助手', style: theme.textTheme.titleLarge),
            Text(
              '按现有食材安排一日三餐',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '重新开始',
            onPressed: _resetConversation,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFEEE2CF), Color(0xFFE3D4BC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2F4C3F),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '告诉我这顿饭想怎么吃，我会结合现有食材帮你安排菜单、做法和备菜顺序。',
                            style: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFF22352C)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ContextChip(label: '现有食材 ${widget.items.length} 项'),
                        _ContextChip(label: '快到期 $_expiringSoonCount 项'),
                        _ContextChip(label: '补货提醒 $_lowStockCount 项'),
                        if (priorityIngredients.isNotEmpty)
                          _ContextChip(label: '优先处理 ${priorityIngredients.join('、')}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: _messages.length + 1,
                itemBuilder: (BuildContext context, int index) {
                  if (index == 0) {
                    return AnimatedOpacity(
                      opacity: _messages.length <= 2 ? 1 : 0.82,
                      duration: const Duration(milliseconds: 220),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _promptPresets
                              .map(
                                (prompt) => ActionChip(
                                  label: Text(prompt),
                                  onPressed: _sending ? null : () => _sendPrompt(prompt),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    );
                  }

                  final message = _messages[index - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _MessageBubble(
                      message: message,
                      markdownStyleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: theme.textTheme.bodyMedium?.copyWith(height: 1.7, color: const Color(0xFF1F3128)),
                        h1: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        code: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: const Color(0xFF234337),
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFFF7F2E7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        listBullet: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF1F3128)),
                        blockquoteDecoration: BoxDecoration(
                          color: const Color(0xFFF7F2E7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE1D6C3)),
                        ),
                      ),
                      onCopy: message.role == _AiMessageRole.assistant && message.text.trim().isNotEmpty
                          ? () async {
                              await Clipboard.setData(ClipboardData(text: message.text));
                              if (!mounted) {
                                return;
                              }
                              _showSnack('回答已复制。');
                            }
                          : null,
                    ),
                  );
                },
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFFFFFCF7),
                border: Border(top: BorderSide(color: Color(0xFFE4DAC9))),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _controller,
                        minLines: 2,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: '例如：晚饭两个人吃，30 分钟内完成，优先用掉鸡蛋和番茄。',
                          suffixIcon: _sending
                              ? IconButton(
                                  tooltip: '暂停回答',
                                  onPressed: _stopStreaming,
                                  icon: const Icon(Icons.stop_circle_outlined),
                                )
                              : IconButton(
                                  tooltip: '发送问题',
                                  onPressed: () => _sendPrompt(),
                                  icon: const Icon(Icons.arrow_upward_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _sending ? '正在整理这顿饭的方案…' : '支持连续追问，我会接着上文继续帮你安排。',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          if (_sending)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF274035),
            ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.markdownStyleSheet,
    this.onCopy,
  });

  final _AiMessage message;
  final MarkdownStyleSheet markdownStyleSheet;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _AiMessageRole.user;
    final bubbleColor = isUser
        ? const Color(0xFF2F4C3F)
        : message.isError
            ? const Color(0xFFF7E5E2)
            : const Color(0xFFFFFCF7);
    final borderColor = isUser
        ? const Color(0xFF2F4C3F)
        : message.isStreaming
            ? const Color(0xFF6B8D78)
            : message.isError
                ? const Color(0xFFE3B3AD)
                : const Color(0xFFE4DAC9);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(isUser ? 22 : 8),
              bottomRight: Radius.circular(isUser ? 8 : 22),
            ),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUser ? '你' : '厨房助手',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isUser ? Colors.white70 : const Color(0xFF6A7268),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              if (isUser)
                SelectableText(
                  message.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.65,
                        color: Colors.white,
                      ),
                )
              else
                MarkdownBody(
                  data: message.text.isEmpty ? '正在整理思路…' : message.text,
                  selectable: true,
                  styleSheet: markdownStyleSheet,
                ),
              if (!isUser)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isStreaming) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '正在整理中',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ] else if (onCopy != null) ...[
                        TextButton.icon(
                          onPressed: onCopy,
                          icon: const Icon(Icons.content_copy_rounded, size: 16),
                          label: const Text('复制回答'),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
