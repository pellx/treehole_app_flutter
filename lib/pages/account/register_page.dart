import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/local.dart';
import '../../services/api.dart';
import '../../services/storage.dart';
import '../../models/device_fingerprint.dart';
import '../../services/device_fingerprint.dart';
import '../../services/pow.dart';
import '../../services/turnstile_service.dart';
import '../../services/unique_token.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

/// 验证步骤状态
enum _StepStatus { pending, loading, completed, failed }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _controller = PageController();
  int _currentPage = 0;
  bool _registering = false;
  String? _error;

  // 注册成功后进入取名阶段
  bool _registered = false;
  final _nameController = TextEditingController();
  bool _renaming = false;
  String? _renameError;

  // 三个验证步骤的状态
  _StepStatus _turnstileStatus = _StepStatus.pending;
  _StepStatus _powStatus = _StepStatus.pending;

  // Turnstile WebView
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _initTurnstile();
    _nameController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initTurnstile() async {
    try {
      final controller = WebViewController();
      TurnstileService.instance.bindController(controller);
      setState(() => _webViewController = controller);
    } catch (e) {
      debugPrint('[Register] Turnstile init failed: $e');
    }
  }

  Future<void> _register() async {
    setState(() {
      _registering = true;
      _error = null;
      _turnstileStatus = _StepStatus.loading;
      _powStatus = _StepStatus.pending;
    });

    try {
      final hasSecret = PostStorage.getDeviceSecret()?.isNotEmpty == true
          && PostStorage.getFingerprintHash()?.isNotEmpty == true;

      if (!hasSecret) {
        // ── 并行启动所有任务，但独立 await 以便 PoW 算完立即显示 ──
        setState(() {
          _turnstileStatus = _StepStatus.loading;
          _powStatus = _StepStatus.loading;
        });

        // 同时启动所有独立任务（不 await，让它们并行跑）
        final turnstileFuture = TurnstileService.instance.getToken();
        final challengeFuture = ApiService.getPoWChallenge();
        final fingerprintFuture = DeviceFingerprintService.collect();
        final uniqueTokenFuture = UniqueTokenService.getOrCreate();

        // PoW：先拿 challenge，再本地求解，算完立即显示成功
        debugPrint('[Register] Fetching PoW challenge...');
        final challenge = await challengeFuture;
        if (challenge == null) {
          debugPrint('[Register] PoW challenge fetch failed');
          setState(() => _powStatus = _StepStatus.failed);
          setState(() => _error = '获取验证挑战失败');
          return;
        }
        debugPrint('[Register] Solving PoW (difficulty=${challenge.difficulty})...');
        final nonce = await PoWService.solve(challenge);
        if (nonce == null || !mounted) {
          debugPrint('[Register] PoW solve failed (nonce=$nonce, mounted=$mounted)');
          setState(() => _powStatus = _StepStatus.failed);
          setState(() => _error = '安全验证超时，请重试');
          return;
        }
        debugPrint('[Register] PoW solved: nonce=$nonce');
        setState(() => _powStatus = _StepStatus.completed);

        // Turnstile
        debugPrint('[Register] Waiting for Turnstile token...');
        final turnstileToken = await turnstileFuture;
        if (!mounted) return;
        if (turnstileToken == null) {
          debugPrint('[Register] Turnstile token is null');
          setState(() => _turnstileStatus = _StepStatus.failed);
          setState(() => _error = 'Turnstile 验证失败');
          return;
        }
        debugPrint('[Register] Turnstile token obtained (${turnstileToken.length} chars)');
        setState(() => _turnstileStatus = _StepStatus.completed);

        // 指纹 & unique_token
        final fingerPrint = await fingerprintFuture;
        final uniqueToken = await uniqueTokenFuture;
        if (!mounted) return;
        if (fingerPrint == null) {
          setState(() => _error = '设备信息采集失败');
          return;
        }

        // ── 所有验证通过，完成设备初始化 ──
        debugPrint('[Register] Calling initDevice...');
        final init = await ApiService.initDevice(
          deviceFingerPrint: fingerPrint,
          turnstileToken: turnstileToken,
          powChallengeId: challenge.challengeId,
          powNonce: nonce,
          uniqueToken: uniqueToken,
        );
        debugPrint('[Register] initDevice result: success=${init.success}, deviceId=${init.deviceId}, hasSecret=${init.deviceSecret != null}, mounted=$mounted');
        if (!init.success || !mounted) {
          debugPrint('[Register] initDevice failed or unmounted, success=${init.success} mounted=$mounted');
          setState(() => _error = '设备初始化失败');
          return;
        }
        await PostStorage.saveDeviceSecret(init.deviceSecret!);
        await PostStorage.saveDeviceId(init.deviceId!);
        await PostStorage.saveFingerprintHash(init.fingerprintHash!);
        debugPrint('[Register] Device secret, ID, and fingerprint_hash saved');
      }

      final deviceSecret = PostStorage.getDeviceSecret()!;
      final fingerprintHash = PostStorage.getFingerprintHash()!;
      final uniqueToken = await UniqueTokenService.getOrCreate();
      debugPrint('[Register] Calling register with fingerprintHash=${fingerprintHash.substring(0, 16)}...');
      final result = await ApiService.register(
        deviceSecret: deviceSecret,
        uniqueToken: uniqueToken,
        fingerprintHash: fingerprintHash,
      );
      debugPrint('[Register] register result: success=${result.success}, failureType=${result.failureType}, mounted=$mounted');

      if (!mounted) {
        debugPrint('[Register] Widget unmounted after register, aborting');
        return;
      }

      if (result.success) {
        debugPrint('[Register] Success! Saving session data...');
        await PostStorage.saveUserExternalToken(result.userExternalToken!);
        await PostStorage.saveSessionSecret(result.sessionSecret!);
        await PostStorage.saveSessionId(result.sessionId!);
        await PostStorage.setRegistered(true);
        debugPrint('[Register] All data saved, entering naming phase');
        setState(() => _registered = true);
      } else {
        final msg = switch (result.failureType) {
          RegistrationFailureType.networkError => '网络连接失败',
          RegistrationFailureType.deviceAlreadyRegistered => '该设备已注册',
          RegistrationFailureType.unknown || null => '注册失败，请重试',
        };
        setState(() => _error = msg);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '注册失败：$e');
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<void> _confirmName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _renaming = true;
      _renameError = null;
    });

    try {
      final userToken = PostStorage.getUserExternalToken();
      if (userToken == null) {
        setState(() => _renameError = '会话异常，请重新登录');
        return;
      }

      final result = await ApiService.rename(
        userExternalToken: userToken,
        newName: name,
      );

      if (!mounted) return;

      if (result != null) {
        await PostStorage.saveDisplayName(result);
        Navigator.pop(context);
      } else {
        setState(() => _renameError = ApiService.lastError ?? '设置名字失败');
      }
    } catch (e) {
      if (mounted) setState(() => _renameError = '网络异常：$e');
    } finally {
      if (mounted) setState(() => _renaming = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: 8,
              top: 4,
              child: IconButton(
                icon: Icon(Icons.delete_forever, size: 20,
                    color: onSurface.withValues(alpha: 0.3)),
                tooltip: '清除本地存储',
                onPressed: () async {
                  await PostStorage.clearAccount();
                  await UniqueTokenService.clear();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已清除本地存储'), duration: Duration(seconds: 1)),
                    );
                  }
                },
              ),
            ),
            // 隐藏的 WebView 用于 Turnstile 验证 — 必须在屏幕内才能加载外部脚本
            // Opacity(0.01) 保持 WebView 引擎活跃且加载资源，但视觉上几乎不可见
            // IgnorePointer 防止用户误触，PageView 在 Stack z-order 上覆盖它
            Positioned(
              left: 0,
              top: 0,
              width: 300,
              height: 300,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.01,
                  child: _webViewController != null
                      ? WebViewWidget(controller: _webViewController!)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            PageView(
              controller: _controller,
              scrollDirection: Axis.vertical,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                _buildPage(
                  image: Image.asset('assets/mu-flower.png', width: 120, height: 120),
                  title: '树通',
                  subtitle: '匿名校园论坛',
                  hint: '上滑了解更多',
                  colors: colors,
                  onSurface: onSurface,
                ),
                _buildPage(
                  icon: Icons.lock_outline,
                  title: '完全匿名',
                  subtitle: '无需手机号、无需邮箱\n你的身份只有你自己知道',
                  colors: colors,
                  onSurface: onSurface,
                ),
                _buildPage(
                  icon: _registered ? Icons.check_circle_outline : Icons.bolt_outlined,
                  title: _registered ? '注册成功' : '即刻发言',
                  subtitle: _registered
                      ? '给自己取个名字吧\n这将是你在树通中的唯一标识'
                      : '一键注册即可发帖评论\n参与校园讨论',
                  colors: colors,
                  onSurface: onSurface,
                  trailing: _registered
                      ? _buildNamingSection(colors, onSurface)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildRegisterButton(colors),
                            if (_turnstileStatus != _StepStatus.pending ||
                                _powStatus != _StepStatus.pending) ...[
                              const SizedBox(height: 24),
                              _buildStepRow('Turnstile 检测', _turnstileStatus, colors, onSurface),
                              const SizedBox(height: 8),
                              _buildStepRow('PoW 检测', _powStatus, colors, onSurface),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: const TextStyle(fontSize: 13, color: Color(0xFFE57373)),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(right: 20, bottom: 32),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        width: 8,
                        height: active ? 24 : 8,
                        decoration: BoxDecoration(
                          color: active ? onSurface : colors.common.trailingIcon.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    IconData? icon,
    Widget? image,
    required String title,
    required String subtitle,
    String? hint,
    Widget? trailing,
    required AppColors colors,
    required Color onSurface,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          if (image != null)
            image
          else if (icon != null)
            Icon(icon, size: 80, color: onSurface.withValues(alpha: 0.8)),
          const SizedBox(height: 32),
          Text(
            title,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: TextStyle(fontSize: 15, color: colors.common.trailingIcon, height: 1.5),
            textAlign: TextAlign.center,
          ),
          if (trailing != null) ...[
            const SizedBox(height: 40),
            trailing,
          ],
          if (hint != null && trailing == null) ...[
            const SizedBox(height: 60),
            Text(hint, style: TextStyle(fontSize: 13, color: colors.common.trailingIcon.withValues(alpha: 0.5))),
          ],
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  /// 构建单个验证步骤行，根据状态显示不同图标和文本
  Widget _buildStepRow(String label, _StepStatus status, AppColors colors, Color onSurface) {
    final textColor = switch (status) {
      _StepStatus.completed => colors.common.trailingIcon,
      _StepStatus.failed => const Color(0xFFE57373),
      _ => onSurface.withValues(alpha: 0.6),
    };

    final statusText = switch (status) {
      _StepStatus.pending => '',
      _StepStatus.loading => '中...',
      _StepStatus.completed => '通过',
      _StepStatus.failed => '失败',
    };

    Widget leading;
    switch (status) {
      case _StepStatus.pending:
        leading = Icon(Icons.circle_outlined, size: 16, color: textColor.withValues(alpha: 0.4));
      case _StepStatus.loading:
        leading = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _StepStatus.completed:
        leading = Icon(Icons.check_circle, size: 16, color: colors.common.trailingIcon);
      case _StepStatus.failed:
        leading = const Icon(Icons.cancel, size: 16, color: Color(0xFFE57373));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        leading,
        const SizedBox(width: 10),
        Text(
          '$label$statusText',
          style: TextStyle(fontSize: 13, color: textColor),
        ),
      ],
    );
  }

  Widget _buildRegisterButton(AppColors colors) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _registering ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.postCreate.submitBg,
          foregroundColor: colors.postCreate.submitText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _registering
            ? const Text('注册中...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500))
            : const Text('一键注册', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildNamingSection(AppColors colors, Color onSurface) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          autofocus: true,
          maxLength: 100,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: onSurface),
          decoration: InputDecoration(
            hintText: '输入你的名字',
            hintStyle: TextStyle(fontSize: 16, color: onSurface.withValues(alpha: 0.3)),
            counterText: '',
            filled: true,
            fillColor: onSurface.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_renaming || _nameController.text.trim().isEmpty) ? null : _confirmName,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.postCreate.submitBg,
              foregroundColor: colors.postCreate.submitText,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _renaming
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('确认', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          ),
        ),
        if (_renameError != null) ...[
          const SizedBox(height: 12),
          Text(
            _renameError!,
            style: const TextStyle(fontSize: 13, color: Color(0xFFE57373)),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
