import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_bottom_sheet.dart';

class ColorModePage extends StatefulWidget {
  const ColorModePage({super.key});

  @override
  State<ColorModePage> createState() => _ColorModePageState();
}

class _ColorModePageState extends State<ColorModePage> {
  ThemeMode _selectedMode = TreeholeApp.themeMode;
  bool _followSystem = TreeholeApp.themeMode == ThemeMode.system;

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

  Future<void> _showModeSelector() async {
    final selected = await showAppSelectorSheet<ThemeMode>(
      context: context,
      title: '颜色模式',
      options: const [ThemeMode.light, ThemeMode.dark],
      labelBuilder: _modeLabel,
      selected: _selectedMode,
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedMode = selected);
    TreeholeApp.setThemeMode(selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final enabled = !_followSystem;
    final dimmed = onSurface.withValues(alpha: 0.3);
    final textColor = enabled ? onSurface : dimmed;

    return AppScaffold(
      title: '颜色模式',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _showModeSelector : null,
            child: SizedBox(
              height: AppDimens.settingsItemHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
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
                      _modeLabel(_selectedMode),
                      style: TextStyle(
                        fontSize: AppDimens.settingsItemFontSize,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(
                        right: AppDimens.settingsArrowRightMargin,
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        size: AppDimens.settingsArrowSize,
                        color: enabled
                            ? colors.common.arrowIcon
                            : colors.common.arrowIcon.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _itemDivider(colors),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _followSystem = !_followSystem;
              });
              if (_followSystem) {
                TreeholeApp.setThemeMode(ThemeMode.system);
              } else {
                TreeholeApp.setThemeMode(_selectedMode);
              }
            },
            child: SizedBox(
              height: AppDimens.settingsItemHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(
                      '跟随系统',
                      style: TextStyle(
                        fontSize: AppDimens.settingsItemFontSize,
                        color: onSurface,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _followSystem,
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        return states.contains(WidgetState.selected)
                            ? colors.common.surface
                            : colors.common.onSurface.withValues(alpha: 0.8);
                      }),
                      trackColor: WidgetStateProperty.resolveWith((states) {
                        return states.contains(WidgetState.selected)
                            ? colors.common.switchActive
                            : colors.common.divider;
                      }),
                      trackOutlineColor: WidgetStateProperty.all(
                        Colors.transparent,
                      ),
                      onChanged: (v) {
                        HapticFeedback.lightImpact();
                        setState(() => _followSystem = v);
                        if (v) {
                          TreeholeApp.setThemeMode(ThemeMode.system);
                        } else {
                          TreeholeApp.setThemeMode(_selectedMode);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          _itemDivider(colors),
        ],
      ),
    );
  }

  Widget _itemDivider(AppColors colors) =>
      Divider(height: 1, thickness: 0.5, color: colors.common.divider);
}
