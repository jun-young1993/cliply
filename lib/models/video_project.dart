import 'package:cliply/models/aspect_ratio_type.dart';
import 'package:cliply/models/edit_mode.dart';
import 'package:cliply/models/export_quality.dart';
import 'package:cliply/models/split_layout.dart';
import 'package:cliply/models/video_clip.dart';
import 'package:flutter/foundation.dart';

@immutable
class VideoProject {
  const VideoProject({
    required this.id,
    required this.editMode,
    required this.aspectRatio,
    required this.splitLayout,
    required this.clips,
    required this.createdAt,
    this.outputPath,
    this.quality = ExportQuality.medium,
  });

  factory VideoProject.create({
    required EditMode editMode,
    AspectRatioType aspectRatio = AspectRatioType.ratio9x16,
    SplitLayout splitLayout = SplitLayout.two,
  }) {
    return VideoProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      editMode: editMode,
      aspectRatio: aspectRatio,
      splitLayout: splitLayout,
      clips: const [],
      createdAt: DateTime.now(),
    );
  }

  final String id;
  final EditMode editMode;
  final AspectRatioType aspectRatio;
  final SplitLayout splitLayout;
  final List<VideoClip> clips;
  final DateTime createdAt;
  final String? outputPath;
  final ExportQuality quality;

  bool get canExport {
    if (editMode == EditMode.merge) return clips.length >= 2;
    return clips.isNotEmpty;
  }

  int get maxSlots {
    if (editMode == EditMode.merge) return 10;
    return splitLayout == SplitLayout.two ? 2 : 3;
  }

  VideoProject copyWith({
    String? id,
    EditMode? editMode,
    AspectRatioType? aspectRatio,
    SplitLayout? splitLayout,
    List<VideoClip>? clips,
    DateTime? createdAt,
    String? outputPath,
    ExportQuality? quality,
  }) {
    return VideoProject(
      id: id ?? this.id,
      editMode: editMode ?? this.editMode,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      splitLayout: splitLayout ?? this.splitLayout,
      clips: clips ?? this.clips,
      createdAt: createdAt ?? this.createdAt,
      outputPath: outputPath ?? this.outputPath,
      quality: quality ?? this.quality,
    );
  }
}
