import 'package:flutter/material.dart';

import '../../widgets/app_app_bar.dart';
import '../../widgets/app_empty_state.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: '消息提醒设置',
      body: AppEmptyState(
        message: '消息提醒设置功能即将上线',
        icon: Icons.notifications_outlined,
      ),
    );
  }
}
