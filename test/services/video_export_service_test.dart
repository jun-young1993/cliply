// ignore_for_file: lines_longer_than_80_chars

import 'dart:io';

import 'package:cliply/models/aspect_ratio_type.dart';
import 'package:cliply/models/edit_mode.dart';
import 'package:cliply/models/split_layout.dart';
import 'package:cliply/models/video_clip.dart';
import 'package:cliply/models/video_project.dart';
import 'package:cliply/services/ffmpeg_service.dart';
import 'package:cliply/services/video_export_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ──────────────────────────────────────────
// FfmpegService fake — executeWithArgs만 가로채고 FFmpeg 실행 없음
// ──────────────────────────────────────────
class _FakeFfmpegService extends FfmpegService {
  List<String>? capturedArgs;
  final bool returnValue;

  _FakeFfmpegService({this.returnValue = true});

  @override
  Future<bool> executeWithArgs(
    List<String> args, {
    void Function(double progress)? onProgress,
    Duration? totalDuration,
  }) async {
    capturedArgs = args;
    return returnValue;
  }
}

// ──────────────────────────────────────────
// 테스트용 헬퍼
// ──────────────────────────────────────────
VideoClip _clip({
  required String id,
  required String path,
  required int slotIndex,
  bool hasAudio = true,
  Duration duration = const Duration(seconds: 10),
  Duration? start,
  Duration? end,
}) {
  final s = start ?? Duration.zero;
  final e = end ?? duration;
  return VideoClip(
    id: id,
    filePath: path,
    duration: duration,
    startTime: s,
    endTime: e,
    slotIndex: slotIndex,
    hasAudio: hasAudio,
  );
}

VideoProject _project(
  EditMode mode,
  List<VideoClip> clips, {
  SplitLayout splitLayout = SplitLayout.two,
}) {
  return VideoProject(
    id: 'test',
    editMode: mode,
    aspectRatio: AspectRatioType.ratio9x16,
    splitLayout: splitLayout,
    clips: clips,
    createdAt: DateTime.now(),
  );
}

/// args에서 [flag] 바로 다음 값을 반환한다.
String _argAfter(List<String> args, String flag) {
  final idx = args.indexOf(flag);
  if (idx < 0 || idx + 1 >= args.length) return '';
  return args[idx + 1];
}

