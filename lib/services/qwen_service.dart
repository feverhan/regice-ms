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
        {
          'role': 'system',
          'content': '你是一位家庭饮食顾问，只能用简体中文回复，并给出一条不超过 70 个汉字的简短建议。',
        },
        {
          'role': 'user',
          'content': '当前库存：\n${jsonEncode(_snapshot(items))}',
        },
      ],
    );
  }

  Future<String> fetchRecipeSuggestions(
    List<InventoryItem> items,
    SettingsData settings,
    String prompt,
  ) {
    return _requestText(
      settings: settings,
      temperature: 0.7,
      messages: <Map<String, String>>[
        {
          'role': 'system',
          'content': '你是一位家庭烹饪助手，只能用简体中文回复。请基于库存推荐实用菜谱，优先使用临期食材，绝不要建议使用过期食材。',
        },
        {
          'role': 'user',
          'content': '用户要求：${prompt.isEmpty ? '请根据库存推荐菜谱。' : prompt}\n\n当前库存：\n${jsonEncode(_snapshot(items))}',
        },
      ],
    );
  }

  Future<List<InventoryItem>> bulkImport(String rawText, SettingsData settings) async {
    final response = await _requestText(
      settings: settings,
      temperature: 0.2,
      messages: <Map<String, String>>[
        {
          'role': 'system',
          'content': '只返回 JSON。每个条目必须包含 name、quantity、unit、category、expiry、minQuantity、note。',
        },
        {
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
