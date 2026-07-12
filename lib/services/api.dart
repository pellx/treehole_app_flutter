import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/comment.dart';
import '../models/device_fingerprint.dart';
import '../models/post.dart';
import 'pow.dart';
import '../models/post_draft.dart';
import '../models/upload_result.dart';
import '../models/version_info.dart';
import 'storage.dart';

bool _isHttpSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

enum RegistrationFailureType {
  networkError,
  deviceAlreadyRegistered,
  unknown,
}

class RegistrationResult {
  final bool success;
  final String? sessionSecret;
  final int? sessionId;
  final String? userExternalToken;
  final RegistrationFailureType? failureType;

  const RegistrationResult._({
    required this.success,
    this.sessionSecret,
    this.sessionId,
    this.userExternalToken,
    this.failureType,
  });

  factory RegistrationResult.ok(String sessionSecret, int sessionId, String userExternalToken) =>
      RegistrationResult._(success: true, sessionSecret: sessionSecret, sessionId: sessionId, userExternalToken: userExternalToken);

  factory RegistrationResult.failure(RegistrationFailureType type) =>
      RegistrationResult._(success: false, failureType: type);
}

class InitDeviceResult {
  final bool success;
  final int? deviceId;
  final String? deviceSecret;
  final String? fingerprintHash;

  const InitDeviceResult._({required this.success, this.deviceId, this.deviceSecret, this.fingerprintHash});

  factory InitDeviceResult.ok(int deviceId, String deviceSecret, String fingerprintHash) =>
      InitDeviceResult._(success: true, deviceId: deviceId, deviceSecret: deviceSecret, fingerprintHash: fingerprintHash);

  factory InitDeviceResult.failure() => const InitDeviceResult._(success: false);
}

class ApiService {
  static const _base = 'https://tree.leisure.xin/node/posts';
  static const _commentBase = 'https://tree.leisure.xin/node/posts/comment'; // 回复 API
  static const _thumbBase = 'https://tree.leisure.xin/node/file-processor/convert/2webp/upload';
  static const _originalBase = 'https://www.leisure.xin:33433/upload';
  static const _uploadBase = 'https://tree.leisure.xin/node/file-processor/upload';
  static const _versionBase = 'https://tree.leisure.xin/node/versions';
  static const _timeout = Duration(seconds: 30);
  static const _useMock = false;

  /// 最近一次 API 调用失败的错误消息（用于前端展示审核拒绝原因）
  static String? lastError;

  static Future<List<int>> getIdList() async {
    if (_useMock) return [12, 345, 6789];
    final res = await http.get(Uri.parse('$_base/idList')).timeout(_timeout);
    return List<int>.from(jsonDecode(res.body));
  }

  static Future<Post?> getPost(int id) async {
    if (_useMock) return _mockPost(id);
    try {
      final res = await http.get(Uri.parse('$_base/$id')).timeout(_timeout);
      if (!_isHttpSuccess(res.statusCode)) {
        debugPrint('[ApiService] getPost($id) status=${res.statusCode}');
        return null;
      }
      return Post.fromJson(jsonDecode(res.body));
    } catch (e) {
      debugPrint('[ApiService] getPost($id) error: $e');
      return null;
    }
  }

  static Future<ThumbnailData?> downloadThumbnail(String fileName) async {
    try {
      final isGif = fileName.toLowerCase().endsWith('.gif');
      final url = isGif
          ? '$_originalBase/$fileName'
          : '$_thumbBase/$fileName';
      final res = await http.get(Uri.parse(url)).timeout(_timeout);
      if (!_isHttpSuccess(res.statusCode)) {
        debugPrint('[ApiService] downloadThumbnail($fileName) status=${res.statusCode}');
        return null;
      }
      final bytes = res.bodyBytes;
      final dims = await _decodeSize(bytes);
      return ThumbnailData(bytes: bytes, width: dims.$1, height: dims.$2);
    } catch (e) {
      debugPrint('[ApiService] downloadThumbnail($fileName) error: $e');
      return null;
    }
  }

