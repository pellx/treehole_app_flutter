import 'upload_result.dart';

class PostDraft {
  final String title;
  final String content;
  final String author;
  final List<UploadResult> uploaded;

  const PostDraft({
    required this.title,
    required this.content,
    required this.author,
    required this.uploaded,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'author': author,
        'uploaded': uploaded.map((e) => e.toJson()).toList(),
      };
}
