import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/comment.dart';
import '../../models/post.dart';
import '../../services/api.dart';
import '../../services/storage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_square_refresh_theme.dart';
import '../../theme/app_square_top_bar_theme.dart';
import '../../widgets/image_overlay.dart';
import '../search/search_page.dart';
import '../../widgets/post_card.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_snackbar.dart';

class SquarePage extends StatefulWidget {
  const SquarePage({super.key});

  @override
  State<SquarePage> createState() => SquarePageState();
}

class SquarePageState extends State<SquarePage>
    with TickerProviderStateMixin {
  List<Post> _posts = []; // 当前展示的帖子列表
  List<int> _allIds = []; // 全部帖子 ID（按 API 返回顺序）
  int _loadedCount = 0; // 已加载到第几个 ID
  bool _loading = false; // 是否正在加载中
  String? _error; // 错误信息（null = 正常）
  final Set<int> _loadingIds = {}; // 正在请求中的 ID（防止重复请求）
  final Map<int, List<Comment>> _comments = {}; // 帖子回复缓存
  final Set<int> _postsNeedCommentRefresh = {}; // 需要刷新回复的帖子 ID

  int _selectedCategoryIndex = 0;

  /// 左侧拉出刷新球的累计下拉距离（像素）
  double _leftPullDistance = 0;

  /// 是否已经在本次拖拽中触发过“拉满”震动反馈
  bool _leftPullHapticTriggered = false;

  /// 是否正在执行左侧刷新
  bool _leftRefreshing = false;

  /// 释放触发刷新时球体的视觉抖动动画（水平来回摆动）
  late final AnimationController _ballShakeController;
  late final Animation<double> _ballShakeOffset;

  /// 未拉满松手（或刷新结束）时球的缩回动画：
  /// 驱动 [_leftPullDistance] 从当前值平滑回落到 0。
  late final AnimationController _retractController;

  /// 缩回动画起始时的下拉距离（缩回起点）。
  double _retractFrom = 0;

  void _initBallShake() {
    _ballShakeController = AnimationController(
      vsync: this,
      duration: AppSquareRefreshTheme.ballShakeDuration,
    );
    final amp = AppSquareRefreshTheme.ballShakeAmplitude;
    _ballShakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -amp), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -amp, end: amp), weight: 2),
      TweenSequenceItem(tween: Tween(begin: amp, end: -amp), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -amp, end: amp), weight: 2),
      TweenSequenceItem(tween: Tween(begin: amp, end: 0.0), weight: 1),
    ]).animate(_ballShakeController);
  }

  void _initBallRetract() {
    _retractController = AnimationController(
      vsync: this,
      duration: AppSquareRefreshTheme.ballRetractDuration,
    )..addListener(() {
        if (!mounted) return;
        setState(() {
          _leftPullDistance =
              _retractFrom *
              (1 -
                  Curves.easeOutCubic.transform(
                    _retractController.value,
                  ));
        });
      });
  }

  /// 未拉满松手（或刷新结束）时，让球平滑缩回顶栏下方而不是直接消失。
  void _animateLeftRetract() {
    if (_leftPullDistance == 0) return;
    _retractController.stop();
    _retractFrom = _leftPullDistance;
    _retractController.forward(from: 0);
  }

  final _scrollController = ScrollController();

  /// 列表是否已经滚到最顶部
  bool get _isAtTop {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 0.01;
  }

  /// 当前左侧拉出进度 0~1
  double get _leftPullProgress =>
      (_leftPullDistance / AppSquareRefreshTheme.pullThreshold).clamp(0.0, 1.0);

  final _categories = ['默认', '问答', '资料', '兴趣', '梗图'];

  List<Post> get _filteredPosts => _posts;

  String? get _currentCategory {
    final index = _selectedCategoryIndex;
    if (index == 0) return null;
    return _categories[index];
  }

  void _onCategoryTap(int index) {
    if (_selectedCategoryIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() => _selectedCategoryIndex = index);
    _reloadCategory();
  }

  /// 切换到默认分类并重新加载
  void resetToDefault() {
    if (_selectedCategoryIndex == 0) {
      _reloadCategory();
      return;
    }
    _selectedCategoryIndex = 0;
    _reloadCategory();
  }

  Future<void> _reloadCategory() async {
    setState(() {
      _posts = [];
      _allIds = [];
      _loadedCount = 0;
      _comments.clear();
      _postsNeedCommentRefresh.clear();
      _loadingIds.clear();
      _loading = false;
      _error = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _initLoad();
  }

  void _onLeftPullEnd() {
    if (_leftPullProgress >= 1.0) {
      _triggerLeftRefresh();
    } else if (_leftPullDistance != 0 || _leftPullHapticTriggered) {
      // 未拉满松手：球平滑缩回，而不是直接消失
      _leftPullHapticTriggered = false;
      _animateLeftRetract();
    }
  }

  Future<void> _triggerLeftRefresh() async {
    // 释放触发刷新：可选触觉 + 球体循环抖动（加载期间持续）
    AppSquareRefreshTheme.hapticOnRefresh.trigger();
    if (_ballShakeController.isAnimating) _ballShakeController.stop();
    _ballShakeController.repeat(from: 0);
    setState(() {
      _leftRefreshing = true;
      _leftPullDistance = AppSquareRefreshTheme.pullThreshold;
      _leftPullHapticTriggered = false;
    });
    await _refresh();
    if (mounted) {
      // 加载完成：停止循环抖动并归位（offset 回到 0）。
      // 保持 puton 图不再切回 waiting（避免刷新很快时出现闪烁），
      // 随缩回动画一起消失；状态在下次下拉开始时重置。
      _ballShakeController.stop();
      _ballShakeController.value = 1.0;
      _animateLeftRetract();
    }
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
    _initBallShake();
    _initBallRetract();
    _initLoad();
    ImageOverlay.onChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _ballShakeController.dispose();
    _retractController.dispose();
    _scrollController.dispose();
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
    final category = _currentCategory;
    try {
      _allIds = await ApiService.getIdList(category: category);
      // 只有「默认」才覆盖全局缓存
      if (category == null) await PostStorage.saveIdList(_allIds);
    } catch (_) {
      _allIds = category == null ? PostStorage.getIdList() : [];
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
    final category = _currentCategory;
    try {
      newIds = await ApiService.getIdList(category: category);
      if (category == null) await PostStorage.saveIdList(newIds);
    } catch (_) {
      newIds = category == null ? PostStorage.getIdList() : [];
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

  /// 用最新帖数据替换列表中同 id 项（内容/署名/评论变化时刷新 UI）
  void _replaceLoadedPost(Post fresh) {
    final idx = _posts.indexWhere((p) => p.id == fresh.id);
    if (idx < 0) return;
    final old = _posts[idx];
    final same =
        old.author == fresh.author &&
        old.isAnonymous == fresh.isAnonymous &&
        old.updateAt == fresh.updateAt &&
        old.title == fresh.title &&
        old.content == fresh.content &&
        _sameIntList(old.comments, fresh.comments) &&
        _sameStringList(
          old.images.map((e) => e.fileName).toList(),
          fresh.images.map((e) => e.fileName).toList(),
        ) &&
        _sameStringList(
          old.attachments.map((e) => e.fileName).toList(),
          fresh.attachments.map((e) => e.fileName).toList(),
        ) &&
        _sameStringList(
          old.attachments.map((e) => e.sourceName).toList(),
          fresh.attachments.map((e) => e.sourceName).toList(),
        );
    if (same) return;
    _posts[idx] = fresh;
    if (mounted) setState(() {});
  }

  static bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 刷新单个帖子：重新拉取帖数据 + 回复，并更新 UI/缓存
  Future<void> _refreshSinglePost(Post post) async {
    Post? fresh;
    try {
      fresh = await ApiService.getPost(post.id);
    } catch (_) {
      fresh = null;
    }
    if (fresh == null) {
      if (mounted) showAppSnackBar(context, message: '刷新失败，请检查网络');
      return;
    }
    await PostStorage.savePost(fresh);
    _replaceLoadedPost(fresh);
    await _refreshPostComments(fresh, fetchLatest: false);
    if (mounted) showAppSnackBar(context, message: '已刷新该帖子');
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final topBarBg = isLight
        ? AppSquareTopBarTheme.backgroundLight
        : AppSquareTopBarTheme.backgroundDark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: topBarBg,
        statusBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
      ),
      child: PopScope(
        canPop: ImageOverlay.currentEntry == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) ImageOverlay.closeCurrent();
        },
        child: Scaffold(
        // 回复栏是 OverlayEntry，键盘弹出时不需要 resize 底层列表，避免底边栏被顶动
        resizeToAvoidBottomInset: false,
        body: Container(
          color: topBarBg,
          child: SafeArea(
            bottom: false,
            child: _buildRefreshShell(_buildBody()),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildBody() {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final topBar = _buildTopBar(colors, onSurface);

    // 顶部栏始终保留，加载/错误/空状态以 SliverFillRemaining 嵌入列表
    if (_loading && _posts.isEmpty) {
      return Container(
        color: colors.common.background,
        child: CustomScrollView(
          slivers: [
            topBar,
            const SliverFillRemaining(
              child: AppLoadingCenter(message: '加载中...'),
            ),
          ],
        ),
      );
    }
    if (_error != null && _posts.isEmpty) {
      return Container(
        color: colors.common.background,
        child: CustomScrollView(
          slivers: [
            topBar,
            SliverFillRemaining(
              child: AppErrorState(message: _error!, onRetry: _initLoad),
            ),
          ],
        ),
      );
    }
    if (_posts.isEmpty) {
      return Container(
        color: colors.common.background,
        child: CustomScrollView(
          slivers: [
            topBar,
            const SliverFillRemaining(
              child: AppEmptyState(
                message: '还没有帖子，快来发布第一条吧',
                icon: Icons.inbox_outlined,
              ),
            ),
          ],
        ),
      );
    }

    final posts = _filteredPosts;

    return Container(
      color: colors.common.background,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300 &&
              !_loading) {
            _loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          controller: _scrollController,
          // 使用 ClampingScrollPhysics，避免在顶部继续下拉出现空白/回弹，
          // 从而让左侧拉出刷新球成为唯一的下拉刷新入口。
          physics: const ClampingScrollPhysics(),
          slivers: [
            topBar,
            if (posts.isEmpty)
              const SliverFillRemaining(
                child: AppEmptyState(
                  message: '该分类下暂无帖子',
                  icon: Icons.inbox_outlined,
                ),
              )
            else
              SliverPadding(
                // 顶部间距控制第一个卡片与顶栏之间的距离；
                // 卡片之间的间距由 PostCard 底部 margin 控制。
                padding: EdgeInsets.fromLTRB(
                  AppDimens.listPaddingLeft,
                  AppSquareTopBarTheme.postListTopSpacing,
                  AppDimens.listPaddingRight,
                  AppDimens.listPaddingBottom,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    posts
                        .map(
                          (p) => PostCard(
                            key: ValueKey(p.id),
                            post: p,
                            comments: _comments[p.id] ?? [],
                            onNeedCommentRefresh: () =>
                                _onNeedCommentRefresh(p.id),
                            onRefreshPost: () => _refreshSinglePost(p),
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
      ),
    );
  }

  /// 顶部下拉刷新球外壳：列表置顶时，任意位置向下拉都会唤出顶栏下方的刷新球
  Widget _buildRefreshShell(Widget child) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final progress = _leftPullProgress;

    return Stack(
      children: [
        child,
        // 手势识别器只覆盖帖子内容区（顶栏以下），不覆盖顶栏，
        // 避免任何情况下影响顶部 tab 和搜索按钮的点击。
        Positioned(
          left: 0,
          right: 0,
          top: AppSquareTopBarTheme.height,
          bottom: 0,
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: {
              _TopPullRecognizer:
                  GestureRecognizerFactoryWithHandlers<_TopPullRecognizer>(
                    _TopPullRecognizer.new,
                    (instance) {
                      instance.isAtTop = () => _isAtTop;
                      instance.onStart = () {
                        // 只在手势开始时重置内部状态，不要 setState，
                        // 否则每次在顶部点击（如切换 tab）都会触发重建，导致 tab 点击失效。
                        // 若上一轮缩回动画仍在进行，先停掉，避免动画回写距离。
                        _retractController.stop();
                        // 新一轮下拉开始：停止上一轮的循环抖动并归位
                        // （控制器通知会触发球体重建，无需 setState）。
                        _ballShakeController.stop();
                        _ballShakeController.value = 1.0;
                        _leftPullDistance = 0;
                        // 球回到 waiting 图（首次 onMove 的 setState
                        // 会带着这个状态重建）。
                        _leftRefreshing = false;
                        _leftPullHapticTriggered = false;
                      };
                      instance.onMove = (cumulativeDy) {
                        setState(() {
                          _leftPullDistance = cumulativeDy;
                          if (_leftPullProgress >= 1.0 &&
                              !_leftPullHapticTriggered) {
                            AppSquareRefreshTheme.hapticOnArmed.trigger();
                            _leftPullHapticTriggered = true;
                          }
                        });
                      };
                      instance.onEnd = _onLeftPullEnd;
                    },
                  ),
            },
          ),
        ),
        // 刷新球：下拉起始位置不变——从顶栏上方竖直滑下，滑过顶栏区域时
        // 被顶栏遮盖（不盖住顶栏、无透明度渐变），从顶栏底边下方露出；
        // 拉满时球顶边停在顶栏底边下方 ballMaxDropDistance 处。
        Positioned(
          left: 0,
          right: 0,
          top: AppSquareTopBarTheme.height,
          bottom: 0,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  // 水平固定在右侧
                  right: AppSquareRefreshTheme.ballRightFinalInset,
                  // 本层坐标原点 = 顶栏底边：拉满时球顶边停在 y = ballMaxDropDistance
                  top:
                      -AppSquareRefreshTheme.ballSize +
                      (AppSquareRefreshTheme.ballSize +
                              AppSquareTopBarTheme.height +
                              AppSquareRefreshTheme.ballMaxDropDistance) *
                          progress -
                      AppSquareTopBarTheme.height,
                  child: AnimatedBuilder(
                    animation: _ballShakeController,
                    // 释放时球与左侧文案一起水平抖动
                    builder: (context, child) => Transform.translate(
                      offset: Offset(_ballShakeOffset.value, 0),
                      child: child,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // “加载中”文案：仅刷新态（puton 图）立即显示，位于球左侧
                        if (_leftRefreshing) ...[
                          Text(
                            AppSquareRefreshTheme.loadingLabelText,
                            style: TextStyle(
                              fontSize: AppSquareRefreshTheme
                                  .loadingLabelFontSize,
                              fontWeight: AppSquareRefreshTheme
                                  .loadingLabelFontWeight,
                              color: AppSquareRefreshTheme.loadingLabelColor,
                            ),
                          ),
                          SizedBox(
                            width: AppSquareRefreshTheme.loadingLabelGap,
                          ),
                        ],
                        Container(
                          width: AppSquareRefreshTheme.ballSize,
                          height: AppSquareRefreshTheme.ballSize,
                          decoration: BoxDecoration(
                            color: colors.common.surface,
                            shape: BoxShape.circle,
                            // 绿色边框圆球：未释放显示 waiting 图，释放刷新切换 puton 图
                            border: Border.all(
                              color: AppSquareRefreshTheme.ballBorderColor,
                              width: AppSquareRefreshTheme.ballBorderWidth,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.common.onSurface.withValues(
                                  alpha: AppSquareRefreshTheme.shadowOpacity,
                                ),
                                blurRadius: 8,
                                offset: const Offset(2, 2),
                              ),
                            ],
                            image: DecorationImage(
                              image: AssetImage(
                                _leftRefreshing
                                    ? AppSquareRefreshTheme.putonImage
                                    : AppSquareRefreshTheme.waitingImage,
                              ),
                              fit: AppSquareRefreshTheme.ballImageFit,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 顶部分类栏：结构与样式分离，样式全部读取 AppSquareTopBarTheme
  Widget _buildTopBar(AppColors colors, Color onSurface) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final topBarBg = isLight
        ? AppSquareTopBarTheme.backgroundLight
        : AppSquareTopBarTheme.backgroundDark;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedHeaderDelegate(
        child: Container(
          color: topBarBg,
          child: Row(
            children: [
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
                            horizontal:
                                AppSquareTopBarTheme.itemHorizontalPadding,
                          ),
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: AppSquareTopBarTheme.fontSize,
                                  fontWeight: selected
                                      ? AppSquareTopBarTheme.selectedFontWeight
                                      : AppSquareTopBarTheme
                                            .unselectedFontWeight,
                                  color: selected
                                      ? colors.common.green
                                      : onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              SizedBox(
                                height:
                                    AppSquareTopBarTheme.indicatorTopSpacing,
                              ),
                              Container(
                                width: AppSquareTopBarTheme.indicatorWidth,
                                height: AppSquareTopBarTheme.indicatorHeight,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? colors.common.green
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    AppSquareTopBarTheme.indicatorBorderRadius,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height:
                                    AppSquareTopBarTheme.indicatorBottomSpacing,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  right: AppSquareTopBarTheme.searchIconRightInset,
                ),
                child: IconButton(
                  constraints: BoxConstraints.tightFor(
                    width: AppSquareTopBarTheme.height,
                    height: AppSquareTopBarTheme.height,
                  ),
                  padding: const EdgeInsets.only(
                    top: AppSquareTopBarTheme.searchIconTopPadding,
                    bottom: AppSquareTopBarTheme.searchIconBottomPadding,
                  ),
                  icon: Icon(
                    Icons.search,
                    color: onSurface,
                    size: AppSquareTopBarTheme.searchIconSize,
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const SearchPage())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部下拉识别器：列表在最顶部时，任意位置的「向下拉」都会触发刷新球。
///
/// 与 Scrollable 的垂直拖拽手势竞争。只有在列表已置顶且用户明显向下拖拽时
/// 才 accept，其他情况立即 reject，把手势还给列表滚动或子组件。
///
/// 注意：在正式 accept 之前不会调用 onMove，避免极小的手指抖动触发 setState
/// 导致顶部 tab 点击失效。
class _TopPullRecognizer extends OneSequenceGestureRecognizer {
  /// 回调：询问当前列表是否已经滚到最顶部。
  bool Function()? isAtTop;

  VoidCallback? onStart;

  /// 回调参数为「从手指按下开始的累计向下位移」，不是单帧 delta。
  ValueChanged<double>? onMove;
  VoidCallback? onEnd;

  double _dx = 0;
  double _dy = 0;
  bool _accepted = false;

  /// 向下拉多少像素后正式接管手势（要比 Scrollable 的拖拽阈值小一点）。
  static const double _acceptThreshold = 12;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    // 每次新手指按下都重置状态，避免上一次成功刷新后 _accepted 残留 true，
    // 导致在列表非顶部时继续响应下拉。
    _dx = 0;
    _dy = 0;
    _accepted = false;

    if (isAtTop == null || !isAtTop!()) {
      resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
      return;
    }
    onStart?.call();
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _dx += event.delta.dx;
      _dy += event.delta.dy;

      if (!_accepted) {
        // 明显向下拉：接管手势，阻止列表滚动。
        if (_dy > _acceptThreshold && _dy > _dx.abs()) {
          _accepted = true;
          resolve(GestureDisposition.accepted);
          onMove?.call(_dy);
          return;
        }

        // 明显是水平方向：拒绝，让给横向滚动或系统返回手势。
        if (_dx.abs() > _acceptThreshold && _dx.abs() > _dy.abs()) {
          resolve(GestureDisposition.rejected);
          return;
        }

        // 还在犹豫区：不调用 onMove，避免触发 setState 影响顶部点击。
        return;
      }

      // 已接管：按累计向下位移更新刷新球。
      if (_dy > 0) {
        onMove?.call(_dy);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      // 未被接管的轻点必须主动让出手势竞技场，
      // 否则该识别器作为竞技场第一个成员会在 sweep 时抢先获胜，
      // 导致列表置顶时内容区所有点击（评论按钮等）失效。
      if (!_accepted) {
        resolve(GestureDisposition.rejected);
      }
      _accepted = false;
      onEnd?.call();
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  String get debugDescription => 'top_pull';

  @override
  void didStopTrackingLastPointer(int pointer) {}
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _PinnedHeaderDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => AppSquareTopBarTheme.height;

  @override
  double get minExtent => AppSquareTopBarTheme.height;

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
