import 'package:cliply/models/aspect_ratio_type.dart';
import 'package:cliply/providers/project_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AspectRatioSelector extends ConsumerWidget {
  const AspectRatioSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    if (project == null) return const SizedBox.shrink();

    return SegmentedButton<AspectRatioType>(
      segments: AspectRatioType.values
          .map((r) => ButtonSegment(value: r, label: Text(r.label)))
          .toList(),
      selected: {project.aspectRatio},
      onSelectionChanged: (v) =>
          ref.read(projectProvider.notifier).setAspectRatio(v.first),
    );
  }
}
