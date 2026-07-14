import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 设备与用户凭证安全存储
///
/// 全部存入 Keystore (Android) / Keychain (iOS)，不写入普通 SharedPreferences、日志或分析平台：
///   - device_id            服务端设备记录 ID
///   - device_secret        服务端设备凭证（保密）
///   - user_external_token  服务端用户凭证（保密）
///   - session_id           当前会话 ID（保密）
///   - session_secret       当前会话密钥（保密）
///   - fingerprint_hash     服务端返回的设备环境哈希（诊断用）
///
/// 退出登录只清 session；清除全部仅用于调试。
class DeviceCredentialStore {
  static const _storage = FlutterSecureStorage();

  static const _kDeviceId = 'device_id';
  static const _kDeviceSecret = 'device_secret';
  static const _kUserExternalToken = 'user_external_token';
  static const _kSessionId = 'session_id';
  static const _kSessionSecret = 'session_secret';
  static const _kFingerprintHash = 'fingerprint_hash';

  // ── device_id ──

  static Future<int?> getDeviceId() async {
    final raw = await _storage.read(key: _kDeviceId);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  static Future<void> saveDeviceId(int id) async {
    await _storage.write(key: _kDeviceId, value: id.toString());
  }

  // ── device_secret ──

  static Future<String?> getDeviceSecret() async {
    return _storage.read(key: _kDeviceSecret);
  }

  static Future<void> saveDeviceSecret(String secret) async {
    await _storage.write(key: _kDeviceSecret, value: secret);
  }

  // ── user_external_token ──

  static Future<String?> getUserExternalToken() async {
    return _storage.read(key: _kUserExternalToken);
  }

  static Future<void> saveUserExternalToken(String token) async {
    await _storage.write(key: _kUserExternalToken, value: token);
  }

  // ── session ──

  static Future<int?> getSessionId() async {
    final raw = await _storage.read(key: _kSessionId);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  static Future<void> saveSessionId(int id) async {
    await _storage.write(key: _kSessionId, value: id.toString());
  }

  static Future<String?> getSessionSecret() async {
    return _storage.read(key: _kSessionSecret);
  }

  static Future<void> saveSessionSecret(String secret) async {
    await _storage.write(key: _kSessionSecret, value: secret);
  }

  // ── fingerprint_hash ──

  static Future<String?> getFingerprintHash() async {
    return _storage.read(key: _kFingerprintHash);
  }

  static Future<void> saveFingerprintHash(String hash) async {
    await _storage.write(key: _kFingerprintHash, value: hash);
  }

  // ── 组合查询 ──

  /// 本地是否已有设备凭证（device_id + device_secret）
  static Future<bool> hasDeviceCredentials() async {
    final id = await _storage.read(key: _kDeviceId);
    final secret = await _storage.read(key: _kDeviceSecret);
    return id != null && secret != null;
  }

  /// 本地是否已有完整用户凭证（设备 + 用户 + session）
  static Future<bool> hasActiveSession() async {
    final sid = await _storage.read(key: _kSessionId);
    final ssec = await _storage.read(key: _kSessionSecret);
    final user = await _storage.read(key: _kUserExternalToken);
    return sid != null && ssec != null && user != null;
  }

  // ── 清除 ──

  /// 退出登录：只清 session，保留设备和用户凭证
  static Future<void> clearSession() async {
    await _storage.delete(key: _kSessionId);
    await _storage.delete(key: _kSessionSecret);
  }

  /// 调试用：清除全部凭证（模拟卸载重装）
  static Future<void> clearAll() async {
    await _storage.delete(key: _kDeviceId);
    await _storage.delete(key: _kDeviceSecret);
    await _storage.delete(key: _kUserExternalToken);
    await _storage.delete(key: _kSessionId);
    await _storage.delete(key: _kSessionSecret);
    await _storage.delete(key: _kFingerprintHash);
  }
}
