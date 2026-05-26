import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import '../models/post.dart';

class ApiService {
  static const _base = 'https://tree.leisure.xin/node/posts';
  static const _thumbBase = 'https://tree.leisure.xin/node/file-processor/convert/2webp/upload';
  static const _timeout = Duration(seconds: 30);
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

  static Future<ThumbnailData?> downloadThumbnail(String fileName) async {
    try {
      final res = await http.get(Uri.parse('$_thumbBase/$fileName')).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final bytes = res.bodyBytes;
      final dims = await _decodeSize(bytes);
      return ThumbnailData(bytes: bytes, width: dims.$1, height: dims.$2);
    } catch (_) {
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
