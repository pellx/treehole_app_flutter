import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_dimens_accent.dart';
import '../../widgets/app_app_bar.dart';
import '../account/device_binding_page.dart';
import '../account/switch_account_page.dart';
import 'color_mode_page.dart';
import 'settings_navigation.dart';

/// 设置列表页：用户资料、颜色模式、设备绑定、账户切换的统一入口
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return AppScaffold(
      title: '设置',
      body: ListView(
        padding: const EdgeInsets.all(AccentDimens.pagePadding),
        children: [
          _groupTitle(context, '账户'),
          _navTile(
            context,
            icon: Icons.person_outline,
            label: '用户资料',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
          ),
          _itemDivider(colors),
          _navTile(
            context,
            icon: Icons.devices_outlined,
            label: '设备绑定',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(topDownRoute(const DeviceBindingPage()));
            },
          ),
          _itemDivider(colors),
          _navTile(
            context,
            icon: Icons.switch_account_outlined,
            label: '账户切换',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(topDownRoute(const SwitchAccountPage()));
            },
          ),
          _itemDivider(colors),
          const SizedBox(height: 16),
          _groupTitle(context, '偏好'),
          _navTile(
            context,
            icon: Icons.palette_outlined,
            label: '颜色模式',
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(topDownRoute(const ColorModePage()));
            },
          ),
          _itemDivider(colors),
        ],
      ),
    );
  }

  Widget _groupTitle(BuildContext context, String label) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(
        left: 12,
        top: 8,
        bottom: 8,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: AppDimens.settingsItemHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: colors.common.trailingIcon),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppDimens.settingsItemFontSize,
                  color: onSurface,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(
                    right: AppDimens.settingsArrowRightMargin),
                child: Icon(
                  Icons.chevron_right,
                  size: AppDimens.settingsArrowSize,
                  color: colors.common.arrowIcon,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemDivider(AppColors colors) => Divider(
        height: 1,
        thickness: AccentDimens.dividerThickness,
        color: colors.common.divider,
      );
}
