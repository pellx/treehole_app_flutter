import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_app_bar.dart';

/// 搜索页（占位）：保留 UI 入口，后续接入搜索 API
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() => _searched = true);
    // TODO: 接入搜索 API
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AppScaffold(
      title: '搜索',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
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
                          setState(() => _searched = false);
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
          Expanded(
            child: _searched
                ? const AppEmptyState(
                    message: '搜索功能即将上线',
                    icon: Icons.search_off,
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search,
                          size: 48,
                          color: colors.common.trailingIcon,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '输入关键词开始搜索',
                          style: TextStyle(
                            fontSize: 15,
                            color: onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
