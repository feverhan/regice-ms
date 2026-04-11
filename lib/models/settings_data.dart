class SettingsData {
  SettingsData({
    required this.apiKey,
    required this.model,
    required this.baseUrls,
  });

  final String apiKey;
  final String model;
  final List<String> baseUrls;

  factory SettingsData.defaults() => SettingsData(
        apiKey: '',
        model: 'qwen3.5-plus',
        baseUrls: const <String>[
          'https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions',
          'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
        ],
      );
}
