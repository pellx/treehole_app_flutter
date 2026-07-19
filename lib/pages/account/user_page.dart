import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api.dart';
import '../../services/avatar_storage.dart';
import '../../services/binding_cache.dart';
import '../../services/session_service.dart';
import '../../services/storage.dart';
import '../../services/device_credential_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens_accent.dart';
import '../settings/settings_navigation.dart';
import 'device_binding_page.dart';
import 'switch_account_page.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  bool _editingName = false;
  bool _submittingName = false;
  bool _resettingToken = false;
  String? _error;
  String _externalToken = '';
  Uint8List? _avatarBytes;
  DateTime? _tokenResetAt;
  DateTime? _displayIdChangedAt;

  /// 两月内有重置 → 绿；否则红（从未重置则用注册时间，由后端 token_reset_at 给出）
  bool get _tokenRecent {
    final at = _tokenResetAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < const Duration(days: 60);
  }

  @override
  void initState() {
    super.initState();
    _nameController.text = PostStorage.getDisplayName() ?? PostStorage.getUserName();
    _nameFocus.addListener(_onNameFocusChange);
    _loadExternalToken();
    _loadAvatar();
    _loadProfile();
    // 预取绑定列表，进入子页时可先展示缓存
    BindingCache.prefetchAll();
  }

  /// 点到输入框外导致失焦时退出编辑；延后一帧以免与「提交」按钮抢序
  void _onNameFocusChange() {
    if (_nameFocus.hasFocus || !_editingName || _submittingName) return;
    Future.microtask(() {
      if (!mounted || _nameFocus.hasFocus || !_editingName || _submittingName) {
        return;
      }
      _exitNameEditing();
    });
  }

  Future<void> _loadAvatar() async {
    final bytes = await AvatarStorage.load();
    if (mounted && bytes != null) setState(() => _avatarBytes = bytes);
  }

  /// 从存储选择一张图片作为头像并保存到本地（与发帖页相同的文件选择方式）
  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'gif', 'webp'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      final bytes = await File(path).readAsBytes();
      await AvatarStorage.save(bytes);
      if (mounted) setState(() => _avatarBytes = bytes);
    } catch (e) {
      debugPrint('[UserPage] 更换头像失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像更换失败'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _loadExternalToken() async {
    final token = await DeviceCredentialStore.getUserExternalToken();
    if (mounted) setState(() => _externalToken = token ?? '');
  }

  Future<({int id, String secret})?> _readySession() async {
    final ok = await SessionService.instance.ensureSession();
    if (!ok) return null;
    final id = await DeviceCredentialStore.getSessionId();
    final secret = await DeviceCredentialStore.getSessionSecret();
    if (id == null || secret == null) return null;
    return (id: id, secret: secret);
  }

  Future<void> _loadProfile() async {
    final session = await _readySession();
    if (session == null) {
      debugPrint('[UserPage] profile: session 未就绪');
      return;
    }
    final profile = await ApiService.getUserProfile(
      sessionId: session.id,
      sessionSecret: session.secret,
    );
    if (!mounted || profile == null) return;
    setState(() {
      if (profile.userDisplayId.isNotEmpty) {
        _nameController.text = profile.userDisplayId;
      }
      _tokenResetAt = profile.tokenResetAt;
      _displayIdChangedAt = profile.displayIdChangedAt;
    });
    if (profile.userDisplayId.isNotEmpty) {
      await PostStorage.saveDisplayName(profile.userDisplayId);
    }
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onNameFocusChange);
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  String _formatRenameDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  /// 冷却结束日：优先用错误体 next_rename_at，否则上次改名 + 14 天
  DateTime? _nextRenameAt() {
    final fromApi = ApiService.lastNextRenameAt;
    if (fromApi != null) return fromApi;
    final last = ApiService.lastDisplayIdChangedAt ?? _displayIdChangedAt;
    if (last == null) return null;
    return last.add(const Duration(days: 14));
  }

  String _mapRenameError(String? raw) {
    return switch (raw) {
      'NAME_EMPTY' => '名字不能为空',
      'NAME_UNCHANGED' => '名字未改变',
      'RENAME_TOO_FREQUENT' => () {
          final next = _nextRenameAt();
          if (next == null) return '改名冷却中，每两周可改一次';
          return '改名冷却中，每两周可改一次\n下一次可更改日期：${_formatRenameDate(next)}';
        }(),
      'NAME_TAKEN' => '该名字已被使用',
      null => '改名失败',
      _ => raw,
    };
  }

  /// 「更改」→ 进入原位编辑；「提交」→ 调后端改名
  Future<void> _onNameButtonTap() async {
    if (!_editingName) {
      setState(() {
        _editingName = true;
        _error = null;
      });
      _nameFocus.requestFocus();
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _exitNameEditing(error: '名字不能为空');
      return;
    }
    final current =
        PostStorage.getDisplayName() ?? PostStorage.getUserName();
    if (name == current) {
      _nameFocus.unfocus();
      setState(() {
        _editingName = false;
        _error = null;
      });
      return;
    }

    setState(() { _submittingName = true; _error = null; });
    try {
      final session = await _readySession();
      if (session == null) {
        if (mounted) _exitNameEditing(error: '会话验证失败，请稍后重试');
        return;
      }
      final result = await ApiService.rename(
        sessionId: session.id,
        sessionSecret: session.secret,
        newName: name,
      );
      if (!mounted) return;
      if (result == null) {
        final changedAt = ApiService.lastDisplayIdChangedAt;
        if (changedAt != null) _displayIdChangedAt = changedAt;
        _exitNameEditing(error: _mapRenameError(ApiService.lastError));
        return;
      }
      await PostStorage.saveDisplayName(result.userDisplayId);
      _nameController.text = result.userDisplayId;
      setState(() {
        _editingName = false;
        _displayIdChangedAt =
            result.displayIdChangedAt ?? DateTime.now();
      });
    } catch (e) {
      if (mounted) _exitNameEditing(error: '网络异常：$e');
    } finally {
      if (mounted) setState(() => _submittingName = false);
    }
  }

  /// 提交失败后退出编辑态，恢复为上次已保存名字
  void _exitNameEditing({String? error}) {
    _nameFocus.unfocus();
    _nameController.text =
        PostStorage.getDisplayName() ?? PostStorage.getUserName();
    setState(() {
      _editingName = false;
      _error = error;
    });
  }

  void _copyToken() {
    if (_externalToken.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _externalToken));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制用户令牌'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _confirmChangeToken() async {
    if (_resettingToken) return;
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
                '是否确认更改用户令牌？更改之后原令牌作废，如需登录，需使用新签发令牌',
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
    if (confirmed == true && mounted) await _onChangeToken();
  }

  Future<void> _onChangeToken() async {
    if (_resettingToken) return;
    setState(() => _resettingToken = true);
    try {
      final session = await _readySession();
      if (session == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('会话验证失败，请稍后重试'), duration: Duration(seconds: 2)),
          );
        }
        return;
      }
      final result = await ApiService.resetUserToken(
        sessionId: session.id,
        sessionSecret: session.secret,
      );
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.lastError ?? '令牌重置失败'),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      final oldToken = await DeviceCredentialStore.getUserExternalToken();
      if (oldToken != null) {
        await DeviceCredentialStore.removeKnownUserToken(oldToken);
      }
      await DeviceCredentialStore.saveUserExternalToken(result.userToken);
      await DeviceCredentialStore.mergeKnownUserTokens([result.userToken]);
      setState(() {
        _externalToken = result.userToken;
        _tokenResetAt = result.tokenResetAt ?? DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('用户令牌已重置'), duration: Duration(seconds: 2)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('网络异常：$e'), duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _resettingToken = false);
    }
  }

  String _formatTokenResetAt() {
    final at = _tokenResetAt;
    if (at == null) return '加载中…';
    final local = at.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _openDeviceBinding() {
    Navigator.of(context).push(topDownRoute(const DeviceBindingPage()));
  }

  void _openLoginOther() {
    Navigator.of(context).push(topDownRoute(const SwitchAccountPage()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_editingName && !_submittingName) _exitNameEditing();
        },
        child: Column(
          children: [
            _topBar(colors),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AccentDimens.pagePadding),
                children: [
                  _avatarIdRow(colors, onSurface),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(
                          bottom: AccentDimens.errorBottomPadding),
                      child: Text(_error!,
                          style: TextStyle(
                              fontSize: AccentDimens.errorFontSize,
                              color: colors.register.errorText)),
                    ),
                  _itemDivider(colors),
                  _tokenRow(onSurface),
                  _itemDivider(colors),
                  _changeTokenRow(colors, onSurface),
                  _itemDivider(colors),
                  _navRow(colors, onSurface, '设备绑定', _openDeviceBinding),
                  _itemDivider(colors),
                  _navRow(colors, onSurface, '账户切换', _openLoginOther),
                  _itemDivider(colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 顶部栏（与颜色模式设置页同款：淡绿背景、标题居中、向上箭头） ----

  Widget _topBar(AppColors colors) {
    final barText = colors.common.barText;
    return Container(
      color: colors.common.drawerHeaderBg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AccentDimens.barHeight,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.keyboard_arrow_up, color: barText),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text('用户',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AccentDimens.barTitleFontSize,
                        fontWeight: FontWeight.w500,
                        color: barText)),
              ),
              const SizedBox(width: AccentDimens.barTrailingWidth),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 头像 + ID + 更改/提交按钮 ----

  Widget _avatarIdRow(AppColors colors, Color onSurface) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: AccentDimens.avatarIdRowVPadding),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AccentDimens.avatarLeftInset),
            child: GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: AccentDimens.avatarRadius,
                backgroundColor: colors.common.idTint.withValues(alpha: 0.2),
                backgroundImage: _avatarBytes != null
                    ? MemoryImage(_avatarBytes!) as ImageProvider
                    : const AssetImage('assets/420px-Transparent_Akkarin.jpg'),
              ),
            ),
          ),
          const SizedBox(width: AccentDimens.avatarIdGap),
          Expanded(
            child: _editingName
                ? TextField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    maxLength: AccentDimens.nameMaxLength,
                    style: TextStyle(
                        fontSize: AccentDimens.idFontSize,
                        fontWeight: FontWeight.w600,
                        color: onSurface),
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: AccentDimens.nameInputVPadding),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: onSurface.withValues(
                                alpha: AccentDimens.nameInputUnderlineAlpha),
                            width: AccentDimens.nameInputUnderlineWidth),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: onSurface,
                            width: AccentDimens.nameInputUnderlineWidth),
                      ),
                    ),
                  )
                : Text(
                    _nameController.text,
                    style: TextStyle(
                        fontSize: AccentDimens.idFontSize,
                        fontWeight: FontWeight.w600,
                        color: onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          const SizedBox(width: AccentDimens.idButtonGap),
          Padding(
            padding: const EdgeInsets.only(
                right: AccentDimens.changeButtonRightInset),
            child: SizedBox(
              height: AccentDimens.buttonHeight,
              child: ElevatedButton(
                onPressed: _submittingName ? null : _onNameButtonTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.postCreate.submitBg.withValues(
                      alpha: _editingName
                          ? AccentDimens.buttonSubmitBgAlpha
                          : AccentDimens.buttonBgAlpha),
                  foregroundColor: colors.postCreate.submitText.withValues(
                      alpha: _editingName
                          ? AccentDimens.buttonSubmitTextAlpha
                          : AccentDimens.buttonTextAlpha),
                  elevation: 0,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AccentDimens.buttonHPadding, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AccentDimens.buttonRadius),
                  ),
                  textStyle:
                      const TextStyle(fontSize: AccentDimens.buttonFontSize),
                ),
                child: _submittingName
                    ? SizedBox(
                        width: AccentDimens.submitSpinnerSize,
                        height: AccentDimens.submitSpinnerSize,
                        child: CircularProgressIndicator(
                            strokeWidth: AccentDimens.submitSpinnerStroke,
                            color: colors.postCreate.submitText.withValues(
                                alpha: AccentDimens.buttonSubmitTextAlpha)))
                    : Text(_editingName ? '提交' : '更改'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 用户 token（点击复制） ----

  Widget _tokenRow(Color onSurface) {
    const head = AccentDimens.tokenHeadChars;
    const tail = AccentDimens.tokenTailChars;
    final display = _externalToken.isEmpty
        ? '—'
        : (_externalToken.length > head + tail
            ? '${_externalToken.substring(0, head)}...'
                '${_externalToken.substring(_externalToken.length - tail)}'
            : _externalToken);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _copyToken,
      child: _itemRow(
        Row(
          children: [
            Text('用户令牌',
                style: TextStyle(
                    fontSize: AccentDimens.itemFontSize, color: onSurface)),
            const Spacer(),
            Text(display,
                style: TextStyle(
                    fontSize: AccentDimens.tokenValueFontSize,
                    color: onSurface.withValues(
                        alpha: AccentDimens.tokenValueAlpha))),
            const SizedBox(width: AccentDimens.tokenCopyIconGap),
            Padding(
              padding: const EdgeInsets.only(
                  right: AccentDimens.copyIconRightInset),
              child: Icon(Icons.copy,
                  size: AccentDimens.tokenCopyIconSize,
                  color: onSurface.withValues(
                      alpha: AccentDimens.tokenCopyIconAlpha)),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 更改用户 token（右侧上次更改时间 + 可用性圆点） ----

  Widget _changeTokenRow(AppColors colors, Color onSurface) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _resettingToken ? null : _confirmChangeToken,
      child: _itemRow(
        Row(
          children: [
            Text('更改用户令牌',
                style: TextStyle(
                    fontSize: AccentDimens.itemFontSize, color: onSurface)),
            const Spacer(),
            if (_resettingToken)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(_formatTokenResetAt(),
                  style: TextStyle(
                      fontSize: AccentDimens.lastChangedFontSize,
                      color: onSurface.withValues(
                          alpha: AccentDimens.lastChangedAlpha))),
            const SizedBox(width: AccentDimens.changeableDotGap),
            Padding(
              padding:
                  const EdgeInsets.only(right: AccentDimens.dotRightInset),
              child: Container(
                width: AccentDimens.changeableDotSize,
                height: AccentDimens.changeableDotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // 两月内有重置 → 绿；超过两月 → 红
                  color: _tokenRecent
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE57373),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- 跳转子页面行 ----

  Widget _navRow(AppColors colors, Color onSurface, String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _itemRow(
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: AccentDimens.itemFontSize, color: onSurface)),
            const Spacer(),
            _rightAligned(Icon(Icons.chevron_right,
                size: AccentDimens.arrowSize,
                color: colors.common.arrowIcon)),
          ],
        ),
      ),
    );
  }

  // ---- 通用（与 color_mode_page 同风格） ----

  /// 每行最右侧元素统一以 rowRightInset 为右侧基准对齐
  Widget _rightAligned(Widget child) => Padding(
        padding: const EdgeInsets.only(right: AccentDimens.rowRightInset),
        child: child,
      );

  Widget _itemRow(Widget child) => SizedBox(
        height: AccentDimens.itemHeight,
        child: Center(child: child),
      );

  Widget _itemDivider(AppColors colors) => Divider(
      height: 1,
      thickness: AccentDimens.dividerThickness,
      color: colors.common.divider);
}
