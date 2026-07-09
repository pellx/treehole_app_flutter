import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/comment.dart';
import '../../models/post.dart';
import '../../services/api.dart';
import '../../services/storage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/image_overlay.dart';
import '../../widgets/post_card.dart';
import '../post/post_create_page.dart';
import '../settings/color_mode_page.dart';
import '../settings/settings_navigation.dart';

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
  Uint8List? _avatarBytes;                          // 抽屉头像字节
  bool _postButtonVisible = true;                   // 发布按钮显隐
  bool _commentOverlayActive = false;                // 评论浮层活跃时禁止滚动唤出
  Duration _postButtonAnimDuration = const Duration(milliseconds: 300);
  late final TextEditingController _nameController;
  final FocusNode _nameFocus = FocusNode();
  bool _editingName = false;

  Future<File> _avatarSavePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/avatar.jpg');
  }

  Future<void> _loadAvatar() async {
    final file = await _avatarSavePath();
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _avatarBytes = bytes);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 256);
    if (picked != null) {
      final bytes = await File(picked.path).readAsBytes();
      final saveFile = await _avatarSavePath();
      await saveFile.writeAsBytes(bytes);
      if (mounted) setState(() => _avatarBytes = bytes);
    }
  }

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
    _nameController = TextEditingController(text: PostStorage.getUserName());
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && _editingName) {
        _saveName();
      }
    });
    _loadAvatar();
    _initLoad();
    ImageOverlay.onChanged = () { if (mounted) setState(() {}); };
  }

  void _saveName() {
    final name = _nameController.text.trim();
    final saved = name.isEmpty ? '匿名用户' : name;
    _nameController.text = saved;
    PostStorage.saveUserName(saved);
    if (mounted) setState(() => _editingName = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
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

    // 移除已不在 ID 列表中的帖子（后端已删除）
    final removedIds = _posts
        .map((p) => p.id)
        .where((id) => !newIds.contains(id))
        .toList();
    for (final id in removedIds) {
      _posts.removeWhere((p) => p.id == id);
      _comments.remove(id);
      _postsNeedCommentRefresh.remove(id);
      await PostStorage.deletePost(id);
    }
    if (removedIds.isNotEmpty) {
      setState(() {});
    }

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

  Widget _drawerTile(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
      title: Text(title, style: TextStyle(fontSize: 15)),
      onTap: onTap ?? () {},
    );
  }

  void _showSettings() {
    final color = Theme.of(context).colorScheme.onSurface;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _settingsTile(Icons.person_outline, '用户设置', () { Navigator.pop(context); navigateToSettingsPage(context, '用户设置', Center(child: Text('没做', style: TextStyle(color: color)))); }),
            _settingsTile(Icons.edit_outlined, '署名设置', () { Navigator.pop(context); navigateToSettingsPage(context, '署名设置', Center(child: Text('没做', style: TextStyle(color: color)))); }),
            _settingsTile(Icons.star_outline, '关注设置', () { Navigator.pop(context); navigateToSettingsPage(context, '关注设置', Center(child: Text('没做', style: TextStyle(color: color)))); }),
            _settingsTile(Icons.palette_outlined, '颜色模式', () { Navigator.pop(context); navigateToSettingsPage(context, '颜色模式', const ColorModePage()); }),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title, VoidCallback onTap) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, color: colors.common.trailingIcon),
      onTap: onTap,
    );
  }

  Future<void> _openCreatePost() async {
    final result = await Navigator.push<bool>(
      context,
      topDownRoute<bool>(const PostCreatePage()),
    );
    if (result == true && mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: ImageOverlay.currentEntry == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ImageOverlay.closeCurrent();
      },
      child: Scaffold(
      drawerEdgeDragWidth: MediaQuery.of(context).size.width / 4,
      drawer: Builder(builder: (ctx) {
        final colors = Theme.of(ctx).extension<AppColors>()!;
        return Drawer(
        shape: const RoundedRectangleBorder(),
        width: MediaQuery.of(ctx).size.width * 4 / 5,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: colors.common.drawerHeaderBg,
                padding: EdgeInsets.only(
                  left: AppDimens.drawerHeaderPaddingLeft,
                  right: AppDimens.drawerHeaderPaddingRight,
                  top: AppDimens.drawerHeaderPaddingTop,
                  bottom: AppDimens.drawerHeaderPaddingBottom,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: _avatarBytes != null
                          ? CircleAvatar(
                              radius: AppDimens.drawerAvatarSize / 2,
                              backgroundImage: MemoryImage(_avatarBytes!),
                            )
                          : CircleAvatar(
                              radius: AppDimens.drawerAvatarSize / 2,
                              backgroundColor: colors.common.idTint.withValues(alpha: 0.2),
                              backgroundImage: const AssetImage('assets/420px-Transparent_Akkarin.jpg'),
                            ),
                    ),
                    SizedBox(width: AppDimens.drawerAvatarTextGap),
                    Expanded(
                      child: _editingName
                          ? TextField(
                              controller: _nameController,
                              focusNode: _nameFocus,
                              autofocus: true,
                              style: TextStyle(fontSize: AppDimens.drawerNameFontSize, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (_) => _saveName(),
                            )
                          : GestureDetector(
                              onTap: () => setState(() => _editingName = true),
                              child: Text(PostStorage.getUserName(), style: TextStyle(fontSize: AppDimens.drawerNameFontSize, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
                            ),
                    ),
                    Icon(Icons.chevron_right, color: colors.common.trailingIcon),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _drawerTile(Icons.home_outlined, '主页（没做）'),
                    _drawerTile(Icons.person_outline, '用户（没做）'),
                    _drawerTile(Icons.settings_outlined, '设置', onTap: _showSettings),
                    _drawerTile(Icons.menu_book_outlined, '操作教学（没做）'),
                  ],
                ),
              ),
            ],
          ),
          ),
        );
      }),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            _loading && _posts.isEmpty
                ? const Center(child: Image(image: AssetImage('assets/loading.gif'), width: AppDimens.loadingGifSize, height: AppDimens.loadingGifSize))
                // 有错误 → 显示错误文字
                    : _error != null
                        ? Center(
                            child: Text(_error!,
                                style: TextStyle(color: Theme.of(context).extension<AppColors>()!.common.trailingIcon)))
                    // 正常 → 帖子列表 + 滚动加载
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300 && !_loading) {
                            _loadMore();
                          }
                          // 滚动方向检测：向下滑隐藏按钮，向上滑显示
                          if (n is ScrollUpdateNotification) {
                            final delta = n.scrollDelta ?? 0;
                            if (delta.abs() > 5) {
                              if (!_commentOverlayActive) {
                                final hide = delta > 0;
                                if (_postButtonVisible != !hide) {
                                  setState(() => _postButtonVisible = !hide);
                                }
                              }
                            }
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
                                  _posts.map((p) => PostCard(key: ValueKey(p.id), post: p, comments: _comments[p.id] ?? [], onNeedCommentRefresh: () => _onNeedCommentRefresh(p.id), onCommentCreated: (cmt) {
                                    setState(() {
                                      _comments[p.id] ??= [];
                                      _comments[p.id] = [..._comments[p.id]!, cmt];
                                    });
                                  }, onCommentOverlayChanged: (visible) {
     setState(() {
       _commentOverlayActive = visible;
       if (visible) {
         _postButtonAnimDuration = Duration.zero;
         _postButtonVisible = false;
       } else {
         _postButtonAnimDuration = const Duration(milliseconds: 300);
         _postButtonVisible = true;
       }
     });
   })).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
            AnimatedPositioned(
              duration: _postButtonAnimDuration,
              curve: Curves.easeOut,
              right: _postButtonVisible
                  ? AppDimens.postCreateButtonRight
                  : -(AppDimens.postCreateButtonSize + 16),
              bottom: AppDimens.postCreateButtonBottom + MediaQuery.of(context).padding.bottom,
              child: SizedBox(
                width: AppDimens.postCreateButtonSize,
                height: AppDimens.postCreateButtonSize,
                child: FloatingActionButton(
                  heroTag: 'post_create',
                  backgroundColor: Theme.of(context).extension<AppColors>()!.postCreate.buttonBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.postCreateButtonRadius),
                  ),
                  onPressed: _openCreatePost,
                  child: Icon(Icons.edit_outlined, size: AppDimens.postCreateButtonIconSize, color: Theme.of(context).extension<AppColors>()!.postCreate.buttonIcon),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
