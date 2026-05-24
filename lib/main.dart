import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/post.dart';
import 'widgets/post_card.dart';
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
  List<Post> _posts = [];
  List<int> _allIds = [];
  int _loadedCount = 0;
  bool _loading = false;
  String? _error;
  final Set<int> _loadingIds = {};

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    final cachedPosts = PostStorage.getAllCachedPosts();
    final cachedIds = cachedPosts.map((p) => p.id).toList();
    if (cachedPosts.isNotEmpty) {
      _posts = cachedPosts;
      _allIds = PostStorage.getIdList();
      _loadedCount = cachedPosts.length;
      setState(() => _loading = false);
    }

    try {
      final newIds = await ApiService.getIdList();
      _allIds = PostStorage.mergeAndSaveIdList(newIds);
      await _loadMore();
    } catch (_) {
      if (_posts.isEmpty) {
        setState(() {
          _loading = false;
          _error = '加载失败，请检查网络';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    final batch = _allIds.skip(_loadedCount).take(7).where((id) => !_loadingIds.contains(id)).toList();
    if (batch.isEmpty) return;

    setState(() => _loading = true);
    for (final id in batch) _loadingIds.add(id);

    final futures = batch.map((id) async {
      final post = PostStorage.getPost(id) ?? await ApiService.getPost(id);
      if (post != null) await PostStorage.savePost(post);
      return post;
    }).toList();

    for (int i = 0; i < futures.length; i++) {
      final post = await futures[i];
      _loadingIds.remove(batch[i]);
      if (post != null && !_posts.any((p) => p.id == post.id)) {
        setState(() {
          _posts.add(post);
          _posts.sort((a, b) => _allIds.indexOf(a.id).compareTo(_allIds.indexOf(b.id)));
        });
      }
    }

    _loadedCount += batch.length;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading && _posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.grey)))
                : NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.pixels >=
                          notification.metrics.maxScrollExtent - 300 &&
                      !_loading) {
                    _loadMore();
                  }
                  return false;
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppDimens.listPaddingLeft,
                    AppDimens.listPaddingTop,
                    AppDimens.listPaddingRight,
                    AppDimens.listPaddingBottom,
                  ),
                  children: _posts
                      .map((p) => PostCard(post: p))
                      .toList(),
                ),
              ),
      ),
    );
  }
}
