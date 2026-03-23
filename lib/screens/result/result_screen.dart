import 'dart:io';

import 'package:cliply/services/gallery_service.dart';
import 'package:cliply/services/permission_service.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.outputPath});

  final String outputPath;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _controller = VideoPlayerController.file(File(widget.outputPath));
    await _controller.initialize();
    _controller.setLooping(true);
    await _controller.play();
    if (mounted) setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('내보내기 완료'),
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          Expanded(
            child: _isInitialized
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                        ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (_, value, _) {
                            if (value.isPlaying) return const SizedBox.shrink();
                            return const Icon(
                              Icons.play_circle_fill,
                              size: 64,
                              color: Colors.white70,
                            );
                          },
                        ),
                      ],
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
          _ActionBar(
            isSaving: _isSaving,
            onSave: _saveToGallery,
            onShare: _shareVideo,
            onReEdit: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final granted =
          await PermissionService().requestStorageWritePermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장 권한이 필요합니다.')),
          );
        }
        return;
      }
      final ok = await GalleryService().saveToGallery(widget.outputPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? '갤러리에 저장되었습니다.' : '저장에 실패했습니다.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareVideo() async {
    await GalleryService().shareVideo(widget.outputPath);
  }
}

// ──────────────────────────────────────────
// 하단 액션 바
// ──────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isSaving,
    required this.onSave,
    required this.onShare,
    required this.onReEdit,
  });

  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onReEdit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('재편집'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_outlined),
                label: const Text('공유'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: isSaving ? null : onSave,
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download),
                label: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
