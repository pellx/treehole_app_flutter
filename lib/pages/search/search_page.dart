import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/comment.dart';
import '../../models/post.dart';
import '../../services/api.dart';
import '../../services/storage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_search_theme.dart';
import '../../theme/app_square_top_bar_theme.dart';
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
  final _categories = ['默认', '问答', '资料', '兴趣', '梗图'];
  int _selectedCategoryIndex = 0;

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
      final category = _selectedCategoryIndex == 0
          ? null
          : _categories[_selectedCategoryIndex];
      final ids = await ApiService.getIdList(
        search: _query.isEmpty ? null : _query,
        category: category,
      );
      final posts = <Post>[];
      await Future.wait(
        ids.take(30).map((id) async {
          final post = await ApiService.getPost(id);
          if (post != null) posts.add(post);
        }),
      );
      for (final post in posts) {
        _comments[post.id] ??= PostStorage.getComments(post.comments);
        _postsNeedCommentRefresh.add(post.id);
      }
      if (mounted) {
        setState(() {
          _posts = posts;
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
            if (_query.isNotEmpty) _buildCategoryBar(colors, onSurface),
            _buildSearchHistory(colors, onSurface),
            Expanded(child: _buildBody(colors)),
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
            child: SizedBox(
              height: AppSearchTheme.searchBarHeight,
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
                  prefixIcon: const SizedBox.shrink(),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  prefix: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: AppSearchTheme.searchIconVerticalAlignment,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          left: AppSearchTheme.searchIconLeftOffset,
                          top: AppSearchTheme.searchIconVerticalOffset,
                        ),
                        child: Icon(
                          Icons.search,
                          color: colors.common.trailingIcon,
                          size: AppSearchTheme.prefixIconSize,
                        ),
                      ),
                      SizedBox(width: AppSearchTheme.searchIconToTextGap),
                    ],
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _controller.clear();
                            if (_query.isNotEmpty) {
                              _query = '';
                              _loadPosts();
                            }
                          },
                          child: Icon(
                            Icons.clear,
                            color: colors.common.trailingIcon,
                            size: AppSearchTheme.clearIconSize,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: colors.common.surface,
                  isDense: AppSearchTheme.inputIsDense,
                  contentPadding: const EdgeInsets.only(
                    left: AppSearchTheme.searchIconLeftPadding,
                    top: AppSearchTheme.inputVerticalPadding,
                    bottom: AppSearchTheme.inputVerticalPadding,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppSearchTheme.inputBorderRadius,
                    ),
                    borderSide: BorderSide(
                      color: colors.common.divider,
                      width: AppSearchTheme.inputBorderWidth,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppSearchTheme.inputBorderRadius,
                    ),
                    borderSide: BorderSide(
                      color: colors.common.divider,
                      width: AppSearchTheme.inputBorderWidth,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppSearchTheme.inputBorderRadius,
                    ),
                    borderSide: BorderSide(
                      color: colors.common.divider,
                      width: AppSearchTheme.inputBorderWidth,
                    ),
                  ),
                ),
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

  Widget _buildCategoryBar(AppColors colors, Color onSurface) {
    final bg = Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : colors.common.surface;

    return Container(
      color: bg,
      height: AppSquareTopBarTheme.height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categories.asMap().entries.map((entry) {
            final index = entry.key;
            final label = entry.value;
            final selected = index == _selectedCategoryIndex;
            return GestureDetector(
              onTap: () {
                if (_selectedCategoryIndex == index) return;
                setState(() => _selectedCategoryIndex = index);
                if (_query.isNotEmpty) _loadPosts();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSquareTopBarTheme.itemHorizontalPadding,
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
                            : AppSquareTopBarTheme.unselectedFontWeight,
                        color: selected
                            ? colors.common.green
                            : onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    SizedBox(
                      height: AppSquareTopBarTheme.indicatorTopSpacing,
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
                      height: AppSquareTopBarTheme.indicatorBottomSpacing,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
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
