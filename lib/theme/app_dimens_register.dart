/// 注册页尺寸、间距、字号、弧度、动画参数
///
/// UI 控件的 `*Top` 为距 Stack 顶端。
/// 椭圆/插图仍用相对垂直中心的 `*VOffset`（与原先画法一致，避免被屏宽压扁）。
/// 修改后需检查亮色/暗色模式下各阶段显示效果。
class RegisterDimens {
  const RegisterDimens._();

  // ── 页面内容 ──
  static const double contentHPadding = 40;
  static const double phaseTitleTop = 345; // 阶段标题距顶端
  static const double phaseTitleFontSize = 22;

  // ── 白色椭圆背景 ──
  static const double ellipseWidth = 1100;
  static const double ellipseHeight = 1000;
  /// 相对垂直中心的竖直偏移（负值向上）
  static const double ellipseVOffset = -580;
  static const double ellipseHOffset = 0;

  // ── 注册页图片 — think（加载中/验证中）──
  static const double thinkWidth = 270;
  static const double thinkHeight = 1000;
  /// 相对垂直中心的竖直偏移（负值向上）
  static const double thinkVOffset = -137;
  static const double thinkHOffset = 10;

  // ── 注册页图片 — true（可以注册）──
  static const double trueWidth = 270;
  static const double trueHeight = 1000;
  /// 相对垂直中心的竖直偏移（负值向上）
  static const double trueVOffset = -137;
  static const double trueHOffset = 6;

  // ── 注册页图片 — flase（已注册）──
  static const double flaseWidth = 270;
  static const double flaseHeight = 1000;
  /// 相对垂直中心的竖直偏移（负值向上）
  static const double flaseVOffset = -137;
  static const double flaseHOffset = 15;

  // ── 错误提示 ──
  static const double errorFontSize = 15;
  static const double errorAlpha = 0.7;
  static const double errorRetryGap = 24;

  // ── 已注册提示 ──
  static const double registeredTop = 380; // 距顶部距离
  static const double registeredFontSize = 16;
  static const double registeredAlpha = 0.8;
  static const double registeredLineHeight = 1.6;

  // ── 已注册 — 登录按钮 ──
  static const double registeredLoginButtonTop = 440;
  static const double registeredLoginButtonWidth = 88;
  static const double registeredLoginButtonHeight = 37;
  static const double registeredLoginButtonPaddingH = 0;
  static const double registeredLoginButtonPaddingV = 0;
  static const double registeredLoginButtonVOffset = 0;
  static const double registeredLoginButtonHOffset = -60;
  static const double registeredLoginButtonRadius = 15;
  static const double registeredLoginButtonBorderWidth = 3;
  static const double registeredLoginButtonFontSize = 19;
  static const double registeredLoginButtonLetterSpacing = 0;

  // ── 已注册 — 联系我们按钮 ──
  static const double registeredContactButtonTop = 439.9;
  static const double registeredContactButtonWidth = 110;
  static const double registeredContactButtonHeight = 37.8;
  static const double registeredContactButtonPaddingH = 0;
  static const double registeredContactButtonPaddingV = 0;
  static const double registeredContactButtonVOffset = 0;
  static const double registeredContactButtonHOffset = 50;
  static const double registeredContactButtonRadius = 16;
  static const double registeredContactButtonBorderWidth = 3;
  static const double registeredContactButtonFontSize = 19;
  static const double registeredContactButtonLetterSpacing = 0;

  // ── 注册按钮 ──
  static const double buttonHeight = 40;
  static const double buttonWidth = 100;
  static const double buttonTop = 39;
  static const double buttonVOffset = 0; // 距顶部距离
  static const double buttonRadius = 13;
  static const double buttonBorderWidth = 3;
  static const double buttonFontSize = 19;
  static const double buttonLetterSpacing = 6;

  // ── 验证步骤行（registering 阶段）──
  static const double stepTop = 380; // 距顶部距离
  static const double stepGap = 12; // 两行步骤间距
  static const double stepIconSize = 16;
  static const double stepIconGap = 10; // 图标和文字间距
  static const double stepFontSize = 13;
  static const double stepLoadingStrokeWidth = 2;
  static const double stepPendingAlpha = 0.4;
  static const double stepDefaultAlpha = 0.6;
  static const double stepErrorGap = 16; // 步骤区和错误信息间距

