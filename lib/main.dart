import 'package:cliply/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ui_kit_theme/controller/ds_theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = DsThemeController();
  await themeController.init();
  runApp(
    ProviderScope(
      child: CliplyApp(themeController: themeController),
    ),
  );
}
