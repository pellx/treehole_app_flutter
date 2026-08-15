import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_bottom_nav_theme.dart';
import '../theme/app_colors.dart';

/// 应用底部导航栏：纯文字 tab + 中央发布按钮
class AppBottomNav extends StatelessWidget {
  final int
  currentIndex; // 0..3 对应 [labels[0], labels[1], labels[2], labels[3]]
  final ValueChanged<int> onTap;
  final VoidCallback onPublishTap;
  final List<String> labels; // 长度固定为 4

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onPublishTap,
    required this.labels,
  }) : assert(labels.length == 4);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight
        ? AppBottomNavTheme.backgroundLight
        : AppBottomNavTheme.backgroundDark;
    final divider = colors.common.divider;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppBottomNavTheme.height,
          child: Row(
            children: [
              _navItem(context, 0, labels[0]),
              _navItem(context, 1, labels[1]),
              _publishButton(context),
              _navItem(context, 2, labels[2]),
              _navItem(context, 3, labels[3]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, int logicalIndex, String label) {
    final selected = logicalIndex == currentIndex;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap(logicalIndex);
        },
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppBottomNavTheme.labelFontSize,
              fontWeight: AppBottomNavTheme.labelFontWeight,
              color: selected
                  ? (isLight
                        ? AppBottomNavTheme.selectedLabelLight
                        : AppBottomNavTheme.selectedLabelDark)
                  : (isLight
                        ? AppBottomNavTheme.unselectedLabelLight
                        : AppBottomNavTheme.unselectedLabelDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _publishButton(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final buttonColor = isLight
        ? AppBottomNavTheme.publishButtonColorLight
        : AppBottomNavTheme.publishButtonColorDark;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.mediumImpact();
          onPublishTap();
        },
        child: Center(
          child: Container(
            width: AppBottomNavTheme.publishButtonWidth,
            height: AppBottomNavTheme.publishButtonHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppBottomNavTheme.publishButtonBorderRadius,
              ),
              border: Border.all(
                color: buttonColor,
                width: AppBottomNavTheme.publishButtonBorderWidth,
              ),
            ),
            child: Icon(
              Icons.add,
              size: AppBottomNavTheme.publishButtonIconSize,
              color: buttonColor,
            ),
          ),
        ),
      ),
    );
  }
}
