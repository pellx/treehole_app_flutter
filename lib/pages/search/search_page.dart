import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/comment.dart';
import '../../models/post.dart';
import '../../services/api.dart';
import '../../services/storage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_search_theme.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/post_card.dart';

/// 搜索页：顶部输入栏 + 搜索历史
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  List<Post> _posts = [];
  bool _loading = false;
  String? _error;
  String _query = '';
  List<String> _history = [];
  int _deletingIndex = -1;
  final Map<int, List<Comment>> _comments = {};
  final Set<int> _postsNeedCommentRefresh = {};
  final _sortOptions = ['最新发布', '最新回复', '最先发布', '回复最多'];
  final _timeOptions = ['不限时间', '最近一周', '最近一月', '最近半年'];
  int _selectedSortIndex = 0;
  int _selectedTimeIndex = 0;
  String? _expandedFilter; // 'sort' | 'time'

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _loadHistory();
    // 进入页面后自动聚焦，唤出键盘
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(() => setState(() {}));
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onClearInput() {
    _controller.clear();
    if (_query.isNotEmpty || _posts.isNotEmpty) {
      setState(() {
        _query = '';
        _posts = [];
        _comments.clear();
        _postsNeedCommentRefresh.clear();
        _error = null;
        _loading = false;
      });
    }
  }

  void _onNeedCommentRefresh(int postId) {
    if (!_postsNeedCommentRefresh.contains(postId)) return;
    final post = _posts.firstWhere((p) => p.id == postId);
    _refreshPostComments(post);
    _postsNeedCommentRefresh.remove(postId);
  }

  Future<void> _refreshPostComments(Post post) async {
    List<int> newIds;
    try {
      final fresh = await ApiService.getPost(post.id);
      if (fresh != null) {
        await PostStorage.savePost(fresh);
        final idx = _posts.indexWhere((p) => p.id == post.id);
        if (idx >= 0) {
          _posts[idx] = fresh;
        }
        newIds = fresh.comments;
      } else {
        newIds = post.comments;
      }
    } catch (_) {
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
    for (final cmt in newCmts) {
      if (!merged.any((e) => e.id == cmt.id)) merged.add(cmt);
    }
    merged.sort(
      (a, b) => newIds.indexOf(a.id).compareTo(newIds.indexOf(b.id)),
    );

    await PostStorage.updatePostCommentIds(post.id, newIds);
    if (mounted) setState(() => _comments[post.id] = merged);
  }

  static int _compareCreatedAtDesc(Post a, Post b) {
    final da = DateTime.tryParse(a.createdAt);
    final db = DateTime.tryParse(b.createdAt);
    if (da == null || db == null) return 0;
    return db.compareTo(da);
  }

  static int _compareCreatedAtAsc(Post a, Post b) {
    final da = DateTime.tryParse(a.createdAt);
    final db = DateTime.tryParse(b.createdAt);
    if (da == null || db == null) return 0;
    return da.compareTo(db);
  }

  Future<void> _loadHistory() async {
    final history = PostStorage.getSearchHistory();
    setState(() {
      _history = history;
      _deletingIndex = -1;
    });
  }

  Future<void> _deleteSingleHistory(String query) async {
    await PostStorage.removeSearchHistory(query);
    _loadHistory();
  }

  Future<void> _showClearHistoryConfirm() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '清空搜索历史',
      message: '确定要清空所有搜索历史吗？此操作无法恢复。',
      cancelText: '取消',
      confirmText: '清空',
    );
    if (confirmed == true) {
      _clearHistory();
    }
  }

  Future<void> _addHistory(String query) async {
    await PostStorage.addSearchHistory(query);
    _loadHistory();
  }

  Future<void> _clearHistory() async {
    await PostStorage.clearSearchHistory();
    _loadHistory();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ids = await ApiService.getIdList(
        search: _query.isEmpty ? null : _query,
      );
      final posts = <Post>[];
      await Future.wait(
        ids.take(30).map((id) async {
          final post = await ApiService.getPost(id);
          if (post != null) posts.add(post);
        }),
      );

      // 时间筛选（客户端）
      final now = DateTime.now();
      var filtered = posts.where((p) {
        if (_selectedTimeIndex == 0) return true;
        final created = DateTime.tryParse(p.createdAt);
        if (created == null) return true;
        final days = _selectedTimeIndex == 1
            ? 7
            : _selectedTimeIndex == 2
                ? 30
                : 180;
        return now.difference(created).inDays <= days;
      }).toList();

      // 排序（客户端）
      switch (_selectedSortIndex) {
        case 1: // 最新回复：优先按评论数量降序，再按发布时间降序
          filtered.sort((a, b) {
            final cmp = b.comments.length.compareTo(a.comments.length);
            if (cmp != 0) return cmp;
            return _compareCreatedAtDesc(a, b);
          });
        case 2: // 最先发布
          filtered.sort(_compareCreatedAtAsc);
        case 3: // 回复最多
          filtered.sort((a, b) => b.comments.length.compareTo(a.comments.length));
        case 0: // 最新发布
        default:
          filtered.sort(_compareCreatedAtDesc);
      }

      for (final post in filtered) {
        _comments[post.id] ??= PostStorage.getComments(post.comments);
        _postsNeedCommentRefresh.add(post.id);
      }
      if (mounted) {
        setState(() {
          _posts = filtered;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '加载失败：$e';
        });
      }
    }
  }

  void _onSearch() {
    final query = _controller.text.trim();
    if (query == _query) {
      _focusNode.unfocus();
      return;
    }
    _query = query;
    _focusNode.unfocus();
    if (query.isNotEmpty) {
      HapticFeedback.lightImpact();
      _addHistory(query);
    }
    _loadPosts();
  }

  void _onHistoryTap(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _onSearch();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: colors.common.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildSearchBar(colors, onSurface),
            if (_query.isNotEmpty) _buildFilterBar(colors, onSurface),
            if (_query.isNotEmpty && _expandedFilter != null)
              _buildFilterPanel(colors, onSurface),
            _buildSearchHistory(colors, onSurface),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (_expandedFilter != null) {
                    setState(() => _expandedFilter = null);
                  }
                },
                child: _buildBody(colors),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppColors colors, Color onSurface) {
    return Container(
      color: colors.common.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSearchTheme.barHorizontalPadding,
        AppSearchTheme.barVerticalPadding,
        AppSearchTheme.barTrailingPadding,
        AppSearchTheme.barVerticalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              color: onSurface,
              size: AppSearchTheme.backIconSize,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Container(
              height: AppSearchTheme.searchBarHeight,
              decoration: BoxDecoration(
                color: colors.common.surface,
                borderRadius: BorderRadius.circular(
                  AppSearchTheme.inputBorderRadius,
                ),
                border: Border.all(
                  color: colors.common.divider,
                  width: AppSearchTheme.inputBorderWidth,
                ),
              ),
              child: Row(
                crossAxisAlignment: AppSearchTheme.searchIconVerticalAlignment,
                children: [
                  SizedBox(width: AppSearchTheme.searchIconLeftPadding),
                  Padding(
                    padding: EdgeInsets.only(
                      left: AppSearchTheme.searchIconLeftOffset,
                    ),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        AppSearchTheme.searchIconVerticalOffset,
                      ),
                      child: Icon(
                        Icons.search,
                        color: colors.common.trailingIcon,
                        size: AppSearchTheme.prefixIconSize,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSearchTheme.searchIconToTextGap),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _onSearch(),
                      cursorColor: AppSearchTheme.searchAccent,
                      decoration: InputDecoration(
                        hintText: AppSearchTheme.inputHint,
                        hintStyle: TextStyle(
                          color: colors.common.trailingIcon,
                          fontSize: AppSearchTheme.inputHintFontSize,
                        ),
                        suffixIcon: _controller.text.isNotEmpty
                            ? GestureDetector(
                                onTap: _onClearInput,
                                child: Icon(
                                  Icons.clear,
                                  color: colors.common.trailingIcon,
                                  size: AppSearchTheme.clearIconSize,
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        filled: false,
                        isDense: AppSearchTheme.inputIsDense,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: AppSearchTheme.inputVerticalPadding,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSearchTheme.searchButtonLeftGap),
          TextButton(
            onPressed: _onSearch,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(
                AppSearchTheme.searchButtonMinWidth,
                AppSearchTheme.searchButtonMinHeight,
              ),
            ),
            child: Text(
              AppSearchTheme.searchButtonText,
              style: TextStyle(
                color: AppSearchTheme.searchButtonColor,
                fontSize: AppSearchTheme.searchButtonFontSize,
                fontWeight: AppSearchTheme.searchButtonFontWeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppColors colors, Color onSurface) {
    final bg = Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : colors.common.surface;

    Widget filterButton(String label, bool expanded) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _expandedFilter = expanded ? null : label;
          });
        },
        child: Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: onSurface.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: bg,
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          filterButton(_sortOptions[_selectedSortIndex],
              _expandedFilter == 'sort'),
          filterButton(_timeOptions[_selectedTimeIndex],
              _expandedFilter == 'time'),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(AppColors colors, Color onSurface) {
    final isSort = _expandedFilter == 'sort';
    final options = isSort ? _sortOptions : _timeOptions;
    final selectedIndex = isSort ? _selectedSortIndex : _selectedTimeIndex;

    return Container(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : colors.common.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: options.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final selected = index == selectedIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSort) {
                  _selectedSortIndex = index;
                } else {
                  _selectedTimeIndex = index;
                }
                _expandedFilter = null;
              });
              if (_query.isNotEmpty) _loadPosts();
            },
            child: Container(
              height: 44,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: selected
                            ? AppSearchTheme.searchAccent
                            : onSurface.withValues(alpha: 0.85),
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: AppSearchTheme.searchAccent,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchHistory(AppColors colors, Color onSurface) {
    if (_query.isNotEmpty || _history.isEmpty) {
      return const SizedBox.shrink();
    }
    final chipBg = AppSearchTheme.chipBg(context);

    return Container(
      color: colors.common.surface,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSearchTheme.historySectionHorizontalPadding,
        AppSearchTheme.historySectionTopPadding,
        AppSearchTheme.historySectionHorizontalPadding,
        AppSearchTheme.historySectionBottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                AppSearchTheme.historyTitle,
                style: TextStyle(
                  fontSize: AppSearchTheme.historyTitleFontSize,
                  fontWeight: AppSearchTheme.historyTitleFontWeight,
                  color: onSurface,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: AppSearchTheme.historyClearIconSize,
                  color: onSurface.withValues(
                    alpha: AppSearchTheme.historyClearIconAlpha,
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: AppSearchTheme.historyIconButtonSize,
                  minHeight: AppSearchTheme.historyIconButtonSize,
                ),
                onPressed: _showClearHistoryConfirm,
              ),
            ],
          ),
          SizedBox(height: AppSearchTheme.historyTitleChipGap),
          Wrap(
            spacing: AppSearchTheme.historyWrapSpacing,
            runSpacing: AppSearchTheme.historyWrapRunSpacing,
            children: _history.asMap().entries.map((entry) {
              final index = entry.key;
              final q = entry.value;
              final showDelete = _deletingIndex == index;
              return GestureDetector(
                onTap: () => _onHistoryTap(q),
                onLongPress: () => setState(() => _deletingIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSearchTheme.historyChipHorizontalPadding,
                    vertical: AppSearchTheme.historyChipVerticalPadding,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(
                      AppSearchTheme.historyChipBorderRadius,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        q,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppSearchTheme.historyChipFontSize,
                          color: onSurface.withValues(
                            alpha: AppSearchTheme.historyChipTextAlpha,
                          ),
                        ),
                      ),
                      if (showDelete)
                        GestureDetector(
                          onTap: () => _deleteSingleHistory(q),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_query.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_loading) {
      return const AppLoadingCenter(message: '加载中...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _loadPosts);
    }
    final posts = _posts;
    if (posts.isEmpty) {
      return const AppEmptyState(
        message: '没有找到相关帖子',
        icon: Icons.search_off_outlined,
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        AppDimens.listPaddingLeft,
        AppDimens.listPaddingTop,
        AppDimens.listPaddingRight,
        AppDimens.listPaddingBottom,
      ),
      itemCount: posts.length,
      itemBuilder: (_, index) {
        final post = posts[index];
        return PostCard(
          key: ValueKey(post.id),
          post: post,
          comments: _comments[post.id] ?? [],
          onNeedCommentRefresh: () => _onNeedCommentRefresh(post.id),
          onCommentCreated: (cmt) {
            setState(() {
              _comments[post.id] ??= [];
              _comments[post.id] = [..._comments[post.id]!, cmt];
            });
          },
        );
      },
    );
  }
}
