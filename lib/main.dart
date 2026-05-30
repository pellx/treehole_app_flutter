import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/post.dart';
import 'models/comment.dart';
import 'widgets/post_card.dart';
import 'widgets/image_overlay.dart';
import 'theme/app_colors.dart';
import 'theme/app_dimens.dart';
import 'services/api.dart';
import 'services/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await PostStorage.init();
  runApp(const TreeholeApp());
}

class TreeholeApp extends StatelessWidget {
  const TreeholeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '树通',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        colorScheme: const ColorScheme.light(
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF333333),
        ),
        extensions: const [AppColors.light],
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF222222),
          onSurface: Color(0xFFF0F0F0),
        ),
        extensions: const [AppColors.dark],
      ),
      home: const SquarePage(),
    );
  }
}

class SquarePage extends StatefulWidget {
  const SquarePage({super.key});

  @override
  State<SquarePage> createState() => _SquarePageState();
}

class _SquarePageState extends State<SquarePage> {
  List<Post> _posts = [];          // 当前展示的帖子列表
  List<int> _allIds = [];          // 全部帖子 ID（按 API 返回顺序）
  int _loadedCount = 0;            // 已加载到第几个 ID
  bool _loading = false;           // 是否正在加载中
  String? _error;                  // 错误信息（null = 正常）
  final Set<int> _loadingIds = {}; // 正在请求中的 ID（防止重复请求）
  final Map<int, List<Comment>> _comments = {}; // 帖子回复缓存
  final Set<int> _postsNeedCommentRefresh = {};  // 需要刷新回复的帖子 ID

  void _onNeedCommentRefresh(int postId) {
    if (!_postsNeedCommentRefresh.contains(postId)) return;
    print('[comment] refreshing postId=$postId');
    final post = _posts.firstWhere((p) => p.id == postId);
    _refreshPostComments(post);
    _postsNeedCommentRefresh.remove(postId);
  }

  @override
  void initState() {
    super.initState();
    _initLoad();
    ImageOverlay.onChanged = () { if (mounted) setState(() {}); };
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

    print('[loadMore] start, _loading=$_loading, _loadedCount=$_loadedCount');
    setState(() => _loading = true);
    for (final id in batch) {
      _loadingIds.add(id);
    }

    // 并行请求所有帖子（缓存 → API fallback）
    final futures = batch.map((id) async {
      final post = PostStorage.getPost(id) ?? await ApiService.getPost(id);
      if (post != null) await PostStorage.savePost(post);
      return post;
    }).toList();

    // 按顺序处理结果，拿到一篇显示一篇
    for (int i = 0; i < futures.length; i++) {
      final post = await futures[i];
      _loadingIds.remove(batch[i]);
      if (post != null && !_posts.any((p) => p.id == post.id)) {
        await _refreshPostComments(post);
        setState(() {
          _posts.add(post);
          _posts.sort(
            (a, b) => _allIds.indexOf(a.id).compareTo(_allIds.indexOf(b.id)),
          );
        });
      }
    }

    _loadedCount += batch.length;
    print('[loadMore] done, _loadedCount=$_loadedCount, _posts=${_posts.length}');
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
    print('[refresh] start');
    _loading = true;
    List<int> newIds;
    try {
      newIds = await ApiService.getIdList();
      await PostStorage.saveIdList(newIds);
    } catch (_) {
      newIds = PostStorage.getIdList();
    }
    if (newIds.isEmpty) { _loading = false; return; }

    final existingIds = _posts.map((p) => p.id).toSet();
    final addedIds = newIds.where((id) => !existingIds.contains(id)).toList();

    final newPosts = <Post>[];
    for (final id in addedIds) {
      final post = PostStorage.getPost(id) ?? await ApiService.getPost(id);
      if (post != null) {
        await PostStorage.savePost(post);
        newPosts.add(post);
      }
    }

    _allIds = newIds;
    _loadedCount = _posts.length + newPosts.length;
    if (newPosts.isNotEmpty) {
      _posts.insertAll(0, newPosts);
      _posts.sort(
        (a, b) => _allIds.indexOf(a.id).compareTo(_allIds.indexOf(b.id)),
      );
      setState(() {});
    }

    for (final p in _posts) {
      _postsNeedCommentRefresh.add(p.id);
    }
    for (final post in _posts.take(7)) {
      if (_postsNeedCommentRefresh.contains(post.id)) {
        await _refreshPostComments(post);
        _postsNeedCommentRefresh.remove(post.id);
      }
    }
    _loading = false;
    print('[refresh] done');
  }

  // 刷新单个帖子的回复：获取最新 ID → 对比本地 → 只拉取新增
  Future<void> _refreshPostComments(Post post) async {
    List<int> newIds;
    try {
      final fresh = await ApiService.getPost(post.id);
      newIds = fresh?.comments ?? post.comments;
    } catch (_) {
      newIds = post.comments;
    }
    if (newIds.isEmpty) return;

    final existingIds = _comments[post.id]?.map((c) => c.id).toSet() ?? {};
    final missingIds = newIds.where((id) => !existingIds.contains(id)).toList();

    if (missingIds.isEmpty) {
      if (_comments[post.id] == null || _comments[post.id]!.length != newIds.length) {
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: ImageOverlay.currentEntry == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ImageOverlay.closeCurrent();
      },
      child: Scaffold(
      body: SafeArea(
        // 首次加载且无数据 → 居中转圈
        child: _loading && _posts.isEmpty
            ? const Center(child: Image(image: AssetImage('assets/loading.gif'), width: AppDimens.loadingGifSize, height: AppDimens.loadingGifSize))
            // 有错误 → 显示错误文字
            : _error != null
                ? Center(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.grey)))
                // 正常 → 帖子列表 + 滚动加载
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300 && !_loading) {
                        _loadMore();
                      }
                      return false;
                    },
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast),
                      cacheExtent: 3000,
                      slivers: [
                        CupertinoSliverRefreshControl(
                          onRefresh: _refresh,
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
                              _posts.map((p) => PostCard(key: ValueKey(p.id), post: p, comments: _comments[p.id] ?? [], onNeedCommentRefresh: () => _onNeedCommentRefresh(p.id))).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    ),
    );
  }
}
