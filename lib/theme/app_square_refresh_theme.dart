import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 广场页顶部下拉刷新球的交互与视觉参数。
///
/// 交互过程：
///   1. 列表在最顶部时，从屏幕任意位置向下滑动。
///   2. 随着下拉距离增加，刷新球从顶栏上方竖直滑下（下拉起始位置固定，
///      水平位置固定于右侧 [ballRightFinalInset]）；滑过顶栏区域时被
///      顶栏遮盖（不盖住顶栏），从顶栏底边下方露出，无透明度渐变。
///   3. 拉满（进度 ≥ 1.0）时球顶边停在顶栏底边下方 [ballMaxDropDistance]
///      处；继续下拉不再改变球的位置。
///   4. 松手时：进度 ≥ 1.0 → 触发刷新并切换为 [putonImage]；否则球以
///      [ballRetractDuration] 平滑缩回顶栏底边后消失，而不是直接消失。
///      （刷新结束后同样平滑缩回。）
///
/// 视觉：未释放（下拉中）时球内背景为 [waitingImage]，边框为绿色
/// [ballBorderColor]；释放进入刷新态后背景切换为 [putonImage]，并伴随
/// [ballShakeAmplitude]/[ballShakeDuration] 参数化的视觉抖动，球左侧
/// 立即显示 [loadingLabelText] 文案（无淡入）。释放后保持 [putonImage]
/// 不再切回 waiting，随缩回动画一起消失（下次下拉开始时重置）。
/// 触觉：拉满瞬间触发 [hapticOnArmed]（可选 [hapticOnRefresh]）。
class AppSquareRefreshTheme {
  const AppSquareRefreshTheme._();

  // ---- 交互 ----

  /// 需要下拉多少像素，刷新球才算完全拉出并触发刷新。
  static const double pullThreshold = 50;

  /// 下拉拉满（进度 ≥ 1.0）瞬间的触觉反馈类型。
  static const RefreshHapticType hapticOnArmed = RefreshHapticType.medium;

  /// 松手触发刷新（进入刷新态）时的触觉反馈类型。
  /// 注：刷新时的“震动”效果默认由视觉抖动 [ballShakeAmplitude] 实现，
  /// 触觉默认关闭，如需可改回 medium。
  static const RefreshHapticType hapticOnRefresh = RefreshHapticType.none;

  // ---- 释放视觉震动 ----

  /// 释放触发刷新时，球体水平抖动的总时长。
  static const Duration ballShakeDuration = Duration(milliseconds: 400);

  /// 释放触发刷新时，球体水平抖动的最大偏移（像素）。
  static const double ballShakeAmplitude = 5;

  // ---- 缩回 ----

  /// 未拉满松手（或刷新结束）时，球缩回顶栏下方的动画时长。
  static const Duration ballRetractDuration = Duration(milliseconds: 220);

  // ---- 刷新中文案 ----

  /// 刷新态（显示 [putonImage]）时球左侧显示的文字。
  /// 出现/消失均为瞬间，无淡入动画。
  static const String loadingLabelText = '加载中';

  /// 刷新中文案的字体大小。
  static const double loadingLabelFontSize = 14;

  /// 刷新中文案的字体粗细。
  static const FontWeight loadingLabelFontWeight = FontWeight.w500;

  /// 刷新中文案的颜色（与球边框同色，亮暗色下均可读）。
  static const Color loadingLabelColor = Color(0xFF7BB380);

  /// 刷新中文案右边缘到球左边缘的间距。
  static const double loadingLabelGap = 8;

  // ---- 球体 ----

  /// 刷新球直径。
  static const double ballSize = 48;

  /// 未释放（下拉中）时球的背景图。
  static const String waitingImage = 'assets/mu/reflash-waiting.png';

  /// 释放触发刷新后球的背景图。
  static const String putonImage = 'assets/mu/reflash-puton.png';

  /// 球边框颜色（绿色）。
  static const Color ballBorderColor = Color(0xFF7BB380);

  /// 球边框宽度。
  static const double ballBorderWidth = 2;

  /// 背景图在球内的填充方式（图片裁成圆形）。
  static const BoxFit ballImageFit = BoxFit.cover;

  /// 刷新球完全拉出后，球右侧到屏幕右边缘的距离。
  static const double ballRightFinalInset = 16;

  /// 刷新球的最大落下距离：拉满时球顶边停在顶部栏底边下方
  /// [ballMaxDropDistance] 处；下拉过程中球从顶栏上方滑下、穿过顶栏后
  /// 露出，最多下落这么多像素。
  static const double ballMaxDropDistance = 14;

  /// 刷新球阴影的不透明度。
  static const double shadowOpacity = 0.15;
}

/// 刷新相关震动类型：可整体关闭或换强度。
enum RefreshHapticType {
  none,
  light,
  medium,
  heavy,
  selection;

  /// 触发本类型对应的系统震动。
  void trigger() {
    switch (this) {
      case RefreshHapticType.none:
        break;
      case RefreshHapticType.light:
        HapticFeedback.lightImpact();
      case RefreshHapticType.medium:
        HapticFeedback.mediumImpact();
      case RefreshHapticType.heavy:
        HapticFeedback.heavyImpact();
      case RefreshHapticType.selection:
        HapticFeedback.selectionClick();
    }
  }
}
