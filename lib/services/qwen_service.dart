import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/inventory_item.dart';
import '../models/settings_data.dart';

class QwenService {
  const QwenService();

  Future<String> fetchDailyAdvice(List<InventoryItem> items, SettingsData settings) {
    return _requestText(
      settings: settings,
      temperature: 0.5,
      messages: <Map<String, String>>[
        <String, String>{
          'role': 'system',
          'content': '你是一位家庭饮食顾问，只能用简体中文回答，并给出一条不超过 70 个汉字的简短建议。',
        },
        <String, String>{
          'role': 'user',
          'content': '当前库存：\n${jsonEncode(_snapshot(items))}',
        },
      ],
    );
  }

  Future<String> fetchRecipeSuggestions(
    List<InventoryItem> items,
    SettingsData settings,
    String prompt, {
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) {
    return _requestText(
      settings: settings,
      temperature: 0.7,
      messages: _buildRecipeMessages(items, prompt, history: history),
    );
  }

  Stream<String> streamRecipeSuggestions(
    List<InventoryItem> items,
    SettingsData settings,
    String prompt, {
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) {
    return _streamText(
      settings: settings,
      temperature: 0.7,
      messages: _buildRecipeMessages(items, prompt, history: history),
    );
  }

  Future<List<InventoryItem>> bulkImport(String rawText, SettingsData settings) async {
    final response = await _requestText(
      settings: settings,
      temperature: 0.2,
      messages: <Map<String, String>>[
        <String, String>{
          'role': 'system',
          'content': '只返回 JSON。每个条目必须包含 name、quantity、unit、category、expiry、minQuantity、note。',
        },
        <String, String>{
          'role': 'user',
          'content': '请把这段文本解析成库存 JSON：\n$rawText',
        },
      ],
    );

    final cleaned = _extractJson(response);
    final decoded = jsonDecode(cleaned);
    final list = decoded is Map<String, dynamic>
        ? decoded['items'] as List<dynamic>? ?? <dynamic>[]
        : decoded as List<dynamic>;
    return list
        .map((entry) => InventoryItem.fromJson(entry as Map<String, dynamic>).withGeneratedIdentity())
        .toList();
  }

  Future<String> _requestText({
    required SettingsData settings,
    required double temperature,
    required List<Map<String, String>> messages,
  }) async {
    if (settings.apiKey.trim().isEmpty) {
      throw Exception('缺少 API 密钥。');
    }

    String lastError = '请求失败。';
    for (final url in settings.baseUrls) {
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: <String, String>{
            'Authorization': 'Bearer ${settings.apiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'model': settings.model,
            'temperature': temperature,
            'messages': messages,
          }),
        );

        if (response.statusCode >= 400) {
          lastError = '${response.statusCode}: ${response.body}';
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = decoded['choices'] as List<dynamic>? ?? <dynamic>[];
        if (choices.isEmpty) {
          throw Exception('模型未返回内容。');
        }
        final message = choices.first['message'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final content = message['content'];
        if (content is String) {
          return content.trim();
        }
        if (content is List) {
          return content
              .map((entry) => (entry as Map<String, dynamic>)['text']?.toString() ?? '')
              .join()
              .trim();
        }
        throw Exception('模型返回格式无效。');
      } catch (error) {
        lastError = '$error';
      }
    }
    throw Exception(lastError);
  }

  Stream<String> _streamText({
    required SettingsData settings,
    required double temperature,
    required List<Map<String, String>> messages,
  }) {
    if (settings.apiKey.trim().isEmpty) {
      return Stream<String>.error(Exception('缺少 API 密钥。'));
    }

    late final StreamController<String> controller;
    http.Client? activeClient;
    var canceled = false;

    Future<void> run() async {
      var lastError = '请求失败。';

      try {
        for (final url in settings.baseUrls) {
          if (canceled) {
            return;
          }

          final client = http.Client();
          activeClient = client;

          try {
            final request = http.Request('POST', Uri.parse(url))
              ..headers.addAll(<String, String>{
                'Authorization': 'Bearer ${settings.apiKey}',
                'Content-Type': 'application/json',
              })
              ..body = jsonEncode(<String, dynamic>{
                'model': settings.model,
                'temperature': temperature,
                'stream': true,
                'stream_options': <String, bool>{'include_usage': true},
                'messages': messages,
              });

            final response = await client.send(request);
            if (response.statusCode >= 400) {
              lastError = '${response.statusCode}: ${await response.stream.bytesToString()}';
              client.close();
              activeClient = null;
              continue;
            }

            await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
              if (canceled) {
                return;
              }
              if (!line.startsWith('data: ')) {
                continue;
              }

              final raw = line.substring(6).trim();
              if (raw.isEmpty) {
                continue;
              }
              if (raw == '[DONE]') {
                await controller.close();
                return;
              }

              final payload = jsonDecode(raw) as Map<String, dynamic>;
              final choices = payload['choices'] as List<dynamic>? ?? const <dynamic>[];
              final delta = choices.isEmpty
                  ? const <String, dynamic>{}
                  : (choices.first['delta'] as Map<String, dynamic>? ?? const <String, dynamic>{});
              final content = delta['content'];

              if (content is String && content.isNotEmpty) {
                controller.add(content);
                continue;
              }

              if (content is List) {
                final chunk = content
                    .map((entry) => (entry as Map<String, dynamic>)['text']?.toString() ?? '')
                    .join();
                if (chunk.isNotEmpty) {
                  controller.add(chunk);
                }
              }
            }

            await controller.close();
            return;
          } catch (error) {
            lastError = '$error';
          } finally {
            client.close();
            if (identical(activeClient, client)) {
              activeClient = null;
            }
          }
        }

        if (!canceled && !controller.isClosed) {
          controller.addError(Exception(lastError));
        }
      } finally {
        if (!controller.isClosed) {
          await controller.close();
        }
        activeClient?.close();
      }
    }

    controller = StreamController<String>(
      onListen: () {
        unawaited(run());
      },
      onCancel: () {
        canceled = true;
        activeClient?.close();
      },
    );

    return controller.stream;
  }

