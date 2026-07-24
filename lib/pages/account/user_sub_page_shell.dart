import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens_accent.dart';

/// 用户页子页外壳：顶栏样式同 [UserPage]（淡绿底、标题居中、向上箭头）
class UserSubPageShell extends StatelessWidget {
  final String title;
  final Widget body;
  /// 顶栏右上角操作（如发帖页「发布」位）
  final Widget? trailing;

  const UserSubPageShell({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final barText = colors.common.barText;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            color: colors.common.drawerHeaderBg,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: AccentDimens.barHeight,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.keyboard_arrow_up, color: barText),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AccentDimens.barTitleFontSize,
                          fontWeight: FontWeight.w500,
                          color: barText,
                        ),
                      ),
                    ),
                    if (trailing != null)
                      trailing!
                    else
                      const SizedBox(width: AccentDimens.barTrailingWidth),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
