import 'package:cliply/models/video_clip.dart';
import 'package:cliply/providers/project_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrimSlider extends ConsumerWidget {
  const TrimSlider({super.key, required this.clip});

  final VideoClip clip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalMs = clip.duration.inMilliseconds.toDouble();
    if (totalMs <= 0) return const SizedBox.shrink();

    final startRatio = clip.startTime.inMilliseconds / totalMs;
    final endRatio = clip.endTime.inMilliseconds / totalMs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RangeSlider(
          values: RangeValues(startRatio, endRatio),
          onChanged: (v) {
            final start = Duration(milliseconds: (v.start * totalMs).round());
            final end = Duration(milliseconds: (v.end * totalMs).round());
            if (end > start) {
              ref
                  .read(projectProvider.notifier)
                  .updateTrim(clip.slotIndex, start, end);
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(clip.startTime),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                _fmt(clip.trimmedDuration),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              Text(
                _fmt(clip.endTime),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
