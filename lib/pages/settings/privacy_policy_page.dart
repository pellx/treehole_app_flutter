import 'package:flutter/material.dart';

import '../../widgets/app_app_bar.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AppScaffold(
      title: '安全与隐私策略',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          '本应用重视您的隐私安全。\n\n'
          '1. 我们仅收集保障服务所必需的最少信息。\n'
          '2. 您的账户令牌与设备凭据仅存储在本地。\n'
          '3. 我们不会将您的发帖、评论等数据用于任何第三方广告或推荐。\n\n'
          '更多详细条款将在后续版本补充。',
          style: TextStyle(fontSize: 15, height: 1.6, color: onSurface),
        ),
      ),
    );
  }
}
