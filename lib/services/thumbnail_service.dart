import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  // 앱 세션 동안 동일 경로 재추출 방지 (클립 재선택·rebuild 시 중복 FFmpeg 호출 제거)
  static final Map<String, String> _cache = {};

  /// [at] 시점의 프레임을 jpg로 추출한다. 실패 시 null 반환.
  /// 경로를 인수 리스트로 전달하여 공백·따옴표 포함 경로도 안전하게 처리.
  Future<String?> extractThumbnail(
    String videoPath, {
    Duration at = const Duration(seconds: 1),
  }) async {
    if (_cache.containsKey(videoPath)) return _cache[videoPath];

    final tempDir = await getTemporaryDirectory();
    final outputPath = p.join(
      tempDir.path,
      'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final seconds = (at.inMilliseconds / 1000.0).toStringAsFixed(3);
    final args = [
      '-ss', seconds,
      '-i', videoPath,
      '-vframes', '1',
      '-q:v', '2',
      outputPath,
    ];

    final completer = Completer<bool>();
    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        final rc = await session.getReturnCode();
        if (!completer.isCompleted) {
          completer.complete(ReturnCode.isSuccess(rc));
        }
      },
    );

    final success = await completer.future;
    if (success) _cache[videoPath] = outputPath;
    return success ? outputPath : null;
  }
}