  List<Map<String, String>> _buildRecipeMessages(
    List<InventoryItem> items,
    String prompt, {
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) {
    final normalizedPrompt = prompt.trim().isEmpty ? '请根据库存推荐一顿实用的家常餐。' : prompt.trim();
    return <Map<String, String>>[
      <String, String>{
        'role': 'system',
        'content':
            '你是一位家庭厨房助手，只能使用简体中文回答。你需要基于当前库存给出实用、可执行的建议，优先消耗临期食材，绝不建议使用过期食材。回答尽量使用清晰的 Markdown 结构，必要时用小标题、列表、加粗和步骤组织内容。',
      },
      <String, String>{
        'role': 'system',
        'content': '当前库存上下文：\n${jsonEncode(_snapshot(items))}',
      },
      ...history,
      <String, String>{
        'role': 'user',
        'content': normalizedPrompt,
      },
    ];
  }

  List<Map<String, dynamic>> _snapshot(List<InventoryItem> items) {
    return items
        .map(
          (item) => <String, dynamic>{
            'name': item.name,
            'quantity': item.quantity,
            'unit': item.unit,
            'category': item.category,
            'expiry': item.expiry.isEmpty ? '未设置' : item.expiry,
            'minQuantity': item.minQuantity,
            'note': item.note,
            'status': item.statusDescription,
          },
        )
        .toList();
  }

  String _extractJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }
    if (_tryParse(text)) {
      return text;
    }
    for (final pair in <List<String>>[
      <String>['[', ']'],
      <String>['{', '}'],
    ]) {
      final start = text.indexOf(pair.first);
      final end = text.lastIndexOf(pair.last);
      if (start >= 0 && end > start) {
        final candidate = text.substring(start, end + 1);
        if (_tryParse(candidate)) {
          return candidate;
        }
      }
    }
    throw Exception('AI 返回内容里没有找到有效 JSON。');
  }

  bool _tryParse(String value) {
    try {
      jsonDecode(value);
      return true;
    } catch (_) {
      return false;
    }
  }
}
