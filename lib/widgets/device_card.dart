import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens_accent.dart';

/// 设备卡片右侧主操作（解绑 / 主设备星标）
enum DeviceCardAction {
  /// 普通解绑垃圾桶
  delete,
  /// 取消解绑申请
  cancelUnbind,
  /// 主设备星标：发起迁移选目标
  primaryStar,
  /// 主设备取消样式：取消迁移 / 退出选目标
  primaryCancel,
  /// 选目标模式下的星标（迁移到此设备）
  transferTarget,
  /// 主设备星标（只读，非本机主设备时不可迁移）
  primaryStarReadonly,
}

/// 设备绑定列表项展示数据
class DeviceCardData {
  /// user_device_binding.id，解绑/改名用
  final int bindingId;
  final int deviceId;
  /// active / unbind_pending
  final String status;
  final DateTime? unbindRequestedAt;
  final DateTime? unbindExecuteAt;
  /// 用户自定义名；为空则回退 [deviceName]
  final String? customName;
  final String deviceName;
  final String brand;
  final String model;
  final String os;
  final String abi;
  /// 是否为当前登录本机
  final bool isCurrent;
  final bool isPrimary;
  final bool isPrimaryPending;
  /// 右侧操作由页面按主设备/选目标态计算
  final DeviceCardAction action;

  const DeviceCardData({
    required this.bindingId,
    required this.deviceId,
    this.status = 'active',
    this.unbindRequestedAt,
    this.unbindExecuteAt,
    this.customName,
    required this.deviceName,
    required this.brand,
    required this.model,
    required this.os,
    required this.abi,
    this.isCurrent = false,
    this.isPrimary = false,
    this.isPrimaryPending = false,
    this.action = DeviceCardAction.delete,
  });

  bool get isUnbindPending => status == 'unbind_pending';

  DateTime? get effectiveUnbindExecuteAt {
    if (unbindExecuteAt != null) return unbindExecuteAt;
    final requested = unbindRequestedAt;
    if (requested == null) return null;
    return requested.add(const Duration(days: 2));
  }

  String get displayName {
    final custom = customName?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return deviceName;
  }

  DeviceCardData copyWith({
    int? bindingId,
    int? deviceId,
    String? status,
    DateTime? unbindRequestedAt,
    DateTime? unbindExecuteAt,
    bool clearUnbind = false,
    String? customName,
    bool clearCustomName = false,
    String? deviceName,
    String? brand,
    String? model,
    String? os,
    String? abi,
    bool? isCurrent,
    bool? isPrimary,
    bool? isPrimaryPending,
    DeviceCardAction? action,
  }) {
    return DeviceCardData(
      bindingId: bindingId ?? this.bindingId,
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      unbindRequestedAt:
          clearUnbind ? null : (unbindRequestedAt ?? this.unbindRequestedAt),
      unbindExecuteAt:
          clearUnbind ? null : (unbindExecuteAt ?? this.unbindExecuteAt),
      customName: clearCustomName ? null : (customName ?? this.customName),
      deviceName: deviceName ?? this.deviceName,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      os: os ?? this.os,
      abi: abi ?? this.abi,
      isCurrent: isCurrent ?? this.isCurrent,
      isPrimary: isPrimary ?? this.isPrimary,
      isPrimaryPending: isPrimaryPending ?? this.isPrimaryPending,
      action: action ?? this.action,
    );
  }
}

/// 设备卡片：显示名可原位编辑；解绑为冷却申请，可取消
class DeviceCard extends StatefulWidget {
  final DeviceCardData data;
  final VoidCallback? onTap;
  final ValueChanged<String>? onRenameSubmit;
  final VoidCallback? onDelete;
  final VoidCallback? onCancelDelete;
  final VoidCallback? onPrimaryStar;
  final VoidCallback? onPrimaryCancel;
  final VoidCallback? onTransferTarget;

