import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../services/binding_cache.dart';
import '../../services/device_credential_store.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_dimens_accent.dart';
import '../../widgets/account_card.dart';
import '../settings/settings_navigation.dart';
import 'register_page.dart';
import 'user_sub_page_shell.dart';

/// 账户切换页：先展示本地缓存，再请求最新并按需更新
class SwitchAccountPage extends StatefulWidget {
  const SwitchAccountPage({super.key});

  @override
  State<SwitchAccountPage> createState() => _SwitchAccountPageState();
}

class _SwitchAccountPageState extends State<SwitchAccountPage> {
  List<BoundAccountInfo> _accounts = [];
  /// 当前登录账户的完整 user_token
  String? _currentToken;
  /// 仅在无缓存且首次请求未完成时显示加载
  bool _loading = false;
  bool _switching = false;
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
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await DeviceCredentialStore.getUserExternalToken();
    if (mounted) {
      setState(() {
        _currentToken = token;
        _accounts = _withCurrentFirst(_accounts);
      });
    }
    await _loadAccounts();
  }

  /// 当前账户置顶，其余保持相对顺序
  List<BoundAccountInfo> _withCurrentFirst(List<BoundAccountInfo> list) {
    if (list.isEmpty) return list;
    final current = <BoundAccountInfo>[];
    final others = <BoundAccountInfo>[];
    for (final a in list) {
      if (_isCurrent(a)) {
        current.add(a);
      } else {
        others.add(a);
      }
    }
    return [...current, ...others];
  }

  Future<void> _loadAccounts() async {
    final list = await BindingCache.refreshAccounts();
    if (!mounted) return;

    if (list == null) {
      setState(() {
        _loading = false;
        if (_accounts.isEmpty) {
          _error = ApiService.lastError ?? '加载账户失败';
        } else {
          _accounts = _withCurrentFirst(_accounts);
        }
      });
      return;
    }

    final next = _withCurrentFirst(list);
    final changed = !BindingCache.accountsEqual(_accounts, next);
    setState(() {
      _loading = false;
      _error = null;
      if (changed) _accounts = next;
    });
  }

  bool _isCurrent(BoundAccountInfo a) {
    final current = _currentToken?.trim() ?? '';
    if (current.isEmpty) return false;
    final token = a.userToken.trim();
    if (token.isEmpty) return false;
    if (token == current) return true;
    // 缓存仅有遮罩预览时，与当前令牌遮罩后比对
    return AccountCard.maskToken(token) == AccountCard.maskToken(current);
  }

  AccountCardData _toCard(BoundAccountInfo a) {
    final id = a.userDisplayId?.trim();
    return AccountCardData(
      bindingId: a.bindingId,
      deviceId: a.deviceId,
      status: a.status,
      displayId: (id != null && id.isNotEmpty) ? id : '未命名账户',
      createdAt: a.createdAt,
      userToken: a.userToken,
      isCurrent: _isCurrent(a),
    );
  }

  Future<String?> _resolveFullToken(BoundAccountInfo a) async {
    final token = a.userToken.trim();
    if (token.isEmpty) return null;
    if (!token.contains('...')) return token;

    final known = await DeviceCredentialStore.getKnownUserTokens();
    final preview = AccountCard.maskToken(token);
    for (final t in known) {
      if (AccountCard.maskToken(t) == preview) return t;
    }
    final current = _currentToken?.trim();
    if (current != null &&
        current.isNotEmpty &&
        AccountCard.maskToken(current) == preview) {
      return current;
    }
    return null;
  }

  Future<bool> _confirmSwitch(String displayId) async {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: colors.common.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AccentDimens.dialogRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AccentDimens.dialogPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '是否切换到「$displayId」？',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AccentDimens.dialogMessageFontSize,
                  height: AccentDimens.dialogMessageLineHeight,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: AccentDimens.dialogActionsTopGap),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: AccentDimens.dialogActionHeight,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: onSurface.withValues(
                              alpha: AccentDimens.dialogCancelTextAlpha),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AccentDimens.dialogActionHPadding),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AccentDimens.dialogActionRadius),
                          ),
                          textStyle: const TextStyle(
                              fontSize: AccentDimens.dialogActionFontSize),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                  ),
                  const SizedBox(width: AccentDimens.dialogActionGap),
                  Expanded(
                    child: SizedBox(
                      height: AccentDimens.dialogActionHeight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.postCreate.submitBg,
                          foregroundColor: colors.postCreate.submitText,
                          elevation: 0,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AccentDimens.dialogActionHPadding),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AccentDimens.dialogActionRadius),
                          ),
                          textStyle: const TextStyle(
                              fontSize: AccentDimens.dialogActionFontSize),
                        ),
                        child: const Text('确认'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed == true;
  }

  String _loginErrorText(String? raw) {
    return switch (raw) {
      'TRANSFER_REQUIRED' => '需先在原设备发起转移申请（15 分钟内有效）',
      'TRANSFER_INVALID' => '转移申请无效或已过期，请在原设备重新申请',
      'DEVICE_COOLDOWN' => '解绑冷却中，暂不可登录',
      _ => raw ?? '登录失败',
    };
  }

  Future<void> _onAccountTap(BoundAccountInfo a) async {
    if (_switching) return;
    final card = _toCard(a);
    if (card.isCurrent) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已是当前账户'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final ok = await _confirmSwitch(card.displayId);
    if (!ok || !mounted) return;

    final token = await _resolveFullToken(a);
    if (!mounted) return;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('令牌不可用，请下拉刷新后重试'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _switching = true);
    final success = await SessionService.instance.switchToAccount(token);
    if (!mounted) return;
    setState(() => _switching = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_loginErrorText(ApiService.lastError)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _currentToken = token;
      _accounts = _withCurrentFirst(_accounts);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已切换账户'),
        duration: Duration(seconds: 1),
      ),
    );
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
      body = Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadAccounts,
            child: ListView.separated(
              padding: const EdgeInsets.all(AccentDimens.pagePadding),
              itemCount: _accounts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AccentDimens.deviceCardGap),
              itemBuilder: (context, index) {
                final a = _accounts[index];
                return AccountCard(
                  data: _toCard(a),
                  onTap: () => _onAccountTap(a),
                );
              },
            ),
          ),
          if (_switching)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: onSurface.withValues(alpha: 0.08),
                  child: const Center(child: _loadingGif),
                ),
              ),
            ),
        ],
      );
    }

    return UserSubPageShell(
      title: '账户切换',
      body: body,
      trailing: Padding(
        padding: const EdgeInsets.only(
            right: AppDimens.postCreateSubmitMarginRight),
        child: SizedBox(
          height: AppDimens.postCreateSubmitHeight,
          child: ElevatedButton(
            onPressed: _switching ? null : _openLoginUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.postCreate.submitBg,
              foregroundColor: colors.postCreate.submitText,
              elevation: 0,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.postCreateSubmitHPadding, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDimens.postCreateSubmitRadius),
              ),
              textStyle:
                  const TextStyle(fontSize: AppDimens.postCreateSubmitFontSize),
            ),
            child: const Text('登录用户'),
          ),
        ),
      ),
    );
  }

  Future<void> _openLoginUser() async {
    await Navigator.of(context).push(
      bottomUpRoute(const RegisterPage(startAtLogin: true)),
    );
    if (!mounted) return;
    await _bootstrap();
  }
}
