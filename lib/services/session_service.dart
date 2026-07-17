import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/device_fingerprint.dart';
import 'api.dart';
import 'device_credential_store.dart';
import 'device_fingerprint.dart';

/// Session 管理服务
///
/// 统一管理 session 的申请和校验。
/// 调用时机：每次唤出输入框时（回复栏、注册页等）。
///
/// 逻辑：
///   1. 本地有 session → 校验有效性 → 有效则继续
///   2. 无 session 或无效 → 检查是否有用户凭证（user_token + device_secret）
///      - 有 → 实时采集指纹 → 计算不变字段哈希 → 申请新 session
///      - 无 → 不做操作（用户尚未注册）
class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();

  /// 正在进行的 ensureSession 调用，用于让并发调用者等待而非直接失败
  Completer<bool>? _pending;

  /// 最近一次 session 校验通过的时间；短期内重复调用跳过网络校验
  DateTime? _lastValidatedAt;
  static const _validationCacheTtl = Duration(minutes: 5);

  /// 使校验缓存失效（收到 401 等 session 失效信号时调用）
  void invalidate() => _lastValidatedAt = null;

  /// 确保当前有有效 session。
  ///
  /// 返回 true 表示 session 已就绪可用，false 表示无法获取 session。
  Future<bool> ensureSession() async {
    if (_pending != null) {
      debugPrint('[SessionService] ensureSession 正在执行中，等待结果...');
      return _pending!.future;
    }
    _pending = Completer<bool>();
    try {
      final result = await _ensureSessionInternal();
      _pending!.complete(result);
      return result;
    } catch (e) {
      _pending!.complete(false);
      rethrow;
    } finally {
      _pending = null;
    }
  }

  Future<bool> _ensureSessionInternal() async {
    // 1. 检查本地是否有 session
    final sessionId = await DeviceCredentialStore.getSessionId();
    final sessionSecret = await DeviceCredentialStore.getSessionSecret();

    if (sessionId != null && sessionSecret != null) {
      final lastValidated = _lastValidatedAt;
      if (lastValidated != null &&
          DateTime.now().difference(lastValidated) < _validationCacheTtl) {
        debugPrint('[SessionService] session 近期已校验，跳过网络请求');
        return true;
      }
      debugPrint('[SessionService] 本地有 session(id=$sessionId)，校验中...');
      final validateResult = await ApiService.validateSession(
        sessionId: sessionId,
        sessionSecret: sessionSecret,
      );
      if (validateResult != null && validateResult.valid) {
        debugPrint('[SessionService] session 仍有效(userId=${validateResult.userId})');
        _lastValidatedAt = DateTime.now();
        return true;
      }
      debugPrint('[SessionService] session 已失效，尝试重新申请');
      _lastValidatedAt = null;
      await DeviceCredentialStore.clearSession();
    } else {
      debugPrint('[SessionService] 本地无 session');
    }

    // 2. 检查是否有用户凭证（注册时获得的 user_token + device_secret）
    final userToken = await DeviceCredentialStore.getUserExternalToken();
    final deviceSecret = await DeviceCredentialStore.getDeviceSecret();

    debugPrint('[SessionService] userToken=${userToken != null ? "存在(${userToken.length}字符)" : "NULL"}, '
        'deviceSecret=${deviceSecret != null ? "存在(${deviceSecret.length}字符)" : "NULL"}');

    if (userToken == null || deviceSecret == null) {
      debugPrint('[SessionService] 无用户凭证，无法申请 session（用户尚未注册）');
      return false;
    }

    // 3. 实时采集设备指纹，只用不变字段计算哈希
    debugPrint('[SessionService] 实时采集设备指纹...');
    final fingerprint = await DeviceFingerprintService.collect();
    final fingerprintHash = _computeFingerprintHash(fingerprint);
    debugPrint('[SessionService] fingerprintHash=$fingerprintHash');

    final createResult = await ApiService.createSession(
      userToken: userToken,
      deviceSecret: deviceSecret,
      fingerprintHash: fingerprintHash,
    );

    if (createResult != null) {
      debugPrint('[SessionService] session 申请成功(id=${createResult.sessionId})');
      await DeviceCredentialStore.saveSessionId(createResult.sessionId);
      await DeviceCredentialStore.saveSessionSecret(createResult.sessionSecret);
      _lastValidatedAt = DateTime.now();
      return true;
    }

    debugPrint('[SessionService] session 申请失败(lastError=${ApiService.lastError})');
    return false;
  }

  /// 计算设备指纹的 SHA-256 hex（每次 session 申请实时采集后计算，不持久化）
  ///
  /// 与后端 FingerprintService.computeHardwareHash() v2 保持一致：
  /// 仅含严格硬件身份字段；数组 sort 后用逗号拼接；所有值用 | 连接后 SHA-256。
  /// 可变字段（ROM 构建信息、systemFeatures、serialNumber 等）已排除，见 advice.md。
  static String _computeFingerprintHash(DeviceFingerprint fp) {
    final fields = <String>[];
    final values = <String>[];

    void add(String name, String value) {
      fields.add(name);
      values.add(value);
    }

    if (fp.platform == DevicePlatform.android && fp.android != null) {
      final a = fp.android!;

      // build_* — 仅硬件身份字段（排除 host/tags/type/bootloader，随 ROM 重建可能变）
      add('build_board', a.build.board);
      add('build_brand', a.build.brand);
      add('build_device', a.build.device);
      add('build_hardware', a.build.hardware);
      add('build_manufacturer', a.build.manufacturer);
      add('build_model', a.build.model);
      add('build_product', a.build.product);

      // abi_* — sort 后 join
      add('abi_supported_abis', _sortedJoin(a.abi.supportedAbis));
      add('abi_supported_32bit', _sortedJoin(a.abi.supported32BitAbis));
      add('abi_supported_64bit', _sortedJoin(a.abi.supported64BitAbis));

      // hw_* — 仅硬件常量（排除 serialNumber、systemFeatures、isLowRamDevice）
      add('hw_is_physical_device', _boolString(a.hardware.isPhysicalDevice));
      add('hw_physical_ram_size', a.hardware.physicalRamSize.toString());
      add('hw_total_disk_size', a.hardware.totalDiskSize.toString());
    } else if (fp.platform == DevicePlatform.ios && fp.ios != null) {
      final i = fp.ios!;

      add('ios_model', i.device.model);
      add('ios_model_name', i.device.modelName);
      add('ios_system_name', i.device.systemName);
      add('ios_localized_model', i.device.localizedModel);
      add('ios_is_physical_device', _boolString(i.device.isPhysicalDevice));
      add('ios_is_ios_app_on_mac', _boolString(i.device.isiOSAppOnMac));
      add('ios_physical_ram_size', i.storage.physicalRamSize.toString());
      add('ios_sysname', i.utsname.sysname);
      add('ios_machine', i.utsname.machine);
    } else {
      // unknown platform — 回退到完整 JSON hash
      final jsonStr = jsonEncode(fp.toJson());
      final bytes = utf8.encode(jsonStr);
      return sha256.convert(bytes).toString();
    }

    debugPrint('[SessionService] === hash 输入字段(${fields.length}个) ===');
    for (int i = 0; i < fields.length; i++) {
      final v = values[i];
      final display = v.length > 80 ? '${v.substring(0, 80)}...(len=${v.length})' : v;
      debugPrint('[SessionService]   $i: ${fields[i]} = $display');
    }
    final input = values.join('|');
    debugPrint('[SessionService] 拼接总长度=${input.length}');
    debugPrint('[SessionService] 拼接前200字符: ${input.substring(0, input.length < 200 ? input.length : 200)}');
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  static String _sortedJoin(List<String> values) {
    final copy = [...values]..sort();
    return copy.join(',');
  }

  static String _boolString(bool value) => value ? 'true' : 'false';
}
