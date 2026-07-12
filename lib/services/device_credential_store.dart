import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 设备凭证安全存储
///
/// 管理四项数据，全部存入 Keystore (Android) / Keychain (iOS)：
///   - unique_token     客户端生成的安装标识
///   - device_id        服务端 init-device 返回
///   - device_secret    服务端 init-device 返回
///   - fingerprint_hash 服务端返回或客户端重算
///
/// 核心规则：
///   一旦本地已有 unique_token，绝不重新生成。
///   登出只清 session，不清这些值。
class DeviceCredentialStore {
  static const _storage = FlutterSecureStorage();

  static const _kUniqueToken = 'unique_token';
  static const _kDeviceId = 'device_id';
  static const _kDeviceSecret = 'device_secret';
  static const _kFingerprintHash = 'fingerprint_hash';

  // ── unique_token ──

  /// 获取或首次生成 unique_token（32 字节 → 64 位小写十六进制）
  static Future<String> getOrCreateUniqueToken() async {
    var token = await _storage.read(key: _kUniqueToken);
    if (token != null) return token;

    token = _generateToken();
    await _storage.write(key: _kUniqueToken, value: token);
    return token;
  }

  static Future<String?> getUniqueToken() async {
    return _storage.read(key: _kUniqueToken);
  }

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

  // ── fingerprint_hash ──

  static Future<String?> getFingerprintHash() async {
    return _storage.read(key: _kFingerprintHash);
  }

  static Future<void> saveFingerprintHash(String hash) async {
    await _storage.write(key: _kFingerprintHash, value: hash);
  }

  // ── 组合查询 ──

  /// 本地是否已有完整的设备凭证（device_id + device_secret）
  /// 有则说明已经走过 init-device，不应再调
  static Future<bool> hasDeviceCredentials() async {
    final id = await _storage.read(key: _kDeviceId);
    final secret = await _storage.read(key: _kDeviceSecret);
    return id != null && secret != null;
  }

  // ── 清除 ──

  /// 清除全部四项（仅用于调试 / 用户主动清除数据）
  static Future<void> clearAll() async {
    await _storage.delete(key: _kUniqueToken);
    await _storage.delete(key: _kDeviceId);
    await _storage.delete(key: _kDeviceSecret);
    await _storage.delete(key: _kFingerprintHash);
  }

  // ── 内部 ──

  static String _generateToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
