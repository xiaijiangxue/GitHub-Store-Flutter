# GitHub-Store-Flutter 全面代码审查 — 问题清单

> 审查范围：全部 91 个 Dart 源文件，12 个功能模块
> 审查日期：2026-04-26

---

## 一、严重级别：功能完全不可用

### BUG-001：搜索页面是空壳（硬编码假数据）
- **文件**：`lib/features/search/presentation/search_screen.dart`
- **问题**：搜索功能完全没有接入任何 API。`_performSearch()` 方法使用 `Future.delayed(1秒)` 模拟网络请求，返回硬编码的假数据 `'$query/result-$index'`。用户输入任何搜索词都只能看到假结果。
- **影响**：搜索功能完全不可用

### BUG-002：GitHub 登录页面无法访问
- **文件**：`lib/core/router/app_router.dart`、`lib/features/profile/presentation/profile_screen.dart`
- **问题**：`AuthScreen` 存在但未在 GoRouter 中注册路由。Profile 页面的"Sign in with GitHub"按钮执行 `context.go('/profile/auth')`，但该路由不存在，会显示"Page Not Found"错误页面。
- **影响**：用户无法登录 GitHub

### BUG-003：Profile 页面多个按钮导航到不存在的路由
- **文件**：`lib/features/profile/presentation/profile_screen.dart`
- **问题**：
  - 第 53 行：`context.go('/profile/auth')` — 路由不存在
  - 第 92 行：`context.go('/download/_placeholder')` — 路径不匹配 `/download/:owner/:repo/:tag`
- **影响**：点击 Sign in、My Downloads 按钮都会显示错误页面

### BUG-004：Trending 错误重试按钮无效
- **文件**：`lib/features/home/presentation/widgets/trending_section.dart`
- **问题**：`_buildErrorState` 中的 Retry 按钮的 `onPressed` 回调是空的 `() {}`，点击无任何反应。
- **影响**：加载失败后无法重试

---

## 二、严重级别：功能部分不可用

### BUG-005：Settings 语言切换不生效
- **文件**：`lib/features/settings/presentation/settings_screen.dart`、`lib/app.dart`
- **问题**：设置页面的语言选择器会更新 `SettingsModel.language`，但 `app.dart` 中的 locale 解析逻辑没有读取 `settingsProvider` 的语言设置，导致切换语言后 UI 不会变化。
- **影响**：语言切换功能无效

### BUG-006：首页 See All 传递的 section 参数被忽略
- **文件**：`lib/features/home/presentation/home_screen.dart`、`lib/features/search/presentation/search_screen.dart`
- **问题**：Trending/Hot/Popular 的 See All 按钮传递 `extra: {'section': 'trending'}`，但 SearchScreen 不读取 `extra` 参数。且搜索本身是假数据（BUG-001）。
- **影响**：See All 功能无效

### BUG-007：Details 页面 Topic 标签点击搜索不生效
- **文件**：`lib/features/details/presentation/details_screen.dart`
- **问题**：Topic 点击使用 `context.push(AppRoute.search.path, extra: {'q': 'topic:$topic'})`，但 SearchScreen 只读取 `state.uri.queryParameters['q']`，不读取 `extra`。
- **影响**：点击 Topic 标签无法跳转搜索

### BUG-008：搜索结果点击使用 go 而非 push
- **文件**：`lib/features/search/presentation/search_screen.dart` 第 201 行
- **问题**：使用 `context.go()` 导航到详情页，会替换搜索页面，导致从详情页返回时不会回到搜索结果。
- **影响**：搜索→详情→返回，无法回到搜索结果

### BUG-009：Starred 页面 Sign-in 导航异常
- **文件**：`lib/features/starred/presentation/starred_screen.dart` 第 102 行
- **问题**：使用 `context.push('/profile')` 导航到 shell 内的 tab，从 shell 外 push 进 shell 可能导致底部导航栏消失。
- **影响**：未登录状态下的 star 页面交互异常

---

## 三、严重级别：数据问题

### BUG-010：translation_service.dart 的 MD5 实现是假的
- **文件**：`lib/core/translation/translation_service.dart` 第 592-602 行
- **问题**：`_md5Hash()` 实际实现的是 DJB2 哈希，不是 MD5。虽然 import 了 `package:crypto/crypto.dart`，但从未使用。导致所有有道翻译 API 调用签名无效，翻译功能完全不可用。
- **影响**：有道翻译完全失效

