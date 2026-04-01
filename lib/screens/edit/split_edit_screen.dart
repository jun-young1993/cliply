import 'dart:io';

import 'package:cliply/models/aspect_ratio_type.dart';
import 'package:cliply/models/edit_mode.dart';
import 'package:cliply/models/split_layout.dart';
import 'package:cliply/models/video_clip.dart';
import 'package:cliply/providers/export_provider.dart';
import 'package:cliply/providers/project_provider.dart';
import 'package:cliply/screens/result/result_screen.dart';
import 'package:cliply/screens/shared/aspect_ratio_selector.dart';
import 'package:cliply/screens/shared/error_dialog.dart';
import 'package:cliply/screens/shared/export_quality_selector.dart';
import 'package:cliply/screens/shared/trim_slider.dart';
import 'package:cliply/services/ffmpeg_service.dart';
import 'package:cliply/services/permission_service.dart';
import 'package:cliply/services/thumbnail_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class SplitEditScreen extends ConsumerStatefulWidget {
  const SplitEditScreen({super.key, required this.mode});

  final EditMode mode;

  @override
  ConsumerState<SplitEditScreen> createState() => _SplitEditScreenState();
}

class _SplitEditScreenState extends ConsumerState<SplitEditScreen> {
  int _selectedSlotIndex = 0;
  bool _isPickingVideo = false;

