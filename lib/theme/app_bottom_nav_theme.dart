import 'package:flutter/material.dart';

/// 底部导航栏样式参数，可在此集中调整
class AppBottomNavTheme {
  const AppBottomNavTheme._();

  /// 整体高度
  static const double height = 50;

  /// 文字 tab 字号
  static const double labelFontSize = 16;

  /// 文字 tab 字重
  static const FontWeight labelFontWeight = FontWeight.normal;

  /// 背景色
  static const Color backgroundLight = Color(0xFFF7F7F7);
  static const Color backgroundDark = Color(0xFF1A1A1A);

  /// 选中文字颜色
  static const Color selectedLabelLight = Color(0xFF00A650);
  static const Color selectedLabelDark = Color(0xFF07C160);

  /// 未选中文字颜色
  static const Color unselectedLabelLight = Color(0xFF999999);
  static const Color unselectedLabelDark = Color(0xFF888888);

  /// 中央发布按钮
  static const double publishButtonWidth = 36;
  static const double publishButtonHeight = 28;
  static const double publishButtonBorderRadius = 9;
  static const double publishButtonBorderWidth = 2.2;
  static const double publishButtonIconSize = 22;
  static const Color publishButtonColorLight = Color(0xFF36373c);
  static const Color publishButtonColorDark = Color(0xFFCCCCCC);
}
