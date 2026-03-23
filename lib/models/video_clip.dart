import 'package:flutter/foundation.dart';

@immutable
class VideoClip {
  const VideoClip({
    required this.id,
    required this.filePath,
    required this.duration,
    required this.startTime,
    required this.endTime,
    required this.slotIndex,
    required this.hasAudio,
    this.thumbnailPath,
  })  : assert(endTime > startTime, 'endTime must be greater than startTime'),
        assert(slotIndex >= 0, 'slotIndex must be >= 0');

  final String id;
  final String filePath;
  final Duration duration;
  final Duration startTime;
  final Duration endTime;
  final int slotIndex;

  /// 오디오 스트림 유무 (영상 선택 시 FFprobe로 1회 감지 후 캐시)
  final bool hasAudio;

  final String? thumbnailPath;

  Duration get trimmedDuration => endTime - startTime;

  VideoClip copyWith({
    String? id,
    String? filePath,
    Duration? duration,
    Duration? startTime,
    Duration? endTime,
    int? slotIndex,
    bool? hasAudio,
    String? thumbnailPath,
  }) {
    return VideoClip(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      slotIndex: slotIndex ?? this.slotIndex,
      hasAudio: hasAudio ?? this.hasAudio,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}
