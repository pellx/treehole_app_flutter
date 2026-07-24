import 'upload_result.dart';

class PostDraft {
  final String title;
  final String content;
  final String author;
  /// 是否匿名（与署名开关相反）
  final bool isAnonymous;
  final List<UploadResult> uploaded;
  /// 暂时选填：有则随请求带上，后端未强制时可不传
  final int? sessionId;
  final String? sessionSecret;
  /// 署名时附加的用户 id（user_display_id）；匿名不传
  final String? userId;

  const PostDraft({
    required this.title,
    required this.content,
    required this.author,
    required this.isAnonymous,
    required this.uploaded,
    this.sessionId,
    this.sessionSecret,
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
    final sid = sessionId;
    final ssec = sessionSecret;
    final uid = userId?.trim();
    if (sid != null) map['session_id'] = sid;
    if (ssec != null && ssec.isNotEmpty) map['session_secret'] = ssec;
    if (uid != null && uid.isNotEmpty) map['user_id'] = uid;
    return map;
  }
}
