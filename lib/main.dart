import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path_provider/path_provider.dart';
import 'models/post.dart';
import 'models/comment.dart';
import 'widgets/post_card.dart';
import 'widgets/image_overlay.dart';
import 'theme/app_colors.dart';
import 'theme/app_dimens.dart';
import 'services/api.dart';
import 'services/storage.dart';

final GlobalKey<_TreeholeAppState> appKey = GlobalKey<_TreeholeAppState>();
ThemeMode _themeMode = ThemeMode.system;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await PostStorage.init();
  runApp(TreeholeApp(key: appKey));
}

class TreeholeApp extends StatefulWidget {
  TreeholeApp({super.key});

  static void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    appKey.currentState?.setState(() {});
  }

  @override
  State<TreeholeApp> createState() => _TreeholeAppState();
}

class _TreeholeAppState extends State<TreeholeApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '树通',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: AppColors.light.background,
        colorScheme: ColorScheme.light(
          surface: AppColors.light.surface,
          onSurface: AppColors.light.onSurface,
        ),
        extensions: const [AppColors.light],
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.dark.background,
        colorScheme: ColorScheme.dark(
          surface: AppColors.dark.surface,
          onSurface: AppColors.dark.onSurface,
        ),
        extensions: const [AppColors.dark],
      ),
      home: const SquarePage(),
    );
  }
}

class _ColorModePage extends StatefulWidget {
  const _ColorModePage();

  @override
  State<_ColorModePage> createState() => _ColorModePageState();
}

class _ColorModePageState extends State<_ColorModePage> {
  ThemeMode _selectedMode = _themeMode;
  bool _showCustom = false;
  bool _modeExpanded = false;
  final Map<String, Color> _customColors = {};

  @override
  void initState() {
    super.initState();
    for (final e in PostStorage.getCustomColors().entries) {
      _customColors[e.key] = Color(e.value);
    }
  }

