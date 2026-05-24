import 'dart:typed_data';
import 'package:hive/hive.dart';
import '../models/post.dart';

class PostStorage {
  static const _idListKey = 'id_list';
  static late Box _idBox;
  static late Box _postBox;
  static late Box _thumbBox;

  static Future<void> init() async {
    _idBox = await Hive.openBox('id_list');
    _postBox = await Hive.openBox('posts');
    _thumbBox = await Hive.openBox('thumbnails');
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

  static Uint8List? getThumbnail(String fileName) {
    final key = 'thumb_$fileName';
    final raw = _thumbBox.get(key);
    if (raw == null) return null;
    return raw as Uint8List;
  }

  static Future<void> saveThumbnail(String fileName, Uint8List bytes) async {
    await _thumbBox.put('thumb_$fileName', bytes);
  }
}
