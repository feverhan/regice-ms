import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_data.dart';

class SettingsRepository {
  static const String _apiKey = 'api_key';
  static const String _model = 'model';
  static const String _baseUrls = 'base_urls';
  static const String _adviceText = 'advice_text';
  static const String _adviceDate = 'advice_date';

  static Future<SettingsData> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsData(
      apiKey: prefs.getString(_apiKey) ?? '',
      model: prefs.getString(_model) ?? 'qwen3.5-plus',
      baseUrls: prefs.getStringList(_baseUrls) ?? SettingsData.defaults().baseUrls,
    );
  }

  static Future<void> save(SettingsData settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKey, settings.apiKey);
    await prefs.setString(_model, settings.model);
    await prefs.setStringList(_baseUrls, settings.baseUrls);
  }

  static Future<void> saveCachedAdvice(String advice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adviceText, advice);
    await prefs.setString(_adviceDate, DateTime.now().toIso8601String().split('T').first);
  }

  static Future<String?> readCachedAdvice() async {
    final prefs = await SharedPreferences.getInstance();
    final date = prefs.getString(_adviceDate);
    if (date != DateTime.now().toIso8601String().split('T').first) {
      return null;
    }
    return prefs.getString(_adviceText);
  }
}
