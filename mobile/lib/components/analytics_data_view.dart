import 'package:flutter/material.dart';

class AnalyticsDataCard extends StatelessWidget {
  final String title;
  final dynamic data;

  const AnalyticsDataCard({
    super.key,
    required this.title,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data is! Map && data is! List) {
      return Card(
        child: ListTile(
          title: Text(title),
          subtitle: Text(AnalyticsDataView.formatValue(data)),
        ),
      );
    }

    return Card(
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [AnalyticsDataView(data: data)],
      ),
    );
  }
}

class AnalyticsDataView extends StatelessWidget {
  final dynamic data;

  const AnalyticsDataView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data is Map) {
      final entries = (data as Map).entries.toList();
      if (entries.isEmpty) return const Text('No data available.');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in entries)
            _field(context, '${entry.key}', entry.value),
        ],
      );
    }

    if (data is List) {
      final items = data as List;
      if (items.isEmpty) return const Text('No records available.');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < items.length; index++)
            _item(context, items[index], index),
        ],
      );
    }

    return Text(formatValue(data));
  }

  Widget _field(BuildContext context, String key, dynamic value) {
    final label = formatLabel(key);
    if (value is Map || value is List) {
      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 12),
        title: Text(label),
        children: [AnalyticsDataView(data: value)],
      );
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(formatValue(value)),
    );
  }

  Widget _item(BuildContext context, dynamic value, int index) {
    if (value is! Map) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(formatValue(value)),
      );
    }

    final fields = <String, dynamic>{
      for (final entry in value.entries) '${entry.key}': entry.value,
    };
    if (fields.length == 2 &&
        fields.containsKey('name') &&
        fields.containsKey('value')) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(formatValue(fields['name'])),
        trailing: Text(formatValue(fields['value'])),
      );
    }

    if (fields.containsKey('text')) {
      final level = fields['level'];
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(_recommendationIcon('$level')),
        title: Text(formatValue(fields['text'])),
        subtitle:
            level == null ? null : Text('Priority: ${formatValue(level)}'),
      );
    }

    final title = _firstValue(fields, const [
      'student',
      'name',
      'title',
      'week',
      'date',
      'booking_id',
      'application_id',
      'task_id',
    ]);
    final subtitle = _firstValue(fields, const [
      'risk',
      'status',
      'trend',
      'level',
    ]);

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 12),
      title: Text(title ?? 'Record ${index + 1}'),
      subtitle: subtitle == null ? null : Text(subtitle),
      children: [AnalyticsDataView(data: fields)],
    );
  }

  static String formatLabel(String value) => value
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map(_capitalize)
      .join(' ');

  static String formatValue(dynamic value) {
    if (value == null || value == '') return '–';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is Map) {
      if (value.isEmpty) return 'No data';
      return value.entries
          .map((entry) =>
              '${formatLabel('${entry.key}')}: ${formatValue(entry.value)}')
          .join(' · ');
    }
    if (value is List) {
      if (value.isEmpty) return 'No records';
      return value.map(formatValue).join(' · ');
    }
    if (value is String) {
      final normalized = value.trim().replaceAll('_', ' ');
      if (normalized.isEmpty) return '–';
      return _capitalize(normalized);
    }
    return '$value';
  }

  static String? _firstValue(Map<String, dynamic> fields, List<String> keys) {
    for (final key in keys) {
      final value = fields[key];
      if (value != null && '$value'.isNotEmpty) return formatValue(value);
    }
    return null;
  }

  static IconData _recommendationIcon(String level) {
    switch (level.toLowerCase()) {
      case 'warn':
        return Icons.warning_amber_outlined;
      case 'ok':
        return Icons.check_circle_outline;
      default:
        return Icons.lightbulb_outline;
    }
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
