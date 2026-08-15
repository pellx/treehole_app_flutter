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
import '../../theme/app_dimens_register.dart';
import '../../widgets/app_app_bar.dart';

enum _StepStatus { pending, loading, completed, failed }

class RegisterPage extends StatefulWidget {
  /// 为 true 时直接进入令牌登录（供账户切换页「登录用户」）
  final bool startAtLogin;

  const RegisterPage({super.key, this.startAtLogin = false});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String _phase =
      'checking'; // checking | registered | failed | unregistered | registering | naming | login | done
  String? _error;

  DeviceFingerprint? _fingerprint;

  final _nameController = TextEditingController();
  final _tokenController = TextEditingController();
  final _tokenFocusNode = FocusNode();
  bool _submitting = false;
  String? _renameError;
  bool _tokenObscured = true;

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
    if (widget.startAtLogin) {
      _phase = 'login';
    } else {
      _check();
      _preFetchVerification();
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
        return '测试未通过，请重试';
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

  ({String path, double width, double height}) get _phaseImageConfig {
    switch (_phase) {
      case 'checking':
      case 'registering':
        return (
          path: 'assets/mu/mu-think.png',
          width: RegisterDimens.thinkWidth,
          height: RegisterDimens.thinkHeight,
        );
      case 'unregistered':
        return (
          path: 'assets/mu/mu-true.png',
          width: RegisterDimens.trueWidth,
          height: RegisterDimens.trueHeight,
        );
      case 'registered':
      case 'failed':
        return (
          path: 'assets/mu/mu-flase.png',
          width: RegisterDimens.flaseWidth,
          height: RegisterDimens.flaseHeight,
        );
      case 'naming':
        return (
          path: 'assets/mu/mu-flower.png',
          width: RegisterDimens.flowerWidth,
          height: RegisterDimens.flowerHeight,
        );
      case 'login':
        return (
          path: 'assets/mu/mu-login.png',
          width: RegisterDimens.loginImageWidth,
          height: RegisterDimens.loginImageHeight,
        );
      default:
        return (
          path: 'assets/mu/mu-think.png',
          width: RegisterDimens.thinkWidth,
          height: RegisterDimens.thinkHeight,
        );
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
    setState(() {
      _phase = 'checking';
      _error = null;
    });
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
    HapticFeedback.mediumImpact();
    _nameController.clear();
    _tokenController.clear();
    _preTurnstileToken = null;
    _prePowNonce = null;
    _prePowChallenge = null;
    _tokenObscured = true;
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
    HapticFeedback.lightImpact();
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
        _turnstileStatus = hasPreTurnstile
            ? _StepStatus.completed
            : _StepStatus.loading;
        _powStatus = hasPrePow ? _StepStatus.completed : _StepStatus.loading;
      });

      // PoW
      int? nonce = _prePowNonce;
      if (nonce == null) {
        final challenge = await ApiService.getPoWChallenge();
        if (challenge == null) {
          setState(() {
            _powStatus = _StepStatus.failed;
            _phase = 'failed';
          });
          return;
        }
        nonce = await PoWService.solve(challenge);
        if (nonce == null || !mounted) {
          setState(() {
            _powStatus = _StepStatus.failed;
            _phase = 'failed';
          });
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
          setState(() {
            _turnstileStatus = _StepStatus.failed;
            _phase = 'failed';
          });
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

    setState(() {
      _submitting = true;
      _renameError = null;
    });

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
        setState(() => _renameError = _mapRegisterError(ApiService.lastError));
        return;
      }

      await DeviceCredentialStore.saveUserExternalToken(result.userToken);
      await DeviceCredentialStore.mergeKnownUserTokens([result.userToken]);
      await DeviceCredentialStore.saveDeviceSecret(result.deviceSecret);
      await PostStorage.saveDisplayName(name);
      await PostStorage.setRegistered(true);

      // 注册未写 binding：建绑后再申请 session
      final activated = await SessionService.instance.activateAfterRegister(
        result.userToken,
      );
      if (!activated) {
        setState(
          () =>
              _renameError = '注册成功，但建绑/会话失败：${ApiService.lastError ?? '未知错误'}',
        );
        return;
      }

      HapticFeedback.mediumImpact();
      setState(() => _phase = 'done');
      if (!mounted) return;
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

      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => _phase = 'done');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _renameError = '网络异常：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _mapRegisterError(String? raw) {
    return switch (raw) {
      'NAME_TAKEN' => '用户名被占用',
      'NAME_EMPTY' => '名字不能为空',
      null || '' => '注册失败',
      final code => '注册失败：$code',
    };
  }

