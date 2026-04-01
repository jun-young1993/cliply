import 'dart:io';

import 'package:cliply/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ui_kit_theme/controller/ds_theme_controller.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = DsThemeController();
  await themeController.init();
  _cleanupOldTempFiles(); // 앱 시작 블로킹 없이 백그라운드 실행
  runApp(
    ProviderScope(
      child: CliplyApp(themeController: themeController),
    ),
  );
}

/// 앱 강제종료·크래시로 남은 24시간 이상 된 임시 파일 삭제.
/// 현재 세션 파일(cliply_*, thumb_*)은 건드리지 않음.
Future<void> _cleanupOldTempFiles() async {
  try {
    final dir = await getTemporaryDirectory();
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith('cliply_') && !name.startsWith('thumb_')) continue;
      try {
        if (entity.statSync().modified.isBefore(cutoff)) {
          entity.deleteSync();
        }
      } catch (_) {}
    }
  } catch (_) {}
}
