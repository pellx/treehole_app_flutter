import 'upload_result.dart';

class PostDraft {
  final String title;
  final String content;
  final String author;
  /// 是否匿名（与署名开关相反）
  final bool isAnonymous;
  final List<UploadResult> uploaded;
  /// 署名时附加的用户 id（user_display_id）；匿名不传
  /// 注意：发帖 body 不要带 session，否则后端 ValidationPipe 会报 session should not exist
  final String? userId;

  const PostDraft({
    required this.title,
    required this.content,
    required this.author,
    required this.isAnonymous,
    required this.uploaded,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'title': title,
      'content': content,
      'author': author,
      'is_anonymous': isAnonymous,
      'uploaded': uploaded.map((e) => e.toJson()).toList(),
    };
    final uid = userId?.trim();
    if (uid != null && uid.isNotEmpty) map['user_id'] = uid;
    return map;
  }
}
