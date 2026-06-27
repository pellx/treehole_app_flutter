# 项目文件结构与代码规范建议

本文档供项目维护者、协作者和编码 agent 阅读。目标是让后续开发在不破坏现有功能的前提下，逐步把项目从"原型期单文件集中实现"整理成可维护的 Flutter 应用。

> 当前项目：`treehole` / "树通 - 学生的匿名论坛"。
>
> **会话历史：** 每次 agent 工作的总结存放在 `AGENT_N.md` 文件中。当前有 `AGENT_1.md`（帖子发布 API 接入与修复）。
>
> **当前结构：** 已初步分层——`main.dart` 仅入口，`app.dart` 管理主题，页面拆入 `pages/`，模型/服务/主题/组件各有目录。

## 总体原则

1. **优先保持行为一致**：重构时不要顺手改 UI、尺寸、颜色、网络逻辑；结构调整和功能调整分开提交。
2. **小步迁移**：不要一次性大重构。每次只搬一类代码，例如“先抽出页面”，再“抽出组件”，再“抽出状态”。
3. **保留现有视觉细节**：本项目 UI 有大量精细调参，尤其是帖子卡片、帖子 ID 数字、图片查看器动画和评论布局。移动代码时不要改动 `AppDimens` 数值，除非任务明确要求。
4. **避免新增全局状态**：现有代码已有 `_themeMode`、`appKey`、`ImageOverlay.currentEntry` 等全局/静态状态。新增功能优先使用显式参数、Controller、Notifier 或页面局部状态。
5. **网络、缓存、UI 分层**：API 请求不要写进 Widget，Hive/文件缓存不要散落在 UI 中。Widget 只负责展示和交互。
6. **错误可见但不打扰**：用户侧显示简洁提示，开发侧保留可追踪日志。不要用空 `catch` 吞掉所有信息，至少在调试模式下可定位。

---

## 推荐目录结构

建议逐步整理为下面结构：

```text
lib/
  main.dart                         # 仅保留启动入口：初始化、runApp
  app.dart                          # TreeholeApp，主题装配，路由入口

  models/                           # 纯数据模型
    post.dart
    comment.dart

  services/                         # 外部服务和基础设施
    api.dart                        # HTTP API 客户端
    storage.dart                    # Hive + 文件缓存

  pages/                            # 页面级 Widget，一个页面一个目录或文件
    square/
      square_page.dart              # 首页帖子流
      square_controller.dart        # 可选：加载/刷新/分页逻辑
      square_drawer.dart            # 首页侧边栏
    settings/
      settings_sheet.dart           # 设置入口 bottom sheet
      color_mode_page.dart          # 颜色模式页
      color_detail_page.dart        # 可选：颜色详情/颜色分类

  widgets/                          # 跨页面复用组件
    post/
      post_card.dart
      post_title_author_row.dart
      thumbnail_image.dart
      comment_section.dart
    image_overlay/
      image_overlay.dart
      page_physics.dart
    common/
      app_top_bar.dart              # 可选：设置页顶部栏等通用组件

  theme/
    app_colors.dart                 # ThemeExtension 与颜色定义
    app_dimens.dart                 # 尺寸、间距、动画参数

  utils/                            # 无状态工具函数
    date_format.dart                # 日期格式化、安全 parse
    debug_log.dart                  # 可选：调试日志封装
```

### 迁移优先级

当前已有进展，下面标记 ✅ 的步骤已完成：

1. ✅ **抽出 `app.dart`** — `main.dart` 仅保留入口，`TreeholeApp` 已在 `lib/app.dart`。

2. ✅ **抽出首页** — `SquarePage` 和 `_SquarePageState` 已移到 `lib/pages/square/square_page.dart`。

3. ✅ **抽出设置相关页面** — `ColorModePage` 已在 `lib/pages/settings/color_mode_page.dart`，`navigateToSettingsPage()` / `navigateToSubPage()` / `topDownRoute()` 已在 `lib/pages/settings/settings_navigation.dart`。

4. **拆分 `PostCard`**（待做）
   - `PostCard` 当前承担标题、正文、图片、附件、评论、缩略图加载等职责。
   - 优先把 `_TitleAuthorRow`、`ThumbnailImage`、评论区域拆到同目录小组件。
   - 拆分时不要改变布局参数。

