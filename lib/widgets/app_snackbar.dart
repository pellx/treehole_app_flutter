import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 显示统一风格的 SnackBar
void showAppSnackBar(
  BuildContext context, {
  required String message,
  Duration duration = const Duration(seconds: 2),
  SnackBarAction? action,
}) {
  final colors = Theme.of(context).extension<AppColors>()!;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: colors.common.onSurface,
          fontSize: 14,
        ),
      ),
      backgroundColor: colors.common.surface,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colors.common.divider),
      ),
      margin: const EdgeInsets.all(12),
      action: action,
    ),
  );
}
