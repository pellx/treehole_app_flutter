import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens_accent.dart';

/// 账户切换列表项展示数据
class AccountCardData {
  final int bindingId;
  final int deviceId;
  final String status;
  /// 昵称 / 显示 ID
  final String displayId;
  final DateTime? createdAt;
  /// 完整或缓存预览用 token（展示时一律遮罩）
  final String userToken;
  /// 是否为当前登录账户
  final bool isCurrent;

  const AccountCardData({
    required this.bindingId,
    required this.deviceId,
    this.status = 'active',
    required this.displayId,
    this.createdAt,
    required this.userToken,
    this.isCurrent = false,
  });
}

/// 账户卡片：上行昵称 + 注册时间，下行遮罩 token；整卡可点切换
class AccountCard extends StatelessWidget {
  final AccountCardData data;
  final VoidCallback? onTap;

  const AccountCard({
    super.key,
    required this.data,
    this.onTap,
  });

  static String maskToken(String token) {
    const head = AccentDimens.tokenHeadChars;
    const tail = AccentDimens.tokenTailChars;
    if (token.isEmpty) return '未知';
    if (token.length > head + tail) {
      return '${token.substring(0, head)}...${token.substring(token.length - tail)}';
    }
    return token;
  }

  static String formatCreatedAt(DateTime? at) {
    if (at == null) return '未知';
    final local = at.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final metaStyle = TextStyle(
      fontSize: AccentDimens.deviceCardMetaSize,
      height: 1.35,
      color: onSurface.withValues(alpha: AccentDimens.deviceCardMetaAlpha),
    );
    final titleStyle = TextStyle(
      fontSize: AccentDimens.deviceCardTitleSize,
      color: onSurface,
      fontWeight: FontWeight.w500,
    );

    return Material(
      color: colors.common.surface,
      borderRadius: BorderRadius.circular(AccentDimens.deviceCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AccentDimens.deviceCardRadius),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AccentDimens.deviceCardRadius),
            border: Border.all(
              color: colors.common.divider,
              width: AccentDimens.deviceCardBorderWidth,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(AccentDimens.deviceCardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.displayId,
                            style: titleStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(
                            width: AccentDimens.deviceCardMetaColGap + 8),
                        Text(formatCreatedAt(data.createdAt),
                            style: metaStyle),
                      ],
                    ),
                    const SizedBox(height: AccentDimens.deviceCardTitleBottom),
                    Text(
                      maskToken(data.userToken),
                      style: TextStyle(
                        fontSize: AccentDimens.tokenValueFontSize,
                        color: onSurface.withValues(
                            alpha: AccentDimens.tokenValueAlpha),
                      ),
                    ),
                  ],
                ),
              ),
              if (data.isCurrent)
                Positioned(
                  right: AccentDimens.accountCardCurrentDotRight,
                  bottom: AccentDimens.accountCardCurrentDotBottom,
                  child: Container(
                    width: AccentDimens.accountCardCurrentDotSize,
                    height: AccentDimens.accountCardCurrentDotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.common.green,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
