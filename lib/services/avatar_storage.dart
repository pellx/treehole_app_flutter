import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 本地头像存储：用户页与侧边栏共用同一文件
class AvatarStorage {
  AvatarStorage._();

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/avatar.jpg');
  }

  static Future<Uint8List?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static Future<void> save(Uint8List bytes) async {
    final file = await _file();
    await file.writeAsBytes(bytes);
  }
}
