import 'package:flutter/material.dart';

import '../models/version_info.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

class VersionCard extends StatelessWidget {
  final VersionInfo version;
  final bool isLatest;
  final VoidCallback? onTap;

  const VersionCard({super.key, required this.version, this.isLatest = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
      padding: EdgeInsets.only(bottom: AppDimens.versionCardBottomMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Padding(
                padding: EdgeInsets.only(left: AppDimens.versionCardVersionPaddingLeft),
                child: Text(
                  'v${version.versionNumber}',
                  style: TextStyle(
                    fontSize: AppDimens.versionCardVersionFontSize,
                    fontWeight: FontWeight.bold,
                    color: colors.versionCard.version,
                  ),
                ),
              ),
              if (isLatest) ...[
                SizedBox(width: AppDimens.versionCardBadgeGap),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDimens.versionCardBadgeHPadding,
                    vertical: AppDimens.versionCardBadgeVPadding,
                  ),
                  decoration: BoxDecoration(
                    color: colors.versionCard.badgeBg,
                    borderRadius: BorderRadius.circular(AppDimens.versionCardBadgeRadius),
                  ),
                  child: Text(
                    'New',
                    style: TextStyle(
                      fontSize: AppDimens.versionCardBadgeFontSize,
                      color: colors.versionCard.badgeText,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: AppDimens.versionCardRowToBoxGap),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: AppDimens.versionCardMaxHeight),
            decoration: BoxDecoration(
              color: colors.versionCard.boxBg,
              borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
              border: isLatest
                  ? Border.all(color: colors.versionCard.latestBorder, width: AppDimens.versionCardLatestBorderWidth)
                  : null,
            ),
            padding: EdgeInsets.all(AppDimens.versionCardBoxPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (version.title.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: AppDimens.versionCardTitlePaddingLeft),
                    child: Text(
                      version.title,
                      style: TextStyle(
                        fontSize: AppDimens.versionCardTitleFontSize,
                        fontWeight: FontWeight.w600,
                        color: colors.versionCard.title,
                      ),
                    ),
                  ),
                if (version.log.isNotEmpty) ...[
                  if (version.title.isNotEmpty) SizedBox(height: AppDimens.versionCardTitleLogGap),
                  Text(
                    version.log,
                    maxLines: AppDimens.versionCardLogMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppDimens.versionCardLogFontSize,
                      color: colors.versionCard.log,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
