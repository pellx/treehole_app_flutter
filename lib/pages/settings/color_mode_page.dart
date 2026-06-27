import 'package:flutter/material.dart';

import '../../app.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

class ColorModePage extends StatefulWidget {
  const ColorModePage({super.key});

  @override
  State<ColorModePage> createState() => _ColorModePageState();
}

class _ColorModePageState extends State<ColorModePage> {
  ThemeMode _selectedMode = TreeholeApp.themeMode;
  bool _followSystem = TreeholeApp.themeMode == ThemeMode.system;
  bool _modeExpanded = false;

  @override
  void initState() {
    super.initState();
    // 如果是跟随系统，默认手动模式为浅色
    if (_followSystem) {
      _selectedMode = ThemeMode.light;
    }
  }

  String _modeLabel(ThemeMode m) => switch (m) {
    ThemeMode.light => '浅色模式',
    ThemeMode.dark => '深色模式',
    ThemeMode.system => '浅色模式', // 不会用于下拉选项
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _dropdownCard(
          context,
          value: _modeLabel(_selectedMode),
          expanded: _modeExpanded,
          enabled: !_followSystem,
          onTap: _followSystem
              ? null
              : () => setState(() => _modeExpanded = !_modeExpanded),
          children: [
            _optionTile('浅色模式',
                !_followSystem && _selectedMode == ThemeMode.light,
                () => _selectMode(ThemeMode.light)),
            _optionTile('深色模式',
                !_followSystem && _selectedMode == ThemeMode.dark,
                () => _selectMode(ThemeMode.dark)),
          ],
        ),
        _itemDivider(),
        _switchCard(context, '跟随系统', _followSystem, (v) {
          setState(() {
            _followSystem = v;
            _modeExpanded = false;
          });
          if (v) {
            TreeholeApp.setThemeMode(ThemeMode.system);
          } else {
            TreeholeApp.setThemeMode(_selectedMode);
          }
        }),
        _itemDivider(),
      ],
    );
  }

  void _selectMode(ThemeMode m) {
    setState(() {
      _selectedMode = m;
      _modeExpanded = false;
    });
    TreeholeApp.setThemeMode(m);
  }

  // ---- 通用组件 ----

  Widget _itemDivider() {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Divider(height: 1, thickness: 0.5, color: colors.common.divider);
  }

  Widget _itemRow(BuildContext ctx, Widget child) => SizedBox(
        height: AppDimens.settingsItemHeight,
        child: Center(child: child),
      );

  Widget _arrowBadge(Widget icon) => Padding(
        padding:
            const EdgeInsets.only(right: AppDimens.settingsArrowRightMargin),
        child: icon,
      );

  Widget _dropdownCard(
    BuildContext ctx, {
    required String value,
    required bool expanded,
    required bool enabled,
    required VoidCallback? onTap,
    required List<Widget> children,
  }) {
    final c = Theme.of(ctx).colorScheme.onSurface;
    final dimmed = c.withValues(alpha: 0.3);
    final textColor = enabled ? c : dimmed;
    final colors = Theme.of(ctx).extension<AppColors>()!;
    final arrowColor = enabled ? colors.common.arrowIcon : colors.common.arrowIcon.withValues(alpha: 0.3);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: _itemRow(
              ctx,
              Row(
                children: [
                  Text(
                    '颜色模式',
                    style: TextStyle(
                      fontSize: AppDimens.settingsItemFontSize,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: AppDimens.settingsItemFontSize,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _arrowBadge(
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        size: AppDimens.settingsArrowSize,
                        color: arrowColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (enabled && expanded) ...children,
        ],
      ),
    );
  }

  Widget _switchCard(
      BuildContext ctx, String label, bool value, ValueChanged<bool> onChanged) {
    final colors = Theme.of(ctx).extension<AppColors>()!;
    return _itemRow(
      ctx,
      Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppDimens.settingsItemFontSize,
              color: Theme.of(ctx).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          Switch(value: value, activeColor: colors.common.switchActive, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _optionTile(String label, bool selected, VoidCallback onTap) {
    final c = Theme.of(context).colorScheme.onSurface;
    final colors = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: selected ? colors.common.switchActive.withValues(alpha: 0.08) : null,
        child: _itemRow(
          context,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 18,
                  color:
                      selected ? colors.common.switchActive : colors.common.trailingIcon,
                ),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontSize: 13, color: c)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
