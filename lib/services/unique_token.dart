import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// 设备唯一标识管理 — 通过 flutter_secure_storage 持久化
class UniqueTokenService {
  static const _key = 'unique_token';
  static const _storage = FlutterSecureStorage();

  /// 获取或首次生成 unique_token（永久保存）
  static Future<String> getOrCreate() async {
    var token = await _storage.read(key: _key);
    if (token == null) {
      token = const Uuid().v4();
      await _storage.write(key: _key, value: token);
    }
    return token;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
