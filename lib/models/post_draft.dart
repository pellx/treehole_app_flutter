import 'upload_result.dart';

class PostDraft {
  final String title;
  final String content;
  final String author;
  /// 是否匿名（与署名开关相反）
  final bool isAnonymous;
  final List<UploadResult> uploaded;
  final int sessionId;
  final String sessionSecret;

  const PostDraft({
    required this.title,
    required this.content,
    required this.author,
    required this.isAnonymous,
    required this.uploaded,
    required this.sessionId,
    required this.sessionSecret,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'author': author,
        'is_anonymous': isAnonymous,
        'uploaded': uploaded.map((e) => e.toJson()).toList(),
        'session_id': sessionId,
        'session_secret': sessionSecret,
      };
}