### BUG-011：suggestLocalizedReadme 循环只执行一次
- **文件**：`lib/core/translation/translation_service.dart` 第 196-217 行
- **问题**：`return` 在循环体内部，导致只检查第一个语言变体就直接返回了。
- **影响**：本地化 README 推荐功能无法找到最佳匹配

### BUG-012：_filterSeen 在三个 Notifier 中都是空实现
- **文件**：`lib/features/home/presentation/providers/home_provider.dart`
- **问题**：`HomeTrendingNotifier`、`HomeHotReleasesNotifier`、`HomePopularNotifier` 的 `_filterSeen()` 方法都直接返回输入，"隐藏已看过的仓库"功能不工作。
- **影响**：Hide Seen 功能无效

### BUG-013：搜索排序 "Recently Updated" 无效
- **文件**：`lib/features/search/presentation/providers/search_provider.dart`
- **问题**：`_mapSortField` 中 `'updated'` 选项匹配到 default 分支，映射为 `'best_match'` 而不是 `'updated'`。
- **影响**：选择"最近更新"排序无效果

### BUG-014：下载历史永远不更新
- **文件**：`lib/features/download/presentation/providers/download_provider.dart`
- **问题**：`downloadHistoryProvider` 只在初始化时加载一次，`_refreshHistory()` 方法体为空。下载完成后历史列表不会更新。
- **影响**：下载历史功能不工作

### BUG-015：下载 Release 使用独立 Dio 实例
- **文件**：`lib/features/details/data/details_repository.dart` 第 252 行
- **问题**：`downloadRelease` 创建独立的 `Dio()` 实例下载文件，绕过了全局的 auth interceptor 和 retry logic。私有仓库的 release 下载会失败。
- **影响**：私有仓库下载失败

---

## 四、严重级别：导航/UI 问题

### BUG-016：DeepLinkScreen 没有注册路由
- **文件**：`lib/core/router/app_router.dart`
- **问题**：`deeplink_screen.dart` 存在但没有对应的 GoRoute。整个文件是不可达代码。
- **影响**：Deep Link 功能不可用

### BUG-017：多个页面使用 Navigator.of(context).pop() 而非 context.pop()
- **文件**：`lib/features/installer/presentation/installer_screen.dart` 第 541 行、`lib/features/auth/presentation/auth_screen.dart` 第 156 行
- **问题**：与 GoRouter 的 `context.pop()` 不一致，在 shell route 中可能导致异常的返回行为。
- **影响**：从 shell 外部页面返回时可能不正常

### BUG-018：Starred/RecentlyViewed 页面导航方式不一致
- **文件**：`lib/features/starred/presentation/starred_screen.dart`、`lib/features/recently_viewed/presentation/recently_viewed_screen.dart`
- **问题**：使用手动 `.replaceAll(':owner', ...)` 拼接路由，而非使用 `AppRoute.withParams()` 辅助方法。
- **影响**：维护性差，容易出错

---

## 五、严重级别：内存/性能问题

### BUG-019：Settings 页面 TextEditingController 泄漏
- **文件**：`lib/features/settings/presentation/settings_screen.dart` 第 217-230 行
- **问题**：Youdao App Key 的 TextField 每次重建都创建新的 `TextEditingController`，旧 controller 不会 dispose，造成内存泄漏。
- **影响**：长时间使用 Settings 页面会导致内存增长

### BUG-020：app.dart 每秒轮询 Settings
- **文件**：`lib/app.dart` 第 163-198 行
- **问题**：使用 `Stream.periodic(1秒)` 轮询 Settings 变化，而 Riverpod 本身提供了 `ref.listen()` 响应式机制。
- **影响**：不必要的 CPU 消耗

### BUG-021：app.dart 剪贴板每 3 秒轮询
- **文件**：`lib/app.dart`
- **问题**：剪贴板监控每 3 秒检查一次，在桌面端持续运行。
- **影响**：持续的 CPU 消耗

---

## 六、严重级别：Provider/架构问题

