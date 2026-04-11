import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../models/settings_data.dart';

class ItemEditorDialog extends StatefulWidget {
  const ItemEditorDialog({super.key, this.item});

  final InventoryItem? item;

  @override
  State<ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<ItemEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;
  late final TextEditingController _categoryController;
  late final TextEditingController _expiryController;
  late final TextEditingController _minQuantityController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _quantityController = TextEditingController(text: item == null ? '1' : InventoryItem.formatNumber(item.quantity));
    _unitController = TextEditingController(text: item?.unit ?? '件');
    _categoryController = TextEditingController(text: item?.category ?? '其他');
    _expiryController = TextEditingController(text: item?.expiry ?? '');
    _minQuantityController = TextEditingController(text: item == null ? '0' : InventoryItem.formatNumber(item.minQuantity));
    _noteController = TextEditingController(text: item?.note ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
    _expiryController.dispose();
    _minQuantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? '添加食材' : '编辑食材'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _input(_nameController, '食材名称'),
            const SizedBox(height: 8),
            _input(_quantityController, '当前数量', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 8),
            _input(_unitController, '单位'),
            const SizedBox(height: 8),
            _input(_categoryController, '分类'),
            const SizedBox(height: 8),
            _input(_expiryController, '到期日（YYYY-MM-DD）'),
            const SizedBox(height: 8),
            _input(
              _minQuantityController,
              '低库存提醒',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            _input(_noteController, '备注（选填）', maxLines: 3),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            try {
              final item = InventoryItem.fromForm(
                base: widget.item,
                name: _nameController.text,
                quantityText: _quantityController.text,
                unit: _unitController.text,
                category: _categoryController.text,
                expiry: _expiryController.text,
                minQuantityText: _minQuantityController.text,
                note: _noteController.text,
              );
              Navigator.pop(context, item);
            } catch (error) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.settings});

  final SettingsData settings;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _baseUrlsController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.settings.apiKey);
    _modelController = TextEditingController(text: widget.settings.model);
    _baseUrlsController = TextEditingController(text: widget.settings.baseUrls.join('\n'));
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _baseUrlsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI 助手设置'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(labelText: 'API Key', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(labelText: '模型', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _baseUrlsController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '接口地址',
                hintText: '支持填写多个地址，每行一个',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              SettingsData(
                apiKey: _apiKeyController.text.trim(),
                model: _modelController.text.trim().isEmpty ? 'qwen3.5-plus' : _modelController.text.trim(),
                baseUrls: _baseUrlsController.text
                    .split('\n')
                    .map((entry) => entry.trim())
                    .where((entry) => entry.isNotEmpty)
                    .toList(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class TextInputDialog extends StatefulWidget {
  const TextInputDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.confirmText,
  });

  final String title;
  final String hint;
  final String confirmText;

  @override
  State<TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<TextInputDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        minLines: 4,
        maxLines: 8,
        decoration: InputDecoration(hintText: widget.hint, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}

class OutputDialog extends StatelessWidget {
  const OutputDialog({super.key, required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: SelectableText(content)),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
      ],
    );
  }
}
