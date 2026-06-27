import 'package:flutter/material.dart';

// ============================================================
//  CommonColors — 全局通用颜色
// ============================================================
class CommonColors {
  final Color background;
  final Color surface;
  final Color onSurface;
  final Color secondary;
  final Color authorColor;
  final Color accentText;
  final Color buttonBg;
  final Color green;
  final Color attachment;
  final Color divider;
  final Color trailingIcon;
  final Color arrowIcon;
  final Color barText;
  final Color expandIconActive;
  final Color switchActive;
  final Color borderColor;
  final Color idTint;
  final Color drawerHeaderBg;
  final Color overlayActionBarBg;
  final Color overlayIcon;
  final Color overlayPageDot;

  const CommonColors({
    required this.background,
    required this.surface,
    required this.onSurface,
    required this.secondary,
    required this.authorColor,
    required this.accentText,
    required this.buttonBg,
    required this.green,
    required this.attachment,
    required this.divider,
    required this.trailingIcon,
    required this.arrowIcon,
    required this.barText,
    required this.expandIconActive,
    required this.switchActive,
    required this.borderColor,
    required this.idTint,
    required this.drawerHeaderBg,
    required this.overlayActionBarBg,
    required this.overlayIcon,
    required this.overlayPageDot,
  });
}

// ============================================================
//  PostCardColors — 帖子卡片专属颜色
// ============================================================
class PostCardColors {
  final Color cardBorder;
  final Color bodyDivider;
  final Color title;
  final Color content;
  final Color dateText;
  final Color remainCount;
  final Color authorName;
  final Color atSymbol;
  final Color attachmentText;
  final Color commentContent;
  final Color commentAuthor;
  final Color commentDate;
  final Color commentRemain;
  final Color commentBg;
  final Color commentIcon;
  final Color commentDateSeparatorLine;
  final Color expandIconBlue;
  final Color expandIconGray;
  final Color dotsButtonBg;
  final Color actionMenuBg;      // 操作菜单背景
  final Color actionBtnText;     // 操作按钮文字
  final Color idTint;
  final Color idErrorFallback;

  const PostCardColors({
    required this.cardBorder,
    required this.bodyDivider,
    required this.title,
    required this.content,
    required this.dateText,
    required this.remainCount,
    required this.authorName,
    required this.atSymbol,
    required this.attachmentText,
    required this.commentContent,
    required this.commentAuthor,
    required this.commentDate,
    required this.commentRemain,
    required this.commentBg,
    required this.commentIcon,
    required this.commentDateSeparatorLine,
    required this.expandIconBlue,
    required this.expandIconGray,
    required this.dotsButtonBg,
    required this.actionMenuBg,
    required this.actionBtnText,
    required this.idTint,
    required this.idErrorFallback,
  });
}

// ============================================================
//  PostCreateColors — 发布页专属颜色
// ============================================================
class PostCreateColors {
  // ---- 页面背景 ----
  final Color pageBg;
  final Color fieldBg;
  final Color divider;

  // ---- 顶部栏 ----
  final Color topBarBg;

  // ---- Floating label（标题）----
  final Color titleLabelRest;
  final Color titleLabelFloat;

  // ---- Floating label（内容）----
  final Color contentLabelRest;
  final Color contentLabelFloat;

  // ---- 预览区 ----
  final Color previewDivider;

  // ---- 上传按钮 ----
  final Color uploadBtnBorder;
  final Color uploadBtnIcon;

  // ---- 删除按钮 ----
  final Color deleteBtnBorder;
  final Color deleteBtnIcon;

  // ---- 展开按钮 ----
  final Color expandBtnBorder;
  final Color expandBtnIcon;

  // ---- 署名按钮（未启用）----
  final Color authorIcon;
  final Color authorBorder;

  // ---- 署名按钮（启用）----
  final Color authorActiveFill;
  final Color authorActiveIcon;

  // ---- 发布按钮 ----
  final Color submitBg;
  final Color submitText;

  // ---- 右下角入口按钮 ----
  final Color buttonBg;
  final Color buttonIcon;

  // ---- 内容展开覆盖层 ----
  final Color contentOverlay;
  final Color contentCollapseIcon;

  const PostCreateColors({
    required this.pageBg,
    required this.fieldBg,
    required this.divider,
    required this.topBarBg,
    required this.titleLabelRest,
    required this.titleLabelFloat,
    required this.contentLabelRest,
    required this.contentLabelFloat,
    required this.previewDivider,
    required this.uploadBtnBorder,
    required this.uploadBtnIcon,
    required this.deleteBtnBorder,
    required this.deleteBtnIcon,
    required this.expandBtnBorder,
    required this.expandBtnIcon,
    required this.authorIcon,
    required this.authorBorder,
    required this.authorActiveFill,
    required this.authorActiveIcon,
    required this.submitBg,
    required this.submitText,
    required this.buttonBg,
    required this.buttonIcon,
    required this.contentOverlay,
    required this.contentCollapseIcon,
  });
}