### BUG-022：authTokenProvider 名称冲突
- **文件**：`lib/features/auth/presentation/providers/auth_provider.dart`、`lib/features/settings/presentation/providers/theme_provider.dart`
- **问题**：两个文件都定义了 `authTokenProvider`，一个 `FutureProvider` 一个 `StateProvider`。根据 import 顺序不同，可能产生难以调试的问题。
- **影响**：Provider 查找可能返回错误的值

### BUG-023：api_client.dart 的 customBaseUrl 参数无效
- **文件**：`lib/core/network/api_client.dart` 第 332 行
- **问题**：`_applyBaseUrl` 将 customBaseUrl 放入 `options.extra` 字典，但没有任何 interceptor 读取这个值来覆盖 baseUrl。当前代码恰好都使用默认 baseUrl 所以没暴露问题。
- **影响**：如果需要调用其他 API 域名会静默失败

### BUG-024：Rate Limit 处理会阻塞事件循环
- **文件**：`lib/core/network/api_client.dart` 第 107 行
- **问题**：`_handleRateLimit` 使用 `Future.delayed` 阻塞等待 rate limit 重置，可能长达数分钟。
- **影响**：触发 rate limit 后整个 UI 可能冻结

### BUG-025：favorites_repository 使用 hashCode.abs() 作为 ID
- **文件**：`lib/features/favorites/data/favorites_repository.dart` 第 125 行
- **问题**：使用 `fullName.hashCode.abs()` 作为仓库 ID，存在哈希碰撞风险，可能导致不同仓库数据互相覆盖。
- **影响**：数据损坏风险

---

## 七、严重级别：UI/UX 问题

### BUG-026：Notifications 按钮是空操作
- **文件**：`lib/features/home/presentation/home_screen.dart` 第 81-87 行
- **问题**：显示 "Notifications coming soon!" snackbar

### BUG-027：Sponsor 按钮是空操作
- **文件**：`lib/features/profile/presentation/profile_screen.dart` 第 105-111 行
- **问题**：显示 "Sponsor page coming soon!" snackbar

### BUG-028：代理测试连接是假的
- **文件**：`lib/features/settings/presentation/settings_screen.dart` 第 703-723 行
- **问题**：`_testProxyConnection()` 固定延迟 1 秒后显示"连接成功"，不管代理配置如何。
- **影响**：用户被误导以为代理配置正确

### BUG-029：app_theme.dart 无意义的三元表达式
- **文件**：`lib/core/theme/app_theme.dart` 第 386、409 行
- **问题**：`isDark ? Color(0xFF8B949E) : Color(0xFF8B949E)` 两个分支颜色相同。
- **影响**：暗色/亮色模式下某些颜色不区分

### BUG-030：Deep Link Handler 是空操作
- **文件**：`lib/main.dart` 第 322-335 行
- **问题**：找到 deep link URL 后只打印 debug 日志，不做任何处理。
- **影响**：Deep Link 功能不可用

---

## 修复优先级排序

| 优先级 | Bug ID | 描述 |
|--------|--------|------|
| P0 | BUG-001 | 搜索页面接入真实 API |
| P0 | BUG-002 | Auth 路由注册 + 登录可达 |
| P0 | BUG-003 | Profile 页面修复导航路径 |
| P0 | BUG-004 | Trending Retry 按钮生效 |
| P0 | BUG-005 | 语言切换生效 |
| P1 | BUG-007 | Topic 搜索修复 |
| P1 | BUG-008 | 搜索→详情使用 push |
| P1 | BUG-009 | Starred 页面登录导航修复 |
| P1 | BUG-013 | 搜索排序修复 |
| P1 | BUG-019 | TextEditingController 泄漏修复 |
| P1 | BUG-022 | authTokenProvider 冲突修复 |
| P1 | BUG-028 | 代理测试连接真实实现 |
| P2 | BUG-006 | See All 传递参数修复 |
| P2 | BUG-010 | MD5 哈希修复 |
| P2 | BUG-012 | _filterSeen 实现或移除 |
| P2 | BUG-014 | 下载历史刷新 |
| P2 | BUG-020 | Settings 轮询改为 ref.listen |
| P3 | BUG-011, BUG-015-018, BUG-021, BUG-023-030 | 其他低优先级 |
