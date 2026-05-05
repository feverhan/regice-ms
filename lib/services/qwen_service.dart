import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/inventory_item.dart';
import '../models/settings_data.dart';

class QwenService {
  const QwenService();

  Future<String> fetchDailyAdvice(
      List<InventoryItem> items, SettingsData settings) {
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

  Future<List<InventoryItem>> bulkImport(
    String rawText,
    SettingsData settings, {
    List<InventoryItem> currentItems = const <InventoryItem>[],
  }) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final response = await _requestText(
      settings: settings,
      temperature: 0.2,
      messages: <Map<String, String>>[
        <String, String>{
          'role': 'system',
          'content': '''
你是一名家庭冰箱库存录入助手。
你的唯一任务是把用户输入的自然语言、购物清单、票据信息或库存变更描述解析成可直接入库的 JSON 数组。
只输出 JSON，不要输出 Markdown，不要解释，不要补充说明。
每个数组元素都必须是对象，并且严格包含这些字段：name, quantity, unit, category, expiry, minQuantity, note。
quantity 和 minQuantity 必须是数字。
unit 必须是简短中文单位，例如 个、把、袋、盒、瓶、包、克、千克、毫升、升。
category 只能是 蔬菜、水果、肉类、海鲜、乳制品、饮料、调料、主食、速食、其他 之一。
expiry 必须是 YYYY-MM-DD 格式；如果用户没有提供有效日期，就填空字符串。
minQuantity 默认为 0，除非用户明确提到提醒值。
note 用于保留原文中的备注、品牌、位置、用途等信息，没有就填空字符串。
如果一句话里提到多个食材，必须拆成多条记录。
如果信息不足，做最保守的合理推断，但不要编造不存在的品牌、日期或规格。
今天日期是 $today，如果用户说今天、明天、后天，请换算成具体日期。
''',
        },
        <String, String>{
          'role': 'user',
          'content': '''
当前库存如下，供你理解已有名称、单位和分类：
${jsonEncode(_snapshot(currentItems))}

请解析下面这段库存录入文本，并直接返回 JSON 数组：
${rawText.trim()}
''',
        },
      ],
    );

    final cleaned = _extractJson(response);
    final decoded = jsonDecode(cleaned);
    final list = decoded is Map<String, dynamic>
        ? decoded['items'] as List<dynamic>? ?? <dynamic>[]
        : decoded as List<dynamic>;
    final items = list
        .whereType<Map<String, dynamic>>()
        .map((entry) => InventoryItem.fromJson(entry).withGeneratedIdentity())
        .where((item) => item.name.trim().isNotEmpty && item.quantity > 0)
        .toList();
    if (items.isEmpty) {
      throw Exception('没有从这段文本里识别出可导入的食材。');
    }
    return items;
  }

  Future<String> _requestText({
    required SettingsData settings,
    required double temperature,
    required List<Map<String, String>> messages,
  }) async {
    if (settings.apiKey.trim().isEmpty) {
      throw Exception('还没有配置 API 密钥。');
    }

    String lastError = '请求没有成功。';
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
          throw Exception('这次没有拿到可用回复。');
        }
        final message = choices.first['message'] as Map<String, dynamic>? ??
            <String, dynamic>{};
        final content = message['content'];
        if (content is String) {
          return content.trim();
        }
        if (content is List) {
          return content
              .map((entry) =>
                  (entry as Map<String, dynamic>)['text']?.toString() ?? '')
              .join()
              .trim();
        }
        throw Exception('返回内容格式不正确。');
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
      return Stream<String>.error(Exception('还没有配置 API 密钥。'));
    }

    late final StreamController<String> controller;
    http.Client? activeClient;
    var canceled = false;

    Future<void> run() async {
      var lastError = '请求没有成功。';

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
              lastError =
                  '${response.statusCode}: ${await response.stream.bytesToString()}';
              client.close();
              activeClient = null;
              continue;
            }

            await for (final line in response.stream
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
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
              final choices =
                  payload['choices'] as List<dynamic>? ?? const <dynamic>[];
              final delta = choices.isEmpty
                  ? const <String, dynamic>{}
                  : (choices.first['delta'] as Map<String, dynamic>? ??
                      const <String, dynamic>{});
              final content = delta['content'];

              if (content is String && content.isNotEmpty) {
                controller.add(content);
                continue;
              }

              if (content is List) {
                final chunk = content
                    .map((entry) =>
                        (entry as Map<String, dynamic>)['text']?.toString() ??
                        '')
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
    final normalizedPrompt =
        prompt.trim().isEmpty ? '请根据库存推荐一顿实用的家常餐。' : prompt.trim();
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
    throw Exception('没有从 AI 返回内容里解析出有效数据。');
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
