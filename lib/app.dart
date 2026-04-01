import 'package:cliply/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_ui_kit_l10n/flutter_ui_kit_l10n.dart';
import 'package:flutter_ui_kit_theme/design_system.dart';

class CliplyApp extends StatelessWidget {
  const CliplyApp({super.key, required this.themeController});

  final DsThemeController themeController;

  @override
  Widget build(BuildContext context){
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) => DsThemeBuilder(
        controller: themeController,
        child: child,
        builder: (theme, child) => MaterialApp(
          title: 'Cliply',
          debugShowCheckedModeBanner: false,
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: theme.themeMode,
          locale: theme.locale,
          localizationsDelegates: UiKitLocalizations.localizationsDelegates,
          supportedLocales: UiKitLocalizations.supportedLocales,
          home: child
        )
      ),
      child: const HomeScreen()
    );
  }
}

