import 'package:cliply/models/export_quality.dart';
import 'package:cliply/providers/project_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExportQualitySelector extends ConsumerWidget {
  const ExportQualitySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quality =
        ref.watch(projectProvider.select((p) => p?.quality ?? ExportQuality.medium));

    return Row(
      children: [
        Text(
          '품질',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SegmentedButton<ExportQuality>(
            segments: ExportQuality.values
                .map((q) => ButtonSegment(value: q, label: Text(q.label)))
                .toList(),
            selected: {quality},
            onSelectionChanged: (set) =>
                ref.read(projectProvider.notifier).setQuality(set.first),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}
