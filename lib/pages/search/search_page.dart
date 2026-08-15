import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/post.dart';
import '../../services/api.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/app_app_bar.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/post_card.dart';

/// 搜索页：现代风格，支持关键词/作者/时间段/品类筛选
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
  bool _loading = true;
  String? _error;

  String _query = '';
  String? _author;
  DateTime? _dateStart;
  DateTime? _dateEnd;
  String _selectedCategory = '全部';

  final _categories = ['全部', '问答', '资料', '兴趣', '梗图'];
  final _categoryKeywords = {
    '问答': ['问', '求助', '怎么办', '帮忙', '求', '？', '?'],
    '资料': ['资料', '资源', '下载', '链接', '文件', '附件', '教程', '攻略'],
    '兴趣': ['兴趣', '闲聊', '吐槽', '八卦', '聊聊', '讨论', '经验', '分享'],
    '梗图': ['梗', '图', '图片', '表情包', '笑', 'meme'],
  };

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _loadPosts();
  }

  @override
  void dispose() {
    _controller.removeListener(() => setState(() {}));
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ids = await ApiService.getIdList(
        search: _query.isEmpty ? null : _query,
        author: _author,
        dateStart: _dateStart != null ? _formatApiDate(_dateStart!) : null,
        dateEnd: _dateEnd != null ? _formatApiDate(_dateEnd!) : null,
        // category 参数等后端支持后再传，目前先客户端关键词兜底
      );
      final posts = <Post>[];
      await Future.wait(
        ids.take(30).map((id) async {
          final post = await ApiService.getPost(id);
          if (post != null) posts.add(post);
        }),
      );
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
    if (query == _query &&
        _author == null &&
        _dateStart == null &&
        _dateEnd == null) {
      _focusNode.unfocus();
      return;
    }
    _query = query;
    _focusNode.unfocus();
    _loadPosts();
  }

  void _onCategoryTap(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedCategory = _categories[index]);
  }

  List<Post> get _filteredPosts {
    final category = _selectedCategory;
    if (category == '全部') return _posts;
    final keywords = _categoryKeywords[category] ?? [];
    return _posts.where((p) {
      final text = '${p.title} ${p.content}'.toLowerCase();
      return keywords.any((k) => text.contains(k));
    }).toList();
  }

  String _formatApiDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _showAuthorPicker() async {
    final controller = TextEditingController(text: _author ?? '');
    final author = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).extension<AppColors>()!;
        final onSurface = Theme.of(ctx).colorScheme.onSurface;
        return AlertDialog(
          backgroundColor: colors.common.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('指定作者', style: TextStyle(color: onSurface)),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: '输入作者名',
              hintStyle: TextStyle(color: colors.common.trailingIcon),
              filled: true,
              fillColor: colors.common.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                '取消',
                style: TextStyle(color: onSurface.withValues(alpha: 0.7)),
              ),
            ),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(ctx).pop(value.isEmpty ? null : value);
              },
              child: Text(
                '确定',
                style: TextStyle(color: colors.common.green),
              ),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (author != _author) {
      setState(() => _author = author);
      _loadPosts();
    }
  }

  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _dateStart != null && _dateEnd != null
          ? DateTimeRange(start: _dateStart!, end: _dateEnd!)
          : null,
      builder: (context, child) {
        final colors = Theme.of(context).extension<AppColors>()!;
        return Theme(
          data: Theme.of(context).copyWith(
            appBarTheme: Theme.of(context).appBarTheme.copyWith(
                  backgroundColor: colors.common.surface,
                  foregroundColor: colors.common.onSurface,
                ),
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: colors.common.green,
                  surface: colors.common.surface,
                ),
          ),
          child: child!,
        );
      },
    );
    if (range == null) return;
    setState(() {
      _dateStart = range.start;
      _dateEnd = range.end;
    });
    _loadPosts();
  }

  Future<void> _showCategoryPicker() async {
    final selected = await showAppSelectorSheet<String>(
      context: context,
      title: '选择品类',
      options: _categories,
      labelBuilder: (c) => c,
      selected: _selectedCategory,
    );
    if (selected == null) return;
    _onCategoryTap(_categories.indexOf(selected));
  }

  void _clearFilters() {
    setState(() {
      _author = null;
      _dateStart = null;
      _dateEnd = null;
      _selectedCategory = '全部';
    });
    _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AppScaffold(
      title: '搜索',
      body: Column(
        children: [
          _buildSearchBar(colors, onSurface),
          _buildFilterChips(colors, onSurface),
          Expanded(child: _buildBody(colors)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppColors colors, Color onSurface) {
    return Container(
      color: colors.common.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _onSearch(),
        decoration: InputDecoration(
          hintText: '搜索帖子关键词...',
          hintStyle: TextStyle(color: colors.common.trailingIcon),
          prefixIcon: Icon(
            Icons.search,
            color: colors.common.trailingIcon,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: colors.common.trailingIcon,
                  ),
                  onPressed: () {
                    _controller.clear();
                    if (_query.isNotEmpty) {
                      _query = '';
                      _loadPosts();
                    }
                  },
                )
              : null,
          filled: true,
          fillColor: colors.common.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.common.green, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChips(AppColors colors, Color onSurface) {
    return Container(
      color: colors.common.surface,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: _author == null || _author!.isEmpty
                  ? '作者'
                  : '作者: $_author',
              active: _author != null && _author!.isNotEmpty,
              onTap: _showAuthorPicker,
            ),
            const SizedBox(width: 10),
            _FilterChip(
              label: _dateStart != null && _dateEnd != null
                  ? '${_formatApiDate(_dateStart!)} ~ ${_formatApiDate(_dateEnd!)}'
                  : '时间段',
              active: _dateStart != null && _dateEnd != null,
              onTap: _showDatePicker,
            ),
            const SizedBox(width: 10),
            _FilterChip(
              label: _selectedCategory == '全部'
                  ? '品类'
                  : '品类: $_selectedCategory',
              active: _selectedCategory != '全部',
              onTap: _showCategoryPicker,
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(width: 10),
              _FilterChip(
                label: '清除',
                active: false,
                onTap: _clearFilters,
                isAction: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasActiveFilters =>
      _author != null && _author!.isNotEmpty ||
      _dateStart != null ||
      _dateEnd != null ||
      _selectedCategory != '全部';

  Widget _buildBody(AppColors colors) {
    if (_loading) {
      return const AppLoadingCenter(message: '加载中...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _loadPosts);
    }
    final posts = _filteredPosts;
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
          comments: const [],
          onNeedCommentRefresh: () {},
          onCommentCreated: (_) {},
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool isAction;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isAction
              ? colors.common.background
              : active
                  ? colors.common.green.withValues(alpha: 0.1)
                  : colors.common.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAction
                ? colors.common.divider
                : active
                    ? colors.common.green
                    : colors.common.divider,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isAction
                ? onSurface.withValues(alpha: 0.7)
                : active
                    ? colors.common.green
                    : onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
