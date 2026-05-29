class Comment {
  final int id;         // 回复 ID
  final int postId;     // 所属帖子 ID
  final int? toId;      // 回复的目标回复 ID（楼中楼）
  final String author;  // 回复者署名
  final String content; // 回复内容
  final String createdAt; // 发布时间

  const Comment({
    required this.id,
    required this.postId,
    this.toId,
    this.author = '',
    this.content = '',
    this.createdAt = '',
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as int,
      postId: json['post_id'] as int,
      toId: json['to_id'] as int?,
      author: json['author'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
