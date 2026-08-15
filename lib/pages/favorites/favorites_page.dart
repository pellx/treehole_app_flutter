import 'package:flutter/material.dart';

import '../../widgets/app_app_bar.dart';
import '../../widgets/app_empty_state.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: '收藏',
      body: AppEmptyState(message: '收藏功能即将上线', icon: Icons.star_border),
    );
  }
}
