import 'package:flutter/material.dart';

/// 广场页顶部分类栏样式参数，可在此集中调整
class AppSquareTopBarTheme {
  const AppSquareTopBarTheme._();

  /// 顶栏高度
  static const double height = 48;

  /// 分类 tab 字号
  static const double fontSize = 15;

  /// 分类 tab 字重
  static const FontWeight selectedFontWeight = FontWeight.w600;
  static const FontWeight unselectedFontWeight = FontWeight.normal;

  /// 分类 tab 水平内边距
  static const double itemHorizontalPadding = 14;

  /// 底部指示条
  static const double indicatorWidth = 20;
  static const double indicatorHeight = 2.5;
  static const double indicatorBorderRadius = 1.25;

  /// 指示条到文字的距离
  static const double indicatorTopSpacing = 4;

  /// 指示条到顶栏底部的距离（让整体视觉上下更平衡）
  static const double indicatorBottomSpacing = 2;

  /// 搜索图标大小
  static const double searchIconSize = 24;

  /// 搜索图标右侧留白（越小越贴边）
  static const double searchIconRightInset = 2;
}
