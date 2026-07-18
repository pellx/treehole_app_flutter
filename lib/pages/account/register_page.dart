import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/device_fingerprint.dart';
import '../../services/api.dart';
import '../../services/device_credential_store.dart';
import '../../services/device_fingerprint.dart';
import '../../services/pow.dart';
import '../../services/session_service.dart';
import '../../services/storage.dart';
import '../../services/turnstile_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens_accent.dart';
import '../../theme/app_dimens_register.dart';

enum _StepStatus { pending, loading, completed, failed }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String _phase = 'checking'; // checking | registered | failed | unregistered | registering | naming | login | done
  String? _error;

  DeviceFingerprint? _fingerprint;

  final _nameController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _submitting = false;
  String? _renameError;

  WebViewController? _webViewController;

  _StepStatus _turnstileStatus = _StepStatus.pending;
  _StepStatus _powStatus = _StepStatus.pending;

  // 预取验证结果（页面加载时后台开始，点击注册时直接使用）
  String? _preTurnstileToken;
  int? _prePowNonce;
  PoWChallenge? _prePowChallenge;

  @override
  void initState() {
    super.initState();
    _initTurnstile();
    _nameController.addListener(() {
      if (mounted) setState(() {});
    });
    _tokenController.addListener(() {
      if (mounted) setState(() {});
    });
    _check();
    _preFetchVerification();
  }

  ({String path, double width, double height, double vOffset, double hOffset}) get _phaseImageConfig {
    switch (_phase) {
      case 'checking':
      case 'registering':
        return (
          path: 'assets/mu/mu-think.png',
          width: RegisterDimens.thinkWidth,
          height: RegisterDimens.thinkHeight,
          vOffset: RegisterDimens.thinkVOffset,
          hOffset: RegisterDimens.thinkHOffset,
        );
      case 'unregistered':
        return (
          path: 'assets/mu/mu-true.png',
          width: RegisterDimens.trueWidth,
          height: RegisterDimens.trueHeight,
          vOffset: RegisterDimens.trueVOffset,
          hOffset: RegisterDimens.trueHOffset,
        );
      case 'registered':
      case 'failed':
        return (
          path: 'assets/mu/mu-flase.png',
          width: RegisterDimens.flaseWidth,
          height: RegisterDimens.flaseHeight,
          vOffset: RegisterDimens.flaseVOffset,
          hOffset: RegisterDimens.flaseHOffset,
        );
      case 'naming':
        return (
          path: 'assets/mu/mu-flower.png',
          width: RegisterDimens.flowerWidth,
          height: RegisterDimens.flowerHeight,
          vOffset: RegisterDimens.flowerVOffset,
          hOffset: RegisterDimens.flowerHOffset,
        );
      case 'login':
        return (
          path: 'assets/mu/mu-login.png',
          width: RegisterDimens.loginImageWidth,
          height: RegisterDimens.loginImageHeight,
          vOffset: RegisterDimens.loginImageVOffset,
          hOffset: RegisterDimens.loginImageHOffset,
        );
      default:
        return (
          path: 'assets/mu/mu-think.png',
          width: RegisterDimens.thinkWidth,
          height: RegisterDimens.thinkHeight,
          vOffset: RegisterDimens.thinkVOffset,
          hOffset: RegisterDimens.thinkHOffset,
        );
    }
  }

  String get _phaseTitle {
    switch (_phase) {
      case 'checking':
        return '让我康康';
      case 'unregistered':
        return '您的设备可进行注册';
      case 'registered':
        return '设备环境无法注册';
      case 'failed':
        return '测试未通过';
      case 'registering':
        return '通过一些测试';
      case 'naming':
        return '注册成功！取个名字吧';
      case 'login':
        return '请粘贴用户令牌';
      default:
        return '';
    }
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

  Future<void> _check() async {
    setState(() { _phase = 'checking'; _error = null; });
    final stopwatch = Stopwatch()..start();
    try {
      final fp = await DeviceFingerprintService.collect();
      if (!mounted) return;
      _fingerprint = fp;
      final registered = await ApiService.check(deviceFingerPrint: fp);
      if (!mounted) return;

      // 至少显示 1300ms 的检测中状态
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 1300) {
        await Future.delayed(Duration(milliseconds: 1300 - elapsed));
        if (!mounted) return;
      }

      if (registered == null) {
        setState(() => _phase = 'failed');
        return;
      }
      setState(() => _phase = registered ? 'registered' : 'unregistered');
    } catch (e) {
      if (mounted) setState(() => _phase = 'failed');
    }
  }

  /// 后台预取 PoW 和 Turnstile 验证，缩短点击注册后的等待时间
  void _preFetchVerification() {
    // PoW
    ApiService.getPoWChallenge().then((challenge) async {
      if (challenge == null || !mounted) return;
      _prePowChallenge = challenge;
      final nonce = await PoWService.solve(challenge);
      if (mounted && nonce != null) _prePowNonce = nonce;
    });
    // Turnstile
    TurnstileService.instance.getToken().then((token) {
      if (mounted && token != null) _preTurnstileToken = token;
    });
  }

  /// 重置页面状态，重新检测
  void _reset() {
    _nameController.clear();
    _tokenController.clear();
    _preTurnstileToken = null;
    _prePowNonce = null;
    _prePowChallenge = null;
    setState(() {
      _phase = 'checking';
      _error = null;
      _submitting = false;
      _renameError = null;
      _turnstileStatus = _StepStatus.pending;
      _powStatus = _StepStatus.pending;
    });
    _check();
  }

  Future<void> _startRegister() async {
    try {
      final fp = _fingerprint;
      if (fp == null) {
        setState(() => _phase = 'failed');
        return;
      }

      // 优先使用预取结果
      final hasPrePow = _prePowNonce != null && _prePowChallenge != null;
      final hasPreTurnstile = _preTurnstileToken != null;

      if (hasPrePow && hasPreTurnstile) {
        // 预取完成，直接跳到取名
        setState(() {
          _turnstileStatus = _StepStatus.completed;
          _powStatus = _StepStatus.completed;
          _phase = 'naming';
        });
        return;
      }

      // 预取未完成，显示加载状态并等待
      setState(() {
        _phase = 'registering';
        _error = null;
        _turnstileStatus = hasPreTurnstile ? _StepStatus.completed : _StepStatus.loading;
        _powStatus = hasPrePow ? _StepStatus.completed : _StepStatus.loading;
      });

      // PoW
      int? nonce = _prePowNonce;
      if (nonce == null) {
        final challenge = await ApiService.getPoWChallenge();
        if (challenge == null) {
          setState(() { _powStatus = _StepStatus.failed; _phase = 'failed'; });
          return;
        }
        nonce = await PoWService.solve(challenge);
        if (nonce == null || !mounted) {
          setState(() { _powStatus = _StepStatus.failed; _phase = 'failed'; });
          return;
        }
        _prePowNonce = nonce;
        _prePowChallenge = challenge;
        setState(() => _powStatus = _StepStatus.completed);
      }

      // Turnstile
      String? turnstileToken = _preTurnstileToken;
      if (turnstileToken == null) {
        turnstileToken = await TurnstileService.instance.getToken();
        if (!mounted) return;
        if (turnstileToken == null) {
          setState(() { _turnstileStatus = _StepStatus.failed; _phase = 'failed'; });
          return;
        }
        _preTurnstileToken = turnstileToken;
        setState(() => _turnstileStatus = _StepStatus.completed);
      }

      // 验证通过 → 进入取名阶段
      setState(() => _phase = 'naming');
    } catch (e) {
      if (mounted) setState(() => _error = '注册失败：$e');
    }
  }

  Future<void> _confirmName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() { _submitting = true; _renameError = null; });

    try {
      final fp = _fingerprint;
      if (fp == null) {
        setState(() => _renameError = '设备指纹丢失，请重试');
        return;
      }

      final result = await ApiService.register(
        userDisplayId: name,
        deviceFingerPrint: fp,
        verificationTurnstile: _preTurnstileToken ?? '',
        verificationPow: PoWResult(
          challengeId: _prePowChallenge!.challengeId,
          nonce: _prePowNonce!,
        ),
      );

      if (!mounted) return;

      if (result == null) {
        setState(() => _renameError = ApiService.lastError ?? '未知错误');
        return;
      }

      await DeviceCredentialStore.saveUserExternalToken(result.userToken);
      await DeviceCredentialStore.mergeKnownUserTokens([result.userToken]);
      await DeviceCredentialStore.saveDeviceSecret(result.deviceSecret);
      await PostStorage.saveDisplayName(name);
      await PostStorage.setRegistered(true);

      // 注册成功后立即申请 session
      await SessionService.instance.ensureSession();

      setState(() => _phase = 'done');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _renameError = '网络异常：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmLogin() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    setState(() {
      _submitting = true;
      _renameError = null;
    });

    try {
      final ok = await SessionService.instance.loginWithToken(token);
      if (!mounted) return;
      if (!ok) {
        setState(() => _renameError = _mapLoginError(ApiService.lastError));
        return;
      }

      await PostStorage.setRegistered(true);
      final sessionId = await DeviceCredentialStore.getSessionId();
      final sessionSecret = await DeviceCredentialStore.getSessionSecret();
      if (sessionId != null && sessionSecret != null) {
        final profile = await ApiService.getUserProfile(
          sessionId: sessionId,
          sessionSecret: sessionSecret,
        );
        if (profile != null && profile.userDisplayId.isNotEmpty) {
          await PostStorage.saveDisplayName(profile.userDisplayId);
        }
      }

      if (!mounted) return;
      setState(() => _phase = 'done');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _renameError = '网络异常：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _mapLoginError(String? raw) {
    return switch (raw) {
      'TOKEN_EMPTY' => '请输入用户令牌',
      'USER_NOT_FOUND' => '用户令牌无效',
      'FINGERPRINT_MISMATCH' => '设备指纹不匹配',
      'DEVICE_NOT_FOUND' => '本机设备未找到，请先在本机完成注册',
      'REBIND_COOLDOWN' => '解绑冷却中，请 2 天后再登录此账户',
      'RATE_LIMITED' => '操作过于频繁，请稍后再试',
      _ => (raw == null || raw.isEmpty) ? '登录失败' : raw,
    };
  }

  String _maskLoginToken(String token) {
    const head = AccentDimens.tokenHeadChars;
    const tail = AccentDimens.tokenTailChars;
    if (token.length > head + tail) {
      return '${token.substring(0, head)}...${token.substring(token.length - tail)}';
    }
    return token;
  }

  Future<void> _pasteLoginToken() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      setState(() => _renameError = '剪贴板为空');
      return;
    }
    setState(() {
      _tokenController.text = text;
      _renameError = null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colors.register.pageBg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 白色椭圆背景 — 最底层
            IgnorePointer(
              child: Center(
                child: OverflowBox(
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: Transform.translate(
                    offset: Offset(RegisterDimens.ellipseHOffset, RegisterDimens.ellipseVOffset),
                    child: ClipOval(
                      child: Container(
                        width: RegisterDimens.ellipseWidth,
                        height: RegisterDimens.ellipseHeight,
                        color: colors.register.ellipseBg,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 隐藏的 WebView 用于 Turnstile（暂移出树，排查触摸拦截）
            // WebView 平台视图可能在 Android 层面拦截触摸事件
            // TODO: 确认按钮可点击后恢复 WebView
            // 悬浮图片 — 根据阶段显示不同图片（纯装饰，置于交互内容下方）
            if (_phase != 'done')
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: Offset(_phaseImageConfig.hOffset, _phaseImageConfig.vOffset),
                      child: Image.asset(_phaseImageConfig.path,
                          width: _phaseImageConfig.width,
                          height: _phaseImageConfig.height),
                    ),
                  ),
                ),
              ),
            // 阶段标题 — 每个阶段显示不同的大文本
            if (_phase != 'done' && _phaseTitle.isNotEmpty)
              Positioned(
                left: 0, right: 0,
                top: RegisterDimens.phaseTitleTop,
                child: Center(
                  child: Text(_phaseTitle,
                      style: TextStyle(
                        fontSize: RegisterDimens.phaseTitleFontSize,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      )),
                ),
              ),
            // 已注册提示文字 — 独立 Positioned，可控制位置
            if (_phase == 'registered')
              Positioned(
                left: 0, right: 0,
                top: RegisterDimens.registeredTop,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: RegisterDimens.contentHPadding),
                    child: _buildRegistered(colors),
                  ),
                ),
              ),
            // 已注册 — 登录按钮
            if (_phase == 'registered')
              Positioned(
                left: 0, right: 0,
                top: RegisterDimens.registeredLoginButtonTop,
                child: Center(
                  child: Transform.translate(
                    offset: Offset(RegisterDimens.registeredLoginButtonHOffset, RegisterDimens.registeredLoginButtonVOffset),
                    child: SizedBox(
                      width: RegisterDimens.registeredLoginButtonWidth,
                      height: RegisterDimens.registeredLoginButtonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _phase = 'login';
                            _renameError = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.register.buttonBg,
                          foregroundColor: colors.register.buttonText,
                          padding: EdgeInsets.symmetric(
                            horizontal: RegisterDimens.registeredLoginButtonPaddingH,
                            vertical: RegisterDimens.registeredLoginButtonPaddingV,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RegisterDimens.registeredLoginButtonRadius),
                            side: BorderSide(
                              color: colors.register.buttonBorderColor,
                              width: RegisterDimens.registeredLoginButtonBorderWidth,
                            ),
                          ),
                        ),
                        child: Text('登录',
                            style: TextStyle(
                              fontSize: RegisterDimens.registeredLoginButtonFontSize,
                              fontWeight: FontWeight.w500,
                              letterSpacing: RegisterDimens.registeredLoginButtonLetterSpacing,
                            )),
                      ),
                    ),
                  ),
                ),
              ),
            // 已注册 — 联系我们按钮
            if (_phase == 'registered')
              Positioned(
                left: 0, right: 0,
                top: RegisterDimens.registeredContactButtonTop,
                child: Center(
                  child: Transform.translate(
                    offset: Offset(RegisterDimens.registeredContactButtonHOffset, RegisterDimens.registeredContactButtonVOffset),
                    child: SizedBox(
                      width: RegisterDimens.registeredContactButtonWidth,
                      height: RegisterDimens.registeredContactButtonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: 导航到联系我们页
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.register.buttonBg,
                          foregroundColor: colors.register.buttonText,
                          padding: EdgeInsets.symmetric(
                            horizontal: RegisterDimens.registeredContactButtonPaddingH,
                            vertical: RegisterDimens.registeredContactButtonPaddingV,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(RegisterDimens.registeredContactButtonRadius),
                            side: BorderSide(
                              color: colors.register.buttonBorderColor,
                              width: RegisterDimens.registeredContactButtonBorderWidth,
                            ),
                          ),
                        ),
                        child: Text('联系我们',
                            style: TextStyle(
                              fontSize: RegisterDimens.registeredContactButtonFontSize,
                              fontWeight: FontWeight.w500,
                              letterSpacing: RegisterDimens.registeredContactButtonLetterSpacing,
                            )),
                      ),
                    ),
                  ),
                ),
              ),
            // 交互内容 — 按钮/输入框等
            if (_phase == 'unregistered' && _error == null)
              Positioned(
                left: 0, right: 0,
                top: RegisterDimens.buttonTop,
                child: Center(
                  child: SizedBox(
                    width: RegisterDimens.buttonWidth,
                    height: RegisterDimens.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _startRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.register.buttonBg,
                        foregroundColor: colors.register.buttonText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RegisterDimens.buttonRadius),
                          side: BorderSide(
                            color: colors.register.buttonBorderColor,
                            width: RegisterDimens.buttonBorderWidth,
                          ),
                        ),
                      ),
                      child: Text('注册',
                          style: TextStyle(
                            fontSize: RegisterDimens.buttonFontSize,
                            fontWeight: FontWeight.w500,
                            letterSpacing: RegisterDimens.buttonLetterSpacing,
                          )),
                    ),
                  ),
                ),
              )
            else if (_phase == 'registering')
              Positioned(
                left: 0, right: 0,
                top: RegisterDimens.stepTop,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: RegisterDimens.contentHPadding),
                    child: _buildRegistering(colors, onSurface),
                  ),
                ),
              )
            else if (_phase == 'naming')
              Positioned(
                left: 0, right: 0,
                top: RegisterDimens.namingInputTop,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: RegisterDimens.contentHPadding),
                    child: _buildNamingInput(colors, onSurface),
                  ),
                ),
              )
            else if (_phase == 'login')
              Positioned(
                left: 0, right: 0,
                top: RegisterDimens.loginInputTop,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: RegisterDimens.contentHPadding),
                    child: _buildLoginInput(colors, onSurface),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: RegisterDimens.contentHPadding),
                    child: _buildPhase(colors, onSurface),
                  ),
                ),
              ),
            // 右上角重新加载按钮
            Positioned(
              right: 8, top: 4,
              child: IconButton(
                icon: Icon(Icons.refresh, size: 22,
                    color: onSurface.withValues(alpha: 0.35)),
                tooltip: '重新加载',
                onPressed: _reset,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhase(AppColors colors, Color onSurface) {
    switch (_phase) {
      case 'checking':
        return const SizedBox.shrink();
      case 'registered':
        return const SizedBox.shrink();
      case 'failed':
        return const SizedBox.shrink();
      case 'unregistered':
        return _error != null
            ? _buildError(onSurface)
            : _buildRegisterButton(colors);
      case 'registering':
        return _buildRegistering(colors, onSurface);
      case 'naming':
        return const SizedBox.shrink();
      case 'login':
        return const SizedBox.shrink();
      case 'done':
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildError(Color onSurface) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_error!,
            style: TextStyle(
              fontSize: RegisterDimens.errorFontSize,
              color: onSurface.withValues(alpha: RegisterDimens.errorAlpha),
            ),
            textAlign: TextAlign.center),
        const SizedBox(height: RegisterDimens.errorRetryGap),
        TextButton(onPressed: _check, child: const Text('重试')),
      ],
    );
  }

  Widget _buildRegistered(AppColors colors) {
    return Text(
      '设备环境已被注册，请登录已有账户或联系我们进行注册',
      style: TextStyle(
        fontSize: RegisterDimens.registeredFontSize,
        color: colors.register.registeredTextColor,
        height: RegisterDimens.registeredLineHeight,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildRegisterButton(AppColors colors) {
    return Transform.translate(
      offset: Offset(0, RegisterDimens.buttonVOffset),
      child: SizedBox(
        width: RegisterDimens.buttonWidth,
        height: RegisterDimens.buttonHeight,
        child: ElevatedButton(
          onPressed: _startRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.register.buttonBg,
            foregroundColor: colors.register.buttonText,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RegisterDimens.buttonRadius),
              side: BorderSide(
                color: colors.register.buttonBorderColor,
                width: RegisterDimens.buttonBorderWidth,
              ),
            ),
          ),
          child: Text('注册',
              style: TextStyle(
                fontSize: RegisterDimens.buttonFontSize,
                fontWeight: FontWeight.w500,
                letterSpacing: RegisterDimens.buttonLetterSpacing,
              )),
        ),
      ),
    );
  }

  Widget _buildRegistering(AppColors colors, Color onSurface) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStepRow('Turnstile 检测', _turnstileStatus, colors, onSurface),
        const SizedBox(height: RegisterDimens.stepGap),
        _buildStepRow('PoW 检测', _powStatus, colors, onSurface),
        if (_error != null) ...[
          const SizedBox(height: RegisterDimens.stepErrorGap),
          Text(_error!,
              style: TextStyle(
                fontSize: RegisterDimens.stepFontSize,
                color: colors.register.errorText,
              ),
              textAlign: TextAlign.center),
        ],
      ],
    );
  }

  Widget _buildNamingInput(AppColors colors, Color onSurface) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: RegisterDimens.namingInputWidth,
              height: RegisterDimens.namingInputHeight,
              child: TextField(
                controller: _nameController,
                autofocus: true,
                maxLength: 100,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: RegisterDimens.namingInputFontSize,
                  color: onSurface,
                ),
                decoration: InputDecoration(
                  hintText: '请输入（每14天可更改一次）',
                  hintStyle: TextStyle(
                    fontSize: RegisterDimens.namingHintFontSize,
                    color: onSurface.withValues(alpha: RegisterDimens.namingHintAlpha),
                  ),
                  counterText: '',
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: onSurface, width: 1),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: onSurface, width: 1),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: onSurface, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: RegisterDimens.namingInputPaddingH,
                    vertical: RegisterDimens.namingInputPaddingV,
                  ),
                ),
              ),
            ),
            SizedBox(width: RegisterDimens.namingButtonGap),
            SizedBox(
              width: RegisterDimens.namingConfirmButtonWidth,
              height: RegisterDimens.namingConfirmButtonHeight,
              child: ElevatedButton(
                onPressed: (_submitting || _nameController.text.trim().isEmpty) ? null : _confirmName,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.disabled)
                        ? colors.register.disabledButtonBg
                        : colors.register.buttonBg),
                  foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.disabled)
                        ? colors.register.disabledButtonText
                        : colors.register.buttonText),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RegisterDimens.namingConfirmButtonRadius),
                    side: BorderSide(
                      color: (_submitting || _nameController.text.trim().isEmpty)
                          ? colors.register.disabledButtonBorderColor
                          : colors.register.buttonBorderColor,
                      width: RegisterDimens.namingConfirmButtonBorderWidth,
                    ),
                  )),
                  padding: WidgetStateProperty.all(EdgeInsets.symmetric(
                    horizontal: RegisterDimens.namingConfirmButtonPaddingH,
                    vertical: RegisterDimens.namingConfirmButtonPaddingV,
                  )),
                ),
                child: _submitting
                    ? SizedBox(
                        width: RegisterDimens.namingButtonConfirmSize,
                        height: RegisterDimens.namingButtonConfirmSize,
                        child: CircularProgressIndicator(
                          strokeWidth: RegisterDimens.namingButtonStrokeWidth,
                          valueColor: AlwaysStoppedAnimation(colors.register.buttonText),
                        ),
                      )
                    : Text('确认',
                        style: TextStyle(
                          fontSize: RegisterDimens.namingConfirmButtonFontSize,
                          fontWeight: FontWeight.w500,
                          letterSpacing: RegisterDimens.namingConfirmButtonLetterSpacing,
                        )),
              ),
            ),
          ],
        ),
        if (_renameError != null) ...[
          const SizedBox(height: RegisterDimens.namingErrorGap),
          Text(_renameError!,
              style: TextStyle(
                fontSize: RegisterDimens.stepFontSize,
                color: colors.register.errorText,
              ),
              textAlign: TextAlign.center),
        ],
      ],
    );
  }

  Widget _buildLoginInput(AppColors colors, Color onSurface) {
    final token = _tokenController.text.trim();
    final hasToken = token.isNotEmpty;
    // 空：粘贴；有内容：确认登录
    final onButtonPressed = _submitting
        ? null
        : (hasToken ? _confirmLogin : _pasteLoginToken);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: RegisterDimens.loginInputWidth,
              height: RegisterDimens.loginInputHeight,
              child: hasToken
                  ? GestureDetector(
                      // 点击掩码可清空，便于重新粘贴
                      onTap: _submitting
                          ? null
                          : () => setState(() {
                                _tokenController.clear();
                                _renameError = null;
                              }),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: onSurface, width: 1),
                          ),
                        ),
                        child: Text(
                          _maskLoginToken(token),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AccentDimens.tokenValueFontSize,
                            color: onSurface.withValues(
                                alpha: AccentDimens.tokenValueAlpha),
                          ),
                        ),
                      ),
                    )
                  : TextField(
                      controller: _tokenController,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: RegisterDimens.loginInputFontSize,
                        color: onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: '请输入令牌',
                        hintStyle: TextStyle(
                          fontSize: RegisterDimens.loginHintFontSize,
                          color: onSurface.withValues(
                              alpha: RegisterDimens.loginHintAlpha),
                        ),
                        counterText: '',
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: onSurface, width: 1),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: onSurface, width: 1),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: onSurface, width: 1),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: RegisterDimens.loginInputPaddingH,
                          vertical: RegisterDimens.loginInputPaddingV,
                        ),
                      ),
                    ),
            ),
            SizedBox(width: RegisterDimens.loginButtonGap),
            SizedBox(
              width: RegisterDimens.loginConfirmButtonWidth,
              height: RegisterDimens.loginConfirmButtonHeight,
              child: ElevatedButton(
                onPressed: onButtonPressed,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.disabled)
                        ? colors.register.disabledButtonBg
                        : colors.register.buttonBg),
                  foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.disabled)
                        ? colors.register.disabledButtonText
                        : colors.register.buttonText),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RegisterDimens.loginConfirmButtonRadius),
                    side: BorderSide(
                      color: _submitting
                          ? colors.register.disabledButtonBorderColor
                          : colors.register.buttonBorderColor,
                      width: RegisterDimens.loginConfirmButtonBorderWidth,
                    ),
                  )),
                  padding: WidgetStateProperty.all(EdgeInsets.symmetric(
                    horizontal: RegisterDimens.loginConfirmButtonPaddingH,
                    vertical: RegisterDimens.loginConfirmButtonPaddingV,
                  )),
                ),
                child: _submitting
                    ? SizedBox(
                        width: RegisterDimens.loginButtonConfirmSize,
                        height: RegisterDimens.loginButtonConfirmSize,
                        child: CircularProgressIndicator(
                          strokeWidth: RegisterDimens.loginButtonStrokeWidth,
                          valueColor: AlwaysStoppedAnimation(colors.register.buttonText),
                        ),
                      )
                    : Text(hasToken ? '确认' : '粘贴',
                        style: TextStyle(
                          fontSize: RegisterDimens.loginConfirmButtonFontSize,
                          fontWeight: FontWeight.w500,
                          letterSpacing: RegisterDimens.loginConfirmButtonLetterSpacing,
                        )),
              ),
            ),
          ],
        ),
        if (_renameError != null) ...[
          const SizedBox(height: RegisterDimens.namingErrorGap),
          Text(
            _renameError!,
            style: TextStyle(
              fontSize: RegisterDimens.stepFontSize,
              color: colors.register.errorText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        SizedBox(height: RegisterDimens.loginRecoverGap),
        GestureDetector(
          onTap: () {
            // TODO: 找回用户逻辑
          },
          child: Text(
            '找回用户',
            style: TextStyle(
              fontSize: RegisterDimens.loginRecoverFontSize,
              color: colors.register.loginRecoverColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepRow(String label, _StepStatus status, AppColors colors, Color onSurface) {
    final regColors = colors.register;

    final textColor = switch (status) {
      _StepStatus.completed => regColors.stepCompleted,
      _StepStatus.failed => regColors.errorText,
      _ => onSurface.withValues(alpha: RegisterDimens.stepDefaultAlpha),
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
        leading = Icon(Icons.circle_outlined,
            size: RegisterDimens.stepIconSize,
            color: textColor.withValues(alpha: RegisterDimens.stepPendingAlpha));
      case _StepStatus.loading:
        leading = SizedBox(
            width: RegisterDimens.stepIconSize,
            height: RegisterDimens.stepIconSize,
            child: CircularProgressIndicator(
              strokeWidth: RegisterDimens.stepLoadingStrokeWidth,
              valueColor: AlwaysStoppedAnimation(regColors.loadingIndicator),
            ));
      case _StepStatus.completed:
        leading = Icon(Icons.check_circle,
            size: RegisterDimens.stepIconSize,
            color: regColors.stepCompleted);
      case _StepStatus.failed:
        leading = Icon(Icons.cancel,
            size: RegisterDimens.stepIconSize,
            color: regColors.errorText);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        leading,
        const SizedBox(width: RegisterDimens.stepIconGap),
        Text('$label$statusText',
            style: TextStyle(fontSize: RegisterDimens.stepFontSize, color: textColor)),
      ],
    );
  }
}