// ============================================================
//  AppColors — 主题扩展（聚合以上三类颜色，注册到 MaterialApp）
// ============================================================
class AppColors extends ThemeExtension<AppColors> {
  final CommonColors common;
  final PostCardColors postCard;
  final PostCreateColors postCreate;

  const AppColors({
    required this.common,
    required this.postCard,
    required this.postCreate,
  });

  @override
  AppColors copyWith({
    CommonColors? common,
    PostCardColors? postCard,
    PostCreateColors? postCreate,
  }) {
    return AppColors(
      common: common ?? this.common,
      postCard: postCard ?? this.postCard,
      postCreate: postCreate ?? this.postCreate,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      common: t < 0.5 ? common : other.common,
      postCard: t < 0.5 ? postCard : other.postCard,
      postCreate: t < 0.5 ? postCreate : other.postCreate,
    );
  }

// ============================================================
//  具体颜色值 — light / dark 成对排列
// ============================================================

// ---- CommonColors ----

static const commonLight = CommonColors(
  background:             Color(0xFFFFFFFF),
  surface:                Color(0xFFFFFFFF),
  onSurface:              Color(0xFF333333),
  secondary:              Color(0xFF747474),
  authorColor:            Color(0xFF2F68C5),
  accentText:             Color(0xFF33B1FF),
  buttonBg:               Color(0xFF2CAEFF),
  green:                  Color(0xFF7BB380),
  attachment:             Color(0xFF545FFF),
  divider:                Color(0xFFE0E0E0),
  trailingIcon:           Color(0xFF9E9E9E),
  arrowIcon:              Color(0x8A000000),
  barText:                Color(0xDD000000),
  expandIconActive:       Color(0xFF3B82F6),
  switchActive:           Color(0xFF0EAB00),
  borderColor:            Color(0xFF999999),
  idTint:                 Color(0xFF0EAB00),
  drawerHeaderBg:         Color(0xFFE8F5E9),
  overlayActionBarBg:     Color(0xE6212121),
  overlayIcon:            Color(0xFFFFFFFF),
  overlayPageDot:         Color(0xFFFFFFFF),
);

static const commonDark = CommonColors(
  background:             Color(0xFF191919),
  surface:                Color(0xFF222222),
  onSurface:              Color(0xFFd3d3d3),
  secondary:              Color(0x70999999),
  authorColor:            Color(0xFF2F68C5),
  accentText:             Color(0xBA5498FF),
  buttonBg:               Color(0xFF2693FF),
  green:                  Color(0xFF7BB380),
  attachment:             Color(0xFF616BFF),
  divider:                Color(0xFF424242),
  trailingIcon:           Color(0xFF757575),
  arrowIcon:              Color(0x8AFFFFFF),
  barText:                Color(0xDDFFFFFF),
  expandIconActive:       Color(0xFF3B82F6),
  switchActive:           Color(0xFF0EAB00),
  borderColor:            Color(0xFF444444),
  idTint:                 Color(0xFF0EAB00),
  drawerHeaderBg:         Color(0xFF1B2E1F),
  overlayActionBarBg:     Color(0xE6212121),
  overlayIcon:            Color(0xFFFFFFFF),
  overlayPageDot:         Color(0xFFFFFFFF),
);

// ---- PostCardColors ----

static const postCardLight = PostCardColors(
  cardBorder:             Color(0x2E999999),
  bodyDivider:            Color(0x2E999999),
  title:                  Color(0xFF333333),
  content:                Color(0xFF333333),
  dateText:               Color(0xFF747474),
  remainCount:            Color(0xFF747474),
  authorName:             Color(0xFF2F68C5),
  atSymbol:               Color(0xFF7BB380),
  attachmentText:         Color(0xFF545FFF),
  commentContent:         Color(0xFF333333),
  commentAuthor:          Color(0xFF2F68C5),
  commentDate:            Color(0xFF747474),
  commentRemain:          Color(0xFF747474),
  commentBg:              Color(0x17747474),
  commentIcon:            Color(0xFF747474),
  commentDateSeparatorLine: Color(0x4D747474),
  expandIconBlue:         Color(0xFF3B82F6),
  expandIconGray:         Color(0x21747474),
  dotsButtonBg:           Color(0x17747474),
  actionMenuBg:           Color(0x17747474),
  actionBtnText:          Color(0xFF333333),
  idTint:                 Color(0x810EAB00),
  idErrorFallback:        Color(0xFFF44336),
);

static const postCardDark = PostCardColors(
  cardBorder:             Color(0x39AEAEAE),
  bodyDivider:            Color(0x2EFF0000),
  title:                  Color(0xFFd3d3d3),
  content:                Color(0xFFd3d3d3),
  dateText:               Color(0xFF8B8B8B),
  remainCount:            Color(0x70999999),
  authorName:             Color(0xE378B0FF),
  atSymbol:               Color(0xB57AFF85),
  attachmentText:         Color(0xFF616BFF),
  commentContent:         Color(0xFFd3d3d3),
  commentAuthor:          Color(0xE378B0FF),
  commentDate:            Color(0xFF8B8B8B),
  commentRemain:          Color(0xA5999999),
  commentBg:              Color(0xFF282828),
  commentIcon:            Color(0xA5999999),
  commentDateSeparatorLine: Color(0x4D5F5D60),
  expandIconBlue:         Color(0xFF326CCA),
  expandIconGray:         Color(0xFF3C3C3C),
  dotsButtonBg:           Color(0xFF3C3C3C),
  actionMenuBg:           Color(0xFF3C3C3C),
  actionBtnText:          Color(0xFFd3d3d3),
  idTint:                 Color(0xFF509E49),
  idErrorFallback:        Color(0xFFF44336),
);

// ---- PostCreateColors ----

static const postCreateLight = PostCreateColors(
  pageBg:                 Color(0xFFF5F5F5),
  fieldBg:                Color(0xFFFFFFFF),
  divider:                Color(0xFFEEEEEE),
  topBarBg:               Color(0xFFD5F2D7),
  titleLabelRest:         Color(0xB1000000),
  titleLabelFloat:        Color(0xFFBBBBBB),
  contentLabelRest:       Color(0xB1000000),
  contentLabelFloat:      Color(0xFFBBBBBB),
  previewDivider:         Color(0xFFE8E8E8),
  uploadBtnBorder:        Color(0xFF67BDFF),
  uploadBtnIcon:          Color(0xFF1D81CD),
  deleteBtnBorder:        Color(0xFFFF8383),
  deleteBtnIcon:          Color(0xFFDF2323),
  expandBtnBorder:        Color(0xFF67BDFF),
  expandBtnIcon:          Color(0xFF1D81CD),
  authorIcon:             Color(0xFF626262),
  authorBorder:           Color(0xFF626262),
  authorActiveFill:       Color(0xFF00CC62),
  authorActiveIcon:       Color(0xFFFFFFFF),
  submitBg:               Color(0xFF00CC62),
  submitText:             Color(0xFFFFFFFF),
  buttonBg:               Color(0xFF2CAEFF),
  buttonIcon:             Color(0xFFFFFFFF),
  contentOverlay:         Color(0xFF000000),
  contentCollapseIcon:    Color(0xFF666666),
);

static const postCreateDark = PostCreateColors(
  pageBg:                 Color(0xFF1A1A1A),
  fieldBg:                Color(0xFF2A2A2A),
  divider:                Color(0xFF3A3A3A),
  topBarBg:               Color(0xFF1B2E1F),
  titleLabelRest:         Color(0xB1FFFFFF),
  titleLabelFloat:        Color(0xFFAAAAAA),
  contentLabelRest:       Color(0xB1FFFFFF),
  contentLabelFloat:      Color(0xFFAAAAAA),
  previewDivider:         Color(0xFF3A3A3A),
  uploadBtnBorder:        Color(0xFF67BDFF),
  uploadBtnIcon:          Color(0xFF1D81CD),
  deleteBtnBorder:        Color(0xFFCC6A6A),
  deleteBtnIcon:          Color(0xFFDF2323),
  expandBtnBorder:        Color(0xFF67BDFF),
  expandBtnIcon:          Color(0xFF1D81CD),
  authorIcon:             Color(0xFFAAAAAA),
  authorBorder:           Color(0xFFAAAAAA),
  authorActiveFill:       Color(0xFF00CC62),
  authorActiveIcon:       Color(0xFFFFFFFF),
  submitBg:               Color(0xFF00CC62),
  submitText:             Color(0xFFFFFFFF),
  buttonBg:               Color(0xFF2693FF),
  buttonIcon:             Color(0xFFFFFFFF),
  contentOverlay:         Color(0xFF000000),
  contentCollapseIcon:    Color(0xFFAAAAAA),
);

// ---- AppColors ----

  static const light = AppColors(
    common: commonLight,
    postCard: postCardLight,
    postCreate: postCreateLight,
  );

  static const dark = AppColors(
    common: commonDark,
    postCard: postCardDark,
    postCreate: postCreateDark,
  );
}
