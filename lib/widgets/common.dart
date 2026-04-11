import 'package:flutter/material.dart';

class AppLayout {
  static bool isPhone(BuildContext context) => MediaQuery.sizeOf(context).width <= 430;

  static double pagePadding(BuildContext context) => isPhone(context) ? 16 : 20;

  static double sectionGap(BuildContext context) => isPhone(context) ? 12 : 16;

  static double cardPadding(BuildContext context) => isPhone(context) ? 14 : 18;

  static double itemTitleSize(BuildContext context) => isPhone(context) ? 16 : 18;

  static double statValueSize(BuildContext context) => isPhone(context) ? 24 : 28;
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.width,
  });

  final String label;
  final String value;
  final Color color;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(AppLayout.cardPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: AppLayout.statValueSize(context),
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
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
      initialValue: value,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      iconSize: 18,
      style: Theme.of(context).textTheme.bodyMedium,
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
