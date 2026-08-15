import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/timezone_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_app_bar.dart';

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

  Future<void> _onSelect(Timezone tz) async {
    if (tz.name == _selected.name) return;
    HapticFeedback.lightImpact();
    await TimezoneService.setSelected(tz);
    setState(() => _selected = tz);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final options = TimezoneService.supported;

    return AppScaffold(
      title: '时区选择',
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: options.length,
        itemBuilder: (context, index) {
          final tz = options[index];
          final isSelected = tz.name == _selected.name;
          final isLast = index == options.length - 1;

          return Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onSelect(tz),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.common.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        tz.label,
                        style: TextStyle(
                          fontSize: 16,
                          color: onSurface,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 20,
                        color: isSelected
                            ? colors.common.green
                            : colors.common.trailingIcon,
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 16,
                  endIndent: 16,
                  color: colors.common.divider,
                ),
            ],
          );
        },
      ),
    );
  }
}