  bool get _isHorizontal => widget.mode == EditMode.horizontalSplit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectProvider.notifier).initProject(widget.mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ExportState>(exportProvider, (_, state) {
      if (state is ExportDone) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              outputPath: state.outputPath,
              editMode: widget.mode,
            ),
          ),
        );
        ref.read(exportProvider.notifier).reset();
      } else if (state is ExportError) {
        showErrorDialog(context, message: state.message);
        ref.read(exportProvider.notifier).reset();
      }
    });

    final project = ref.watch(projectProvider);
    final clips = project?.clips ?? [];
    final maxSlots = project?.maxSlots ?? 2;
    final selectedClip = _clipAt(clips, _selectedSlotIndex);

    final exportState = ref.watch(exportProvider);
    final isExporting = exportState is ExportProcessing;
    final exportProgress = isExporting ? exportState.progress : 0.0;

    final title = _isHorizontal ? '가로 분할' : '세로 분할';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 비율 선택
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: const AspectRatioSelector(),
          ),

          // 2분할 / 3분할 선택
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SegmentedButton<SplitLayout>(
              segments: const [
                ButtonSegment(value: SplitLayout.two, label: Text('2분할')),
                ButtonSegment(value: SplitLayout.three, label: Text('3분할')),
              ],
              selected: {project?.splitLayout ?? SplitLayout.two},
              onSelectionChanged: project == null
                  ? null
                  : (set) => ref
                      .read(projectProvider.notifier)
                      .setSplitLayout(set.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),

          // 2. 분할 미리보기
          if (project != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _SplitPreview(
                isHorizontal: _isHorizontal,
                aspectRatio: project.aspectRatio.value,
                clips: clips,
                maxSlots: maxSlots,
                selectedSlotIndex: _selectedSlotIndex,
                onSlotTap: (i) => setState(() => _selectedSlotIndex = i),
              ),
            ),

          // 3. 슬롯 그리드
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SlotGrid(
              clips: clips,
              maxSlots: maxSlots,
              selectedSlotIndex: _selectedSlotIndex,
              isPickingVideo: _isPickingVideo,
              onSlotTap: (i) => setState(() => _selectedSlotIndex = i),
              onAddVideo: (i) {
                setState(() => _selectedSlotIndex = i);
                _pickVideo(i);
              },
              onRemove: (slotIndex) =>
                  ref.read(projectProvider.notifier).removeClip(slotIndex),
              onToggleMute: (slotIndex) =>
                  ref.read(projectProvider.notifier).toggleClipMute(slotIndex),
            ),
          ),

          // 4. 트림 슬라이더
          if (selectedClip != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TrimSlider(clip: selectedClip),
            )
          else
            const Spacer(),

          // 5. 품질 선택
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ExportQualitySelector(),
          ),

          // 6. 하단 버튼
          _BottomBar(
            canExport: project?.canExport ?? false,
            isExporting: isExporting,
            exportProgress: exportProgress,
            onExport: isExporting
                ? null
                : () {
                    if (project != null) {
                      ref
                          .read(exportProvider.notifier)
                          .startExport(project);
                    }
                  },
            onCancelExport: isExporting
                ? () => ref.read(exportProvider.notifier).cancel()
                : null,
          ),
        ],
      ),
    );
  }

  VideoClip? _clipAt(List<VideoClip> clips, int slotIndex) {
    for (final c in clips) {
      if (c.slotIndex == slotIndex) return c;
    }
    return null;
  }

  Future<void> _pickVideo(int slotIndex) async {
    if (_isPickingVideo) return;
    setState(() => _isPickingVideo = true);

    try {
      final granted =
          await PermissionService().requestVideoReadPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('갤러리 접근 권한이 필요합니다.')),
          );
        }
        return;
      }

      final xFile =
          await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (xFile == null || !mounted) return;

      final info = await FfmpegService().getVideoInfo(xFile.path);
      if (!mounted) return;

      final project = ref.read(projectProvider);
      if (project == null) return;

      // 슬롯에 기존 클립이 있으면 교체
      final existing = _clipAt(project.clips, slotIndex);
      if (existing != null) {
        ref.read(projectProvider.notifier).removeClip(slotIndex);
      }

      final clip = VideoClip(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: xFile.path,
        duration: info.duration,
        startTime: Duration.zero,
        endTime: info.duration,
        slotIndex: slotIndex,
        hasAudio: info.hasAudio,
      );

      ref.read(projectProvider.notifier).addClip(clip);

      // 썸네일 비동기 추출
      ThumbnailService().extractThumbnail(xFile.path).then((thumbPath) {
        if (thumbPath != null && mounted) {
          ref
              .read(projectProvider.notifier)
              .updateClip(clip.copyWith(thumbnailPath: thumbPath));
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('영상을 불러오지 못했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingVideo = false);
    }
  }
}

// ──────────────────────────────────────────
// 분할 미리보기
// ──────────────────────────────────────────

class _SplitPreview extends StatelessWidget {
  const _SplitPreview({
    required this.isHorizontal,
    required this.aspectRatio,
    required this.clips,
    required this.maxSlots,
    required this.selectedSlotIndex,
    required this.onSlotTap,
  });

  final bool isHorizontal;
  final double aspectRatio;
  final List<VideoClip> clips;
  final int maxSlots;
  final int selectedSlotIndex;
  final void Function(int) onSlotTap;

  @override
  Widget build(BuildContext context) {
    final slots = List.generate(maxSlots, (i) {
      VideoClip? clip;
      for (final c in clips) {
        if (c.slotIndex == i) {
          clip = c;
          break;
        }
      }
      final isSelected = i == selectedSlotIndex;

      return Expanded(
        child: GestureDetector(
          onTap: () => onSlotTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: clip?.thumbnailPath != null
                ? Image.file(File(clip!.thumbnailPath!), fit: BoxFit.cover)
                : Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.add_circle_outline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
      );
    });

    // 고정 높이 200 기준으로 비율에 맞는 너비 계산
    // (9:16 → 112px, 1:1 → 200px, 16:9 → 355px)
    const double previewH = 200.0;
    return Center(
      child: SizedBox(
        height: previewH,
        width: previewH * aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isHorizontal
              ? Column(children: slots)
              : Row(children: slots),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// 슬롯 그리드 (카드 목록)
// ──────────────────────────────────────────

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.clips,
    required this.maxSlots,
    required this.selectedSlotIndex,
    required this.isPickingVideo,
    required this.onSlotTap,
    required this.onAddVideo,
    required this.onRemove,
    required this.onToggleMute,
  });

  final List<VideoClip> clips;
  final int maxSlots;
  final int selectedSlotIndex;
  final bool isPickingVideo;
  final void Function(int) onSlotTap;
  final void Function(int) onAddVideo;
  final void Function(int) onRemove;
  final void Function(int) onToggleMute;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(maxSlots, (i) {
        VideoClip? clip;
        for (final c in clips) {
          if (c.slotIndex == i) {
            clip = c;
            break;
          }
        }
        final isSelected = i == selectedSlotIndex;
        final colorScheme = Theme.of(context).colorScheme;

        return Expanded(
          child: GestureDetector(
            onTap: () => onSlotTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(
                right: i < maxSlots - 1 ? 8 : 0,
                top: 4,
                bottom: 4,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '슬롯 ${i + 1}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 6),
                  if (clip == null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: isPickingVideo ? null : () => onAddVideo(i),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Icon(Icons.add, size: 20),
                      ),
                    )
                  else ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: clip.thumbnailPath != null
                            ? Image.file(
                                File(clip.thumbnailPath!),
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _fmtDuration(clip.trimmedDuration),
                            style: Theme.of(context).textTheme.labelSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (clip.hasAudio)
                          GestureDetector(
                            onTap: () => onToggleMute(i),
                            child: Icon(
                              clip.muted
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              size: 16,
                              color: clip.muted
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => onRemove(i),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ──────────────────────────────────────────
// 하단 버튼
// ──────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canExport,
    required this.isExporting,
    required this.exportProgress,
    required this.onExport,
    required this.onCancelExport,
  });

  final bool canExport;
  final bool isExporting;
  final double exportProgress;
  final VoidCallback? onExport;
  final VoidCallback? onCancelExport;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isExporting)
            LinearProgressIndicator(
                value: exportProgress == 0 ? null : exportProgress),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: isExporting
                ? OutlinedButton.icon(
                    onPressed: onCancelExport,
                    icon: const Icon(Icons.stop),
                    label: Text(
                        '${(exportProgress * 100).toStringAsFixed(0)}% — 취소'),
                  )
                : FilledButton.icon(
                    onPressed: canExport ? onExport : null,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('저장'),
                  ),
          ),
        ],
      ),
    );
  }
}
