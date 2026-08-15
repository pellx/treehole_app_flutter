import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/comment.dart';
import '../../models/post.dart';
import '../../services/api.dart';
import '../../services/storage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/image_overlay.dart';
import '../search/search_page.dart';
import '../settings/settings_navigation.dart';
import '../../widgets/post_card.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_empty_state.dart';

class SquarePage extends StatefulWidget {
  const SquarePage({super.key});

  @override
  State<SquarePage> createState() => _SquarePageState();
}

class _SquarePageState extends State<SquarePage> {
  List<Post> _posts = []; // 当前展示的帖子列表
  List<int> _allIds = []; // 全部帖子 ID（按 API 返回顺序）
  int _loadedCount = 0; // 已加载到第几个 ID
  bool _loading = false; // 是否正在加载中
  String? _error; // 错误信息（null = 正常）
  final Set<int> _loadingIds = {}; // 正在请求中的 ID（防止重复请求）
  final Map<int, List<Comment>> _comments = {}; // 帖子回复缓存
  final Set<int> _postsNeedCommentRefresh = {}; // 需要刷新回复的帖子 ID

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedCategoryIndex = 0;

  final _categories = ['推荐', '经验', '求助', '闲聊', '资源'];
  final _categoryKeywords = {
    '经验': ['经验', '教程', '攻略', '如何', '怎么', '技巧', '分享'],
    '求助': ['求助', '问', '请问', '怎么办', '帮忙', '求'],
    '闲聊': ['闲聊', '吐槽', '八卦', '聊聊', '讨论'],
    '资源': ['资源', '下载', '链接', '文件', '附件'],
  };

  final _channels = ['校园', '城市', '兴趣', '活动', '其他'];
  int? _selectedChannelIndex;

  List<Post> get _filteredPosts {
    final category = _categories[_selectedCategoryIndex];
    if (category == '推荐') return _posts;
    final keywords = _categoryKeywords[category] ?? [];
    return _posts.where((p) {
      final text = '${p.title} ${p.content}'.toLowerCase();
      return keywords.any((k) => text.contains(k));
    }).toList();
  }

