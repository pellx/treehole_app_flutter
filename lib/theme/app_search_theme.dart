import 'package:flutter/material.dart';

/// 搜索页主题参数：集中在此，方便微调样式。
///
/// 修改后直接热重启（按 R）即可生效。
class AppSearchTheme {
  AppSearchTheme._();

  // ---- 颜色 ----
  /// 搜索页强调色，用于光标、搜索按钮文字、历史选中项等。
  static const Color searchAccent = Color(0xFF0EAB00);

  /// 右侧「搜索」按钮的文字颜色，默认与强调色一致。
  static const Color searchButtonColor = searchAccent;

  static const Color _chipBgLight = Color(0xFFF5F5F5);
  static const Color _chipBgDark = Color(0xFF2C2C2C);

  /// 搜索历史 chip 的背景色（根据主题自动切换深浅）。
  static Color chipBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? _chipBgLight
        : _chipBgDark;
  }

  // ---- 顶部搜索栏 ----
  /// 搜索栏容器左侧内边距。
  static const double barHorizontalPadding = 0;

  /// 搜索栏容器右侧内边距（搜索按钮左侧）。
  static const double barTrailingPadding = 10;

  /// 搜索栏容器上下内边距。
  static const double barVerticalPadding = 6;

  /// 左上角返回箭头图标大小。
  static const double backIconSize = 32;

  /// 输入框圆角半径。
  static const double inputBorderRadius = 22;

  /// 输入框边框宽度。
  static const double inputBorderWidth = 1.4;

  /// 输入框整体固定高度。
  static const double searchBarHeight = 40;

  /// 输入框内部文字上下内边距（配合 isDense 控制垂直居中）。
  static const double inputVerticalPadding = 1;

  /// 搜索图标左侧到输入框左边缘的距离。
  static const double searchIconLeftPadding = 12;

  /// 搜索图标再向右的额外偏移（正值往右移）。
  static const double searchIconLeftOffset = 5;

  /// 搜索图标右侧到输入文字的距离。
  static const double searchIconToTextGap = 2;

  /// 搜索图标上下偏移（正值往下移，负值往上移）。
  static const double searchIconVerticalOffset = 0;

  /// 搜索图标在输入框内的垂直对齐方式（center/start/end）。
  static const CrossAxisAlignment searchIconVerticalAlignment =
      CrossAxisAlignment.center;

  /// 是否使用紧凑模式，true 时输入框高度更贴 contentPadding。
  static const bool inputIsDense = true;

  /// 输入框提示文字字号。
  static const double inputHintFontSize = 16;

  /// 搜索图标大小。
  static const double prefixIconSize = 24;

  /// 清空按钮（×）图标大小。
  static const double clearIconSize = 18;

  /// 右侧「搜索」按钮文字字号。
  static const double searchButtonFontSize = 16;

  /// 右侧「搜索」按钮文字字重。
  static const FontWeight searchButtonFontWeight = FontWeight.w600;

  /// 输入框与「搜索」按钮之间的水平间距。
  static const double searchButtonLeftGap = 8;

  /// 「搜索」按钮最小宽度。
  static const double searchButtonMinWidth = 40;

  /// 「搜索」按钮最小高度。
  static const double searchButtonMinHeight = 36;

  /// 输入框为空时的提示文字。
  static const String inputHint = '输入关键词';

  /// 右侧按钮文字。
  static const String searchButtonText = '搜索';

  // ---- 搜索历史 ----
  /// 历史区域标题文字。
  static const String historyTitle = '搜索历史';

  /// 历史区域上内边距。
  static const double historySectionTopPadding = 0;

  /// 历史区域下内边距。
  static const double historySectionBottomPadding = 0;

  /// 历史区域左右内边距。
  static const double historySectionHorizontalPadding = 16;

  /// 历史标题字号。
  static const double historyTitleFontSize = 16;

  /// 历史标题字重。
  static const FontWeight historyTitleFontWeight = FontWeight.w600;

  /// 清空历史按钮图标大小。
  static const double historyClearIconSize = 20;

  /// 清空历史按钮图标透明度（0~1）。
  static const double historyClearIconAlpha = 0.3;

  /// 展开/收起历史按钮图标大小（当前未使用，可保留）。
  static const double historyExpandIconSize = 20;

  /// 展开/收起历史按钮图标透明度（当前未使用，可保留）。
  static const double historyExpandIconAlpha = 0.35;

  /// 历史区竖线分隔线宽度（当前未使用，可保留）。
  static const double historyDividerWidth = 0;

  /// 历史区竖线分隔线高度（当前未使用，可保留）。
  static const double historyDividerHeight = 16;

  /// 历史区竖线分隔线左右间距（当前未使用，可保留）。
  static const double historyDividerHorizontalMargin = 4;

  /// 历史区图标按钮最小尺寸。
  static const double historyIconButtonSize = 36;

  /// 历史 chip 水平间距。
  static const double historyWrapSpacing = 12;

  /// 历史 chip 垂直间距。
  static const double historyWrapRunSpacing = 12;

  /// 历史 chip 水平内边距。
  static const double historyChipHorizontalPadding = 7;

  /// 历史 chip 垂直内边距。
  static const double historyChipVerticalPadding = 8;

  /// 历史 chip 圆角半径。
  static const double historyChipBorderRadius = 6;

  /// 历史 chip 文字字号。
  static const double historyChipFontSize = 14;

  /// 历史 chip 文字透明度（0~1）。
  static const double historyChipTextAlpha = 0.85;

  /// 历史标题与 chip 列表之间的垂直间距。
  static const double historyTitleChipGap = 14;

  /// 历史超过多少条时折叠（当前未使用，可保留）。
  static const int historyCollapseThreshold = 8;

  /// 历史展开/收起动画时长（当前未使用，可保留）。
  static const Duration historyExpandAnimationDuration =
      Duration(milliseconds: 200);
}
