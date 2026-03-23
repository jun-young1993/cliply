import 'dart:io';

import 'package:cliply/models/aspect_ratio_type.dart';
import 'package:cliply/models/edit_mode.dart';
import 'package:cliply/models/video_project.dart';
import 'package:cliply/services/ffmpeg_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VideoExportService {
  VideoExportService(this._ffmpeg);

  final FfmpegService _ffmpeg;

  /// 프로젝트 모드에 따라 영상을 내보내고 출력 경로를 반환한다. 실패 시 null.
  Future<String?> export(
    VideoProject project, {
    void Function(double progress)? onProgress,
  }) async {
    if (project.clips.isEmpty) return null;
    if (project.editMode == EditMode.merge) {
      return _exportMerge(project, onProgress: onProgress);
    }
    return _exportSplit(project, onProgress: onProgress);
  }

  // ──────────────────────────────────────────
  // 분할 편집 (가로: vstack / 세로: hstack)
  // ──────────────────────────────────────────
  Future<String?> _exportSplit(
    VideoProject project, {
    void Function(double progress)? onProgress,
  }) async {
    final outputPath = await _generateOutputPath();
    final (outW, outH) = project.aspectRatio.outputSize;
    final clips = [...project.clips]
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    final count = clips.length;

    final isHorizontal = project.editMode == EditMode.horizontalSplit;
    final slotW = isHorizontal ? outW : outW ~/ count;
    final slotH = isHorizontal ? outH ~/ count : outH;

    final trimParts = <String>[];
    for (var i = 0; i < count; i++) {
      final clip = clips[i];
      final start = _sec(clip.startTime);
      final end = _sec(clip.endTime);
      trimParts.add(
        '[$i:v]trim=start=$start:end=$end,setpts=PTS-STARTPTS,'
        'scale=$slotW:$slotH,setsar=1[v$i]',
      );
    }

    final stackIn = List.generate(count, (i) => '[v$i]').join('');
    final stackFilter = isHorizontal
        ? '${stackIn}vstack=inputs=$count[out]'
        : '${stackIn}hstack=inputs=$count[out]';

    final filterComplex = '${trimParts.join(';')};$stackFilter';

    final totalMs = clips
        .map((c) => c.trimmedDuration.inMilliseconds)
        .reduce((a, b) => a < b ? a : b);

    // 파일 경로를 별도 인수로 전달 (쉘 인젝션 방지)
    final args = <String>[];
    for (final clip in clips) {
      args.addAll(['-i', clip.filePath]);
    }
    args.addAll(['-filter_complex', filterComplex]);
    args.addAll(['-map', '[out]', '-map', '0:a?']);
    args.addAll(['-c:v', 'libx264', '-preset', 'fast', '-crf', '23']);
    args.addAll(['-c:a', 'aac', '-shortest']);
    args.add(outputPath);

    final ok = await _ffmpeg.executeWithArgs(
      args,
      onProgress: onProgress,
      totalDuration: Duration(milliseconds: totalMs),
    );

    if (!ok) {
      _tryDeleteFile(outputPath);
      return null;
    }
    return outputPath;
  }

  // ──────────────────────────────────────────
  // 이어붙이기 (concat)
  // ──────────────────────────────────────────
  Future<String?> _exportMerge(
    VideoProject project, {
    void Function(double progress)? onProgress,
  }) async {
    if (project.clips.length < 2) return null;

    final outputPath = await _generateOutputPath();
    final (outW, outH) = project.aspectRatio.outputSize;
    final clips = project.clips;
    final count = clips.length;

    final trimParts = <String>[];
    for (var i = 0; i < count; i++) {
      final clip = clips[i];
      final start = _sec(clip.startTime);
      final end = _sec(clip.endTime);
      final durationSec = clip.trimmedDuration.inMilliseconds / 1000.0;

      trimParts.add(
        '[$i:v]trim=start=$start:end=$end,setpts=PTS-STARTPTS,'
        'scale=$outW:$outH,setsar=1[v$i]',
      );

      // hasAudio는 영상 선택 시 이미 감지됨 (캐시) — 여기서 FFprobe 재호출 없음
      if (clip.hasAudio) {
        trimParts.add(
          '[$i:a]atrim=start=$start:end=$end,asetpts=PTS-STARTPTS[a$i]',
        );
      } else {
        // 오디오 없는 클립은 무음 신호로 대체
        trimParts.add(
          'anullsrc=r=44100:cl=stereo,'
          'atrim=duration=${durationSec.toStringAsFixed(3)}[a$i]',
        );
      }
    }

    final concatIn = List.generate(count, (i) => '[v$i][a$i]').join('');
    final concatFilter = '${concatIn}concat=n=$count:v=1:a=1[vout][aout]';
    final filterComplex = '${trimParts.join(';')};$concatFilter';

    final totalMs = clips.fold(
      0,
      (sum, c) => sum + c.trimmedDuration.inMilliseconds,
    );

    final args = <String>[];
    for (final clip in clips) {
      args.addAll(['-i', clip.filePath]);
    }
    args.addAll(['-filter_complex', filterComplex]);
    args.addAll(['-map', '[vout]', '-map', '[aout]']);
    args.addAll(['-c:v', 'libx264', '-preset', 'fast', '-crf', '23']);
    args.addAll(['-c:a', 'aac']);
    args.add(outputPath);

    final ok = await _ffmpeg.executeWithArgs(
      args,
      onProgress: onProgress,
      totalDuration: Duration(milliseconds: totalMs),
    );

    if (!ok) {
      _tryDeleteFile(outputPath);
      return null;
    }
    return outputPath;
  }

  // ──────────────────────────────────────────
  // 유틸
  // ──────────────────────────────────────────
  String _sec(Duration d) => (d.inMilliseconds / 1000.0).toStringAsFixed(3);

  Future<String> _generateOutputPath() async {
    final dir = await getTemporaryDirectory();
    return p.join(
      dir.path,
      'cliply_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
  }

  void _tryDeleteFile(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }
}
