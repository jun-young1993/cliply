import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ThumbnailService {
  /// [at] 시점의 프레임을 jpg로 추출한다. 실패 시 null 반환.
  Future<String?> extractThumbnail(
    String videoPath, {
    Duration at = const Duration(seconds: 1),
  }) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = p.join(
      tempDir.path,
      'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final seconds = at.inMilliseconds / 1000.0;
    final command =
        '-ss $seconds -i "$videoPath" -vframes 1 -q:v 2 "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) return outputPath;
    return null;
  }
}
