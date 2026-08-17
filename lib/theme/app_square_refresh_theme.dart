import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_square_top_bar_theme.dart';

/// 广场页顶部下拉刷新球的交互与视觉参数。
///
/// 交互过程：
///   1. 列表在最顶部时，从屏幕任意位置向下滑动。
///   2. 随着下拉距离增加，刷新球从顶部栏上方竖直滑下（水平位置固定于右侧
///      [ballRightFinalInset]），直到下拉距离达到 [pullThreshold] 时球完全
///      显示并停在顶部栏正下方（球顶边 = 顶部栏底边，即最顶端位置）。
///   3. 继续下拉不再改变球的位置（进度被钳制在 1.0）。
///   4. 松手时如果进度 ≥ 1.0，触发刷新并切换为 [putonImage]；否则球收回。
///
/// 视觉：未释放（下拉中）时球内背景为 [waitingImage]，边框为绿色
/// [ballBorderColor]；释放进入刷新态后背景切换为 [putonImage]，并伴随
/// [ballShakeAmplitude]/[ballShakeDuration] 参数化的视觉抖动。
/// 触觉：拉满瞬间触发 [hapticOnArmed]（可选 [hapticOnRefresh]）。
class AppSquareRefreshTheme {
  const AppSquareRefreshTheme._();

  // ---- 交互 ----

  /// 需要下拉多少像素，刷新球才算完全拉出并触发刷新。
  static const double pullThreshold = 150;

  /// 下拉拉满（进度 ≥ 1.0）瞬间的触觉反馈类型。
  static const RefreshHapticType hapticOnArmed = RefreshHapticType.medium;

  /// 松手触发刷新（进入刷新态）时的触觉反馈类型。
  /// 注：刷新时的“震动”效果默认由视觉抖动 [ballShakeAmplitude] 实现，
  /// 触觉默认关闭，如需可改回 medium。
  static const RefreshHapticType hapticOnRefresh = RefreshHapticType.none;

  // ---- 释放视觉震动 ----

  /// 释放触发刷新时，球体水平抖动的总时长。
  static const Duration ballShakeDuration = Duration(milliseconds: 350);

  /// 释放触发刷新时，球体水平抖动的最大偏移（像素）。
  static const double ballShakeAmplitude = 6;

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

  /// 刷新球完全拉出后，球顶边相对屏幕顶部的距离。
  /// 默认 = 顶部栏高度，即球停在顶部栏正下方（最顶端位置）。
  static const double ballTopFinalInset = AppSquareTopBarTheme.height;

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
