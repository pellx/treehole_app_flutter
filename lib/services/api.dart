import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/post.dart';

class ApiService {
  static const _base = 'https://tree.leisure.xin/node/posts';
  static const _imgBase = 'https://www.leisure.xin:33433/upload';
  static const _timeout = Duration(seconds: 10);
  static const _useMock = false;

  static Future<List<int>> getIdList() async {
    if (_useMock) return [12, 345, 6789];
    final res = await http.get(Uri.parse('$_base/idList')).timeout(_timeout);
    return List<int>.from(jsonDecode(res.body));
  }

  static Future<Post?> getPost(int id) async {
    if (_useMock) return _mockPost(id);
    try {
      final res = await http.get(Uri.parse('$_base/$id')).timeout(_timeout);
      if (res.statusCode != 200) return null;
      return Post.fromJson(jsonDecode(res.body));
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> downloadThumbnail(String fileName) async {
    try {
      final res = await http.get(Uri.parse('$_imgBase/$fileName!2thum')).timeout(_timeout);
      if (res.statusCode != 200) return null;
      return res.bodyBytes;
    } catch (_) {
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
