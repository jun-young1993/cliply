import 'dart:io';

import 'package:cliply/models/aspect_ratio_type.dart';
import 'package:cliply/models/edit_mode.dart';
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

class MergeEditScreen extends ConsumerStatefulWidget {
  const MergeEditScreen({super.key});

  @override
  ConsumerState<MergeEditScreen> createState() => _MergeEditScreenState();
}

class _MergeEditScreenState extends ConsumerState<MergeEditScreen> {
  int _selectedIndex = 0;
  bool _isPickingVideo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectProvider.notifier).initProject(EditMode.merge);
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
              editMode: EditMode.merge,
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
    final clampedIndex =
        clips.isEmpty ? 0 : _selectedIndex.clamp(0, clips.length - 1);
    final selectedClip = clips.isEmpty ? null : clips[clampedIndex];

    final exportState = ref.watch(exportProvider);
    final isExporting = exportState is ExportProcessing;
    final exportProgress = isExporting ? exportState.progress : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('이어붙이기')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: const AspectRatioSelector(),
          ),

          // 썸네일 미리보기
          if (selectedClip != null)
            _ThumbnailPreview(
              clip: selectedClip,
              aspectRatio: project!.aspectRatio.value,
            ),

          // 클립 목록 or 빈 상태
          Expanded(
            child: clips.isEmpty
                ? _EmptyState(onAdd: _isPickingVideo ? null : _pickVideo)
                : _ClipList(
                    clips: clips,
                    selectedIndex: clampedIndex,
                    onSelect: (i) => setState(() => _selectedIndex = i),
                    onDelete: (slotIndex) {
                      ref
                          .read(projectProvider.notifier)
                          .removeClip(slotIndex);
                      final newLen = clips.length - 1;
                      if (newLen > 0 && _selectedIndex >= newLen) {
                        setState(() => _selectedIndex = newLen - 1);
                      }
                    },
                    onReorder: (oldIdx, newIdx) {
                      if (newIdx > oldIdx) newIdx--;
                      ref
                          .read(projectProvider.notifier)
                          .reorderClips(oldIdx, newIdx);
                    },
                    onToggleMute: (slotIndex) =>
                        ref.read(projectProvider.notifier).toggleClipMute(slotIndex),
                  ),
          ),

          // 트림 슬라이더
          if (selectedClip != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: TrimSlider(clip: selectedClip),
            ),

          // 품질 선택
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: ExportQualitySelector(),
          ),

          // 하단 버튼 + 진행바
          _BottomBar(
            canAddMore: clips.length < (project?.maxSlots ?? 10),
            canExport: project?.canExport ?? false,
            isExporting: isExporting,
            exportProgress: exportProgress,
            onAdd: _isPickingVideo ? null : _pickVideo,
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

  Future<void> _pickVideo() async {
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
      final project = ref.read(projectProvider);
      if (project == null || !mounted) return;

      final clip = VideoClip(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: xFile.path,
        duration: info.duration,
        startTime: Duration.zero,
        endTime: info.duration,
        slotIndex: project.clips.length,
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
// 서브 위젯
// ──────────────────────────────────────────

class _ThumbnailPreview extends StatelessWidget {
  const _ThumbnailPreview({required this.clip, required this.aspectRatio});

  final VideoClip clip;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: clip.thumbnailPath != null
              ? Image.file(
                  File(clip.thumbnailPath!),
                  fit: BoxFit.cover,
                )
              : Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            '영상을 추가해보세요',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '2개 이상 추가해야 이어붙이기가 가능합니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('영상 추가'),
          ),
        ],
      ),
    );
  }
}

class _ClipList extends StatelessWidget {
  const _ClipList({
    required this.clips,
    required this.selectedIndex,
    required this.onSelect,
    required this.onDelete,
    required this.onReorder,
    required this.onToggleMute,
  });

  final List<VideoClip> clips;
  final int selectedIndex;
  final void Function(int index) onSelect;
  final void Function(int slotIndex) onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int slotIndex) onToggleMute;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: clips.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final clip = clips[index];
        final isSelected = index == selectedIndex;
        return _ClipTile(
          key: ValueKey(clip.id),
          clip: clip,
          index: index,
          isSelected: isSelected,
          onTap: () => onSelect(index),
          onDelete: () => onDelete(clip.slotIndex),
          onToggleMute: () => onToggleMute(clip.slotIndex),
        );
      },
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    super.key,
    required this.clip,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onToggleMute,
  });

  final VideoClip clip;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fileName = clip.filePath.split('/').last.split('\\').last;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
              const SizedBox(width: 8),
              // 썸네일
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: clip.thumbnailPath != null
                      ? Image.file(
                          File(clip.thumbnailPath!),
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.video_file, size: 24),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      _fmtDuration(clip.trimmedDuration),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (clip.hasAudio)
                IconButton(
                  icon: Icon(
                    clip.muted ? Icons.volume_off : Icons.volume_up,
                    color: clip.muted
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onToggleMute,
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
                color: colorScheme.error,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canAddMore,
    required this.canExport,
    required this.isExporting,
    required this.exportProgress,
    required this.onAdd,
    required this.onExport,
    required this.onCancelExport,
  });

  final bool canAddMore;
  final bool canExport;
  final bool isExporting;
  final double exportProgress;
  final VoidCallback? onAdd;
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
            LinearProgressIndicator(value: exportProgress == 0 ? null : exportProgress),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canAddMore ? onAdd : null,
                    icon: const Icon(Icons.add),
                    label: const Text('영상 추가'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isExporting
                      ? OutlinedButton.icon(
                          onPressed: onCancelExport,
                          icon: const Icon(Icons.stop),
                          label: Text(
                            '${(exportProgress * 100).toStringAsFixed(0)}%',
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: canExport ? onExport : null,
                          icon: const Icon(Icons.save_alt),
                          label: const Text('저장'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
