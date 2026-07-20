import 'package:flutter/material.dart';

import '../../services/realtime_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

/// 用户设置：含 Socket.IO 连通性测试（`test.start` / `test.tick`）
class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({super.key});

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  bool _busy = false;

  RealtimeService get _rt => RealtimeService.instance;

  @override
  void dispose() {
    _rt.stopTest();
    super.dispose();
  }

  Future<void> _ensureConnected() async {
    if (_rt.isConnected) return;
    setState(() => _busy = true);
    try {
      await SessionService.instance.ensureSession();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleTest(bool on) async {
    if (on) {
      await _ensureConnected();
      if (!mounted) return;
      if (!_rt.startTest()) {
        setState(() {});
      } else {
        setState(() {});
      }
    } else {
      _rt.stopTest();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _statusRow(
          label: '实时连接',
          child: ValueListenableBuilder<String>(
            valueListenable: _rt.connectionLabel,
            builder: (_, label, __) => Text(
              label,
              style: TextStyle(
                fontSize: AppDimens.settingsItemFontSize,
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: colors.common.divider),
        ValueListenableBuilder<bool>(
          valueListenable: _rt.testRunning,
          builder: (_, running, __) => _switchRow(
            label: 'WS 测试',
            value: running,
            enabled: !_busy,
            onChanged: _toggleTest,
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: colors.common.divider),
        _statusRow(
          label: '收到推送',
          child: ValueListenableBuilder<String?>(
            valueListenable: _rt.lastTestTickLabel,
            builder: (_, text, __) => Text(
              text ?? '（开启测试后显示）',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: AppDimens.settingsItemFontSize,
                color: onSurface.withValues(
                  alpha: text == null ? 0.4 : 0.85,
                ),
              ),
            ),
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: colors.common.divider),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            '开启后向服务端发送 test.start，每秒显示 test.tick 的递增数字，用于确认 WebSocket 已建立。',
            style: TextStyle(
              fontSize: 12,
              color: onSurface.withValues(alpha: 0.45),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusRow({required String label, required Widget child}) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: AppDimens.settingsItemHeight,
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppDimens.settingsItemFontSize,
              color: onSurface,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Align(alignment: Alignment.centerRight, child: child)),
        ],
      ),
    );
  }

  Widget _switchRow({
    required String label,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: AppDimens.settingsItemHeight,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppDimens.settingsItemFontSize,
                color: onSurface,
              ),
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
        ],
      ),
    );
  }
}
