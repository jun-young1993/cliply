import 'package:cliply/models/edit_mode.dart';
import 'package:cliply/screens/edit/merge_edit_screen.dart';
import 'package:cliply/screens/edit/split_edit_screen.dart';
import 'package:cliply/screens/home/widgets/feature_card.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
          ],
        ),
      ),
    );
  }

  void _navigateToSplit(BuildContext context, EditMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SplitEditScreen(mode: mode)),
    );
  }

  void _navigateToMerge(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MergeEditScreen()),
    );
  }
}
