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
  static const double cardBodySpacing = 2;
  static const double cardMarginBottom = 28;
  static const double cardLeftMargin = 22;
  static const double cardBorderRadius = 8;
  static const double cardBorderWidth = 1.7;
  static const double cardBorderOpacity = 0.18;   // 卡片边框透明度

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
  static const double idGradientStopTop = 0.0;
  static const double idGradientStopMid = 0.5;
  static const double idGradientStopBottom = 1.0;

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
  static const double expandBtnDotsGap = 2;
  static const double expandRemainGap = 4;   // 展开按钮与 +N 间距
  static const double expandIconSize = 27;
  static const double expandIconCornerRadius = 3;
  static const int expandIconAnimMs = 0;
  static const double expandIconTop = -4;
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
  static const double dotsBgOpacity = 0.09;
  static const double commentBgOpacity = 0.09;   // 回复区域背景透明度
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

  // ---- 下拉刷新 ----
  static const int refreshIndicatorColor = 0xFF0EAB00;            // 刷新圆圈颜色（同贴子ID）
  static const int refreshIndicatorBackgroundColor = 0xFFFFFFFF;  // 刷新背景色（纯白）
  static const double refreshIndicatorDisplacement = 2.0;        // 下拉位移（0=不推内容）
  static const double drawerEdgeDragWidth = 50.0;               // 左滑唤出抽屉灵敏度
  static const int drawerAnimMs = 300;                          // 抽屉动画时长(ms)
  static const int drawerHeaderBgColor = 0xFFE8F5E9;           // 抽屉头部色块背景
  static const double drawerAvatarSize = 56;                    // 抽屉头像大小
  static const double drawerHeaderPaddingLeft = 16;             // 头部左间距
  static const double drawerHeaderPaddingRight = 16;            // 头部右间距
  static const double drawerHeaderPaddingTop = 50;              // 头部上间距
  static const double drawerHeaderPaddingBottom = 20;           // 头部下间距
  static const double drawerAvatarTextGap = 12;                 // 头像与名字间距
  static const double drawerNameFontSize = 16;                  // 名字字号

  static const double settingsBarHeight = 48;                   // 设置页顶部栏高度
  static const double settingsItemFontSize = 16;                 // 设置项字号
  static const double settingsItemHeight = 60;                   // 设置项行高
  static const double settingsArrowRightMargin = 17;             // 箭头距右侧距离
  static const double settingsArrowSize = 21;                    // 箭头图标大小
  static const double settingsColorSwatchSize = 22;              // 颜色展示色块大小

  static const double colorPickerSliderHeight = 230;             // 选色器滑杆高度
  static const double colorPickerSliderWidth = 45;               // 选色器滑杆宽度
  static const double colorPickerSliderGap = 0;                  // 两滑杆间距
  static const double colorPickerAreaGap = 5;                   // 色域与滑杆间距
  
  static const double colorPickerSVSize = 220;                   // 渐变色域大小(正方形边长)

  // ---- 图片查看器操作栏 ----
  static const int overlayActionBarBgColor = 0xE6212121;   // 操作栏背景色（grey[900] 90% 不透明）
  static const int overlayIconColor = 0xFFFFFFFF;          // 操作栏按钮图标色（纯白）
  static const int overlayPageDotColor = 0xFFFFFFFF;       // 页码指示器颜色（纯白）
  static const double overlayPageDotActiveOpacity = 0.9;   // 当前页不透明度
  static const double overlayPageDotInactiveOpacity = 0.4;  // 非当前页不透明度
  static const double overlaySaveToastBgOpacity = 0.0;     // 保存提示弹窗背景透明度

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
  static const int actionBarAnimMs = 80; // 操作栏显示动画时长
  static const int actionBarCloseAnimMs = 80; // 操作栏隐藏动画时长
  static const double actionBarBtnGap = 40; // 两按钮间距

  // ---- 保存提示弹窗 ----
  static const double saveToastRadius = 5; // 弹窗圆角
  static const double saveToastHPadding = 24; // 弹窗水平内边距
  static const double saveToastVPadding = 10; // 弹窗垂直内边距
  static const double saveToastBottomMargin = 112; // 距底部距离
  static const double saveToastFontSize = 14; // 文字大小
  static const int saveToastDurationMs = 1500; // 显示时长
  static const int saveToastAnimMs = 80; // 动画时长

  // ---- 回复 ----
  static const double commentFontSize = 14;          // 回复内容字号
  static const double commentDateFontSize = 14;      // 回复日期字号
  static const double commentAuthorFontSize = 14;    // 回复署名字号
  static const int commentMaxLines = 1000;              // 回复内容最大行数
  static const int commentMaxShown = 3;              // 折叠时最多显示条数
  static const int commentStep = 3;                   // 每次点击 + 增加的条数
  static const double commentLineHeight = 1.4;       // 回复内容行高
  static const double commentVPadding = 0;           // 回复条间距
  static const double commentDateWidth = 46;         // 日期列宽
  static const double commentDateRightMargin = 0;    // 日期右侧间距
  static const double commentAuthorWidth = 52;       // 署名列宽
  static const double commentSectionTopPadding = 2;  // 回复区域内顶部间距
  static const double commentDateLineTopOffset = 9;   // 日期分隔横线竖直偏移
  static const double commentSectionMarginTop = 0;   // 回复区域距上方日期行间距
  static const double commentBgRadius = 4;            // 回复区域背景圆角
  static const double commentBtnSize = 18;            // +/- 按钮大小
  static const double commentBtnGap = 2;             // +/- 按钮间距
  static const double commentRemainFontSize = 12;     // 剩余回复数字号
  static const double commentRemainTopOffset = 0;      // 剩余回复数竖直偏移
  static const double commentRemainBtnGap = 6;         // +N 与 [-] 间距

  static const double pageIndicatorDotSize = 6; // 圆点大小
  static const double pageIndicatorDotGap = 8; // 圆点间距
  static const double pageIndicatorActiveOpacity = 0.9; // 当前页透明度
  static const double pageIndicatorInactiveOpacity = 0.4; // 非当前页透明度
  static const double pageIndicatorBottomMargin = 40; // 距底部距离
  static const int pageIndicatorFadeMs = 80; // 页码指示器消失动画时长
}