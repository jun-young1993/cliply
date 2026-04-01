import 'dart:convert';

import 'package:cliply/models/edit_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentProject {
  const RecentProject({
    required this.editMode,
    required this.savedAt,
    required this.savedToGallery,
  });

  final EditMode editMode;
  final DateTime savedAt;
  final bool savedToGallery;

  String get modeLabel => switch (editMode) {
        EditMode.horizontalSplit => '가로 분할',
        EditMode.verticalSplit => '세로 분할',
        EditMode.merge => '이어붙이기',
      };

  Map<String, dynamic> toJson() => {
        'editMode': editMode.name,
        'savedAt': savedAt.toIso8601String(),
        'savedToGallery': savedToGallery,
      };

  factory RecentProject.fromJson(Map<String, dynamic> json) => RecentProject(
        editMode: EditMode.values.firstWhere(
          (e) => e.name == json['editMode'],
          orElse: () => EditMode.merge,
        ),
        savedAt: DateTime.parse(json['savedAt'] as String),
        savedToGallery: json['savedToGallery'] as bool? ?? false,
      );
}

class RecentProjectsService {
  static const _key = 'recent_projects';
  static const _maxItems = 10;

  Future<List<RecentProject>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_key) ?? [];
      return jsonList
          .map((s) =>
              RecentProject.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(RecentProject project) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await load();
      final updated = [project, ...existing].take(_maxItems).toList();
      await prefs.setStringList(
        _key,
        updated.map((p) => jsonEncode(p.toJson())).toList(),
      );
    } catch (_) {}
  }
}
