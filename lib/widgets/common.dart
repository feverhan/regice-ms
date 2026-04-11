import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DropdownField extends StatelessWidget {
  const DropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: items.entries
          .map((entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              ))
          .toList(),
      onChanged: (value) => onChanged(value ?? ''),
    );
  }
}
