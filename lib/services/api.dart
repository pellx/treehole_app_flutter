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
import 'device_credential_store.dart';

bool _isHttpSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

/// POST /user/register 返回的凭证
class RegisterResult {
  final String userToken;
  final String deviceSecret;

  const RegisterResult({required this.userToken, required this.deviceSecret});
}

/// POST /user/session/create 返回的 session 凭证
class SessionCreateResult {
  final int sessionId;
  final String sessionSecret;

  const SessionCreateResult({required this.sessionId, required this.sessionSecret});
}

/// POST /user/session/validate 返回的校验结果
class SessionValidateResult {
  final bool valid;
  final int? userId;

  const SessionValidateResult({required this.valid, this.userId});
}

/// PoW 求解结果（challenge_id + nonce）
class PoWResult {
  final String challengeId;
  final int nonce;

  const PoWResult({required this.challengeId, required this.nonce});
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
      final sessionId = await DeviceCredentialStore.getSessionId() ?? 0;
      final sessionSecret = await DeviceCredentialStore.getSessionSecret() ?? '';
      final request = http.MultipartRequest('POST', Uri.parse(_uploadBase));
      request.fields['type'] = type.apiValue;
      request.fields['session_id'] = sessionId.toString();
      request.fields['session_secret'] = sessionSecret;
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
      final sessionId = await DeviceCredentialStore.getSessionId() ?? 0;
      final sessionSecret = await DeviceCredentialStore.getSessionSecret() ?? '';
      final body = <String, dynamic>{
        'postId': postId,
        'content': content,
        'session_id': sessionId,
        'session_secret': sessionSecret,
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

  /// POST /user/check — 纯查询，不消耗 Turnstile/PoW，返回该指纹是否已注册
  static Future<bool?> check({
    required DeviceFingerprint deviceFingerPrint,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$_userBase/check'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'device_finger_print': deviceFingerPrint.toJson(),
              }))
          .timeout(_timeout);
      if (_isHttpSuccess(res.statusCode)) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['registered'] as bool? ?? false;
      }
      debugPrint('[ApiService] check status=${res.statusCode} body=${res.body}');
      return null;
    } catch (e) {
      debugPrint('[ApiService] check error: $e');
      return null;
    }
  }

  /// POST /user/register — 为新设备创建用户，返回 user_token + device_secret
  static Future<RegisterResult?> register({
    required String userDisplayId,
    required DeviceFingerprint deviceFingerPrint,
    required String verificationTurnstile,
    required PoWResult verificationPow,
  }) async {
    try {
      final requestBody = {
        'user_display_id': userDisplayId,
        'device_finger_print': deviceFingerPrint.toJson(),
        'verification_turnstile': verificationTurnstile,
        'verification_pow': {
          'challenge_id': verificationPow.challengeId,
          'nonce': verificationPow.nonce,
        },
      };
      debugPrint('[ApiService] register request: ${jsonEncode(requestBody)}');
      final res = await http
          .post(Uri.parse('$_userBase/register'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestBody))
          .timeout(_timeout);
      if (_isHttpSuccess(res.statusCode)) {
        debugPrint('[ApiService] register success body=${res.body}');
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final token = data['user_token'] as String?;
        final secret = data['device_secret'] as String?;
        if (token != null && secret != null) {
          return RegisterResult(userToken: token, deviceSecret: secret);
        }
        lastError = '响应缺少字段（token=$token, secret=$secret）';
        debugPrint('[ApiService] register missing fields: ${res.body}');
      } else {
        lastError = _parseErrorMessage(res.body);
        debugPrint('[ApiService] register status=${res.statusCode} body=${res.body}');
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] register error: $e');
      return null;
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

  /// POST /user/session/create — 申请 session
  /// 需要注册时获得的 user_token + device_secret + fingerprint_hash
  static Future<SessionCreateResult?> createSession({
    required String userToken,
    required String deviceSecret,
    required String fingerprintHash,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$_userBase/session/create'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'user_token': userToken,
                'device_secret': deviceSecret,
                'fingerprint_hash': fingerprintHash,
              }))
          .timeout(_timeout);
      if (_isHttpSuccess(res.statusCode)) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final sessionId = data['session_id'] as int?;
        final sessionSecret = data['session_secret'] as String?;
        if (sessionId != null && sessionSecret != null) {
          return SessionCreateResult(sessionId: sessionId, sessionSecret: sessionSecret);
        }
        debugPrint('[ApiService] createSession missing fields: ${res.body}');
        return null;
      }
      lastError = _parseErrorMessage(res.body);
      debugPrint('[ApiService] createSession status=${res.statusCode} body=${res.body}');
      return null;
    } catch (e) {
      debugPrint('[ApiService] createSession error: $e');
      return null;
    }
  }

  /// POST /user/session/validate — 校验 session 是否有效
  static Future<SessionValidateResult?> validateSession({
    required int sessionId,
    required String sessionSecret,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$_userBase/session/validate'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'session_id': sessionId,
                'session_secret': sessionSecret,
              }))
          .timeout(_timeout);
      if (_isHttpSuccess(res.statusCode)) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return SessionValidateResult(
          valid: data['valid'] == true,
          userId: data['user_id'] as int?,
        );
      }
      debugPrint('[ApiService] validateSession status=${res.statusCode} body=${res.body}');
      return null;
    } catch (e) {
      debugPrint('[ApiService] validateSession error: $e');
      return null;
    }
  }

  /// 用户改名（5 天冷却期）
  static Future<String?> rename({
    required String userToken,
    required String newName,
  }) async {
    try {
      final res = await http
          .post(Uri.parse('$_userBase/rename'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'user_token': userToken,
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
