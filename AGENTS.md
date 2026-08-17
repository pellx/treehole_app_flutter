# 树通 Flutter — Agent 协作指南

本文件汇总项目背景、结构、设计约定与协作规范，供后续 Agent 快速接手。

## 1. 项目 overview

- **应用名称**：树通（树洞 Flutter 客户端）。
- **定位**：学生匿名论坛，核心功能包括广场贴文流、发帖（图片/附件）、评论、注册/登录、设备绑定、账户切换、设置。
- **技术栈**：Flutter 3.x，Dart，http / socket_io_client，webview_flutter（Turnstile），photo_view 等。
- **状态管理**：**只使用 `setState` + Hive**。不要引入 Riverpod / BLoC / GetX / MobX 等新依赖。
- **本地缓存**：Hive（`PostStorage`、`AvatarStorage`、`DeviceCredentialStore`、`BindingCache` 等）。
- **后端通信**：`ApiService` 提供静态方法；`SessionService` 负责 session 激活与保活。

## 2. 目录结构

```
lib/
  app.dart              # 应用入口、主题、locale（中文）
  app_navigator.dart    # 根 NavigatorKey
  main.dart
  config/               # 配置常量
  models/               # 数据模型（Post、Comment、PostMeta 等）
  pages/                # 页面
    square/             # 广场主页
    search/             # 搜索页
    post/               # 发帖页
    account/            # 用户、注册、登录、设备绑定、账户切换
    favorites/          # 收藏（占位）
    messages/           # 消息（占位）
    settings/           # 设置相关
  services/             # API、session、存储、时区、PoW、Turnstile 等
  theme/                # 颜色、尺寸、页面专属主题文件
  widgets/              # 通用组件（AppAppBar、AppBottomNav、ImageOverlay、PostCard 等）
```

## 3. 设计与交互约定

### 3.1 导航

- 应用主壳为 `MainShell`，使用 `IndexedStack` + 底部导航栏（广场 / 收藏 / 消息 / 我的）。
- 子页面统一通过 `topDownRoute` / `bottomUpRoute`（定义于 `pages/settings/settings_navigation.dart`）进入：
  - `topDownRoute`：常规子页面从上滑入。
  - `bottomUpRoute`：登录/注册等从底部滑入。
- 页面返回优先使用 `AppAppBar`（统一左侧返回箭头 + 居中标题）。

### 3.2 状态栏 / 安全栏颜色

**状态栏颜色必须和「紧挨在状态栏下方的元素背景」一致**，避免顶部出现异色条：

- 使用 `AppAppBar` / `AppScaffold` 的页面：已在 `AppAppBar` 内通过 `AnnotatedRegion<SystemUiOverlayStyle>` 自动把状态栏设为 `colors.common.drawerHeaderBg`。
- `SquarePage`：状态栏设为 `AppSquareTopBarTheme.backgroundLight/Dark`。
- `SearchPage`：状态栏设为 `colors.common.surface`（搜索栏/筛选面板背景）。
- `UserPage`：状态栏设为页面显式背景 `#F2F2F2` / `#111111`。
- 若新增页面顶部有独立背景色，请在页面根节点包 `AnnotatedRegion<SystemUiOverlayStyle>`。

### 3.3 主题与尺寸

- **颜色**：使用 `Theme.of(context).extension<AppColors>()!` 获取 `AppColors`，再按语义取色（如 `colors.common.surface`、`colors.postCard.title`）。
- **尺寸**：通用尺寸放 `lib/theme/app_dimens.dart`；页面/组件专属尺寸放到独立文件：
  - `app_search_theme.dart`
  - `app_square_top_bar_theme.dart`
  - `app_square_refresh_theme.dart`
  - `app_dimens_register.dart`
  - `app_dimens_accent.dart`
  - `app_bottom_nav_theme.dart`
- 不要硬编码颜色和尺寸，优先使用主题常量。

### 3.4 通用组件

新增页面/交互优先复用现有组件：