  String _mapLoginError(String? raw) {
    return switch (raw) {
      'TOKEN_EMPTY' => '请输入用户令牌',
      'USER_NOT_FOUND' => '用户令牌无效',
      'FINGERPRINT_MISMATCH' => '设备指纹不匹配',
      'DEVICE_NOT_FOUND' => '本机设备未找到，请先在本机完成注册',
      'REBIND_COOLDOWN' => '解绑冷却中，请 2 天后再登录此账户',
      'TRANSFER_REQUIRED' => '需先在原设备发起转移申请（15 分钟内有效）',
      'TRANSFER_INVALID' => '转移申请无效或已过期，请在原设备重新申请',
      'DEVICE_SESSION_LOCKED' => '本机切号锁定中（约 2 天），暂不可切换到其他账户',
      'RATE_LIMITED' => '操作过于频繁，请稍后再试',
      _ => (raw == null || raw.isEmpty) ? '登录失败' : raw,
    };
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
    _tokenFocusNode.dispose();
    _nameController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: colors.register.pageBg,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              AppAppBar(
                title: widget.startAtLogin ? '登录用户' : '注册',
                onBack: () => Navigator.pop(context),
                trailing: !widget.startAtLogin
                    ? IconButton(
                        icon: Icon(
                          Icons.refresh,
                          size: RegisterDimens.refreshIconSize,
                          color: onSurface.withValues(alpha: 0.35),
                        ),
                        tooltip: '重新加载',
                        onPressed: _reset,
                      )
                    : null,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              const Spacer(flex: 2),
                              // 椭圆装饰
                              _ellipseDecoration(colors),
                              const SizedBox(height: 24),
                              // 阶段插图
                              if (_phase != 'done') _phaseImage(),
                              const SizedBox(height: 20),
                              // 阶段标题
                              if (_phase != 'done' && _phaseTitle.isNotEmpty)
                                Text(
                                  _phaseTitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: RegisterDimens.phaseTitleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: onSurface,
                                  ),
                                ),
                              const SizedBox(height: 24),
                              // 交互内容
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: RegisterDimens.contentHPadding,
                                ),
                                child: _buildPhaseContent(colors, onSurface),
                              ),
                              const Spacer(flex: 3),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Turnstile 需挂在树上才能跑 JS（1×1 透明，不拦截触摸）
              if (_webViewController != null)
                SizedBox(
                  width: 1,
                  height: 1,
                  child: Opacity(
                    opacity: 0,
                    child: IgnorePointer(
                      child: WebViewWidget(controller: _webViewController!),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ellipseDecoration(AppColors colors) {
    return SizedBox(
      width: RegisterDimens.ellipseWidth,
      height: RegisterDimens.ellipseHeight,
      child: ClipOval(child: ColoredBox(color: colors.register.ellipseBg)),
    );
  }

  Widget _phaseImage() {
    final img = _phaseImageConfig;
    return SizedBox(
      width: img.width,
      height: img.height,
      child: Image.asset(
        img.path,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
      ),
    );
  }

  Widget _buildPhaseContent(AppColors colors, Color onSurface) {
    switch (_phase) {
      case 'checking':
      case 'done':
        return const SizedBox.shrink();
      case 'unregistered':
        return _error != null
            ? _buildError(onSurface)
            : _buildRegisterButton(colors);
      case 'registered':
        return _buildRegistered(colors);
      case 'failed':
        return _buildErrorWithRetry(onSurface);
      case 'registering':
        return _buildRegistering(colors, onSurface);
      case 'naming':
        return _buildNamingInput(colors, onSurface);
      case 'login':
        return _buildLoginInput(colors, onSurface);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildError(Color onSurface) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _error ?? '',
          style: TextStyle(
            fontSize: RegisterDimens.errorFontSize,
            color: onSurface.withValues(alpha: RegisterDimens.errorAlpha),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorWithRetry(Color onSurface) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _error ?? '检测失败',
          style: TextStyle(
            fontSize: RegisterDimens.errorFontSize,
            color: onSurface.withValues(alpha: RegisterDimens.errorAlpha),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RegisterDimens.errorRetryGap),
        TextButton(onPressed: _check, child: const Text('重试')),
      ],
    );
  }

  Widget _buildRegistered(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '设备环境已被注册，请登录已有账户或联系我们进行注册',
          style: TextStyle(
            fontSize: RegisterDimens.registeredFontSize,
            color: colors.register.registeredTextColor,
            height: RegisterDimens.registeredLineHeight,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: RegisterDimens.registeredLoginButtonWidth,
          height: RegisterDimens.registeredLoginButtonHeight,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
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
                borderRadius: BorderRadius.circular(
                  RegisterDimens.registeredLoginButtonRadius,
                ),
                side: BorderSide(
                  color: colors.register.buttonBorderColor,
                  width: RegisterDimens.registeredLoginButtonBorderWidth,
                ),
              ),
            ),
            child: Text(
              '登录',
              style: TextStyle(
                fontSize: RegisterDimens.registeredLoginButtonFontSize,
                fontWeight: FontWeight.w500,
                letterSpacing:
                    RegisterDimens.registeredLoginButtonLetterSpacing,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
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
                borderRadius: BorderRadius.circular(
                  RegisterDimens.registeredContactButtonRadius,
                ),
                side: BorderSide(
                  color: colors.register.buttonBorderColor,
                  width: RegisterDimens.registeredContactButtonBorderWidth,
                ),
              ),
            ),
            child: Text(
              '联系我们',
              style: TextStyle(
                fontSize: RegisterDimens.registeredContactButtonFontSize,
                fontWeight: FontWeight.w500,
                letterSpacing:
                    RegisterDimens.registeredContactButtonLetterSpacing,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton(AppColors colors) {
    return SizedBox(
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
        child: Text(
          '注册',
          style: TextStyle(
            fontSize: RegisterDimens.buttonFontSize,
            fontWeight: FontWeight.w500,
            letterSpacing: RegisterDimens.buttonLetterSpacing,
          ),
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
          Text(
            _error!,
            style: TextStyle(
              fontSize: RegisterDimens.stepFontSize,
              color: colors.register.errorText,
            ),
            textAlign: TextAlign.center,
          ),
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
                    color: onSurface.withValues(
                      alpha: RegisterDimens.namingHintAlpha,
                    ),
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
                onPressed: (_submitting || _nameController.text.trim().isEmpty)
                    ? null
                    : _confirmName,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled)
                        ? colors.register.disabledButtonBg
                        : colors.register.buttonBg,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled)
                        ? colors.register.disabledButtonText
                        : colors.register.buttonText,
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        RegisterDimens.namingConfirmButtonRadius,
                      ),
                      side: BorderSide(
                        color:
                            (_submitting || _nameController.text.trim().isEmpty)
                            ? colors.register.disabledButtonBorderColor
                            : colors.register.buttonBorderColor,
                        width: RegisterDimens.namingConfirmButtonBorderWidth,
                      ),
                    ),
                  ),
                  padding: WidgetStateProperty.all(
                    EdgeInsets.symmetric(
                      horizontal: RegisterDimens.namingConfirmButtonPaddingH,
                      vertical: RegisterDimens.namingConfirmButtonPaddingV,
                    ),
                  ),
                ),
                child: _submitting
                    ? SizedBox(
                        width: RegisterDimens.namingButtonConfirmSize,
                        height: RegisterDimens.namingButtonConfirmSize,
                        child: CircularProgressIndicator(
                          strokeWidth: RegisterDimens.namingButtonStrokeWidth,
                          valueColor: AlwaysStoppedAnimation(
                            colors.register.buttonText,
                          ),
                        ),
                      )
                    : Text(
                        '确认',
                        style: TextStyle(
                          fontSize: RegisterDimens.namingConfirmButtonFontSize,
                          fontWeight: FontWeight.w500,
                          letterSpacing:
                              RegisterDimens.namingConfirmButtonLetterSpacing,
                        ),
                      ),
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
      ],
    );
  }

  Widget _buildLoginInput(AppColors colors, Color onSurface) {
    final token = _tokenController.text.trim();
    final hasToken = token.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: RegisterDimens.loginInputWidth,
          height: widget.startAtLogin
              ? RegisterDimens.loginFromUserInputHeight
              : RegisterDimens.loginInputHeight,
          child: TextField(
            controller: _tokenController,
            focusNode: _tokenFocusNode,
            enabled: !_submitting,
            autofocus: true,
            textAlign: TextAlign.center,
            obscureText: _tokenObscured,
            style: TextStyle(
              fontSize: RegisterDimens.loginInputFontSize,
              color: onSurface,
            ),
            cursorColor: onSurface,
            decoration: InputDecoration(
              hintText: '请输入令牌',
              hintStyle: TextStyle(
                fontSize: RegisterDimens.loginHintFontSize,
                color: onSurface.withValues(
                  alpha: RegisterDimens.loginHintAlpha,
                ),
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
              suffixIcon: IconButton(
                icon: Icon(
                  _tokenObscured ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: onSurface.withValues(alpha: 0.5),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _tokenObscured = !_tokenObscured);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: RegisterDimens.loginConfirmButtonWidth,
              height: RegisterDimens.loginConfirmButtonHeight,
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : (hasToken ? _confirmLogin : _pasteLoginToken),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled)
                        ? colors.register.disabledButtonBg
                        : colors.register.buttonBg,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled)
                        ? colors.register.disabledButtonText
                        : colors.register.buttonText,
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        RegisterDimens.loginConfirmButtonRadius,
                      ),
                      side: BorderSide(
                        color: _submitting
                            ? colors.register.disabledButtonBorderColor
                            : colors.register.buttonBorderColor,
                        width: RegisterDimens.loginConfirmButtonBorderWidth,
                      ),
                    ),
                  ),
                  padding: WidgetStateProperty.all(
                    EdgeInsets.symmetric(
                      horizontal: RegisterDimens.loginConfirmButtonPaddingH,
                      vertical: RegisterDimens.loginConfirmButtonPaddingV,
                    ),
                  ),
                ),
                child: _submitting
                    ? SizedBox(
                        width: RegisterDimens.loginButtonConfirmSize,
                        height: RegisterDimens.loginButtonConfirmSize,
                        child: CircularProgressIndicator(
                          strokeWidth: RegisterDimens.loginButtonStrokeWidth,
                          valueColor: AlwaysStoppedAnimation(
                            colors.register.buttonText,
                          ),
                        ),
                      )
                    : Text(
                        hasToken ? '确认' : '粘贴',
                        style: TextStyle(
                          fontSize: RegisterDimens.loginConfirmButtonFontSize,
                          fontWeight: FontWeight.w500,
                          letterSpacing:
                              RegisterDimens.loginConfirmButtonLetterSpacing,
                        ),
                      ),
              ),
            ),
            if (hasToken) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: RegisterDimens.loginConfirmButtonWidth,
                height: RegisterDimens.loginConfirmButtonHeight,
                child: OutlinedButton(
                  onPressed: _submitting ? null : _pasteLoginToken,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: onSurface.withValues(alpha: 0.7),
                    side: BorderSide(color: onSurface.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        RegisterDimens.loginConfirmButtonRadius,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: RegisterDimens.loginConfirmButtonPaddingH,
                      vertical: RegisterDimens.loginConfirmButtonPaddingV,
                    ),
                  ),
                  child: const Text('粘贴'),
                ),
              ),
            ],
          ],
        ),
        if (widget.startAtLogin) ...[
          const SizedBox(height: RegisterDimens.loginTransferTipGap),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RegisterDimens.loginTransferTipHPadding,
            ),
            child: Text(
              '请在已登录账户设备的 [用户]=>[设备绑定] 页面中点击 [转移申请] 发出登录许可后进行登录',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: RegisterDimens.loginTransferTipFontSize,
                height: RegisterDimens.loginTransferTipLineHeight,
                color: onSurface.withValues(
                  alpha: RegisterDimens.loginTransferTipAlpha,
                ),
              ),
            ),
          ),
        ],
        if (!widget.startAtLogin && _phase == 'login') ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
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
      ],
    );
  }

  Widget _buildStepRow(
    String label,
    _StepStatus status,
    AppColors colors,
    Color onSurface,
  ) {
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
        leading = Icon(
          Icons.circle_outlined,
          size: RegisterDimens.stepIconSize,
          color: textColor.withValues(alpha: RegisterDimens.stepPendingAlpha),
        );
      case _StepStatus.loading:
        leading = SizedBox(
          width: RegisterDimens.stepIconSize,
          height: RegisterDimens.stepIconSize,
          child: CircularProgressIndicator(
            strokeWidth: RegisterDimens.stepLoadingStrokeWidth,
            valueColor: AlwaysStoppedAnimation(regColors.loadingIndicator),
          ),
        );
      case _StepStatus.completed:
        leading = Icon(
          Icons.check_circle,
          size: RegisterDimens.stepIconSize,
          color: regColors.stepCompleted,
        );
      case _StepStatus.failed:
        leading = Icon(
          Icons.cancel,
          size: RegisterDimens.stepIconSize,
          color: regColors.errorText,
        );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        leading,
        const SizedBox(width: RegisterDimens.stepIconGap),
        Text(
          '$label$statusText',
          style: TextStyle(
            fontSize: RegisterDimens.stepFontSize,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