  String _modeLabel(ThemeMode m) => switch (m) { ThemeMode.light => '浅色模式', ThemeMode.dark => '深色模式', ThemeMode.system => '跟随系统' };

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurface;
    final sub = c.withValues(alpha: 0.5);
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _dropdownCard(
          context,
          value: _modeLabel(_selectedMode),
          expanded: _modeExpanded,
          onTap: () => setState(() => _modeExpanded = !_modeExpanded),
          children: [
            _optionTile('浅色模式', _selectedMode == ThemeMode.light, () => _selectMode(ThemeMode.light)),
            _optionTile('深色模式', _selectedMode == ThemeMode.dark, () => _selectMode(ThemeMode.dark)),
            _optionTile('跟随系统', _selectedMode == ThemeMode.system, () => _selectMode(ThemeMode.system)),
          ],
        ),
        _itemDivider(),
        _switchCard(context, '自定义颜色设置（没做完）', _showCustom, (v) => setState(() => _showCustom = v)),
        _itemDivider(),
        if (_showCustom) ...[
          _navCard(context, '浅色模式颜色', () => _showColorDetail('浅色模式颜色', AppColors.light)),
          _itemDivider(),
          _navCard(context, '深色模式颜色', () => _showColorDetail('深色模式颜色', AppColors.light)),
          _itemDivider(),
        ],
      ],
    );
  }

  void _selectMode(ThemeMode m) {
    setState(() { _selectedMode = m; _modeExpanded = false; });
    TreeholeApp.setThemeMode(m);
  }

  // ---- 通用组件 ----

  Widget _itemDivider() {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Divider(height: 1, thickness: 0.5, color: colors.divider);
  }

  Widget _itemRow(BuildContext ctx, Widget child) => SizedBox(
    height: AppDimens.settingsItemHeight,
    child: Center(child: child),
  );

  Widget _arrowBadge(Widget icon) => Padding(
    padding: EdgeInsets.only(right: AppDimens.settingsArrowRightMargin),
    child: icon,
  );

  Widget _dropdownCard(BuildContext ctx, {required String value, required bool expanded, required VoidCallback onTap, required List<Widget> children}) {
    final c = Theme.of(ctx).colorScheme.onSurface;
    final colors = Theme.of(ctx).extension<AppColors>()!;
    return AnimatedSize(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: _itemRow(ctx, Row(children: [
              Text(value, style: TextStyle(fontSize: AppDimens.settingsItemFontSize, color: c)),
              Spacer(),
              _arrowBadge(AnimatedRotation(turns: expanded ? 0.5 : 0, duration: Duration(milliseconds: 200), child: Icon(Icons.expand_more, size: AppDimens.settingsArrowSize, color: colors.arrowIcon))),
            ])),
          ),
          if (expanded) ...children,
        ],
      ),
    );
  }

  Widget _switchCard(BuildContext ctx, String label, bool value, ValueChanged<bool> onChanged) {
    final colors = Theme.of(ctx).extension<AppColors>()!;
    return _itemRow(ctx, Row(children: [
      Text(label, style: TextStyle(fontSize: AppDimens.settingsItemFontSize, color: Theme.of(ctx).colorScheme.onSurface)),
      Spacer(),
      Switch(value: value, activeColor: colors.switchActive, onChanged: onChanged),
    ]));
  }

  Widget _navCard(BuildContext ctx, String label, VoidCallback onTap) {
    final colors = Theme.of(ctx).extension<AppColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _itemRow(ctx, Row(children: [
        Text(label, style: TextStyle(fontSize: AppDimens.settingsItemFontSize, color: Theme.of(ctx).colorScheme.onSurface)),
        Spacer(),
        _arrowBadge(Icon(Icons.chevron_right, size: AppDimens.settingsArrowSize, color: colors.arrowIcon)),
      ])),
    );
  }

  Widget _optionTile(String label, bool selected, VoidCallback onTap) {
    final c = Theme.of(context).colorScheme.onSurface;
    final colors = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: selected ? colors.switchActive.withValues(alpha: 0.08) : null,
        child: _itemRow(context, Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: selected ? colors.switchActive : colors.trailingIcon),
              SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13, color: c)),
            ],
          ),
        )),
      ),
    );
  }

  Widget _colorRow(String name, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(name, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface))),
            Container(width: AppDimens.settingsColorSwatchSize, height: AppDimens.settingsColorSwatchSize, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade400))),
            SizedBox(width: 8),
            Text('#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}', style: TextStyle(fontSize: 12, color: Theme.of(context).extension<AppColors>()!.trailingIcon)),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(String name, Color currentColor) {
    double hue = HSVColor.fromColor(currentColor).hue;
    double sat = HSVColor.fromColor(currentColor).saturation;
    double val = HSVColor.fromColor(currentColor).value;
    double alpha = currentColor.a;
    Color getColor() => HSVColor.fromAHSV(alpha, hue, sat, val).toColor();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setInner) {
          void changed() { setInner(() {}); _onColorSelected(name, getColor()); }
          final barColor = Theme.of(context).extension<AppColors>()!.drawerHeaderBg;
          final hexCtrl = TextEditingController(text: getColor().value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase());
          final hexListener = () {
            final text = hexCtrl.text.replaceFirst('#', '');
            final c = colorFromHex(text, enableAlpha: true);
            if (c != null) {
              final h = HSVColor.fromColor(c);
              hue = h.hue; sat = h.saturation; val = h.value; alpha = h.alpha;
              changed();
            }
          };
          hexCtrl.addListener(hexListener);
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hexCtrl,
                          style: TextStyle(fontSize: 14, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Container(width: 36, height: 36, decoration: BoxDecoration(color: getColor(), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade400))),
                      SizedBox(width: 12),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: barColor),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('确定', style: TextStyle(color: Colors.black87, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: AppDimens.colorPickerSVSize,
                        height: AppDimens.colorPickerSVSize,
                        child: ColorPickerArea(HSVColor.fromAHSV(1, hue, sat, val), (hsv) { sat = hsv.saturation; val = hsv.value; changed(); }, PaletteType.hsv),
                      ),
                      SizedBox(width: AppDimens.colorPickerAreaGap),
                      SizedBox(
                        height: AppDimens.colorPickerSliderHeight,
                        child: Row(
                          children: [
                            _rotatedSlider(TrackType.hue, HSVColor.fromAHSV(1, hue, sat, val), (hsv) { hue = hsv.hue; changed(); }),
                            SizedBox(width: AppDimens.colorPickerSliderGap),
                            _rotatedSlider(TrackType.alpha, HSVColor.fromAHSV(alpha, hue, sat, val), (hsv) { alpha = hsv.alpha; changed(); }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _rotatedSlider(TrackType type, HSVColor hsv, ValueChanged<HSVColor> onChanged) {
    return SizedBox(
      // 这里不要改！！！！
      width: AppDimens.colorPickerSliderWidth,
      height: AppDimens.colorPickerSliderHeight,
      child: RotatedBox(
        quarterTurns: -1,
        child: ColorPickerSlider(type, hsv, onChanged),
      ),
    );
  }

  void _onColorSelected(String name, Color color) {
    setState(() => _customColors[name] = color);
    final map = <String, int>{};
    for (final e in _customColors.entries) map[e.key] = e.value.value;
    PostStorage.saveCustomColors(map);
  }

  void _restoreDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('恢复初始值'),
        content: Text('是否确认恢复所有颜色为默认值？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('否')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('是')),
        ],
      ),
    );
    if (confirm == true) {
      await PostStorage.clearCustomColors();
      setState(() => _customColors.clear());
    }
  }

  void _showColorDetail(String title, AppColors themeColors) {
    final pc = themeColors.postCard;
    final Map<String, Map<String, Color>> categories = {
      '贴文颜色': {
        '卡片边框': pc.cardBorder, '正文分割线': pc.bodyDivider,
        '标题文字': pc.title, '正文文字': pc.content,
        '日期文字': pc.dateText, '剩余字数': pc.remainCount,
        '作者署名': pc.authorName, 'AT符号': pc.atSymbol,
        '附件文字': pc.attachmentText, '评论文字': pc.commentContent,
        '评论署名': pc.commentAuthor, '评论日期': pc.commentDate,
        '剩余回复数': pc.commentRemain, '评论背景': pc.commentBg,
        '评论图标': pc.commentIcon, '评论日期分隔线': pc.commentDateSeparatorLine,
        '展开按钮激活': pc.expandIconBlue, '展开按钮灰色': pc.expandIconGray,
        '点按钮背景': pc.dotsButtonBg, '帖子ID颜色': pc.idTint,
        'ID错误占位': pc.idErrorFallback,
      },
      '侧边栏颜色': {
        '抽屉头部背景': themeColors.drawerHeaderBg,
        'ID品牌色': themeColors.idTint,
      },
      '设置栏颜色': {
        '箭头图标': themeColors.arrowIcon, '栏文字颜色': themeColors.barText,
        '分割线': themeColors.divider, '尾部图标': themeColors.trailingIcon,
        '开关激活': themeColors.switchActive, '展开按钮': themeColors.expandIconActive,
      },
      '基本颜色': {
        '页面背景': themeColors.background, '卡片表面': themeColors.surface,
        '主文字': themeColors.onSurface, '次要文字': themeColors.secondary,
        '边框色': themeColors.borderColor, '强调色': themeColors.accentText,
        '绿色标识': themeColors.green, '按钮背景': themeColors.buttonBg,
        '附件色': themeColors.attachment,
      },
    };
    navigateToSubPage(context, title, ListView(
      padding: EdgeInsets.all(16),
      children: [
        for (final cat in categories.entries) ...[
          _navCard(context, cat.key, () => _showCategoryColors('$title · ${cat.key}', cat.value)),
          _itemDivider(),
        ],
      ],
    ));
  }

  void _showCategoryColors(String title, Map<String, Color> colors) {
    navigateToSubPage(context, title, ListView(
      padding: EdgeInsets.all(16),
      children: [
        ...colors.entries.map((e) {
          final displayColor = _customColors[e.key] ?? e.value;
          return _colorRow(e.key, displayColor, () => _showColorPicker(e.key, displayColor));
        }),
        _itemDivider(),
        ListTile(
          leading: Icon(Icons.restore, color: Theme.of(context).extension<AppColors>()!.trailingIcon),
          title: Text('恢复初始值'),
          onTap: _restoreDefaults,
        ),
      ],
    ));
  }
}

void navigateToSubPage(BuildContext context, String title, Widget body) {
  final colors = Theme.of(context).extension<AppColors>()!;
  final barText = colors.barText;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            height: AppDimens.settingsBarHeight,
            color: colors.drawerHeaderBg,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: barText),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: barText)),
                ),
                SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    ),
  )));
}