5. **最后再考虑状态管理**（待做）
   - 如果功能继续增加，再引入 `ChangeNotifier`、`ValueNotifier`、Provider/Riverpod 等。
   - 在没有明确痛点前，不要为了"架构正确"引入重型状态管理。

---

## 文件职责规范

### `main.dart`

只做启动，不放页面实现。

推荐职责：

- `WidgetsFlutterBinding.ensureInitialized()`；
- 初始化 Hive / Storage；
- `runApp()`。

不推荐：

- 页面 UI；
- API 调用；
- 业务状态；
- 颜色设置页面；
- Drawer 实现。

### `app.dart`

负责应用根节点。

推荐职责：

- `MaterialApp`；
- light/dark theme 装配；
- 全局主题模式状态；
- 首页入口。

注意：当前主题模式用全局 `_themeMode` + `GlobalKey` 刷新，可以先保留；后续可迁移到 `ValueNotifier<ThemeMode>` 或持久化设置。

### `models/`

只放数据结构和 JSON 转换。

要求：

- 不依赖 Flutter UI；
- 不发网络请求；
- 不读写 Hive；
- 字段尽量 `final`；
- `fromJson` 对缺失字段保持兼容；
- 如新增 `toJson`，字段名要与 API / Hive 存储格式明确对应。

### `services/api.dart`

只负责远端请求和响应转换。

**当前状态（AGENT_1 已改进）：**

- 所有请求统一使用 `_isHttpSuccess(statusCode)` 判断，范围 200-299（与 JS 端 `res.ok` 一致），修复了 POST 返回 `201 Created` 被误判为失败的问题。
- 所有 `catch` 分支使用 `debugPrint('[ApiService] methodName ... error: $e')` 输出可追踪日志，不再吞异常。
- URL 常量集中在类顶部（`_base`、`_commentBase`、`_thumbBase`、`_originalBase`、`_uploadBase`）。
- 所有请求均有 30 秒 `_timeout`。

**待改进：**

- mock 开关（`_useMock`）不要长期写死在私有常量中，后续可通过环境变量或 debug 配置控制。

### `services/storage.dart`

只负责本地持久化和文件缓存。

**当前状态：**

- 5 个 Hive Box：`id_list`、`posts`、`thumbnails`、`comments`、`custom_colors`。
- 帖子缓存提供完整 CRUD：`getPost` / `savePost` / `deletePost` / `markFetched` / `isFetched`。
- 缩略图缓存兼容旧格式（`Uint8List`）和新格式（`Map`含宽高）。
- 原图文件缓存于临时目录 `png_cache/`。
- 评论缓存支持 `getComment` / `saveComment` / `getComments`（批量）。
- `deletePost(int id)` 在 AGENT_1 新增，用于下拉刷新时清理已删除的帖子。

**待改进：**

- Hive box 名称集中定义；
- 存储结构变更要考虑兼容旧数据；
- 图片原图/缩略图缓存和帖子/评论缓存可以逐步拆分；
- 不要在 Widget 中直接写文件路径拼接逻辑，统一经过 storage/service。

### `theme/app_colors.dart`

负责颜色语义，不负责尺寸。

规范：

- 颜色命名使用“用途语义”，例如 `commentAuthor`，不要使用 `blue1`、`gray2`；
- light/dark 成对维护；
- 新增颜色时同时更新：构造函数、`copyWith`、`lerp`、light、dark；
- 帖子卡片专属颜色继续放在 `PostCardColors`，避免全局颜色膨胀。

### `theme/app_dimens.dart`

负责尺寸、间距、字号、动画时长。

规范：

- 不放颜色；
- 不放业务逻辑；
- 修改数值要说明影响区域；
- 帖子卡片和图片查看器的参数非常敏感，修改后需要手动检查不同内容长度、单图/多图、亮色/暗色模式。

---

## 命名规范

### 文件名

使用 Dart/Flutter 常见的 `snake_case.dart`：

```text
square_page.dart
post_card.dart
image_overlay.dart
app_colors.dart
```

页面文件建议以 `_page.dart` 结尾，组件文件以组件名命名。

### 类名

使用 `UpperCamelCase`：