  // ── 注册页图片 — flower（输入用户名）──
  static const double flowerWidth = 270;
  static const double flowerHeight = 1000;
  /// 相对垂直中心的竖直偏移（负值向上）
  static const double flowerVOffset = -140;
  static const double flowerHOffset = 6;

  // ── 注册页图片 — login（登录令牌输入）──
  static const double loginImageWidth = 270;
  static const double loginImageHeight = 1000;
  /// 相对垂直中心的竖直偏移（负值向上）
  static const double loginImageVOffset = -137;
  static const double loginImageHOffset = 6;

  // ── 取名阶段（naming）──
  static const double namingInputTop = 390; // 输入框+按钮距顶部距离
  static const double namingInputHeight = 20;
  static const double namingInputWidth = 200;
  static const double namingInputFontSize = 14;
  static const double namingHintFontSize = 14;
  static const double namingHintAlpha = 0.3;
  static const double namingInputPaddingH = 0;
  static const double namingInputPaddingV = 10;

  static const double namingButtonGap = 6;
  static const double namingConfirmButtonWidth = 50;
  static const double namingConfirmButtonHeight = 27;
  static const double namingConfirmButtonPaddingH = 0;
  static const double namingConfirmButtonPaddingV = 0;
  static const double namingConfirmButtonRadius = 11;
  static const double namingConfirmButtonBorderWidth = 2;
  static const double namingConfirmButtonFontSize = 16;
  static const double namingConfirmButtonLetterSpacing = 0;

  static const double namingButtonConfirmSize = 20;
  static const double namingButtonStrokeWidth = 2;
  static const double namingErrorGap = 12;

  // ── 登录阶段（login）──
  static const double loginInputTop = 390; // 输入框距顶部距离
  static const double loginInputHeight = 20;
  static const double loginInputWidth = 200;
  static const double loginInputFontSize = 17;
  static const double loginHintFontSize = 17;
  static const double loginHintAlpha = 0.3;
  static const double loginInputPaddingH = 0;
  static const double loginInputPaddingV = 10;

  /// 粘贴后掩码令牌（首末四位）字号
  static const double loginMaskedFontSize = 17;
  /// 掩码令牌透明度
  static const double loginMaskedAlpha = 0.6;
  /// 掩码令牌相对输入框水平偏移（负值向左）
  static const double loginMaskedHOffset = 0;
  /// 掩码令牌相对输入框竖直偏移（负值向上）
  static const double loginMaskedVOffset = -4;

  static const double loginButtonGap = 10;
  static const double loginConfirmButtonWidth = 50;
  static const double loginConfirmButtonHeight = 27;
  static const double loginConfirmButtonPaddingH = 0;
  static const double loginConfirmButtonPaddingV = 0;
  static const double loginConfirmButtonRadius = 11;
  static const double loginConfirmButtonBorderWidth = 2;
  static const double loginConfirmButtonFontSize = 16;
  static const double loginConfirmButtonLetterSpacing = 0;

  static const double loginButtonConfirmSize = 20;
  static const double loginButtonStrokeWidth = 2;
  static const double loginErrorGap = 12;

  static const double loginRecoverGap = 2; // 输入框和"找回用户"间距（保留）
  static const double loginRecoverFontSize = 12;
  /// 「找回用户」相对页面顶部（与 loginInputTop 配套，独立 Positioned）
  static const double loginRecoverTop = 430;
  static const double loginRecoverHitPaddingH = 12;
  static const double loginRecoverHitPaddingV = 8;

  // ── 账户切换「登录用户」底部提示 ──
  static const double loginTransferTipBottom = 28;
  static const double loginTransferTipHPadding = 28;
  static const double loginTransferTipFontSize = 12;
  static const double loginTransferTipAlpha = 0.45;
  static const double loginTransferTipLineHeight = 1.5;
}
