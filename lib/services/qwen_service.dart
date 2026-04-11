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
          'content':
              'You are a home food advisor. Reply in Simplified Chinese only. Give exactly one short suggestion under 70 Chinese characters.',
        },
        {
          'role': 'user',
          'content': 'Inventory:\n${jsonEncode(_snapshot(items))}',
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
          'content':
              'You are a home cooking assistant. Reply in Simplified Chinese only. Recommend practical recipes using the inventory. Prioritize items expiring soon and never suggest expired food.',
        },
        {
          'role': 'user',
          'content':
              'User request: ${prompt.isEmpty ? 'Recommend recipes based on the inventory.' : prompt}\n\nInventory:\n${jsonEncode(_snapshot(items))}',
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
          'content':
              'Return JSON only. Each item must include name, quantity, unit, category, expiry, minQuantity, note.',
        },
        {
          'role': 'user',
          'content': 'Parse this text into inventory JSON:\n$rawText',
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
      throw Exception('Missing API key.');
    }

    String lastError = 'Request failed.';
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
          throw Exception('Model returned no content.');
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
        throw Exception('Invalid model payload.');
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
            'expiry': item.expiry.isEmpty ? 'not set' : item.expiry,
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
    throw Exception('AI response did not contain valid JSON.');
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
