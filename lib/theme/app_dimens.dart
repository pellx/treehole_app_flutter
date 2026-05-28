class AppDimens {
  const AppDimens._();

  // ---- 间距 ----
  static const double spacingXs = 2;
  static const double paddingXs = 2;
  static const double paddingSm = 4;
  static const double paddingMd = 8;
  static const double paddingLg = 4;
  static const double paddingXl = 24;

  // ---- 帖子卡片 ----
  static const double cardHPadding = 7;
  static const double cardContentLeft = 7;
  static const double cardImageTop = 2;
  static const double cardImageBottom = 7;
  static const double cardBodySpacing = 5;
  static const double cardMarginBottom = 23;
  static const double cardLeftMargin = 22;
  static const double cardBorderRadius = 8;
  static const double cardBorderWidth = 1.7;

  // ---- 标题区域 ----
  static const double titleVPadding = 3;
  static const double idTitleGap = 8;

  // ---- 装饰引号 ----
  static const double quoteTop = -20;
  static const double quoteLeft = -22;
  static const double quoteBottom = -10;
  static const double quoteRight = -21;
  static const double quoteOpacity = 0.4;

  // ---- 帖子 ID ----
  static const double idRight = -32;
  static const double idTop = -2;
  static const double idOpacity = 0.36;
  static const double idImageHeight = 32;
  static const double idImageOverlap = 15;
  static const double idDigitWidth = 23;
  static const bool idVertical = true;
  static const int idGradientTop = 0xD10EAB00;
  static const int idGradientMid = 0x770E7799;
  static const int idGradientBottom = 0x000EAB00;
  static const double idGradientStopTop = 0.0;
  static const double idGradientStopMid = 0.5;
  static const double idGradientStopBottom = 1.0;
  static const int idTintColor = 0xFF0EAB00;

  // ---- 文字 ----
  static const double fontSizeQuote = 57;
  static const double fontSizeId = 40;
  static const double fontSizeTitle = 18;
  static const double fontSizeAt = 15;
  static const double fontSizeContent = 15;
  static const double fontSizeAuthor = 18;
  static const double titleAuthorMaxWidth = 282;
  static const double authorAtGap = 3;
  static const double fontSizeSmall = 14;

  // ---- 内容 ----
  static const int contentMaxLength = 256;

  // ---- 缩略图 ----
  static const double singleImageMaxArea = 40000;
  static const double singleImageMinRatio = 0.25;
  static const double singleImageMaxRatio = 4.0;
  static const double gridImageSize = 92;
  static const double thumbnailGap = 4;

  // ---- 展开/收起按钮 ----
  static const double expandBtnDotsGap = 10;
  static const double expandIconSize = 27;
  static const double expandIconCornerRadius = 3;
  static const int expandIconAnimMs = 0;
  static const double expandIconTop = -4;
  static const int expandIconColorBlue = 0xFF3B82F6;
  static const double expandIconGrayAlpha = 0.13;

  // ---- 内容文字 ----
  static const double contentLineHeight = 1.5;

  // ---- 两个点按钮 ----
  static const double dotsBtnWidth = 26;
  static const double dotsBtnHeight = 15;
  static const double dotsBtnRadius = 4;
  static const double dotsBtnBorderWidth = 0.5;
  static const double dotsFontSize = 18;
  static const double dotsGap = -20;
  static const double dotsTopPadding = -5.2;
  static const double dotsLeftPadding = 5;
  static const double dotsRightPadding = 5;
  static const double dotsBgOpacity = 0.13;
  static const double dotsPositionedRight = 1;
  static const double dotsPositionedTop = 2;

  // ---- 时间行 ----
  static const double dateRowTopSpacing = 2;
  static const double dateRowBottomSpacing = 2;

  // ---- 列表 ----
  static const double listPaddingLeft = 12;
  static const double listPaddingTop = 24;
  static const double listPaddingRight = 12;
  static const double listPaddingBottom = 40;

  // ---- 加载动画 ----
  static const double loadingGifSize = 40;
  static const double loadingGifThumbSize = 24;

  // ---- 图片查看器动画 ----
  static const int imageExpandMs = 250; // 打开/关闭伸缩动画时长
  static const int imageFadeMs = 500; // WebP 淡出时长
  static const double pageSnapMass = 0.2; // 切页弹簧质量（越小越快）
  static const double pageSnapStiffness = 100; // 切页弹簧刚度（越大越快）
  static const double pageSnapDampingRatio = 1.4; // 切页阻尼比（0.9=稍有回弹, 1.0=临界无回弹, 1.1=柔和减速）
  static const double bounceMass = 0.2; // 溢出回弹弹簧质量（越小越快）
  static const double bounceStiffness = 300; // 溢出回弹弹簧刚度（越大越快）
  static const double bounceDampingRatio = 1.4; // 溢出回弹阻尼比

  // ---- 长按操作栏 ----
  static const double actionBarHeight = 48; // 操作栏高度
  static const double actionBarRadius = 12; // 操作栏圆角
  static const double actionBarBottomMargin = 60; // 距底部距离
  static const double actionBarBtnSize = 28; // 按钮图标大小
  static const int actionBarAnimMs = 80; // 操作栏显示/隐藏动画时长
  static const double actionBarBtnGap = 40; // 两按钮间距

  // ---- 保存提示弹窗 ----
  static const double saveToastRadius = 5; // 弹窗圆角
  static const double saveToastHPadding = 24; // 弹窗水平内边距
  static const double saveToastVPadding = 10; // 弹窗垂直内边距
  static const double saveToastBottomMargin = 112; // 距底部距离
  static const double saveToastFontSize = 14; // 文字大小
  static const int saveToastDurationMs = 1500; // 显示时长
  static const int saveToastAnimMs = 80; // 动画时长

  // ---- 页码指示器 ----
  static const double pageIndicatorDotSize = 6; // 圆点大小
  static const double pageIndicatorDotGap = 8; // 圆点间距
  static const double pageIndicatorActiveOpacity = 0.9; // 当前页透明度
  static const double pageIndicatorInactiveOpacity = 0.4; // 非当前页透明度
  static const double pageIndicatorBottomMargin = 40; // 距底部距离
  static const int pageIndicatorFadeMs = 80; // 页码指示器消失动画时长
}