# 树通 Flutter UI/UX 优化计划（最终版）

## 项目现状

- **应用类型**：学生匿名论坛（树洞），核心功能为浏览帖子广场、发帖（图片/附件）、评论、用户注册/登录、设备绑定、账户切换、设置。
- **技术栈**：Flutter 3.x，手动 `setState` 状态管理，Hive 本地缓存，http/socket_io_client 通信。
- **当前结构**：
  - 单首页 `SquarePage` + 左侧抽屉导航。
  - 发帖、用户、设置等通过 `Navigator.push` 进入，转场方向不统一（上滑/下滑/底部 Sheet 混用）。
  - 帖子卡片、评论输入、图片查看器、注册流程均为自定义实现。

## 核心问题诊断

1. **导航结构不现代**：首页仅依赖左侧抽屉，没有底部导航栏；抽屉内存在多个"没做"占位项。
2. **帖子广场与卡片交互粗糙**：操作菜单通过两点按钮弹出自定义 Overlay；长文展开使用右上角旋转 SVG；评论展开使用 `+/-` SVG 图标。
3. **发帖页输入体验不流畅**：自定义 Floating Label 复杂；内容区最大高度仅 200；返回按钮为向上箭头；图片预览缺少单张删除。
4. **注册/登录页体验欠佳**：绝对定位布局适配性差；登录令牌输入掩码逻辑复杂。
5. **设置入口分散**：设置从抽屉/Sheet 进入，不符合现代 App"用户页 → 设置"的层级习惯。
6. **反馈与状态处理不统一**：错误提示形式多样；加载状态统一使用 GIF；缺少空状态插画/提示；缺少触觉反馈。

## 优化目标

在不引入新依赖、不大改状态管理的前提下：

- **让用户更快上手**：引入底部导航栏，统一四个核心模块入口；统一返回手势与 AppBar。
- **用得更流畅**：优化输入、评论、发帖的高频操作路径，减少步骤和打断。
- **提升现代感**：统一转场、AppBar、按钮、反馈，使用底部 Sheet/选择器、文字按钮等现代交互模式。
- **保留品牌感知**：底部导航不抢占视觉中心，帖子广场仍是主体内容。

## 推荐方案

### 一、底部导航栏（核心改造）

**移除左侧抽屉（Drawer）**，新增四个底部 Tab：

1. **主页** — 现有 `SquarePage` 的广场贴文流。
2. **搜索** — 新建占位页面（保留 UI 入口，后续可接入搜索 API）。
3. **发布** — 点击后进入 `PostCreatePage`，发布成功返回主页并刷新。
4. **用户** — 个人中心页，内聚"用户信息 / 设置 / 设备绑定 / 账户切换"入口。

设计约束：

- 底部导航栏高度、图标、标签字号均保持克制，背景与页面背景一致或使用轻微分割线，不抢夺贴文视觉中心。
- 选中态使用主题绿色（`AppColors.common.green`），未选中态使用低对比灰色。
- 在滚动贴文时，底部导航栏可跟随发布按钮逻辑**轻微下沉隐藏**（可选），向上滑动时恢复，进一步减少视觉干扰。
- 设置从抽屉中移除，统一收敛到"用户"页内的设置行。

### 二、统一导航与返回

- 所有子页面统一使用左侧返回箭头（`arrow_back` / `arrow_back_ios`）+ 居中标题的 AppBar。
- 统一子页面为底部上滑进入（`bottomUpRoute`），与底部导航和系统返回手势一致。
- 左侧抽屉完全移除；低频入口（如关于/帮助）后续可在用户页或设置中补充。

### 三、帖子卡片现代化

- **操作菜单**：两点按钮点击后弹出 `BottomSheet` 选项（收藏 / 举报 / 复制 / 分享）。
- **长文展开**：改为卡片底部的"展开全文"文字按钮，带渐变截断提示；收起使用"收起"。
- **评论展开**：
  - 移除 `+/-` SVG 图标。
  - 改为"展开 X 条回复"文字按钮，每次固定展开有限条数（每次 3 条），避免一次展开过多占满屏幕。
  - 到达末尾后按钮变为"收起回复"。
- **评论输入**：
  - 未登录时底部输入栏显示"登录后评论"，点击跳转注册。
  - 已登录时保持底部固定输入栏，优化键盘同步与发送按钮状态。

### 四、发帖页优化

