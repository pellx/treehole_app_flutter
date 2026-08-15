import 'package:flutter/material.dart';

import '../../widgets/app_app_bar.dart';
import '../../widgets/app_empty_state.dart';

class UserSettingsPage extends StatelessWidget {
  const UserSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: '用户设置',
      body: AppEmptyState(message: '用户设置功能即将上线', icon: Icons.person_outline),
    );
  }
}
