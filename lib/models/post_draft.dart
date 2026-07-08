import 'upload_result.dart';

class PostDraft {
  final String title;
  final String content;
  final String author;
  final List<UploadResult> uploaded;
  final int sessionId;
  final String sessionSecret;

  const PostDraft({
    required this.title,
    required this.content,
    required this.author,
    required this.uploaded,
    required this.sessionId,
    required this.sessionSecret,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'author': author,
        'uploaded': uploaded.map((e) => e.toJson()).toList(),
        'session_id': sessionId,
        'session_secret': sessionSecret,
      };
}