- `AppAppBar` / `AppScaffold`：统一顶栏和页面外壳。
- `AppBottomNav`：底部导航栏。
- `AppBottomSheet`：底部操作菜单 / 选择器。
- `AppSnackBar` / `showAppToast`：统一轻提示。
- `AppLoadingIndicator` / `AppLoadingCenter`：加载状态。
- `AppEmptyState` / `AppErrorState`：空/错误状态。
- `AppConfirmDialog`：确认对话框。
- `ImageOverlay`：全屏图片查看（含保存/分享）。

### 3.5 图片与媒体

- 帖子流小图：使用 `PostCard` 内的 `ThumbnailImage`。
  - 网格图默认 `BoxFit.cover`（裁切填充）。
  - 单张图使用 `BoxFit.contain`（完整显示）。
- 全屏预览：`ImageOverlay` 使用 `PhotoViewGalleryPageOptions.customChild`。
- 发帖图片预览：`BoxFit.cover` 小缩略图，支持单张删除。
- 不要额外引入图片处理依赖；已有 `image_picker` / `file_picker` / `gal` / `share_plus`。

### 3.6 反馈与触觉

关键操作加 `HapticFeedback.lightImpact()` / `mediumImpact()`：

- 按钮点击、发布、评论、登录、切换账户、收藏/举报菜单等。
- 错误/成功提示统一用 `AppSnackBar` / `showAppToast`，避免直接使用 `ScaffoldMessenger`。

## 4. 高频页面特殊约定

### 4.1 SquarePage（广场）

- 顶部分类栏背景色 `AppSquareTopBarTheme.backgroundLight/Dark`。
- 分类过滤通过后端 `category` 参数实现，默认 `null` 表示全部。
- 下拉刷新通过自定义 `LeftPullScrollPhysics` + 小球动画实现。

### 4.2 PostCard（帖子卡片）

- 操作菜单使用 `showAppActionsSheet`（底部 Sheet），不要恢复旧的 Overlay 菜单。
- 长文展开使用旋转 SVG `expand_icon.svg`。
- 评论展开使用 `+/-` SVG 按钮。
- **评论输入栏对齐目标**：帖子最底部（有回复时为回复展示区 `_commentSectionKey` 底部，无回复时为 `_dateRowKey` 底部），自动平滑定位到输入栏上方。

### 4.3 PostCreatePage（发帖页）

- 顶部自定义栏：左侧返回箭头，右侧发布按钮。
- 标题/内容使用自定义 Floating Label 输入卡片。
- 支持图片上传、单张删除、附件、署名切换。

### 4.4 UserPage（我的）

- 页面整体背景为 `#F2F2F2`（light）/ `#111111`（dark）。
- 顶部个人资料卡片 + 下方栏目（账户安全 / 应用 / 账户管理）作为一个整体居中，偏移量见 `AppDimens.userSectionsVOffset / HOffset`。

## 5. 代码规范

- **语言**：用户交互文本全部中文；代码注释可中文。
- **格式化**：保持现有风格，长参数列表可换行对齐。
- **私有成员**：类内部私有用 `_` 前缀。
- **不要引入新依赖**；如确实需要，必须先征得用户同意。
- **避免大改架构**：继续 `setState` + Hive；不要上状态管理框架。
- **lint**：保持 `flutter analyze --no-pub` 无问题。

## 6. 工作流

1. 修改前先快速 `flutter analyze --no-pub` 确认基线干净。
2. 改动尽量小、聚焦；多页面改动拆成多次提交。
3. 每次改动后运行 `flutter analyze --no-pub`。
4. 用 `git add -A && git commit -m "..."` 提交，commit message 用英文小写（`type(scope): description`）。
5. 页面级改动需要 `flutter run` 后按 `R` 热重启才能生效。
6. 不要自行 `git push` / `git reset` / `git rebase`。

## 7. 验证清单

每次涉及广场/发帖/评论/登录/设置等高频路径后，建议手动验证：

- 启动 → 底部导航切换
- 广场下拉刷新 / 分类切换
- 点击帖子图片预览、左右滑动、保存
- 发帖：输入、选图、删除、发布 → 返回广场默认分类并刷新
- 评论展开 / 回复输入栏对齐
- 用户页 / 设置页进入与返回
- 注册/登录流程（Turnstile / PoW）
