class Post {
  final int id;
  final String title;
  final String content;
  final String author;
  final String createdAt;
  final String updateAt;
  final List<PostImage> images;
  final List<PostAttachment> attachments;
  final List<int> comments;

  const Post({
    required this.id,
    required this.title,
    this.content = '',
    this.author = '',
    this.createdAt = '',
    this.updateAt = '',
    this.images = const [],
    this.attachments = const [],
    this.comments = const [],
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      author: json['author'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updateAt: json['update_at'] as String? ?? '',
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => PostImage(fileName: e['file_name'] as String))
              .toList() ??
          [],
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => PostAttachment(
                  fileName: e['file_name'] as String,
                  sourceName: e['source_name'] as String? ?? ''))
              .toList() ??
          [],
      comments: (json['comments'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}

class PostImage {
  final String fileName;
  const PostImage({required this.fileName});
}

class PostAttachment {
  final String fileName;
  final String sourceName;
  const PostAttachment({required this.fileName, required this.sourceName});
}
