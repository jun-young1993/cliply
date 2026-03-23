import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

class GalleryService {
  /// 완성 영상을 기기 갤러리에 저장한다.
  Future<bool> saveToGallery(String videoPath) async {
    try {
      await Gal.putVideo(videoPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 완성 영상을 외부 앱으로 공유한다.
  Future<void> shareVideo(String videoPath) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(videoPath)]));
  }
}