- 顶部返回改为标准返回箭头，右侧保留发布按钮。
- 标题/内容输入区改用标准 `TextField` + `InputDecoration`（`labelText`/`hintText`），移除复杂自定义 Floating Label。
- 内容区默认高度提升并支持自适应扩展，减少"展开"按钮依赖；保留全屏编辑作为可选入口。
- 图片预览支持单张删除（每张缩略图右上角小 ×）。

### 五、注册/登录页优化

- 将绝对定位改为基于 `Column` + `Spacer` 的响应式布局。
- **保留**检测阶段强制等待时间，避免闪烁。
- 登录令牌输入使用标准 `TextField`，提供"粘贴"按钮和"显示/隐藏"切换。

### 六、用户页与设置收敛

- 用户页新增设置入口行，点击进入设置列表页。
- 设置列表页包含：用户设置、颜色模式、设备绑定、账户切换等分组。
- 颜色模式使用底部选择器（`showModalBottomSheet` + `RadioListTile`）。

### 七、统一反馈组件

- 新增可复用组件：`AppLoadingIndicator`、`AppEmptyState`、`AppErrorState`、`AppSnackBar`。
- 在关键操作（发帖、评论、登录、切换账户）添加 `HapticFeedback.lightImpact()`/`mediumImpact()`。

## 文件改动清单

### 新增文件

- `lib/widgets/app_bottom_nav.dart`：底部导航栏组件。
- `lib/widgets/app_app_bar.dart`：统一 AppBar。
- `lib/widgets/app_bottom_sheet.dart`：统一底部选择器/操作菜单。
- `lib/widgets/app_loading_indicator.dart`：统一加载指示器。
- `lib/widgets/app_empty_state.dart`：空状态组件。
- `lib/widgets/app_error_state.dart`：错误状态组件。
- `lib/widgets/app_snackbar.dart`：统一 SnackBar 辅助。
- `lib/pages/search/search_page.dart`：搜索占位页。
- `lib/pages/main_shell.dart`：底部导航 + 各 Tab 内容的外壳。

### 修改文件

- `lib/app.dart`：配置统一页面转场（`pageTransitionsTheme`）、主题细节；根页面改为 `MainShell`。
- `lib/pages/square/square_page.dart`：
  - 作为底部导航的"主页" Tab 内容。
  - **移除抽屉（Drawer）**。
  - 优化加载/错误/空状态展示。
- `lib/widgets/post_card.dart`：
  - 操作菜单改为 BottomSheet。
  - 长文/评论展开改为文字按钮，评论每次展开固定条数。
  - 评论输入栏优化未登录态。
- `lib/pages/post/post_create_page.dart`：
  - 顶部栏统一。
  - 输入区简化。
  - 图片单张删除。
- `lib/pages/account/register_page.dart`：响应式布局、登录输入优化；保留强制等待。
- `lib/pages/account/user_page.dart`：统一 AppBar、新增设置入口、改名交互优化。
- `lib/pages/settings/settings_navigation.dart`：统一子页面转场和 AppBar。
- `lib/pages/settings/color_mode_page.dart`：改为底部选择器调用。
- `lib/pages/settings/user_settings_page.dart`：接入新设置列表。
- `lib/pages/account/device_binding_page.dart` / `switch_account_page.dart`：统一 AppBar、反馈组件。
- `lib/theme/app_dimens.dart`：补充新组件所需尺寸常量。

## 风险与回退

- **风险**：改造涉及导航结构和多个高频页面，可能引入布局或手势回归。
- **回退**：所有改动均为 Dart 文件修改，不涉及原生代码；若需要，可通过 `git checkout` 回退。
- **缓解**：每完成一个页面改动即运行 `flutter analyze` 和页面级热重载验证。

## 验证方式

1. `flutter analyze` 无错误。
2. `flutter build apk --debug` / `flutter build ios --debug` 成功。
3. 关键路径手动验证：启动 → 底部导航切换 → 广场下拉刷新 → 点击发布 → 输入/选择图片/发布 → 评论展开/回复 → 进入用户/设置 → 返回。

## 备注

- 不引入新依赖（如 Riverpod、GetX），保持现有 `setState` + Hive 架构。
- 保留现有绿色主题和帖子卡片视觉风格，避免用户感到"换了一个 App"。
- 搜索页先作为占位页面实现，仅保留 UI 入口，后续可接入搜索 API。
