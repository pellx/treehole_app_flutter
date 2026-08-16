/// 贴文元数据，来自 /posts/idListv2。
class PostMeta {
  final int id;
  final String title;
  final String? author;
  final String category;
  final int replyTimes;
  final String createdAt;
  final String updateAt;

  const PostMeta({
    required this.id,
    this.title = '',
    this.author,
    this.category = '默认',
    this.replyTimes = 0,
    this.createdAt = '',
    this.updateAt = '',
  });

  factory PostMeta.fromJson(Map<String, dynamic> json) {
    return PostMeta(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      author: json['author'] as String?,
      category: json['category'] as String? ?? '默认',
      replyTimes: json['reply_times'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      updateAt: json['update_at'] as String? ?? '',
    );
  }
}

/// /posts/idListv2 的返回结构。
class IdListV2Result {
  final int total;
  final int? offset;
  final int? limit;
  final List<PostMeta> items;

  const IdListV2Result({
    required this.total,
    this.offset,
    this.limit,
    required this.items,
  });

  factory IdListV2Result.fromJson(Map<String, dynamic> json) {
    return IdListV2Result(
      total: json['total'] as int? ?? 0,
      offset: json['offset'] as int?,
      limit: json['limit'] as int?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => PostMeta.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
