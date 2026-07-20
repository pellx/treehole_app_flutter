class Comment {
  final int id; // 回复 ID
  final int postId; // 所属帖子 ID
  final int? toId; // 回复的目标回复 ID（楼中楼）
  final String author; // 回复者署名（服务端已处理匿名）
  final bool isAnonymous;
  final String content; // 回复内容
  final String createdAt; // 发布时间

  const Comment({
    required this.id,
    required this.postId,
    this.toId,
    this.author = '',
    this.isAnonymous = false,
    this.content = '',
    this.createdAt = '',
  });

  /// 对外展示署名：匿名或空名则不显示
  String get displayAuthor {
    if (isAnonymous) return '';
    return author.trim();
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as int,
      postId: json['post_id'] as int,
      toId: json['to_id'] as int?,
      author: json['author'] as String? ?? '',
      isAnonymous: _asBool(json['is_anonymous']),
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    return s == 'true' || s == '1';
  }
  return false;
}
