import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// 갤러리 영상 읽기 권한 요청
  Future<bool> requestVideoReadPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }

    final sdkInt = await _androidSdkInt();
    if (sdkInt >= 33) {
      final status = await Permission.videos.request();
      return status.isGranted;
    } else {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  /// 갤러리 저장 권한 요청 (Android 10+ / iOS는 gal이 내부 처리)
  Future<bool> requestStorageWritePermission() async {
    if (Platform.isIOS) return true; // gal이 내부 처리

    final sdkInt = await _androidSdkInt();
    if (sdkInt >= 29) return true; // Scoped storage — 별도 권한 불필요
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<int> _androidSdkInt() async {
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  }
}
