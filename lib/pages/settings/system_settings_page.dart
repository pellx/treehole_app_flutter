import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_empty_state.dart';
import 'color_mode_page.dart';
import 'settings_navigation.dart';

class SystemSettingsPage extends StatelessWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AppScaffold(
      title: '系统设置',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _navTile(
            colors,
            onSurface,
            '颜色模式',
            Icons.palette_outlined,
            () =>
                Navigator.of(context).push(topDownRoute(const ColorModePage())),
          ),
          const AppEmptyState(
            message: '更多系统设置即将上线',
            icon: Icons.settings_outlined,
          ),
        ],
      ),
    );
  }

  Widget _navTile(
    AppColors colors,
    Color onSurface,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: colors.common.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.common.green),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 16, color: onSurface)),
            const Spacer(),
            Icon(Icons.chevron_right, size: 21, color: colors.common.arrowIcon),
          ],
        ),
      ),
    );
  }
}