  const DeviceCard({
    super.key,
    required this.data,
    this.onTap,
    this.onRenameSubmit,
    this.onDelete,
    this.onCancelDelete,
    this.onPrimaryStar,
    this.onPrimaryCancel,
    this.onTransferTarget,
  });

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  bool _editing = false;
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.data.displayName;
    _nameFocus.addListener(_onNameFocusChange);
  }

  @override
  void didUpdateWidget(covariant DeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.data.displayName != widget.data.displayName) {
      _nameController.text = widget.data.displayName;
    }
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onNameFocusChange);
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// 点到输入框外失焦时取消编辑；延后一帧以免与对勾提交抢序
  void _onNameFocusChange() {
    if (_nameFocus.hasFocus || !_editing || _committing) return;
    Future.microtask(() {
      if (!mounted || _nameFocus.hasFocus || !_editing || _committing) return;
      _cancelEditing();
    });
  }

  void _cancelEditing() {
    _nameFocus.unfocus();
    _nameController.text = widget.data.displayName;
    setState(() => _editing = false);
  }

  void _onEditOrSubmit() {
    if (!_editing) {
      setState(() {
        _editing = true;
        _nameController.text = widget.data.displayName;
      });
      _nameFocus.requestFocus();
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _nameFocus.unfocus();
      setState(() => _editing = false);
      _nameController.text = widget.data.displayName;
      return;
    }
    // 与当前展示名相同则不请求后端
    if (name == widget.data.displayName) {
      _nameFocus.unfocus();
      setState(() => _editing = false);
      return;
    }
    // 先提交再失焦，避免失焦取消把名字打回旧值
    _committing = true;
    _nameController.text = name;
    setState(() => _editing = false);
    widget.onRenameSubmit?.call(name);
    _nameFocus.unfocus();
    _committing = false;
  }

  Future<void> _confirmDelete() async {
    final message = widget.data.isCurrent
        ? '是否确认申请解绑本机？将于2天后解绑，期间仍可登录，解绑后可凭用户令牌登录'
        : '是否确认立即解绑该设备？解绑后该设备将无法继续使用本账户';
    final ok = await _confirmDialog(message: message);
    if (ok && mounted) widget.onDelete?.call();
  }

  Future<void> _confirmCancelDelete() async {
    final ok = await _confirmDialog(message: '是否确认取消解绑申请？');
    if (ok && mounted) widget.onCancelDelete?.call();
  }

  Future<void> _confirmPrimaryStar() async {
    final ok = await _confirmDialog(message: '是否进行主设备迁移？');
    if (ok && mounted) widget.onPrimaryStar?.call();
  }

  Future<void> _confirmPrimaryCancel() async {
    final ok = await _confirmDialog(message: '是否取消主设备迁移？');
    if (ok && mounted) widget.onPrimaryCancel?.call();
  }

  Future<void> _confirmTransferTarget() async {
    final ok = await _confirmDialog(
      message:
          '是否迁移到「${widget.data.displayName}」？\n该更改将于两天后生效',
    );
    if (ok && mounted) widget.onTransferTarget?.call();
  }

  Future<bool> _confirmDialog({required String message}) async {
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
                message,
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

  String _formatUnbindTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final metaStyle = TextStyle(
      fontSize: AccentDimens.deviceCardMetaSize,
      height: 1.35,
      color: onSurface.withValues(alpha: AccentDimens.deviceCardMetaAlpha),
    );

    return Material(
      color: colors.common.surface,
      borderRadius: BorderRadius.circular(AccentDimens.deviceCardRadius),
      child: InkWell(
        onTap: _editing ? null : widget.onTap,
        borderRadius: BorderRadius.circular(AccentDimens.deviceCardRadius),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AccentDimens.deviceCardRadius),
            border: Border.all(
              color: colors.common.divider,
              width: AccentDimens.deviceCardBorderWidth,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(AccentDimens.deviceCardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.translate(
                          offset:
                              Offset(0, AccentDimens.deviceCardIconTopInset),
                          child: Icon(
                            Icons.smartphone_outlined,
                            size: AccentDimens.deviceCardIconSize,
                            color: onSurface.withValues(
                                alpha: AccentDimens.deviceCardMetaAlpha),
                          ),
                        ),
                        const SizedBox(width: AccentDimens.deviceCardIconGap),
                        if (!_editing) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _nameField(onSurface),
                              Transform.translate(
                                offset: Offset(
                                    AccentDimens.deviceCardRenameGap, 0),
                                child: _editButton(onSurface),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Transform.translate(
                            offset: Offset(
                                0, AccentDimens.deviceCardDeleteTopInset),
                            child: _unbindActions(colors, onSurface),
                          ),
                        ] else ...[
                          Expanded(child: _nameField(onSurface)),
                          Transform.translate(
                            offset:
                                Offset(AccentDimens.deviceCardRenameGap, 0),
                            child: _editButton(onSurface),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AccentDimens.deviceCardTitleBottom),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: AccentDimens.deviceCardMetaLeftInset),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: Text('品牌：${widget.data.brand}',
                                      style: metaStyle)),
                              const SizedBox(
                                  width: AccentDimens.deviceCardMetaColGap),
                              Expanded(
                                  child: Text('型号：${widget.data.model}',
                                      style: metaStyle)),
                            ],
                          ),
                          const SizedBox(
                              height: AccentDimens.deviceCardMetaGap),
                          Row(
                            children: [
                              Expanded(
                                  child: Text('系统：${widget.data.os}',
                                      style: metaStyle)),
                              const SizedBox(
                                  width: AccentDimens.deviceCardMetaColGap),
                              Expanded(
                                  child: Text('架构：${widget.data.abi}',
                                      style: metaStyle)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.data.isCurrent)
                Positioned(
                  right: AccentDimens.accountCardCurrentDotRight,
                  bottom: AccentDimens.accountCardCurrentDotBottom,
                  child: Container(
                    width: AccentDimens.accountCardCurrentDotSize,
                    height: AccentDimens.accountCardCurrentDotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.common.green,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nameField(Color onSurface) {
    final style = TextStyle(
      fontSize: AccentDimens.deviceCardTitleSize,
      fontWeight: FontWeight.w500,
      color: onSurface,
    );
    if (!_editing) {
      return Text(
        widget.data.displayName,
        style: style,
      );
    }
    return TextField(
      controller: _nameController,
      focusNode: _nameFocus,
      maxLength: AccentDimens.nameMaxLength,
      style: style,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _onEditOrSubmit(),
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
              color: onSurface, width: AccentDimens.nameInputUnderlineWidth),
        ),
      ),
    );
  }

  Widget _unbindActions(AppColors colors, Color onSurface) {
    final pending = widget.data.isUnbindPending;
    final executeAt = widget.data.effectiveUnbindExecuteAt;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pending && executeAt != null) ...[
          Text(
            _formatUnbindTime(executeAt),
            style: TextStyle(
              fontSize: AccentDimens.deviceCardUnbindTimeSize,
              color: onSurface.withValues(
                  alpha: AccentDimens.deviceCardUnbindTimeAlpha),
            ),
          ),
          const SizedBox(width: AccentDimens.deviceCardUnbindTimeGap),
        ],
        if (pending)
          _iconAction(
            icon: Icons.undo,
            color: onSurface.withValues(
                alpha: AccentDimens.deviceCardRenameAlpha),
            onPressed: _confirmCancelDelete,
          )
        else
          _trailingAction(colors, onSurface),
      ],
    );
  }

  static const _primaryStarAsset =
      'assets/icons/game-pack/five-pointed-star.svg';

  Widget _trailingAction(AppColors colors, Color onSurface) {
    final star = colors.common.devicePrimaryStar;
    switch (widget.data.action) {
      case DeviceCardAction.delete:
        return _iconAction(
          icon: Icons.delete_outline,
          color: colors.common.deviceDeleteIcon,
          onPressed: _confirmDelete,
        );
      case DeviceCardAction.cancelUnbind:
        return _iconAction(
          icon: Icons.undo,
          color: onSurface.withValues(
              alpha: AccentDimens.deviceCardRenameAlpha),
          onPressed: _confirmCancelDelete,
        );
      case DeviceCardAction.primaryStar:
        return _starAction(color: star, onPressed: _confirmPrimaryStar);
      case DeviceCardAction.primaryCancel:
        return _starAction(
          color: star.withValues(
              alpha: AccentDimens.deviceCardPrimaryCancelAlpha),
          onPressed: _confirmPrimaryCancel,
        );
      case DeviceCardAction.transferTarget:
        return _starAction(color: star, onPressed: _confirmTransferTarget);
      case DeviceCardAction.primaryStarReadonly:
        return _starAction(
          color: star.withValues(
              alpha: AccentDimens.deviceCardPrimaryReadonlyAlpha),
          onPressed: null,
        );
    }
  }

  /// 与帖子卡片收藏同一 SVG，着色为黄色
  Widget _starAction({
    required Color color,
    required Future<void> Function()? onPressed,
  }) {
    return IconButton(
      onPressed: _editing || onPressed == null
          ? null
          : () {
              onPressed();
            },
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: SvgPicture.asset(
        _primaryStarAsset,
        width: AccentDimens.deviceCardPrimaryStarSize,
        height: AccentDimens.deviceCardPrimaryStarSize,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required Future<void> Function()? onPressed,
  }) {
    return IconButton(
      onPressed: _editing || onPressed == null
          ? null
          : () {
              onPressed();
            },
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: Icon(
        icon,
        size: AccentDimens.deviceCardDeleteSize,
        color: color,
      ),
    );
  }

  Widget _editButton(Color onSurface) {
    return IconButton(
      onPressed: _onEditOrSubmit,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: Icon(
        _editing ? Icons.check : Icons.edit_outlined,
        size: AccentDimens.deviceCardRenameSize,
        color: onSurface.withValues(alpha: AccentDimens.deviceCardRenameAlpha),
      ),
    );
  }
}
