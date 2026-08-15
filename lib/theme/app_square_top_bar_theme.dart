import 'package:flutter/material.dart';

/// 广场页顶部分类栏样式参数，可在此集中调整。
///
/// 顶栏是一个高度固定的水平 Row（高度 = [height]），内部包含：
///   - 左侧横向滚动的分类 tab
///   - 右侧搜索图标按钮
///
/// 每个 tab 内部采用「底部对齐」布局，结构如下（从下到上）：
///   顶栏底部
///   [indicatorBottomSpacing]  ← 指示条底部到顶栏底部的距离，直接决定指示条位置
///   指示条（宽 [indicatorWidth] × 高 [indicatorHeight]）
///   [indicatorTopSpacing]     ← 文字底部到指示条顶部的距离
///   文字
class AppSquareTopBarTheme {
  const AppSquareTopBarTheme._();

  /// 顶栏容器高度，所有内容都必须在这个高度内排布。
  /// 如果改这个值，tab 文字、指示条、搜索图标的视觉位置会一起被撑开/压缩。
  static const double height = 48;

  /// 分类 tab 字号。
  static const double fontSize = 15;

  /// 分类 tab 字重。
  static const FontWeight selectedFontWeight = FontWeight.w600;
  static const FontWeight unselectedFontWeight = FontWeight.normal;

  /// 每个分类 tab 的左右内边距，用来控制 tab 之间的间距。
  /// 数值越大，tab 之间越疏松。
  static const double itemHorizontalPadding = 14;

  /// 底部指示条的宽度、高度、圆角。
  static const double indicatorWidth = 20;
  static const double indicatorHeight = 2.5;
  static const double indicatorBorderRadius = 1.25;

  /// 文字底部到指示条顶部的距离。
  /// 这个值越大，文字和指示条分得越开。
  static const double indicatorTopSpacing = 4;

  /// 指示条底部到顶栏容器底部的距离。
  /// 这是「直接距离」：tab 内部按底部对齐，改这个值会立刻改变指示条在顶栏里的高低。
  static const double indicatorBottomSpacing = 2;

  /// 搜索图标本身的大小。
  static const double searchIconSize = 24;

  /// 搜索按钮右侧到顶栏右边缘的留白。
  /// 数值越小，搜索图标越贴近屏幕右边。
  static const double searchIconRightInset = 2;

  /// 搜索按钮的顶部内边距。
  /// [IconButton] 会把图标放在剩余空间的中心；topPadding 越大，图标越靠下。
  static const double searchIconTopPadding = 8;

  /// 搜索按钮的底部内边距。
  /// 与 [searchIconTopPadding] 配合，调大一个、调小另一个即可让图标上下偏移。
  static const double searchIconBottomPadding = 8;
}
