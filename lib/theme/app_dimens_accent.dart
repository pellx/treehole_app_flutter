/// 用户页（UserPage）专用尺寸常量
///
/// 与 AppDimens 的设置页风格保持一致，独立成文件便于单独调整。
class AccentDimens {
  AccentDimens._();

  // ── 顶部栏（与颜色模式页同款） ──
  static const double barHeight = 48;          // 顶栏高度
  static const double barTitleFontSize = 17;   // 顶栏标题字号
  static const double barTrailingWidth = 48;   // 标题右侧占位宽度（平衡返回按钮）

  // ── 页面整体 ──
  static const double pagePadding = 16;        // ListView 四周留白
  static const double dividerThickness = 0.5;  // 分隔线粗细

  /// 每行最右侧元素距行右边缘的默认基准（跳转箭头等）
  static const double rowRightInset = 17;

  // ── 各最右侧元素独立的右侧距离（默认与 rowRightInset 一致，可单独调整） ──
  static const double copyIconRightInset = 19;   // 复制图标距右
  static const double dotRightInset = 22;        // 状态圆点距右
  static const double changeButtonRightInset = 17; // 更改/提交按钮距右

  // ── 头像 + ID 行 ──
  static const double avatarIdRowVPadding = 10; // 行上下留白
  static const double avatarLeftInset = 15;      // 头像距行左边缘距离
  static const double avatarRadius = 28;        // 头像半径
  static const double avatarIdGap = 12;         // 头像与 ID 间距
  static const double idFontSize = 16;          // ID 字号
  static const double idButtonGap = 12;         // ID 与按钮间距
  static const double nameInputVPadding = 6;    // 编辑态输入框上下内边距
  static const double nameInputUnderlineWidth = 1;   // 输入框下划线粗细
  static const double nameInputUnderlineAlpha = 0.3; // 未聚焦下划线透明度
  static const int    nameMaxLength = 100;      // ID 最大长度

  // ── 更改/提交按钮（样式同发帖页发布按钮可点击态） ──
  static const double buttonHeight = 24;        // 按钮高度
  static const double buttonRadius = 8;         // 按钮圆角
  static const double buttonHPadding = 6;      // 按钮水平内边距
  static const double buttonFontSize = 14;      // 按钮字号
  static const double buttonBgAlpha = 0.6;    // 「更改」态背景透明度（0~1）
  static const double buttonTextAlpha = 1.0;  // 「更改」态文字透明度（0~1）
  static const double buttonSubmitBgAlpha = 1.0;   // 「提交」态背景透明度
  static const double buttonSubmitTextAlpha = 1.0; // 「提交」态文字透明度
  static const double submitSpinnerSize = 13;   // 提交中转圈尺寸
  static const double submitSpinnerStroke = 2;  // 转圈线宽

  // ── 错误提示 ──
  static const double errorFontSize = 13;       // 错误文字字号
  static const double errorBottomPadding = 8;   // 错误文字下方间距

  // ── 列表行（与设置页一致） ──
  static const double itemHeight = 60;          // 行高
  static const double itemFontSize = 16;        // 行标签字号

  // ── 用户令牌行 ──
  static const int    tokenHeadChars = 4;        // token 显示开头字符数
  static const int    tokenTailChars = 4;        // token 显示结尾字符数（中间以 ... 隐藏）
  static const double tokenValueFontSize = 14;   // token 文本字号
  static const double tokenValueAlpha = 0.6;     // token 文本透明度
  static const double tokenCopyIconSize = 14;    // 复制图标大小
  static const double tokenCopyIconGap = 12;      // token 与图标间距
  static const double tokenCopyIconAlpha = 0.8;  // 复制图标透明度

  // ── 更改令牌行 ──
  static const double lastChangedFontSize = 13;  // 上次更改时间字号
  static const double lastChangedAlpha = 0.5;    // 时间文本透明度
  static const double changeableDotSize = 10;    // 可更改状态圆点直径
  static const double changeableDotGap = 12;      // 时间与圆点间距

  // ── 更改令牌确认弹窗 ──
  static const double dialogRadius = 12;           // 弹窗圆角
  static const double dialogPadding = 24;          // 弹窗内边距
  static const double dialogMessageFontSize = 16;  // 正文字号
  static const double dialogMessageLineHeight = 1.5; // 正文行高
  static const double dialogActionsTopGap = 20;    // 正文与按钮间距
  static const double dialogActionGap = 20;        // 取消/确认间距
  static const double dialogActionHeight = 36;     // 按钮高度
  static const double dialogActionRadius = 8;      // 按钮圆角
  static const double dialogActionHPadding = 10;   // 按钮水平内边距
  static const double dialogActionFontSize = 15;   // 按钮字号
  static const double dialogCancelTextAlpha = 0.6; // 取消文字透明度

  // ── 跳转行箭头 ──
  static const double arrowSize = 21;            // 箭头图标大小

  // ── 设备绑定卡片 ──
  static const double deviceCardRadius = 12;       // 卡片圆角
  static const double deviceCardPadding = 13;      // 卡片内边距
  static const double deviceCardGap = 18;          // 卡片间距
  static const double deviceCardBorderWidth = 0.5; // 边框粗细
  static const double deviceCardTitleSize = 16;    // 显示名称字号
  static const double deviceCardMetaSize = 13;     // 参数字号
  static const double deviceCardMetaAlpha = 0.65;  // 参数文字透明度
  static const double deviceCardMetaGap = 6;       // 参数行间距
  static const double deviceCardMetaColGap = 0;    // 同一行两参数间距
  static const double deviceCardTitleBottom = 6;  // 设备名到参数间距
  static const double deviceCardMetaLeftInset = 10; // 参数相对卡片内容左侧间距
  static const double deviceCardIconSize = 22;     // 左侧设备图标
  static const double deviceCardIconGap = 5;      // 图标与文字间距
  static const double deviceCardIconTopInset = 8;  // 设备图标竖直偏移（负值向上）
  static const double deviceCardRenameGap = -3;    // 名称与改名图标间距（负值向左）
  static const double deviceCardRenameSize = 17;   // 改名笔图标大小
  static const double deviceCardRenameAlpha = 0.55; // 改名笔图标透明度
  static const double deviceCardDeleteSize = 21;   // 删除垃圾桶图标大小
  static const double deviceCardDeleteTopInset = -4; // 删除按钮距最上端（负值向上）
  static const double deviceCardUnbindTimeSize = 12; // 解绑预计时间字号
  static const double deviceCardUnbindTimeAlpha = 0.5; // 解绑预计时间透明度
  static const double deviceCardUnbindTimeGap = 6;  // 时间与删除/取消按钮间距
  static const double deviceCardCancelFontSize = 13; // 「取消」文字字号
}
