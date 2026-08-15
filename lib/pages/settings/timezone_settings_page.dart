import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/timezone_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_bottom_sheet.dart';

class TimezoneSettingsPage extends StatefulWidget {
  const TimezoneSettingsPage({super.key});

  @override
  State<TimezoneSettingsPage> createState() => _TimezoneSettingsPageState();
}

class _TimezoneSettingsPageState extends State<TimezoneSettingsPage> {
  late Timezone _selected;

  @override
  void initState() {
    super.initState();
    _selected = TimezoneService.selected;
  }

  Future<void> _showSelector() async {
    final selected = await showAppSelectorSheet<Timezone>(
      context: context,
      title: '选择时区',
      options: TimezoneService.supported,
      labelBuilder: (tz) => tz.label,
      selected: _selected,
    );
    if (selected == null || !mounted) return;
    await TimezoneService.setSelected(selected);
    setState(() => _selected = selected);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AppScaffold(
      title: '时区选择',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              _showSelector();
            },
            child: SizedBox(
              height: AppDimens.settingsItemHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(
                      '当前时区',
                      style: TextStyle(
                        fontSize: AppDimens.settingsItemFontSize,
                        color: onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _selected.label,
                      style: TextStyle(
                        fontSize: AppDimens.settingsItemFontSize,
                        color: onSurface,
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
                        color: colors.common.arrowIcon,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: colors.common.divider,
          ),
        ],
      ),
    );
  }
}