void navigateToSettingsPage(BuildContext context, String title, Widget body) {
  final colors = Theme.of(context).extension<AppColors>()!;
  final barText = colors.barText;
  Navigator.of(context).push(PageRouteBuilder(
    pageBuilder: (_, __, ___) => Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: AppDimens.settingsBarHeight,
              color: colors.drawerHeaderBg,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: barText),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: barText)),
                  ),
                  SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    ),
    transitionsBuilder: (_, animation, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: child,
    ),
    transitionDuration: Duration(milliseconds: AppDimens.drawerAnimMs),
  ));
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
  Uint8List? _avatarBytes;                          // 抽屉头像字节

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
    _loadAvatar();
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
            _settingsTile(Icons.palette_outlined, '颜色模式', () { Navigator.pop(context); navigateToSettingsPage(context, '颜色模式', const _ColorModePage()); }),
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
      trailing: Icon(Icons.chevron_right, color: colors.trailingIcon),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: ImageOverlay.currentEntry == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ImageOverlay.closeCurrent();
      },
      child: Scaffold(
      drawerEdgeDragWidth: MediaQuery.of(context).size.width,
      drawer: Builder(builder: (ctx) {
        final colors = Theme.of(ctx).extension<AppColors>()!;
        return Drawer(
        shape: const RoundedRectangleBorder(),
        width: MediaQuery.of(ctx).size.width * 4 / 5,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: colors.drawerHeaderBg,
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
                              backgroundColor: colors.idTint.withValues(alpha: 0.2),
                              backgroundImage: const AssetImage('assets/420px-Transparent_Akkarin.jpg'),
                            ),
                    ),
                    SizedBox(width: AppDimens.drawerAvatarTextGap),
                    Expanded(
                      child: Text('匿名用户', style: TextStyle(fontSize: AppDimens.drawerNameFontSize, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
                    ),
                    Icon(Icons.chevron_right, color: colors.trailingIcon),
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
                    _drawerTile(Icons.system_update_outlined, '更新（没做）'),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('版本 1.0.0', style: TextStyle(fontSize: 12, color: colors.trailingIcon)),
              ),
            ],
          ),
          ),
        );
      }),
      body: SafeArea(
        bottom: false,
        child: _loading && _posts.isEmpty
            ? const Center(child: Image(image: AssetImage('assets/loading.gif'), width: AppDimens.loadingGifSize, height: AppDimens.loadingGifSize))
            // 有错误 → 显示错误文字
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: TextStyle(color: Theme.of(context).extension<AppColors>()!.trailingIcon)))
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
