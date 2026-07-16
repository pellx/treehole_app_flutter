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
///      - 有 → 申请新 session
///      - 无 → 不做操作（用户尚未注册）
class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();

  /// 防止并发调用
  bool _ensuring = false;

  /// 确保当前有有效 session。
  ///
  /// 返回 true 表示 session 已就绪可用，false 表示无法获取 session。
  Future<bool> ensureSession() async {
    // 防止并发
    if (_ensuring) {
      debugPrint('[SessionService] ensureSession 已在执行中，跳过');
      return false;
    }
    _ensuring = true;
    try {
      return await _ensureSessionInternal();
    } finally {
      _ensuring = false;
    }
  }

  Future<bool> _ensureSessionInternal() async {
    // 1. 检查本地是否有 session
    final sessionId = await DeviceCredentialStore.getSessionId();
    final sessionSecret = await DeviceCredentialStore.getSessionSecret();

    if (sessionId != null && sessionSecret != null) {
      // 有 session → 校验有效性
      debugPrint('[SessionService] 本地有 session(id=$sessionId)，校验中...');
      final validateResult = await ApiService.validateSession(
        sessionId: sessionId,
        sessionSecret: sessionSecret,
      );
      if (validateResult != null && validateResult.valid) {
        debugPrint('[SessionService] session 仍有效(userId=${validateResult.userId})');
        return true;
      }
      debugPrint('[SessionService] session 已失效(result=$validateResult)，尝试重新申请');
      // session 失效，清掉旧的
      await DeviceCredentialStore.clearSession();
    } else {
      debugPrint('[SessionService] 本地无 session(sessionId=$sessionId, sessionSecret=${sessionSecret != null})');
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

    // 3. 计算 fingerprint_hash 并申请 session
    debugPrint('[SessionService] 有用户凭证，申请新 session...');
    final fingerprint = await DeviceFingerprintService.collect();
    final fingerprintHash = _computeFingerprintHash(fingerprint);
    debugPrint('[SessionService] fingerprintHash=$fingerprintHash');

    // 保存 fingerprint_hash 以备后用
    await DeviceCredentialStore.saveFingerprintHash(fingerprintHash);

    final createResult = await ApiService.createSession(
      userToken: userToken,
      deviceSecret: deviceSecret,
      fingerprintHash: fingerprintHash,
    );

    if (createResult != null) {
      debugPrint('[SessionService] session 申请成功(id=${createResult.sessionId})');
      await DeviceCredentialStore.saveSessionId(createResult.sessionId);
      await DeviceCredentialStore.saveSessionSecret(createResult.sessionSecret);
      return true;
    }

    debugPrint('[SessionService] session 申请失败(lastError=${ApiService.lastError})');
    return false;
  }

  /// 计算设备指纹的 SHA-256 hex
  static String _computeFingerprintHash(DeviceFingerprint fp) {
    final jsonStr = jsonEncode(fp.toJson());
    final bytes = utf8.encode(jsonStr);
    return sha256.convert(bytes).toString();
  }
}
