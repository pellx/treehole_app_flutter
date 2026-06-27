import 'package:flutter/material.dart';

import 'pages/square/square_page.dart';
import 'theme/app_colors.dart';

final GlobalKey<TreeholeAppState> appKey = GlobalKey<TreeholeAppState>();
ThemeMode _themeMode = ThemeMode.system;

class TreeholeApp extends StatefulWidget {
  const TreeholeApp({super.key});

  static ThemeMode get themeMode => _themeMode;

  static void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    appKey.currentState?.refresh();
  }

  @override
  State<TreeholeApp> createState() => TreeholeAppState();
}

class TreeholeAppState extends State<TreeholeApp> {
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '树通',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: AppColors.light.common.background,
        colorScheme: ColorScheme.light(
          surface: AppColors.light.common.surface,
          onSurface: AppColors.light.common.onSurface,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.light.common.green,
          selectionColor: AppColors.light.common.green.withValues(alpha: 0.3),
          selectionHandleColor: AppColors.light.common.green,
        ),
        extensions: const [AppColors.light],
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.dark.common.background,
        colorScheme: ColorScheme.dark(
          surface: AppColors.dark.common.surface,
          onSurface: AppColors.dark.common.onSurface,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.dark.common.green,
          selectionColor: AppColors.dark.common.green.withValues(alpha: 0.3),
          selectionHandleColor: AppColors.dark.common.green,
        ),
        extensions: const [AppColors.dark],
      ),
      home: const SquarePage(),
    );
  }
}
