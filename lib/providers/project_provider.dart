import 'package:cliply/models/aspect_ratio_type.dart';
import 'package:cliply/models/edit_mode.dart';
import 'package:cliply/models/video_clip.dart';
import 'package:cliply/models/video_project.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProjectNotifier extends Notifier<VideoProject?> {
  @override
  VideoProject? build() => null;

  void initProject(EditMode mode) {
    state = VideoProject.create(editMode: mode);
  }

  void addClip(VideoClip clip) {
    final project = state;
    if (project == null) return;
    state = project.copyWith(clips: [...project.clips, clip]);
  }

  void updateClip(VideoClip updated) {
    final project = state;
    if (project == null) return;
    final clips = project.clips
        .map((c) => c.slotIndex == updated.slotIndex ? updated : c)
        .toList();
    state = project.copyWith(clips: clips);
  }

  void removeClip(int slotIndex) {
    final project = state;
    if (project == null) return;
    final clips =
        project.clips.where((c) => c.slotIndex != slotIndex).toList();
    state = project.copyWith(clips: clips);
  }

  void updateTrim(int slotIndex, Duration start, Duration end) {
    final project = state;
    if (project == null) return;
    final clips = project.clips.map((c) {
      if (c.slotIndex != slotIndex) return c;
      return c.copyWith(startTime: start, endTime: end);
    }).toList();
    state = project.copyWith(clips: clips);
  }

  /// merge 모드에서 클립 순서 변경 후 slotIndex 재정렬
  void reorderClips(int oldIndex, int newIndex) {
    final project = state;
    if (project == null) return;
    final clips = [...project.clips];
    final item = clips.removeAt(oldIndex);
    clips.insert(newIndex, item);
    final reindexed = [
      for (var i = 0; i < clips.length; i++) clips[i].copyWith(slotIndex: i),
    ];
    state = project.copyWith(clips: reindexed);
  }

  void setAspectRatio(AspectRatioType ratio) {
    final project = state;
    if (project == null) return;
    state = project.copyWith(aspectRatio: ratio);
  }

  void setOutputPath(String path) {
    final project = state;
    if (project == null) return;
    state = project.copyWith(outputPath: path);
  }

  void reset() => state = null;
}

final projectProvider =
    NotifierProvider<ProjectNotifier, VideoProject?>(ProjectNotifier.new);
