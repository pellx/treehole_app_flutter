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
  static const double pageSnapStiffness = 300; // 切页弹簧刚度（越大越快）
  static const double pageSnapDampingRatio = 1.4; // 切页阻尼比（0.9=稍有回弹, 1.0=临界无回弹, 1.1=柔和减速）
  static const double bounceMass = 0.2; // 溢出回弹弹簧质量（越小越快）
  static const double bounceStiffness = 300; // 溢出回弹弹簧刚度（越大越快）
  static const double bounceDampingRatio = 1.4; // 溢出回弹阻尼比
}