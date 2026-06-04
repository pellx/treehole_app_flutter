import 'dart:io';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../services/api.dart';

class PostStorage {
  static const _idListKey = 'id_list';
  static late Box _idBox;
  static late Box _postBox;
  static late Box _thumbBox;
  static late Box _commentBox; // 回复 Hive 缓存
  static late Box _customColorsBox; // 自定义颜色缓存

  static Future<void> init() async {
    _idBox = await Hive.openBox('id_list');
    _postBox = await Hive.openBox('posts');
    _thumbBox = await Hive.openBox('thumbnails');
    _commentBox = await Hive.openBox('comments');
    _customColorsBox = await Hive.openBox('custom_colors');
  }

  // ---- ID 列表 ----

  static List<int> getIdList() {
    final raw = _idBox.get(_idListKey);
    if (raw == null) return [];
    return List<int>.from(raw as List);
  }

  static Future<void> saveIdList(List<int> ids) async {
    await _idBox.put(_idListKey, ids);
  }

  static List<int> mergeAndSaveIdList(List<int> newIds) {
    final old = getIdList();
    final merged = <int>[...newIds];
    for (final id in old) {
      if (!merged.contains(id)) merged.add(id);
    }
    _idBox.put(_idListKey, merged);
    return merged;
  }

  // ---- 帖子内容 ----

  static Post? getPost(int id) {
    final raw = _postBox.get(id);
    if (raw == null) return null;
    final map = Map<String, dynamic>.from(raw as Map);
    map.remove('fetched');
    return Post.fromJson(map);
  }

  static Future<void> savePost(Post post) async {
    final map = <String, dynamic>{
      'id': post.id,
      'title': post.title,
      'content': post.content,
      'author': post.author,
      'created_at': post.createdAt,
      'update_at': post.updateAt,
      'images': post.images.map((e) => {'file_name': e.fileName}).toList(),
      'attachments': post.attachments
          .map((e) => {'file_name': e.fileName, 'source_name': e.sourceName})
          .toList(),
      'comments': post.comments,
      'fetched': true,
    };
    await _postBox.put(post.id, map);
  }

  static Future<void> updatePostCommentIds(int postId, List<int> newIds) async {
    final raw = _postBox.get(postId);
    if (raw == null) return;
    final map = Map<String, dynamic>.from(raw as Map);
    map['comments'] = newIds;
    await _postBox.put(postId, map);
  }

  static Future<void> markFetched(int id) async {
    final raw = _postBox.get(id);
    if (raw != null) {
      final map = Map<String, dynamic>.from(raw as Map);
      map['fetched'] = true;
      await _postBox.put(id, map);
    }
  }

  static bool isFetched(int id) {
    final raw = _postBox.get(id);
    if (raw == null) return false;
    final map = raw as Map;
    return map['fetched'] == true;
  }

  static List<int> getCachedIds() {
    return _postBox.keys.cast<int>().toList();
  }

  static List<int> getFetchedIds() {
    return _postBox.keys.cast<int>().where((id) => isFetched(id)).toList();
  }

  static List<Post> getAllCachedPosts() {
    return _postBox.keys.cast<int>().map((id) => getPost(id)!).where((p) => true).toList();
  }

  // ---- 缩略图 ----

  static ThumbnailData? getThumbnail(String fileName) {
    final raw = _thumbBox.get('thumb_$fileName');
    if (raw == null) return null;
    // 兼容旧格式（Uint8List）和新格式（Map）
    if (raw is Uint8List) {
      return ThumbnailData(bytes: raw, width: 0, height: 0);
    }
    final map = raw as Map;
    return ThumbnailData(
      bytes: map['bytes'] as Uint8List,
      width: map['w'] as int,
      height: map['h'] as int,
    );
  }

  static Future<void> saveThumbnail(String fileName, ThumbnailData data) async {
    await _thumbBox.put('thumb_$fileName', {
      'bytes': data.bytes,
      'w': data.width,
      'h': data.height,
    });
  }

  // ---- PNG 原图文件缓存 ----

  static Future<Directory> _pngCacheDir() async {
    final dir = Directory(
        '${(await getTemporaryDirectory()).path}/png_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Uint8List?> getPng(String fileName) async {
    final file = File(
        '${(await _pngCacheDir()).path}/$fileName');
    if (await file.exists()) return await file.readAsBytes();
    return null;
  }

  static Future<void> savePng(String fileName, Uint8List bytes) async {
    final file = File(
        '${(await _pngCacheDir()).path}/$fileName');
    await file.writeAsBytes(bytes);
  }

  // ---- 回复缓存 ----

  static Comment? getComment(int id) {
    final raw = _commentBox.get(id);
    if (raw == null) return null;
    final map = Map<String, dynamic>.from(raw as Map);
    return Comment.fromJson(map);
  }

  static Future<void> saveComment(Comment comment) async {
    await _commentBox.put(comment.id, <String, dynamic>{
      'id': comment.id,
      'post_id': comment.postId,
      'to_id': comment.toId,
      'author': comment.author,
      'content': comment.content,
      'created_at': comment.createdAt,
    });
  }

  static List<Comment> getComments(List<int> ids) {
    return ids.map((id) => getComment(id)).whereType<Comment>().toList();
  }

  // ---- 自定义颜色 ----

  static Map<String, int> getCustomColors() {
    final raw = _customColorsBox.get('colors');
    if (raw == null) return {};
    return Map<String, int>.from(raw as Map);
  }

  static Future<void> saveCustomColors(Map<String, int> colors) async {
    await _customColorsBox.put('colors', colors);
  }

  static Future<void> clearCustomColors() async {
    await _customColorsBox.delete('colors');
  }
}
