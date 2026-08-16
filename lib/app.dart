import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/main_shell.dart';
import 'app_navigator.dart';
import 'services/session_service.dart';
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

class TreeholeAppState extends State<TreeholeApp> with WidgetsBindingObserver {
  void refresh() => setState(() {});

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ensureSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 后台期间他机可能已解绑本机，回前台尽早清登录 / 切号，并重连 WS
      SessionService.instance.invalidate();
      _ensureSession();
    }
  }

  /// 启动与回前台时检测 session / 绑定有效性
  Future<void> _ensureSession() async {
    await SessionService.instance.ensureSession();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '树通',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
      ],
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: AppColors.light.common.background,
        colorScheme: ColorScheme.light(
          primary: AppColors.light.common.green,
          onPrimary: Colors.white,
          surface: AppColors.light.common.surface,
          onSurface: AppColors.light.common.onSurface,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.light.common.green,
          selectionColor: AppColors.light.common.green.withValues(alpha: 0.3),
          selectionHandleColor: AppColors.light.common.green,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        extensions: const [AppColors.light],
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.dark.common.background,
        colorScheme: ColorScheme.dark(
          primary: AppColors.dark.common.green,
          onPrimary: Colors.black,
          surface: AppColors.dark.common.surface,
          onSurface: AppColors.dark.common.onSurface,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.dark.common.green,
          selectionColor: AppColors.dark.common.green.withValues(alpha: 0.3),
          selectionHandleColor: AppColors.dark.common.green,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        extensions: const [AppColors.dark],
      ),
      home: const MainShell(),
    );
  }
}
