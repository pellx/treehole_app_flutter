import 'package:flutter/material.dart';

/// 搜索页主题参数：集中在此，方便微调样式。
class AppSearchTheme {
  AppSearchTheme._();

  // ---- 颜色 ----
  static const Color searchAccent = Color(0xFF0EAB00);
  static const Color searchButtonColor = searchAccent;

  static const Color _chipBgLight = Color(0xFFF5F5F5);
  static const Color _chipBgDark = Color(0xFF2C2C2C);

  static Color chipBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? _chipBgLight
        : _chipBgDark;
  }

  // ---- 顶部搜索栏 ----
  static const double barHorizontalPadding = 0;
  static const double barTrailingPadding = 10;
  static const double barVerticalPadding = 6;
  static const double backIconSize = 32;
  static const double inputBorderRadius = 22;
  static const double inputBorderWidth = 1.4;
  static const double searchBarHeight = 40;
  static const double inputVerticalPadding = 1;
  static const double searchIconLeftPadding = 12;
  static const double searchIconLeftOffset = 5;
  static const double searchIconToTextGap = 2;
  static const double searchIconVerticalOffset = 0;
  static const CrossAxisAlignment searchIconVerticalAlignment =
      CrossAxisAlignment.center;
  static const bool inputIsDense = true;
  static const double inputHintFontSize = 16;
  static const double prefixIconSize = 24;
  static const double clearIconSize = 18;
  static const double searchButtonFontSize = 16;
  static const FontWeight searchButtonFontWeight = FontWeight.w600;
  static const double searchButtonLeftGap = 8;
  static const double searchButtonMinWidth = 40;
  static const double searchButtonMinHeight = 36;
  static const String inputHint = '输入关键词';
  static const String searchButtonText = '搜索';

  // ---- 搜索历史 ----
  static const String historyTitle = '搜索历史';
  static const double historySectionTopPadding = 0;
  static const double historySectionBottomPadding = 0;
  static const double historySectionHorizontalPadding = 16;
  static const double historyTitleFontSize = 16;
  static const FontWeight historyTitleFontWeight = FontWeight.w600;
  static const double historyClearIconSize = 20;
  static const double historyClearIconAlpha = 0.3;
  static const double historyExpandIconSize = 20;
  static const double historyExpandIconAlpha = 0.35;
  static const double historyDividerWidth = 0;
  static const double historyDividerHeight = 16;
  static const double historyDividerHorizontalMargin = 4;
  static const double historyIconButtonSize = 36;
  static const double historyWrapSpacing = 12;
  static const double historyWrapRunSpacing = 12;
  static const double historyChipHorizontalPadding = 7;
  static const double historyChipVerticalPadding = 8;
  static const double historyChipBorderRadius = 6;
  static const double historyChipFontSize = 14;
  static const double historyChipTextAlpha = 0.85;
  static const double historyTitleChipGap = 14;
  static const int historyCollapseThreshold = 8;
  static const Duration historyExpandAnimationDuration =
      Duration(milliseconds: 200);
}
