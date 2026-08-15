import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_bottom_nav.dart';
import '../pages/square/square_page.dart';
import '../pages/search/search_page.dart';
import '../pages/account/user_page.dart';
import '../pages/post/post_create_page.dart';
import '../pages/settings/settings_navigation.dart';

/// 应用主外壳：底部导航栏 + 各 Tab 内容
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final _homeKey = GlobalKey();
  final _searchKey = GlobalKey();
  final _userKey = GlobalKey();

  static const _items = [
    AppNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '主页'),
    AppNavItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      label: '搜索',
    ),
    AppNavItem(icon: Icons.edit_outlined, activeIcon: Icons.edit, label: '发布'),
    AppNavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: '用户',
    ),
  ];

  Future<void> _openCreatePost() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.of(
      context,
    ).push<bool>(topDownRoute(const PostCreatePage()));
    if (result == true && mounted) {
      // 发布成功后切回主页并刷新
      setState(() => _currentIndex = 0);
    }
  }

  void _onTap(int index) {
    if (index == 2) {
      _openCreatePost();
      return;
    }
    if (index != _currentIndex) {
      HapticFeedback.lightImpact();
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      SquarePage(key: _homeKey),
      SearchPage(key: _searchKey),
      const SizedBox.shrink(), // 发布由底部导航点击事件处理，不占页面
      UserPage(key: _userKey),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTap,
        items: _items,
      ),
    );
  }
}
