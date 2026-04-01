import 'package:cliply/models/edit_mode.dart';
import 'package:cliply/screens/edit/merge_edit_screen.dart';
import 'package:cliply/screens/edit/split_edit_screen.dart';
import 'package:cliply/screens/home/widgets/feature_card.dart';
import 'package:cliply/services/recent_projects_service.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<RecentProject>> _recentFuture;

  @override
  void initState() {
    super.initState();
    _recentFuture = RecentProjectsService().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliply'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            Text(
              '어떻게 편집할까요?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '원하는 편집 방식을 선택하세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            FeatureCard(
              icon: Icons.vertical_split,
              title: '가로 분할',
              subtitle: '영상 2개를 위아래로 나란히 재생',
              onTap: () => _navigateToSplit(context, EditMode.horizontalSplit),
            ),
            const SizedBox(height: 12),
            FeatureCard(
              icon: Icons.horizontal_split,
              title: '세로 분할',
              subtitle: '영상 2개를 좌우로 나란히 재생',
              onTap: () => _navigateToSplit(context, EditMode.verticalSplit),
            ),
            const SizedBox(height: 12),
            FeatureCard(
              icon: Icons.movie_edit,
              title: '이어붙이기',
              subtitle: '여러 영상을 하나로 이어 붙이기',
              onTap: () => _navigateToMerge(context),
            ),
            const SizedBox(height: 32),
            _RecentProjectsSection(future: _recentFuture),
          ],
        ),
      ),
    );
  }

  void _navigateToSplit(BuildContext context, EditMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SplitEditScreen(mode: mode)),
    ).then((_) => setState(() {
          _recentFuture = RecentProjectsService().load();
        }));
  }

  void _navigateToMerge(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MergeEditScreen()),
    ).then((_) => setState(() {
          _recentFuture = RecentProjectsService().load();
        }));
  }
}

// ──────────────────────────────────────────
// 최근 작업 섹션
// ──────────────────────────────────────────

class _RecentProjectsSection extends StatelessWidget {
  const _RecentProjectsSection({required this.future});

  final Future<List<RecentProject>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RecentProject>>(
      future: future,
      builder: (context, snapshot) {
        final projects = snapshot.data;
        if (projects == null || projects.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '최근 작업',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: projects.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _RecentCard(project: projects[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.project});

  final RecentProject project;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                _modeIcon(project.editMode),
                size: 14,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                project.modeLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(project.savedAt),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          if (project.savedToGallery)
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 11,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 2),
                Text(
                  '갤러리 저장됨',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.tertiary,
                        fontSize: 10,
                      ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  IconData _modeIcon(EditMode mode) => switch (mode) {
        EditMode.horizontalSplit => Icons.vertical_split,
        EditMode.verticalSplit => Icons.horizontal_split,
        EditMode.merge => Icons.movie_edit,
      };

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}
