import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
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
  final PostCardColors postCard;

  const AppColors({
    required this.postCard,
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

  Map<String, Color> get colors => {
    '背景': background,
    '卡片背景': surface,
    '主文字': onSurface,
    '次要文字': secondary,
    '作者署名': authorColor,
    '强调文字': accentText,
    '按钮': buttonBg,
    '绿色': green,
    '附件': attachment,
    '分割线': divider,
    '尾部图标': trailingIcon,
    '箭头图标': arrowIcon,
    '栏文字': barText,
    '展开按钮激活': expandIconActive,
    '开关激活': switchActive,
    '边框': borderColor,
    '帖子ID': idTint,
    '抽屉头部背景': drawerHeaderBg,
    '操作栏背景': overlayActionBarBg,
    '操作栏图标': overlayIcon,
    '页码点': overlayPageDot,
  };

  static const light = AppColors(
    postCard: PostCardColors.light,
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF333333),
    secondary: Color(0xFF747474),
    authorColor: Color(0xFF2F68C5),
    accentText: Color(0xFF33B1FF),
    buttonBg: Color(0xFF2CAEFF),
    green: Color(0xFF7BB380),
    attachment: Color(0xFF545FFF),
    divider: Color(0xFFE0E0E0),
    trailingIcon: Color(0xFF9E9E9E),
    arrowIcon: Color(0x8A000000),
    barText: Color(0xDD000000),
    expandIconActive: Color(0xFF3B82F6),
    switchActive: Color(0xFF0EAB00),
    borderColor: Color(0xFF999999),
    idTint: Color(0xFF0EAB00),
    drawerHeaderBg: Color(0xFFE8F5E9),
    overlayActionBarBg: Color(0xE6212121),
    overlayIcon: Color(0xFFFFFFFF),
    overlayPageDot: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    postCard: PostCardColors.dark,
    background: Color(0xFF191919),
    surface: Color(0xFF222222),
    onSurface: Color(0xFFd3d3d3),
    secondary: Color(0x70999999),
    authorColor: Color(0xFF2F68C5),
    accentText: Color(0xBA5498FF),
    buttonBg: Color(0xFF2693FF),
    green: Color(0xFF7BB380),
    attachment: Color(0xFF616BFF),
    divider: Color(0xFF424242),
    trailingIcon: Color(0xFF757575),
    arrowIcon: Color(0x8AFFFFFF),
    barText: Color(0xDDFFFFFF),
    expandIconActive: Color(0xFF3B82F6),
    switchActive: Color(0xFF0EAB00),
    borderColor: Color(0xFF444444),
    idTint: Color(0xFF0EAB00),
    drawerHeaderBg: Color(0xFF1B2E1F),
    overlayActionBarBg: Color(0xE6212121),
    overlayIcon: Color(0xFFFFFFFF),
    overlayPageDot: Color(0xFFFFFFFF),
  );

  @override
  AppColors copyWith({
    PostCardColors? postCard,
    Color? background, Color? surface, Color? onSurface,
    Color? secondary, Color? authorColor, Color? accentText, Color? green,
    Color? buttonBg, Color? expandIconActive, Color? switchActive,
    Color? borderColor, Color? divider,
    Color? trailingIcon, Color? arrowIcon, Color? barText,
    Color? attachment,
    Color? idTint, Color? drawerHeaderBg,
    Color? overlayActionBarBg, Color? overlayIcon, Color? overlayPageDot,
  }) {
    return AppColors(
      postCard: postCard ?? this.postCard,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      secondary: secondary ?? this.secondary,
      authorColor: authorColor ?? this.authorColor,
      accentText: accentText ?? this.accentText,
      green: green ?? this.green,
      buttonBg: buttonBg ?? this.buttonBg,
      expandIconActive: expandIconActive ?? this.expandIconActive,
      switchActive: switchActive ?? this.switchActive,
      borderColor: borderColor ?? this.borderColor,
      divider: divider ?? this.divider,
      trailingIcon: trailingIcon ?? this.trailingIcon,
      arrowIcon: arrowIcon ?? this.arrowIcon,
      barText: barText ?? this.barText,
      attachment: attachment ?? this.attachment,
      idTint: idTint ?? this.idTint,
      drawerHeaderBg: drawerHeaderBg ?? this.drawerHeaderBg,
      overlayActionBarBg: overlayActionBarBg ?? this.overlayActionBarBg,
      overlayIcon: overlayIcon ?? this.overlayIcon,
      overlayPageDot: overlayPageDot ?? this.overlayPageDot,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      postCard: t < 0.5 ? postCard : other.postCard,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      authorColor: Color.lerp(authorColor, other.authorColor, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      green: Color.lerp(green, other.green, t)!,
      buttonBg: Color.lerp(buttonBg, other.buttonBg, t)!,
      expandIconActive: Color.lerp(expandIconActive, other.expandIconActive, t)!,
      switchActive: Color.lerp(switchActive, other.switchActive, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      trailingIcon: Color.lerp(trailingIcon, other.trailingIcon, t)!,
      arrowIcon: Color.lerp(arrowIcon, other.arrowIcon, t)!,
      barText: Color.lerp(barText, other.barText, t)!,
      attachment: Color.lerp(attachment, other.attachment, t)!,
      idTint: Color.lerp(idTint, other.idTint, t)!,
      drawerHeaderBg: Color.lerp(drawerHeaderBg, other.drawerHeaderBg, t)!,
      overlayActionBarBg: Color.lerp(overlayActionBarBg, other.overlayActionBarBg, t)!,
      overlayIcon: Color.lerp(overlayIcon, other.overlayIcon, t)!,
      overlayPageDot: Color.lerp(overlayPageDot, other.overlayPageDot, t)!,
    );
  }
}

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
    required this.idTint,
    required this.idErrorFallback,
  });

  static const light = PostCardColors(
    cardBorder: Color(0x2E999999), bodyDivider: Color(0x2E999999),
    title: Color(0xFF333333), content: Color(0xFF333333),
    dateText: Color(0xFF747474), remainCount: Color(0xFF747474),
    authorName: Color(0xFF2F68C5), atSymbol: Color(0xFF7BB380),
    attachmentText: Color(0xFF545FFF),
    commentContent: Color(0xFF333333), commentAuthor: Color(0xFF2F68C5),
    commentDate: Color(0xFF747474), commentRemain: Color(0xFF747474),
    commentBg: Color(0x17747474), commentIcon: Color(0xFF747474),
    commentDateSeparatorLine: Color(0x4D747474),
    expandIconBlue: Color(0xFF3B82F6), expandIconGray: Color(0x21747474),
    dotsButtonBg: Color(0x17747474),
    idTint: Color(0x810EAB00), idErrorFallback: Color(0xFFF44336),
  );

  static const dark = PostCardColors(
    cardBorder: Color(0x39AEAEAE), bodyDivider: Color(0x2EFF0000),
    title: Color(0xFFd3d3d3), content: Color(0xFFd3d3d3),
    dateText: Color(0xFF8B8B8B), remainCount: Color(0x70999999),
    authorName: Color(0xE378B0FF), atSymbol: Color(0xB57AFF85),
    attachmentText: Color(0xFF616BFF),
    commentContent: Color(0xFFd3d3d3), commentAuthor: Color(0xE378B0FF),
    commentDate: Color(0xFF8B8B8B), commentRemain: Color(0xA5999999),
    commentBg: Color(0xFF282828), commentIcon: Color(0xA5999999),
    commentDateSeparatorLine: Color(0x4D5F5D60),
    expandIconBlue: Color(0xFF326CCA), expandIconGray: Color(0xFF3C3C3C),
    dotsButtonBg: Color(0xFF3C3C3C),
    idTint: Color(0xFF509E49), idErrorFallback: Color(0xFFF44336),
  );
}
