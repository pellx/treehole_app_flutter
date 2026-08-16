import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens_accent.dart';

/// 通用确认弹窗，复用设置页「清除数据」的弹窗样式。
///
/// [title] 为可选标题，如果不为空则显示在正文上方。
/// 返回 `true` 表示用户点击了确认，`false` 表示取消，`null` 表示关闭弹窗。
Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  String? title,
  required String message,
  String cancelText = '取消',
  String confirmText = '确认',
}) async {
  final colors = Theme.of(context).extension<AppColors>()!;
  final onSurface = Theme.of(context).colorScheme.onSurface;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: colors.common.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AccentDimens.dialogRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AccentDimens.dialogPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AccentDimens.dialogMessageFontSize,
                  fontWeight: FontWeight.bold,
                  height: AccentDimens.dialogMessageLineHeight,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AccentDimens.dialogMessageFontSize,
                height: AccentDimens.dialogMessageLineHeight,
                color: onSurface,
              ),
            ),
            const SizedBox(height: AccentDimens.dialogActionsTopGap),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AccentDimens.dialogActionHeight,
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: onSurface.withValues(
                          alpha: AccentDimens.dialogCancelTextAlpha,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AccentDimens.dialogActionHPadding,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AccentDimens.dialogActionRadius,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontSize: AccentDimens.dialogActionFontSize,
                        ),
                      ),
                      child: Text(cancelText),
                    ),
                  ),
                ),
                const SizedBox(width: AccentDimens.dialogActionGap),
                Expanded(
                  child: SizedBox(
                    height: AccentDimens.dialogActionHeight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.postCreate.submitBg,
                        foregroundColor: colors.postCreate.submitText,
                        elevation: 0,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AccentDimens.dialogActionHPadding,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AccentDimens.dialogActionRadius,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontSize: AccentDimens.dialogActionFontSize,
                        ),
                      ),
                      child: Text(confirmText),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
