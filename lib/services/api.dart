import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/comment.dart';
import '../models/post.dart';
import '../models/post_draft.dart';
import '../models/upload_result.dart';
import '../models/version_info.dart';

bool _isHttpSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

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

  static Future<UploadResult?> uploadFile(PostUploadType type, File file, {String? clientToken}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadBase));
      request.fields['type'] = type.apiValue;
      if (clientToken != null) request.fields['client_token'] = clientToken;
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
    String? clientToken,
  }) async {
    try {
      final body = <String, dynamic>{
        'postId': postId,
        'content': content,
      };
      if (author != null && author.isNotEmpty) body['author'] = author;
      if (toId != null) body['toId'] = toId;
      if (clientToken != null) body['client_token'] = clientToken;
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

  static Future<bool> register({
    required String clientToken,
    required String deviceId,
    required String platform,
    required String deviceModel,
    required String osVersion,
    String? brand,
    String? manufacturer,
    bool isPhysicalDevice = true,
    List<String>? supportedAbis,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_userBase/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'client_token': clientToken,
              'device_id': deviceId,
              'platform': platform,
              'device_model': deviceModel,
              'os_version': osVersion,
              'brand': brand,
              'manufacturer': manufacturer,
              'is_physical_device': isPhysicalDevice,
              'supported_abis': supportedAbis,
            }),
          )
          .timeout(_timeout);
      return _isHttpSuccess(res.statusCode);
    } catch (e) {
      debugPrint('[ApiService] register error: $e');
      return false;
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
