import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../services/binding_cache.dart';
import '../../services/device_credential_store.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_dimens_accent.dart';
import '../../widgets/device_card.dart';
import 'user_sub_page_shell.dart';

/// 设备绑定页：先展示本地缓存，再请求最新并按需更新
class DeviceBindingPage extends StatefulWidget {
  const DeviceBindingPage({super.key});

  @override
  State<DeviceBindingPage> createState() => _DeviceBindingPageState();
}

class _DeviceBindingPageState extends State<DeviceBindingPage> {
  List<DeviceCardData> _devices = [];
  /// 仅在无缓存且首次请求未完成时显示加载
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cached = BindingCache.getDevices();
    if (cached.isNotEmpty) {
      _devices = cached.map(_toCard).toList();
    } else {
      _loading = true;
    }
    _loadDevices();
  }

  Future<({int id, String secret})?> _readySession() async {
    final ok = await SessionService.instance.ensureSession();
    if (!ok) return null;
    final id = await DeviceCredentialStore.getSessionId();
    final secret = await DeviceCredentialStore.getSessionSecret();
    if (id == null || secret == null) return null;
    return (id: id, secret: secret);
  }

  DeviceCardData _toCard(BoundDeviceInfo info) {
    final fallbackName = (info.deviceName?.trim().isNotEmpty == true)
        ? info.deviceName!.trim()
        : (info.model?.trim().isNotEmpty == true ? info.model!.trim() : '设备');
    return DeviceCardData(
      bindingId: info.bindingId,
      deviceId: info.deviceId,
      status: info.status,
      unbindRequestedAt: info.unbindRequestedAt,
      unbindExecuteAt: info.unbindExecuteAt ?? info.effectiveUnbindExecuteAt,
      customName: info.deviceDisplayName,
      deviceName: fallbackName,
      brand: info.brand?.trim().isNotEmpty == true ? info.brand!.trim() : '未知',
      model: info.model?.trim().isNotEmpty == true ? info.model!.trim() : '未知',
      os: info.os?.trim().isNotEmpty == true ? info.os!.trim() : '未知',
      memory:
          info.memory?.trim().isNotEmpty == true ? info.memory!.trim() : '未知',
    );
  }

  bool _cardListEqual(List<DeviceCardData> a, List<DeviceCardData> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].bindingId != b[i].bindingId ||
          a[i].deviceId != b[i].deviceId ||
          a[i].status != b[i].status ||
          a[i].unbindRequestedAt != b[i].unbindRequestedAt ||
          a[i].unbindExecuteAt != b[i].unbindExecuteAt ||
          a[i].customName != b[i].customName ||
          a[i].deviceName != b[i].deviceName ||
          a[i].brand != b[i].brand ||
          a[i].model != b[i].model ||
          a[i].os != b[i].os ||
          a[i].memory != b[i].memory) {
        return false;
      }
    }
    return true;
  }

  Future<void> _persistDevicesFromCards() async {
    await BindingCache.saveDevices(
      _devices
          .map((d) => BoundDeviceInfo(
                bindingId: d.bindingId,
                deviceId: d.deviceId,
                status: d.status,
                unbindRequestedAt: d.unbindRequestedAt,
                unbindExecuteAt: d.unbindExecuteAt,
                deviceDisplayName: d.customName,
                deviceName: d.deviceName,
                brand: d.brand,
                model: d.model,
                os: d.os,
                memory: d.memory,
              ))
          .toList(),
    );
  }

  Future<void> _loadDevices() async {
    final list = await BindingCache.refreshDevices();
    if (!mounted) return;

    if (list == null) {
      setState(() {
        _loading = false;
        if (_devices.isEmpty) {
          _error = ApiService.lastError ?? '加载设备失败';
        }
      });
      return;
    }

    final next = list.map(_toCard).toList();
    final changed = !_cardListEqual(_devices, next);
    setState(() {
      _loading = false;
      _error = null;
      if (changed) _devices = next;
    });
  }

  Future<void> _onRename(int index, String name) async {
    final device = _devices[index];
    final previous = device;
    setState(() {
      _devices[index] = name == device.deviceName
          ? device.copyWith(clearCustomName: true)
          : device.copyWith(customName: name);
    });
    await _persistDevicesFromCards();

    final session = await _readySession();
    if (session == null) {
      if (!mounted) return;
      setState(() => _devices[index] = previous);
      await _persistDevicesFromCards();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('会话验证失败，请稍后重试'), duration: Duration(seconds: 2)),
      );
      return;
    }

    final result = await ApiService.renameBinding(
      sessionId: session.id,
      sessionSecret: session.secret,
      bindingId: device.bindingId,
      newName: name,
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => _devices[index] = previous);
      await _persistDevicesFromCards();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.lastError ?? '设备改名失败'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      final d = _devices[index];
      _devices[index] = result == d.deviceName
          ? d.copyWith(clearCustomName: true)
          : d.copyWith(customName: result);
    });
    await _persistDevicesFromCards();
  }

  Future<void> _onDelete(int index) async {
    final device = _devices[index];
    final session = await _readySession();
    if (session == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('会话验证失败，请稍后重试'), duration: Duration(seconds: 2)),
      );
      return;
    }

    final result = await ApiService.deleteBinding(
      sessionId: session.id,
      sessionSecret: session.secret,
      bindingId: device.bindingId,
    );
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.lastError ?? '解绑失败'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _devices[index] = device.copyWith(
        status: result.status,
        unbindRequestedAt: result.unbindRequestedAt,
        unbindExecuteAt: result.unbindExecuteAt,
      );
    });
    await _persistDevicesFromCards();
  }

  Future<void> _onCancelDelete(int index) async {
    final device = _devices[index];
    final session = await _readySession();
    if (session == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('会话验证失败，请稍后重试'), duration: Duration(seconds: 2)),
      );
      return;
    }

    final ok = await ApiService.cancelDeleteBinding(
      sessionId: session.id,
      sessionSecret: session.secret,
      bindingId: device.bindingId,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.lastError ?? '取消解绑失败'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _devices[index] = device.copyWith(
        status: 'active',
        clearUnbind: true,
      );
    });
    await _persistDevicesFromCards();
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
              TextButton(onPressed: _loadDevices, child: const Text('重试')),
            ],
          ),
        ),
      );
    } else if (_devices.isEmpty) {
      body = Center(
        child: Text(
          '暂无绑定设备',
          style: TextStyle(
            fontSize: AccentDimens.itemFontSize,
            color: onSurface.withValues(alpha: 0.55),
          ),
        ),
      );
    } else {
      body = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: RefreshIndicator(
          onRefresh: _loadDevices,
          child: ListView.separated(
            padding: const EdgeInsets.all(AccentDimens.pagePadding),
            itemCount: _devices.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AccentDimens.deviceCardGap),
            itemBuilder: (context, index) {
              return DeviceCard(
                key: ValueKey('${_devices[index].deviceId}-$index'),
                data: _devices[index],
                onRenameSubmit: (name) => _onRename(index, name),
                onDelete: () => _onDelete(index),
                onCancelDelete: () => _onCancelDelete(index),
              );
            },
          ),
        ),
      );
    }

    return UserSubPageShell(title: '设备绑定', body: body);
  }
}
