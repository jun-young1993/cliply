import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';

class FfmpegService {
  /// FFmpeg을 인수 리스트로 실행하고 성공 여부를 반환한다.
  /// 통계 콜백은 per-session으로 등록하여 글로벌 오염 없음.
  Future<bool> executeWithArgs(
    List<String> args, {
    void Function(double progress)? onProgress,
    Duration? totalDuration,
  }) async {
    final completer = Completer<bool>();

    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        // completeCallback — 실행 완료 시 호출
        final rc = await session.getReturnCode();
        if (!completer.isCompleted) {
          completer.complete(ReturnCode.isSuccess(rc));
        }
      },
      null, // logCallback
      (onProgress != null && totalDuration != null)
          ? (Statistics stats) {
              final progress =
                  stats.getTime() / totalDuration.inMilliseconds.toDouble();
              onProgress(progress.clamp(0.0, 1.0));
            }
          : null,
    );

    return completer.future;
  }

  /// FFprobe로 영상 메타데이터(duration + hasAudio)를 한 번에 가져온다.
  /// 영상 선택 시 호출 → VideoClip에 캐시 → export 시 재사용
  Future<({Duration duration, bool hasAudio})> getVideoInfo(
    String filePath,
  ) async {
    final session = await FFprobeKit.getMediaInformation(filePath);
    final info = session.getMediaInformation();
    final durationMs =
        ((double.tryParse(info?.getDuration() ?? '0') ?? 0) * 1000).round();
    final hasAudio =
        info?.getStreams().any((s) => s.getType() == 'audio') ?? false;
    return (duration: Duration(milliseconds: durationMs), hasAudio: hasAudio);
  }

  /// 실행 중인 모든 FFmpeg 세션을 취소한다.
  Future<void> cancel() async {
    await FFmpegKit.cancel();
  }
}