  void _onCategoryTap(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedCategoryIndex = index);
  }

  void _onNeedCommentRefresh(int postId) {
    if (!_postsNeedCommentRefresh.contains(postId)) return;
    final post = _posts.firstWhere((p) => p.id == postId);
    _refreshPostComments(post);
    _postsNeedCommentRefresh.remove(postId);
  }

  @override
  void initState() {
    super.initState();
    _initLoad();
    ImageOverlay.onChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ---- 首次启动加载 ----
  //
  // 流程：
  //   1. 先从 API 获取最新 ID 列表（失败则用 Hive 缓存的旧列表）
  //   2. 取前 7 个 ID，逐个加载帖子
  //      - Hive 有 → 直接用
  //      - Hive 无 → API 请求 → 存入 Hive
  //   3. 帖子按 _allIds 顺序排列显示
  //
  // 第二次打开时，Hive 里的旧帖子秒出，新帖子从 API 补。
  //
  Future<void> _initLoad() async {
    // 1. 获取最新 ID 列表
    try {
      _allIds = await ApiService.getIdList();
      await PostStorage.saveIdList(_allIds);
    } catch (_) {
      _allIds = PostStorage.getIdList(); // API 失败，用本地缓存
    }

    if (_allIds.isEmpty) {
      setState(() {
        _loading = false;
        _error = '加载失败，请检查网络';
      });
      return;
    }

    // 2. 按 ID 顺序加载帖子（缓存优先）
    _posts = [];
    _loadedCount = 0;
    await _loadMore();

    if (_posts.isEmpty) {
      setState(() {
        _loading = false;
        _error = '加载失败，请检查网络';
      });
    }
  }

  // ---- 加载下一批帖子（7 篇）----
  //
  // 流程：
  //   1. 从 _allIds 中取 _loadedCount 之后的 7 个 ID
  //   2. 7 个请求并行发出（不串行等待）
  //   3. 拿到一篇就立即显示一篇
  //   4. 排序保证与 _allIds 顺序一致
  //
  // 调用时机：
  //   - _initLoad 首次加载
  //   - 列表滚到距底部 300px 时触发
  //
  Future<void> _loadMore() async {
    if (_loading) return; // 上一批还没加载完，跳过
    final batch = _allIds
        .skip(_loadedCount)
        .take(7)
        .where((id) => !_loadingIds.contains(id))
        .toList();
    if (batch.isEmpty) return;

    setState(() => _loading = true);
    for (final id in batch) {
      _loadingIds.add(id);
    }

    // 并行请求所有帖子（缓存 → API fallback）；fresh 标记该帖是否刚从 API 拉取
    final futures = batch.map((id) async {
      final cached = PostStorage.getPost(id);
      if (cached != null) return (post: cached, fresh: false);
      final post = await ApiService.getPost(id);
      if (post != null) await PostStorage.savePost(post);
      return (post: post, fresh: true);
    }).toList();

    // 按顺序处理结果，拿到一篇立即显示，评论走缓存 + 后台刷新（不阻塞帖子上屏）
    for (int i = 0; i < futures.length; i++) {
      final result = await futures[i];
      final post = result.post;
      _loadingIds.remove(batch[i]);
      if (post != null && !_posts.any((p) => p.id == post.id)) {
        _comments[post.id] ??= PostStorage.getComments(post.comments);
        final order = {for (var j = 0; j < _allIds.length; j++) _allIds[j]: j};
        setState(() {
          _posts.add(post);
          _posts.sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));
        });
        // 刚从 API 拉的帖子评论列表已是最新，无需再 getPost
        _refreshPostComments(post, fetchLatest: !result.fresh);
      }
    }

    _loadedCount += batch.length;
    setState(() => _loading = false);

    // 后台预下载缩略图，Hive 有就跳过
    for (final post in _posts) {
      for (final img in post.images) {
        if (PostStorage.getThumbnail(img.fileName) == null) {
          ApiService.downloadThumbnail(img.fileName).then((data) {
            if (data != null) PostStorage.saveThumbnail(img.fileName, data);
          });
        }
      }
    }
  }

  // ---- 下拉刷新 ----
  Future<void> _refresh() async {
    // 指示器至少显示 300ms，避免刷新过快时一闪而过
    final stopwatch = Stopwatch()..start();
    _loading = true;
    List<int> newIds;
    try {
      newIds = await ApiService.getIdList();
      await PostStorage.saveIdList(newIds);
    } catch (_) {
      newIds = PostStorage.getIdList();
    }
    if (newIds.isEmpty) {
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 300) {
        await Future.delayed(Duration(milliseconds: 300 - elapsed));
      }
      _loading = false;
      return;
    }

    // 移除已不在 ID 列表中的帖子（后端已删除）
    final newIdSet = newIds.toSet();
    final removedIds = _posts
        .map((p) => p.id)
        .where((id) => !newIdSet.contains(id))
        .toList();
    if (removedIds.isNotEmpty) {
      for (final id in removedIds) {
        _posts.removeWhere((p) => p.id == id);
        _comments.remove(id);
        _postsNeedCommentRefresh.remove(id);
      }
      setState(() {});
      await Future.wait(removedIds.map(PostStorage.deletePost));
    }

    final existingIds = _posts.map((p) => p.id).toSet();
    final addedIds = newIds.where((id) => !existingIds.contains(id)).toList();

    // 并行拉取新帖，避免逐篇串行等待；fresh 标记是否刚从 API 拉取
    final fetched = await Future.wait(
      addedIds.map((id) async {
        final cached = PostStorage.getPost(id);
        if (cached != null) return (post: cached, fresh: false);
        final post = await ApiService.getPost(id);
        if (post != null) await PostStorage.savePost(post);
        return (post: post, fresh: true);
      }),
    );
    final newPosts = [
      for (final r in fetched)
        if (r.post != null) r.post!,
    ];
    final freshIds = {
      for (final r in fetched)
        if (r.fresh && r.post != null) r.post!.id,
    };

    _allIds = newIds;
    _loadedCount = _posts.length + newPosts.length;
    if (newPosts.isNotEmpty) {
      // 先用缓存评论填充，帖子立即完整上屏
      for (final p in newPosts) {
        _comments[p.id] ??= PostStorage.getComments(p.comments);
      }
      final order = {for (var i = 0; i < _allIds.length; i++) _allIds[i]: i};
      _posts.insertAll(0, newPosts);
      _posts.sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));
      setState(() {});
    }

    for (final p in _posts) {
      _postsNeedCommentRefresh.add(p.id);
    }
    // 前 7 篇评论后台并行刷新，不阻塞下拉刷新指示器；其余滚动到时再刷
    final top = _posts.take(7).toList();
    for (final p in top) {
      _postsNeedCommentRefresh.remove(p.id);
    }
    unawaited(
      Future.wait(
        top.map(
          // 刚从 API 拉过的帖评论列表已最新，跳过重复 getPost
          (p) => _refreshPostComments(p, fetchLatest: !freshIds.contains(p.id)),
        ),
      ),
    );
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 800) {
      await Future.delayed(Duration(milliseconds: 800 - elapsed));
    }
    _loading = false;
  }

  static bool _sameIntList(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // 刷新单个帖子的回复：获取最新 ID → 对比本地 → 只拉取新增
  // fetchLatest=false 时直接用 post.comments（帖子刚从 API 拉取，列表已最新，省一次 getPost）
  Future<void> _refreshPostComments(
    Post post, {
    bool fetchLatest = true,
  }) async {
    List<int> newIds;
    if (fetchLatest) {
      try {
        final fresh = await ApiService.getPost(post.id);
        if (fresh != null) {
          await PostStorage.savePost(fresh);
          _replaceLoadedPost(fresh);
          newIds = fresh.comments;
        } else {
          newIds = post.comments;
        }
      } catch (_) {
        newIds = post.comments;
      }
    } else {
      newIds = post.comments;
    }
    if (newIds.isEmpty) return;

    final existingIds = _comments[post.id]?.map((c) => c.id).toSet() ?? {};
    final missingIds = newIds.where((id) => !existingIds.contains(id)).toList();

    if (missingIds.isEmpty) {
      if (_comments[post.id] == null ||
          _comments[post.id]!.length != newIds.length) {
        _comments[post.id] = PostStorage.getComments(newIds);
        await PostStorage.updatePostCommentIds(post.id, newIds);
        if (mounted) setState(() {});
      }
      return;
    }

    final futures = missingIds.map((id) async {
      final cmt = await ApiService.getComment(id);
      if (cmt != null) await PostStorage.saveComment(cmt);
      return cmt;
    });
    final newCmts = (await Future.wait(futures)).whereType<Comment>().toList();

    final existing = _comments[post.id] ?? PostStorage.getComments(newIds);
    final merged = <Comment>[...existing];
    for (final c in newCmts) {
      if (!merged.any((e) => e.id == c.id)) merged.add(c);
    }
    merged.sort((a, b) => newIds.indexOf(a.id).compareTo(newIds.indexOf(b.id)));

    await PostStorage.updatePostCommentIds(post.id, newIds);
    if (mounted) setState(() => _comments[post.id] = merged);
  }

  /// 用最新帖数据替换列表中同 id 项（署名变更时刷新 UI）
  void _replaceLoadedPost(Post fresh) {
    final idx = _posts.indexWhere((p) => p.id == fresh.id);
    if (idx < 0) return;
    final old = _posts[idx];
    if (old.author == fresh.author &&
        old.isAnonymous == fresh.isAnonymous &&
        old.updateAt == fresh.updateAt &&
        _sameIntList(old.comments, fresh.comments)) {
      return;
    }
    _posts[idx] = fresh;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: ImageOverlay.currentEntry == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ImageOverlay.closeCurrent();
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(),
        body: SafeArea(bottom: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildDrawer() {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '栏目选择',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _channels.length,
                itemBuilder: (context, index) {
                  final selected = index == _selectedChannelIndex;
                  return ListTile(
                    leading: Icon(
                      Icons.folder_outlined,
                      color: selected
                          ? colors.common.green
                          : onSurface.withValues(alpha: 0.6),
                    ),
                    title: Text(
                      _channels[index],
                      style: TextStyle(
                        color: selected ? colors.common.green : onSurface,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: selected
                        ? Icon(Icons.check, color: colors.common.green)
                        : null,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedChannelIndex = index);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _posts.isEmpty) {
      return const AppLoadingCenter(message: '加载中...');
    }
    if (_error != null && _posts.isEmpty) {
      return AppErrorState(message: _error!, onRetry: _initLoad);
    }
    if (_posts.isEmpty) {
      return const AppEmptyState(
        message: '还没有帖子，快来发布第一条吧',
        icon: Icons.inbox_outlined,
      );
    }
    if (_filteredPosts.isEmpty) {
      return const AppEmptyState(
        message: '该分类下暂无帖子',
        icon: Icons.inbox_outlined,
      );
    }

    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300 && !_loading) {
          _loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.fast,
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _refresh),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchBarHeaderDelegate(
              child: Container(
                color: colors.common.surface,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.menu, color: onSurface),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.asMap().entries.map((entry) {
                            final index = entry.key;
                            final label = entry.value;
                            final selected = index == _selectedCategoryIndex;
                            return GestureDetector(
                              onTap: () => _onCategoryTap(index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: selected
                                            ? colors.common.green
                                            : onSurface.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: 20,
                                      height: 2.5,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? colors.common.green
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          1.25,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.search, color: onSurface),
                      onPressed: () => Navigator.of(
                        context,
                      ).push(topDownRoute(const SearchPage())),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppDimens.listPaddingLeft,
              AppDimens.listPaddingTop,
              AppDimens.listPaddingRight,
              AppDimens.listPaddingBottom,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _filteredPosts
                    .map(
                      (p) => PostCard(
                        key: ValueKey(p.id),
                        post: p,
                        comments: _comments[p.id] ?? [],
                        onNeedCommentRefresh: () => _onNeedCommentRefresh(p.id),
                        onCommentCreated: (cmt) {
                          setState(() {
                            _comments[p.id] ??= [];
                            _comments[p.id] = [..._comments[p.id]!, cmt];
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SearchBarHeaderDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _SearchBarHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
