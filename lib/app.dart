import 'package:flutter/material.dart';

import 'pages/square/square_page.dart';
import 'services/api.dart';
import 'services/storage.dart';
import 'services/device_credential_store.dart';
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
  void initState() {
    super.initState();
    _ensureSession();
  }

  /// 启动时检测 session 有效性，失效则尝试自动重新登录
  Future<void> _ensureSession() async {
    // 未注册 → 跳过
    if (!PostStorage.isRegistered()) return;

    final sessionId = PostStorage.getSessionId();
    final sessionSecret = PostStorage.getSessionSecret();

    // 有 session → 先检查是否仍有效
    if (sessionId != null && sessionSecret != null) {
      final valid = await ApiService.checkSession(
        sessionId: sessionId,
        sessionSecret: sessionSecret,
      );
      if (valid && mounted) {
        debugPrint('[App] session 仍有效，继续使用');
        return;
      }
    }

    // session 无效或缺失 → 尝试用存储的凭证重新登录
    debugPrint('[App] session 失效或缺失，尝试重新登录');

    final deviceSecret = await DeviceCredentialStore.getDeviceSecret();
    final deviceId = await DeviceCredentialStore.getDeviceId();
    final userExternalToken = PostStorage.getUserExternalToken();
    final fingerprintHash = await DeviceCredentialStore.getFingerprintHash();

    if (deviceSecret == null || deviceId == null ||
        userExternalToken == null || fingerprintHash == null) {
      debugPrint('[App] 缺少登录凭证，无法自动登录');
      return;
    }

    final result = await ApiService.login(
      deviceId: deviceId,
      deviceSecret: deviceSecret,
      userExternalToken: userExternalToken,
      fingerprintHash: fingerprintHash,
    );

    if (!mounted) return;

    if (result.success) {
      debugPrint('[App] 自动登录成功，session 已更新');
      await PostStorage.saveSessionId(result.sessionId!);
      await PostStorage.saveSessionSecret(result.sessionSecret!);
      if (result.userExternalToken != null && result.userExternalToken!.isNotEmpty) {
        await PostStorage.saveUserExternalToken(result.userExternalToken!);
      }
    } else {
      debugPrint('[App] 自动登录失败: ${result.failureType}');
    }
  }

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
