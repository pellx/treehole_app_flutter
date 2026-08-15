import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final bg = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF7F7F7)
        : const Color(0xFF1A1A1A);
    final divider = colors.common.divider;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _navItem(context, 0, labels[0]),
              _navItem(context, 1, labels[1]),
              _publishButton(context, onSurface),
              _navItem(context, 2, labels[2]),
              _navItem(context, 3, labels[3]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, int logicalIndex, String label) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final colors = Theme.of(context).extension<AppColors>()!;
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
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: selected
                  ? (isLight ? const Color(0xFF07C160) : colors.common.green)
                  : (isLight
                        ? const Color(0xFF999999)
                        : onSurface.withValues(alpha: 0.4)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _publishButton(BuildContext context, Color onSurface) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final buttonColor = isLight
        ? const Color(0xFF333333)
        : onSurface.withValues(alpha: 0.8);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.mediumImpact();
          onPublishTap();
        },
        child: Center(
          child: Container(
            width: 44,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: buttonColor, width: 1.8),
            ),
            child: Icon(Icons.add, size: 22, color: buttonColor),
          ),
        ),
      ),
    );
  }
}
