import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../services/binding_cache.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_dimens_accent.dart';
import 'user_sub_page_shell.dart';

/// 用户切换页：先展示本地缓存，再请求最新并按需更新
class SwitchAccountPage extends StatefulWidget {
  const SwitchAccountPage({super.key});

  @override
  State<SwitchAccountPage> createState() => _SwitchAccountPageState();
}

class _SwitchAccountPageState extends State<SwitchAccountPage> {
  List<BoundAccountInfo> _accounts = [];
  /// 仅在无缓存且首次请求未完成时显示加载
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cached = BindingCache.getAccounts();
    if (cached.isNotEmpty) {
      _accounts = cached;
    } else {
      _loading = true;
    }
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final list = await BindingCache.refreshAccounts();
    if (!mounted) return;

    if (list == null) {
      setState(() {
        _loading = false;
        if (_accounts.isEmpty) {
          _error = ApiService.lastError ?? '加载账户失败';
        }
      });
      return;
    }

    final changed = !BindingCache.accountsEqual(_accounts, list);
    setState(() {
      _loading = false;
      _error = null;
      if (changed) _accounts = list;
    });
  }

  static const _loadingGif = Image(
    image: AssetImage('assets/loading.gif'),
    width: AppDimens.loadingGifSize,
    height: AppDimens.loadingGifSize,
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    Widget body;
    if (_loading) {
      body = const Center(child: _loadingGif);
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AccentDimens.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AccentDimens.errorFontSize,
                  color: colors.register.errorText,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadAccounts, child: const Text('重试')),
            ],
          ),
        ),
      );
    } else if (_accounts.isEmpty) {
      body = Center(
        child: Text(
          '暂无绑定账户',
          style: TextStyle(
            fontSize: AccentDimens.itemFontSize,
            color: onSurface.withValues(alpha: 0.55),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _loadAccounts,
        child: ListView.separated(
          padding: const EdgeInsets.all(AccentDimens.pagePadding),
          itemCount: _accounts.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AccentDimens.deviceCardGap),
          itemBuilder: (context, index) {
            final a = _accounts[index];
            final title = (a.userDisplayId?.trim().isNotEmpty == true)
                ? a.userDisplayId!.trim()
                : '未命名账户';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title, style: TextStyle(color: onSurface)),
            );
          },
        ),
      );
    }

    return UserSubPageShell(title: '登录其他账户', body: body);
  }
}