```dart
class SquarePage extends StatefulWidget {}
class PostCard extends StatefulWidget {}
class AppColors extends ThemeExtension<AppColors> {}
```

私有类加 `_`：

```dart
class _SquarePageState extends State<SquarePage> {}
```

### 方法和变量

使用 `lowerCamelCase`：

```dart
Future<void> loadMore()
final loadedCount = 0;
```

私有成员加 `_`：

```dart
bool _loading = false;
Future<void> _refreshPostComments(Post post) async {}
```

### 常量

项目当前使用 `AppDimens.xxx` 静态常量风格，继续保持：

```dart
AppDimens.cardHPadding
AppDimens.commentMaxShown
```

不要在 Widget 中直接散落魔法数字。确实只用一次的局部值可以保留，但和 UI 视觉强相关的数值应进 `AppDimens`。

---

## Widget 编写规范

1. **优先拆小组件**
   - 单个 build 方法不要无限增长。
   - 重复 UI 提取成私有方法或独立 Widget。
   - 如果子组件有自己的状态，优先独立成 `StatefulWidget`。

2. **不要在 `build()` 中发网络请求或写缓存**
   - 请求放在 `initState()`、事件回调、Controller 或明确的加载方法中。
   - 当前 `ThumbnailImage` 在 `initState()` 中加载缩略图是合理的。

3. **异步回调后检查 `mounted`**
   - `await` 之后调用 `setState` 前必须检查 `mounted`。
   - 项目里已有这种写法，继续保持。

4. **构造函数尽量使用 `const`**
   - 没有状态且参数可 const 的 Widget 构造函数加 `const`。

5. **回调命名表达意图**
   - 例如 `onNeedCommentRefresh` 比 `callback` 更清楚。

6. **避免 `dynamic`**
   - 例如 `_TitleAuthorRow` 当前 `post` 是 `dynamic`，后续拆分时建议改成 `Post post`。

---

## 异步、缓存和加载规范

### 帖子加载

当前首页加载逻辑是：

1. 获取 ID 列表；
2. 每批加载 7 个帖子；
3. Hive 优先，API fallback；
4. 加载成功后写入 Hive；
5. 刷新评论；
6. 后台预下载缩略图。

**下拉刷新（`_refresh()`）行为（AGENT_1 补充了删除逻辑）：**

1. 重新获取 ID 列表；
2. 移除已在列表中的帖子（后端删除），同时清理 `_comments`、`_postsNeedCommentRefresh`、Hive 缓存；
3. 拉取新帖插入顶部，按 `_allIds` 排序；
4. 标记所有帖子需要评论刷新，取前 7 个执行。

后续修改时应保持这些行为，除非任务明确要求改变。

### 评论加载

当前评论刷新逻辑是：

- 先重新获取帖子，拿最新 comment IDs；
- 对比本地已有评论；
- 只请求缺失评论；
- 合并后按 comment IDs 排序。

不要改成“每次刷新全量评论”，除非确认性能和接口压力可接受。

### 图片缓存

当前有两级图片体验：

- 缩略图：Hive 缓存；
- 原图：临时目录文件缓存。

图片查看器会先显示缩略图，再加载原图并淡入。这个体验是核心交互，不要在普通重构中移除。

---

## 错误处理和日志建议

**AGENT_1 已改进：** `api.dart` 中 5 个方法已使用 `debugPrint('[ApiService] methodName ... error: $e')` + `_isHttpSuccess(200-299)`，不再吞异常。

**仍待处理：** `square_page.dart`、`post_card.dart` 中仍有 `print()` 调用（如 `print('[loadMore] start...')`、`print('[comment] refreshing...')`）。建议逐步改为 `debugPrint` 或封装 `debugLog()`：

```dart
void debugLog(String message) {
  assert(() {
    // ignore: avoid_print
    debugPrint(message);
    return true;
  }());
}
```

规范：

- 用户可恢复错误：显示简洁 UI 文案，例如"加载失败，请检查网络"；
- 开发排错信息：debug 模式下输出请求 URL、状态码、异常类型；
- 不要在 release 中大量输出日志；
- 不要吞掉会影响数据一致性的异常。

---

## 日期和字符串处理建议

