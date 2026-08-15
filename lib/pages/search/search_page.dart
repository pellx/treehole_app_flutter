import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/post.dart';
import '../../services/api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/post_card.dart';

/// 搜索/发现页：顶部参考微信式栏目导航，左侧栏目占位抽屉
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

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
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
      );
      final posts = <Post>[];
      for (final id in ids.take(30)) {
        final post = await ApiService.getPost(id);
        if (post != null) posts.add(post);
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
    if (query == _query) return;
    _query = query;
    _focusNode.unfocus();
    _loadPosts();
  }

  void _onCategoryTap(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedCategoryIndex = index);
  }

  List<Post> get _filteredPosts {
    final category = _categories[_selectedCategoryIndex];
    if (category == '推荐') return _posts;
    final keywords = _categoryKeywords[category] ?? [];
    return _posts.where((p) {
      final text = '${p.title} ${p.content}'.toLowerCase();
      return keywords.any((k) => text.contains(k));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      drawer: _buildDrawer(colors),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(colors),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _onSearch(),
                decoration: InputDecoration(
                  hintText: '搜索帖子、用户...',
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
                  fillColor: colors.common.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.common.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.common.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.common.green),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            Expanded(child: _buildBody(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppColors colors) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      height: 48,
      color: colors.common.surface,
      child: Row(
        children: [
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.menu, color: onSurface),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14),
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
                              borderRadius: BorderRadius.circular(1.25),
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
            onPressed: () => _focusNode.requestFocus(),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(AppColors colors) {
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
        message: '该分类下暂无帖子',
        icon: Icons.inbox_outlined,
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
