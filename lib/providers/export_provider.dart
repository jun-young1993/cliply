import 'package:cliply/models/video_project.dart';
import 'package:cliply/providers/project_provider.dart';
import 'package:cliply/services/ffmpeg_service.dart';
import 'package:cliply/services/video_export_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class ExportState {
  const ExportState();
}

class ExportIdle extends ExportState {
  const ExportIdle();
}

class ExportProcessing extends ExportState {
  const ExportProcessing(this.progress);
  final double progress; // 0.0 ~ 1.0
}

class ExportDone extends ExportState {
  const ExportDone(this.outputPath);
  final String outputPath;
}

class ExportError extends ExportState {
  const ExportError(this.message);
  final String message;
}

class ExportNotifier extends Notifier<ExportState> {
  FfmpegService? _service;

  @override
  ExportState build() => const ExportIdle();

  Future<void> startExport(VideoProject project) async {
    state = const ExportProcessing(0);
    _service = FfmpegService();

    try {
      final outputPath = await VideoExportService(_service!).export(
        project,
        onProgress: (p) => state = ExportProcessing(p),
      );

      if (outputPath != null) {
        ref.read(projectProvider.notifier).setOutputPath(outputPath);
        state = ExportDone(outputPath);
      } else {
        state = const ExportError('영상 내보내기에 실패했습니다.');
      }
    } catch (e) {
      state = ExportError('내보내기 오류: $e');
    } finally {
      _service = null;
    }
  }

  Future<void> cancel() async {
    if (_service != null) {
      await _service!.cancel();
    } else {
      await FfmpegService().cancel();
    }
    state = const ExportIdle();
  }

  void reset() => state = const ExportIdle();
}

final exportProvider =
    NotifierProvider<ExportNotifier, ExportState>(ExportNotifier.new);