当前多处直接 `DateTime.parse(dateStr)`。建议后续新增工具函数：

```dart
DateTime? tryParseDate(String value) {
  if (value.isEmpty) return null;
  return DateTime.tryParse(value);
}
```

UI 格式化函数放到 `lib/utils/date_format.dart`，避免重复实现：

- 帖子日期：`yy.M.d-HH:mm`；
- 评论时间：`HH:mm`；
- 日期分隔：`yy.M.d`。

这样 API 返回异常日期时，不会导致整个 Widget build 崩溃。

---

## 主题和自定义颜色建议

当前颜色模式页可以保存自定义颜色，但自定义颜色尚未真正应用到全局主题。后续实现时建议：

1. 先明确颜色 key 使用稳定的英文内部 key，不要只用中文显示名作为存储 key；
2. 保存结构区分 light/dark；
3. 启动时从 `PostStorage` 读取自定义颜色并 merge 到 `AppColors.light/dark`；
4. 修改颜色后通知 `TreeholeApp` 重建主题；
5. 显示名可以中文，但内部字段和存储 key 应稳定。

注意：颜色设置页中“深色模式颜色”应使用暗色主题颜色作为基础，避免误用浅色主题。

---

## 测试和质量检查

建议提交前至少运行：

```bash
flutter analyze
flutter test
```

当前默认 `test/widget_test.dart` 仍是 Flutter counter 模板，引用了不存在的 `MyApp`。在补测试前，`flutter test` 可能失败。建议先将测试改为能启动 `TreeholeApp` 的 smoke test，或删除无效 counter 断言。

推荐测试方向：

- `Post.fromJson` 缺字段兼容；
- `Comment.fromJson` 缺字段兼容；
- 日期格式化工具；
- `PostStorage` 的序列化/反序列化；
- `PostCard` 基础渲染 smoke test。

---

## 给编码 agent 的特别注意事项

1. **修改前先读相关文件**：尤其是 `main.dart`、`post_card.dart`、`image_overlay.dart`、`app_dimens.dart`。
2. **不要随意格式化整个大文件**：大范围格式化会制造噪音 diff。只格式化修改过的文件，或在用户明确要求时再全量格式化。
3. **不要擅自改 UI 数值**：`AppDimens` 中很多数值是手调结果，改动前必须确认目标。
4. **不要把重构和功能变更混在一起**：如果任务是“拆文件”，就不要顺手改加载逻辑、颜色、动画。
5. **保留中文 UI 文案风格**：现有用户可见文案主要是中文，新增文案也使用中文。
6. **外部行为要小心**：保存图片、分享图片、访问远端 API 都属于外部交互；测试时不要做破坏性操作。
7. **注意当前工作区可能有未提交修改**：动手前查看 git diff/status，不要覆盖他人改动。

---

## 建议的近期整理任务

已完成（vs 原始 AGENTS.md 建议清单）：
- ✅ 把 `TreeholeApp` 抽到 `lib/app.dart`
- ✅ 把 `SquarePage` 抽到 `lib/pages/square/square_page.dart`
- ✅ 把设置和颜色模式页抽到 `lib/pages/settings/`

待做（按优先级）：
1. 修复 `test/widget_test.dart`，改为能启动 `TreeholeApp` 的 smoke test
2. 把 `PostCard` 内的 `ThumbnailImage`、`_TitleAuthorRow`、评论区域拆成独立文件
3. 新增 `lib/utils/date_format.dart` 并替换直接 `DateTime.parse`
4. 为 README 补充项目介绍、运行方式和主要功能
5. 设计并完成自定义颜色真正应用到主题的流程

## 已知待解决问题

1. **fluter analyze warnings：** `color_mode_page.dart` 中 `deprecated_member_use`、`square_page.dart` 中 `avoid_print` 等
2. **`_loadMore()` 中 `cacheExtent` 已废弃** → 应改用 `scrollCacheExtent`
3. **Hive 缩略图和评论未同步清理：** 帖子被删时仅清理了 `_postBox`，`_thumbBox` 和 `_commentBox` 中对应数据未清理
4. **`test/widget_test.dart`** 仍是 Counter 模板，引用了不存在的 `MyApp`

以上任务应分开提交，每步都保持应用可运行。