  static Future<(int, int)> _decodeSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width;
    final h = frame.image.height;
    frame.image.dispose();
    codec.dispose();
    return (w, h);
  }

  static Future<UploadResult?> uploadFile(PostUploadType type, File file) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadBase));
      request.fields['type'] = type.apiValue;
      request.fields['session_id'] = (PostStorage.getSessionId() ?? 0).toString();
      request.fields['session_secret'] = PostStorage.getSessionSecret() ?? '';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await request.send().timeout(_timeout);
      if (!_isHttpSuccess(streamed.statusCode)) {
        final body = await streamed.stream.bytesToString();
        debugPrint('[ApiService] uploadFile($type, ${file.path}) status=${streamed.statusCode} body=$body');
        lastError = _parseErrorMessage(body);
        return null;
      }
      final body = await streamed.stream.bytesToString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      return UploadResult(
        type: type,
        original: data['originalName'] as String? ?? file.uri.pathSegments.last,
        filename: data['filename'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('[ApiService] uploadFile($type, ${file.path}) error: $e');
      return null;
    }
  }

  static Future<Post?> createPost(PostDraft draft) async {
    try {
      final res = await http
          .post(
            Uri.parse(_base),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(draft.toJson()),
          )
          .timeout(_timeout);
      if (!_isHttpSuccess(res.statusCode)) {
        debugPrint('[ApiService] createPost status=${res.statusCode} body=${res.body}');
        lastError = _parseErrorMessage(res.body);
        return null;
      }
      return Post.fromJson(jsonDecode(res.body));
    } catch (e) {
      debugPrint('[ApiService] createPost error: $e');
      return null;
    }
  }

  // ---- 回复 ----

  static Future<Comment?> getComment(int id) async {
    try {
      final res = await http.get(Uri.parse('$_commentBase/$id')).timeout(_timeout);
      if (!_isHttpSuccess(res.statusCode)) {
        debugPrint('[ApiService] getComment($id) status=${res.statusCode}');
        return null;
      }
      return Comment.fromJson(jsonDecode(res.body));
    } catch (e) {
      debugPrint('[ApiService] getComment($id) error: $e');
      return null;
    }
  }

  static Future<Comment?> createComment({
    required int postId,
    required String content,
    String? author,
    int? toId,
  }) async {
    try {
      final body = <String, dynamic>{
        'postId': postId,
        'content': content,
        'session_id': PostStorage.getSessionId() ?? 0,
        'session_secret': PostStorage.getSessionSecret() ?? '',
      };
      if (author != null && author.isNotEmpty) body['author'] = author;
      if (toId != null) body['toId'] = toId;
      final res = await http
          .post(
            Uri.parse(_commentBase),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (!_isHttpSuccess(res.statusCode)) {
        debugPrint('[ApiService] createComment status=${res.statusCode} body=${res.body}');
        lastError = _parseErrorMessage(res.body);
        return null;
      }
      return Comment.fromJson(jsonDecode(res.body));
    } catch (e) {
      debugPrint('[ApiService] createComment error: $e');
      return null;
    }
  }

  /// 从 API 错误响应中提取 message 字段
  static String _parseErrorMessage(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['message'] as String? ?? '操作失败';
    } catch (_) {
      return '操作失败';
    }
  }

  // ---- 版本更新 ----

  static Future<VersionInfo?> getLatestVersion({String platform = 'android'}) async {
    try {
      final res = await http.get(Uri.parse('$_versionBase/latest?platform=$platform')).timeout(_timeout);
      if (!_isHttpSuccess(res.statusCode)) {
        debugPrint('[ApiService] getLatestVersion status=${res.statusCode}');
        return null;
      }
      return VersionInfo.fromJson(jsonDecode(res.body));
    } catch (e) {
      debugPrint('[ApiService] getLatestVersion error: $e');
      return null;
    }
  }

  static Future<List<VersionInfo>> getAllVersions({String platform = 'android'}) async {
    try {
      final res = await http.get(Uri.parse('$_versionBase?platform=$platform')).timeout(_timeout);
      if (!_isHttpSuccess(res.statusCode)) {
        debugPrint('[ApiService] getAllVersions status=${res.statusCode}');
        return [];
      }
      final list = jsonDecode(res.body) as List;
      return list.map((j) => VersionInfo.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[ApiService] getAllVersions error: $e');
      return [];
    }
  }

  // ---- 账号注册 ----

  static const _userBase = 'https://tree.leisure.xin/node/user';

  static Future<InitDeviceResult> initDevice({
    required String turnstileToken,
    required String powChallengeId,
    required int powNonce,
    required DeviceFingerprint deviceFingerPrint,
    required String uniqueToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'verification_turnstile': turnstileToken,
        'verification_pow': {
          'challenge_id': powChallengeId,
          'nonce': powNonce,
        },
        'device_finger_print': deviceFingerPrint.toJson(),
        'unique_token': uniqueToken,
      };
      final res = await http
          .post(Uri.parse('$_userBase/init-device'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(_timeout);
      if (_isHttpSuccess(res.statusCode)) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final deviceId = data['device_id'] as int?;
        final deviceSecret = data['device_secret'] as String?;
        final fingerprintHash = data['fingerprint_hash'] as String?;
        if (deviceId != null && deviceSecret != null && fingerprintHash != null) {
          return InitDeviceResult.ok(deviceId, deviceSecret, fingerprintHash);
        }
        debugPrint('[ApiService] initDevice parsed but missing fields: ${res.body}');
      } else {
        debugPrint('[ApiService] initDevice status=${res.statusCode} body=${res.body}');
      }
      return InitDeviceResult.failure();
    } catch (e) {
      debugPrint('[ApiService] initDevice error: $e');
      return InitDeviceResult.failure();
    }
  }

  /// 获取 PoW hashcash challenge
  static Future<PoWChallenge?> getPoWChallenge() async {
    try {
      final res = await http.get(Uri.parse('$_userBase/pow-challenge')).timeout(_timeout);
      if (!_isHttpSuccess(res.statusCode)) {
        debugPrint('[ApiService] getPoWChallenge status=${res.statusCode}');
        return null;
      }
      return PoWChallenge.fromJson(jsonDecode(res.body));
    } catch (e) {
      debugPrint('[ApiService] getPoWChallenge error: $e');
      return null;
    }
  }

  static Future<RegistrationResult> register({
    required int deviceId,
    required String deviceSecret,
    required String fingerprintHash,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$_userBase/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'device_id': deviceId,
                'device_secret': deviceSecret,
                'fingerprint_hash': fingerprintHash,
              }))
          .timeout(_timeout);
      if (_isHttpSuccess(res.statusCode)) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return RegistrationResult.ok(
          data['session_secret'] as String,
          data['session_id'] as int,
          data['user_external_token'] as String,
        );
      }
      if (res.statusCode == 401) return RegistrationResult.failure(RegistrationFailureType.deviceAlreadyRegistered);
      return RegistrationResult.failure(RegistrationFailureType.unknown);
    } catch (e) {
      debugPrint('[ApiService] register error: $e');
      return RegistrationResult.failure(RegistrationFailureType.networkError);
    }
  }

  static Future<RegistrationResult> login({
    required int deviceId,
    required String deviceSecret,
    required String userExternalToken,
    required String fingerprintHash,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$_userBase/login'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'device_id': deviceId,
                'device_secret': deviceSecret,
                'user_external_token': userExternalToken,
                'fingerprint_hash': fingerprintHash,
              }))
          .timeout(_timeout);
      if (_isHttpSuccess(res.statusCode)) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return RegistrationResult.ok(
          data['session_secret'] as String,
          data['session_id'] as int,
          data['user_external_token'] as String? ?? userExternalToken,
        );
      }
      if (res.statusCode == 401) return RegistrationResult.failure(RegistrationFailureType.deviceAlreadyRegistered);
      return RegistrationResult.failure(RegistrationFailureType.unknown);
    } catch (e) {
      debugPrint('[ApiService] login error: $e');
      return RegistrationResult.failure(RegistrationFailureType.networkError);
    }
  }

  /// 检查 session 是否仍然有效
  static Future<bool> checkSession({
    required int sessionId,
    required String sessionSecret,
  }) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_userBase/check-session').replace(queryParameters: {
              'session_id': sessionId.toString(),
              'session_secret': sessionSecret,
            }),
          )
          .timeout(_timeout);
      if (_isHttpSuccess(res.statusCode)) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['valid'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] checkSession error: $e');
      return false;
    }
  }

  /// 用户改名（5 天冷却期）
  static Future<String?> rename({
    required String userExternalToken,
    required String newName,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$_userBase/rename'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'user_external_token': userExternalToken,
                'new_name': newName,
              }))
          .timeout(_timeout);
      if (_isHttpSuccess(res.statusCode)) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['user_display_id'] as String?;
      }
      lastError = _parseErrorMessage(res.body);
      debugPrint('[ApiService] rename status=${res.statusCode} body=${res.body}');
      return null;
    } catch (e) {
      debugPrint('[ApiService] rename error: $e');
      lastError = '网络连接失败';
      return null;
    }
  }

  static Post _mockPost(int id) {
    return Post(
      id: id,
      title: 'Mock Post $id',
      content: 'This is mock content for post $id.',
      author: 'mock_user',
      createdAt: DateTime.now().toIso8601String(),
    );
  }
}

class ThumbnailData {
  final Uint8List bytes;
  final int width;
  final int height;
  const ThumbnailData({required this.bytes, required this.width, required this.height});
}