/// args에서 '-i' 플래그 다음 값을 순서대로 수집한다.
List<String> _inputFiles(List<String> args) {
  final result = <String>[];
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '-i') result.add(args[i + 1]);
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // path_provider 채널 모킹 — 테스트에서 플랫폼 구현 없이 임시 경로 반환
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getTemporaryDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  // ────────────────────────────────────────
  // 분할 편집
  // ────────────────────────────────────────
  group('VideoExportService — 분할 편집', () {
    test('빈 클립 목록: export()가 null 반환, FFmpeg 호출 없음', () async {
      final fake = _FakeFfmpegService();
      final result =
          await VideoExportService(fake).export(_project(EditMode.horizontalSplit, []));
      expect(result, isNull);
      expect(fake.capturedArgs, isNull);
    });

    test('-i 인수가 slotIndex 순서대로 추가된다', () async {
      final fake = _FakeFfmpegService();
      await VideoExportService(fake).export(_project(
        EditMode.horizontalSplit,
        [
          _clip(id: '1', path: '/a.mp4', slotIndex: 0),
          _clip(id: '2', path: '/b.mp4', slotIndex: 1),
        ],
      ));
      expect(_inputFiles(fake.capturedArgs!), ['/a.mp4', '/b.mp4']);
    });

    test('가로 분할: filter_complex에 vstack 포함, hstack 없음', () async {
      final fake = _FakeFfmpegService();
      await VideoExportService(fake).export(_project(
        EditMode.horizontalSplit,
        [
          _clip(id: '1', path: '/a.mp4', slotIndex: 0),
          _clip(id: '2', path: '/b.mp4', slotIndex: 1),
        ],
      ));
      final fc = _argAfter(fake.capturedArgs!, '-filter_complex');
      expect(fc, contains('vstack'));
      expect(fc, isNot(contains('hstack')));
    });

    test('세로 분할: filter_complex에 hstack 포함, vstack 없음', () async {
      final fake = _FakeFfmpegService();
      await VideoExportService(fake).export(_project(
        EditMode.verticalSplit,
        [
          _clip(id: '1', path: '/a.mp4', slotIndex: 0),
          _clip(id: '2', path: '/b.mp4', slotIndex: 1),
        ],
      ));
      final fc = _argAfter(fake.capturedArgs!, '-filter_complex');
      expect(fc, contains('hstack'));
      expect(fc, isNot(contains('vstack')));
    });

    test('trim 구간이 filter_complex의 trim 필터에 반영된다', () async {
      final fake = _FakeFfmpegService();
      await VideoExportService(fake).export(_project(
        EditMode.horizontalSplit,
        [
          _clip(
            id: '1',
            path: '/a.mp4',
            slotIndex: 0,
            start: const Duration(seconds: 2),
            end: const Duration(seconds: 7),
          ),
          _clip(id: '2', path: '/b.mp4', slotIndex: 1),
        ],
      ));
      final fc = _argAfter(fake.capturedArgs!, '-filter_complex');
      expect(fc, contains('trim=start=2.000:end=7.000'));
    });

    test('FFmpeg 실패(false) 시 null 반환', () async {
      final fake = _FakeFfmpegService(returnValue: false);
      final result = await VideoExportService(fake).export(_project(
        EditMode.horizontalSplit,
        [
          _clip(id: '1', path: '/a.mp4', slotIndex: 0),
          _clip(id: '2', path: '/b.mp4', slotIndex: 1),
        ],
      ));
      expect(result, isNull);
    });

    test('slotIndex가 내림차순이어도 오름차순으로 정렬되어 처리된다', () async {
      final fake = _FakeFfmpegService();
      // slotIndex 역순으로 전달
      await VideoExportService(fake).export(_project(
        EditMode.horizontalSplit,
        [
          _clip(id: '2', path: '/b.mp4', slotIndex: 1),
          _clip(id: '1', path: '/a.mp4', slotIndex: 0),
        ],
      ));
      expect(_inputFiles(fake.capturedArgs!), ['/a.mp4', '/b.mp4']);
    });
  });

  // ────────────────────────────────────────
  // 이어붙이기
  // ────────────────────────────────────────
  group('VideoExportService — 이어붙이기', () {
    test('클립 1개: null 반환, FFmpeg 호출 없음', () async {
      final fake = _FakeFfmpegService();
      final result = await VideoExportService(fake).export(_project(
        EditMode.merge,
        [_clip(id: '1', path: '/a.mp4', slotIndex: 0)],
      ));
      expect(result, isNull);
      expect(fake.capturedArgs, isNull);
    });

    test('filter_complex에 concat 포함', () async {
      final fake = _FakeFfmpegService();
      await VideoExportService(fake).export(_project(
        EditMode.merge,
        [
          _clip(id: '1', path: '/a.mp4', slotIndex: 0),
          _clip(id: '2', path: '/b.mp4', slotIndex: 1),
        ],
      ));
      final fc = _argAfter(fake.capturedArgs!, '-filter_complex');
      expect(fc, contains('concat'));
    });

    test('오디오 없는 클립: filter_complex에 anullsrc 포함', () async {
      final fake = _FakeFfmpegService();
      await VideoExportService(fake).export(_project(
        EditMode.merge,
        [
          _clip(id: '1', path: '/a.mp4', slotIndex: 0, hasAudio: false),
          _clip(id: '2', path: '/b.mp4', slotIndex: 1, hasAudio: true),
        ],
      ));
      final fc = _argAfter(fake.capturedArgs!, '-filter_complex');
      expect(fc, contains('anullsrc'));
    });

    test('모든 클립에 오디오가 있으면 anullsrc 없음', () async {
      final fake = _FakeFfmpegService();
      await VideoExportService(fake).export(_project(
        EditMode.merge,
        [
          _clip(id: '1', path: '/a.mp4', slotIndex: 0, hasAudio: true),
          _clip(id: '2', path: '/b.mp4', slotIndex: 1, hasAudio: true),
        ],
      ));
      final fc = _argAfter(fake.capturedArgs!, '-filter_complex');
      expect(fc, isNot(contains('anullsrc')));
    });

    test('클립 3개: concat n=3 포함', () async {
      final fake = _FakeFfmpegService();
      await VideoExportService(fake).export(_project(
        EditMode.merge,
        [
          _clip(id: '1', path: '/a.mp4', slotIndex: 0),
          _clip(id: '2', path: '/b.mp4', slotIndex: 1),
          _clip(id: '3', path: '/c.mp4', slotIndex: 2),
        ],
      ));
      final fc = _argAfter(fake.capturedArgs!, '-filter_complex');
      expect(fc, contains('concat=n=3'));
    });

    test('FFmpeg 실패(false) 시 null 반환', () async {
      final fake = _FakeFfmpegService(returnValue: false);
      final result = await VideoExportService(fake).export(_project(
        EditMode.merge,
        [
          _clip(id: '1', path: '/a.mp4', slotIndex: 0),
          _clip(id: '2', path: '/b.mp4', slotIndex: 1),
        ],
      ));
      expect(result, isNull);
    });
  });
}
