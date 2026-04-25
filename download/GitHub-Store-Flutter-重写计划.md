# GitHub-Store Flutter Desktop 重写计划

> **目标**: 用 Flutter Desktop 完整重写 [OpenHub-Store/GitHub-Store](https://github.com/OpenHub-Store/GitHub-Store)
> **原始项目**: Kotlin Multiplatform + Compose Multiplatform, 54,000 行代码, 33 模块
> **目标项目**: Flutter 3.x + Dart, 桌面端 (Windows/macOS/Linux)
> **目标体积**: 15–25 MB (原版 200+ MB, 减少 90%)

---

## 一、技术选型

| 层面 | 原版 (Kotlin) | 新版 (Flutter) |
|------|-------------|---------------|
| 语言 | Kotlin 2.3.10 | Dart 3.x |
| UI 框架 | Compose Multiplatform | Flutter (Material 3) |
| 状态管理 | ViewModel + StateFlow | Riverpod 2.x |
| 依赖注入 | Koin 4.x | Riverpod (内置) |
| 网络请求 | Ktor 3.x + OkHttp | Dio |
| 本地数据库 | Room 2.8 | Drift (SQLite) |
| 序列化 | kotlinx-serialization | json_serializable + freezed |
| 路由导航 | Navigation Compose | GoRouter |
| Markdown | multiplatform-markdown-renderer | flutter_markdown |
| 图片加载 | Coil 3 + Landscapist | cached_network_image |
| 主题系统 | Material You + 自定义 | Material 3 + 自定义 |
| 平台通道 | expect/actual (KMP) | dart:io + Platform + process_run |
| 国际化 | Android Resources | flutter_localizations + intl |
| Deep Link | Platform-specific | uni_links / desktop_deep_link |
| 桌面打包 | Compose Desktop nativeDistributions | Flutter Desktop build |

### 目标体积预估

| 组件 | 预估大小 |
|------|---------|
| Flutter 引擎 (Skia) | ~8–12 MB |
| 应用代码 + 依赖 | ~3–8 MB |
| 资源 (字体/图标) | ~2–4 MB |
| **总计** | **~15–25 MB** |

---

## 二、项目结构

```
github_store_flutter/
├── lib/
│   ├── main.dart                          # 应用入口
│   ├── app.dart                           # MaterialApp + GoRouter
│   │
│   ├── core/                              # 核心基础设施层
│   │   ├── constants/
│   │   │   ├── api_constants.dart         # API 端点常量
│   │   │   ├── app_constants.dart         # 应用常量
│   │   │   └── platform_constants.dart    # 平台相关常量
│   │   ├── errors/
│   │   │   ├── exceptions.dart            # 自定义异常
│   │   │   └── failures.dart              # 失败类型
│   │   ├── extensions/
│   │   │   ├── string_extensions.dart
│   │   │   ├── datetime_extensions.dart
│   │   │   └── context_extensions.dart
│   │   ├── network/
│   │   │   ├── api_client.dart            # Dio 客户端配置
│   │   │   ├── github_store_api.dart      # GitHub Store 后端 API
│   │   │   ├── github_api.dart            # GitHub API (认证)
│   │   │   ├── translate_api.dart         # 翻译 API (Google/有道)
│   │   │   ├── interceptors/
│   │   │   │   ├── auth_interceptor.dart  # Token 注入
│   │   │   │   ├── rate_limit_interceptor.dart
│   │   │   │   └── error_interceptor.dart
│   │   │   └── proxy/
│   │   │       ├── proxy_config.dart      # 代理配置模型
│   │   │       └── proxy_manager.dart     # 三通道代理管理
│   │   ├── cache/
│   │   │   ├── memory_cache.dart          # 内存 LRU 缓存
│   │   │   ├── database_cache.dart        # 数据库持久缓存
│   │   │   └── cache_manager.dart         # 两级缓存管理器
│   │   ├── database/
│   │   │   ├── app_database.dart          # Drift 数据库定义
│   │   │   ├── tables/
│   │   │   │   ├── installed_apps.dart
│   │   │   │   ├── favorites.dart
│   │   │   │   ├── recently_viewed.dart
│   │   │   │   ├── search_history.dart
│   │   │   │   ├── pending_installs.dart
│   │   │   │   ├── download_cache.dart
│   │   │   │   └── telemetry_events.dart
│   │   │   └── daos/
│   │   │       ├── installed_app_dao.dart
│   │   │       ├── favorite_dao.dart
│   │   │       ├── recently_viewed_dao.dart
│   │   │       └── search_history_dao.dart
│   │   ├── platform/
│   │   │   ├── platform_service.dart      # 平台服务抽象接口
│   │   │   ├── windows_platform.dart      # Windows 实现
│   │   │   ├── macos_platform.dart        # macOS 实现
│   │   │   ├── linux_platform.dart        # Linux 实现
│   │   │   ├── installer_service.dart     # 安装器服务接口
│   │   │   ├── distro_detector.dart       # Linux 发行版检测
│   │   │   ├── arch_detector.dart         # CPU 架构检测
│   │   │   └── notification_service.dart  # 桌面通知
│   │   ├── auth/
│   │   │   ├── auth_service.dart          # GitHub OAuth Device Flow
│   │   │   ├── token_storage.dart         # Token 加密存储
│   │   │   └── auth_state.dart            # 认证状态
│   │   ├── utils/
│   │   │   ├── asset_matcher.dart         # 安装包智能匹配
│   │   │   ├── markdown_preprocessor.dart # Markdown 预处理
│   │   │   ├── url_parser.dart            # GitHub URL 解析
│   │   │   ├── file_utils.dart            # 文件大小格式化等
│   │   │   └── debouncer.dart
│   │   └── theme/
│   │       ├── app_theme.dart             # 主题定义 (6色 x 3模式)
│   │       ├── app_colors.dart            # 颜色方案
│   │       └── app_typography.dart        # 字体配置
│   │
│   ├── features/                          # 功能模块层
│   │   ├── home/
│   │   │   ├── data/
│   │   │   │   ├── home_repository.dart
│   │   │   │   └── home_api.dart
│   │   │   ├── domain/
│   │   │   │   └── home_models.dart
│   │   │   └── presentation/
│   │   │       ├── home_screen.dart
│   │   │       ├── home_provider.dart
│   │   │       └── widgets/
│   │   │           ├── trending_section.dart
│   │   │           ├── hot_release_section.dart
│   │   │           ├── popular_section.dart
│   │   │           └── topic_category_section.dart
│   │   │
│   │   ├── search/
│   │   │   ├── data/
│   │   │   │   ├── search_repository.dart
│   │   │   │   └── search_api.dart
│   │   │   ├── domain/
│   │   │   │   └── search_models.dart
│   │   │   └── presentation/
│   │   │       ├── search_screen.dart
│   │   │       ├── search_provider.dart
│   │   │       └── widgets/
│   │   │           ├── search_filters.dart
│   │   │           ├── language_filter_sheet.dart
│   │   │           └── search_history_chips.dart
│   │   │
│   │   ├── details/
│   │   │   ├── data/
│   │   │   │   ├── details_repository.dart
│   │   │   │   └── details_api.dart
│   │   │   ├── domain/
│   │   │   │   └── details_models.dart
│   │   │   └── presentation/
│   │   │       ├── details_screen.dart
│   │   │       ├── details_provider.dart
│   │   │       └── widgets/
│   │   │           ├── repo_header.dart
│   │   │           ├── repo_stats.dart
│   │   │           ├── owner_card.dart
│   │   │           ├── readme_section.dart
│   │   │           ├── release_browser.dart
│   │   │           ├── asset_list.dart
│   │   │           ├── install_button.dart
│   │   │           └── attestation_badge.dart
│   │   │
│   │   ├── download/
│   │   │   ├── data/
│   │   │   │   ├── download_repository.dart
│   │   │   │   └── download_manager.dart
│   │   │   ├── domain/
│   │   │   │   └── download_models.dart
│   │   │   └── presentation/
│   │   │       ├── download_provider.dart
│   │   │       └── widgets/
│   │   │           ├── download_progress_tile.dart
│   │   │           └── download_notification.dart
│   │   │
│   │   ├── installer/
│   │   │   ├── data/
│   │   │   │   ├── installer_repository.dart
│   │   │   │   └── installer_service_impl.dart
│   │   │   └── presentation/
│   │   │       └── install_provider.dart
│   │   │
│   │   ├── apps/
│   │   │   ├── data/
│   │   │   │   ├── apps_repository.dart
│   │   │   │   └── update_checker.dart
│   │   │   ├── domain/
│   │   │   │   └── apps_models.dart
│   │   │   └── presentation/
│   │   │       ├── apps_screen.dart
│   │   │       ├── apps_provider.dart
│   │   │       ├── link_app_screen.dart
│   │   │       └── export_import_screen.dart
│   │   │
│   │   ├── favorites/
│   │   │   ├── data/
│   │   │   │   └── favorites_repository.dart
│   │   │   ├── domain/
│   │   │   │   └── favorite_models.dart
│   │   │   └── presentation/
│   │   │       ├── favorites_screen.dart
│   │   │       └── favorites_provider.dart
│   │   │
│   │   ├── starred/
│   │   │   ├── data/
│   │   │   │   └── starred_repository.dart
│   │   │   ├── domain/
│   │   │   │   └── starred_models.dart
│   │   │   └── presentation/
│   │   │       ├── starred_screen.dart
│   │   │       └── starred_provider.dart
│   │   │
│   │   ├── recently_viewed/
│   │   │   ├── data/
│   │   │   │   └── recently_viewed_repository.dart
│   │   │   └── presentation/
│   │   │       ├── recently_viewed_screen.dart
│   │   │       └── recently_viewed_provider.dart
│   │   │
│   │   ├── dev_profile/
│   │   │   ├── data/
│   │   │   │   └── dev_profile_repository.dart
│   │   │   ├── domain/
│   │   │   │   └── dev_profile_models.dart
│   │   │   └── presentation/
│   │   │       ├── dev_profile_screen.dart
│   │   │       ├── dev_profile_provider.dart
│   │   │       └── widgets/
│   │   │           └── dev_repo_list.dart
│   │   │
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   └── auth_repository.dart
│   │   │   ├── domain/
│   │   │   │   └── auth_models.dart
│   │   │   └── presentation/
│   │   │       ├── auth_screen.dart
│   │   │       ├── auth_provider.dart
│   │   │       └── widgets/
│   │   │           └── device_flow_dialog.dart
│   │   │
│   │   ├── profile/
│   │   │   └── presentation/
│   │   │       ├── profile_screen.dart
│   │   │       ├── profile_provider.dart
│   │   │       └── widgets/
│   │   │           ├── storage_card.dart
│   │   │           └── sponsor_card.dart
│   │   │
│   │   ├── settings/
│   │   │   ├── data/
│   │   │   │   └── settings_repository.dart
│   │   │   ├── domain/
│   │   │   │   └── settings_models.dart
│   │   │   └── presentation/
│   │   │       ├── settings_screen.dart
│   │   │       ├── settings_provider.dart
│   │   │       └── widgets/
│   │   │           ├── appearance_section.dart
│   │   │           ├── language_section.dart
│   │   │           ├── proxy_section.dart
│   │   │           ├── translation_section.dart
│   │   │           ├── installation_section.dart
│   │   │           ├── storage_section.dart
│   │   │           └── about_section.dart
│   │   │
│   │   └── deeplink/
│   │       ├── data/
│   │       │   └── deeplink_repository.dart
│   │       └── presentation/
│   │           └── deeplink_handler.dart
│   │
│   ├── shared/                            # 共享 UI 组件层
│   │   ├── widgets/
│   │   │   ├── repository_card.dart       # 仓库卡片
│   │   │   ├── expressive_card.dart       # Material You 表现力卡片
│   │   │   ├── loading_indicator.dart
│   │   │   ├── error_view.dart
│   │   │   ├── empty_state.dart
│   │   │   ├── scrollbar_container.dart
│   │   │   ├── platform_chip.dart
│   │   │   ├── language_chip.dart
│   │   │   ├── section_header.dart
│   │   │   ├── download_progress_bar.dart
│   │   │   └── animated_bottom_nav.dart   # 毛玻璃底部导航
│   │   └── providers/
│   │       ├── locale_provider.dart
│   │       ├── theme_provider.dart
│   │       └── connectivity_provider.dart
│   │
│   └── l10n/                              # 国际化
│       ├── app_en.arb                     # English
│       ├── app_zh.arb                     # 中文
│       ├── app_ar.arb                     # العربية
│       ├── app_bn.arb                     # বাংলা
│       ├── app_es.arb                     # Español
│       ├── app_fr.arb                     # Français
│       ├── app_hi.arb                     # हिन्दी
│       ├── app_it.arb                     # Italiano
│       ├── app_ja.arb                     # 日本語
│       ├── app_ko.arb                     # 한국어
│       ├── app_pl.arb                     # Polski
│       ├── app_ru.arb                     # Русский
│       └── app_tr.arb                     # Türkçe
│
├── test/                                  # 测试
├── windows/                               # Windows 平台配置
├── macos/                                 # macOS 平台配置
├── linux/                                 # Linux 平台配置
├── assets/                                # 静态资源
│   ├── fonts/
│   │   ├── Inter-Variable.ttf
│   │   └── JetBrainsMono-Variable.ttf
│   ├── icons/
│   │   └── app_icon.ico
│   └── images/
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

---

## 三、模块重写清单（17 个阶段）

### 阶段 1: 项目基础架构 [进度: 待开始]
- [ ] Flutter 项目初始化 (flutter create)
- [ ] pubspec.yaml 依赖配置
- [ ] 目录结构搭建
- [ ] Riverpod Provider 架构
- [ ] GoRouter 路由配置 (12 个路由)
- [ ] Drift 数据库初始化
- [ ] Dio 网络层配置
- [ ] 主题系统 (6色 x 3模式 x AMOLED)
- [ ] 底部导航栏 (毛玻璃效果)

### 阶段 2: Core 层 — 数据模型 [进度: 待开始]
- [ ] Repository 模型 (owner, name, desc, stars, forks, etc.)
- [ ] Release 模型 (tag, name, prerelease, assets)
- [ ] ReleaseAsset 模型 (name, url, size, platform, arch)
- [ ] User 模型 (avatar, bio, repos, followers)
- [ ] Topic/Category 模型
- [ ] SearchFilter 模型
- [ ] ProxyConfig 模型
- [ ] Settings 模型
- [ ] ExportData 模型 (v4 schema)
- [ ] TelemetryEvent 模型

### 阶段 3: Core 层 — 网络与缓存 [进度: 待开始]
- [ ] GitHub Store 后端 API 客户端
  - GET /categories/{category}/{platform}
  - GET /topics/{bucket}/{platform}
  - GET /search
  - GET /search/explore
  - GET /repo/{owner}/{name}
  - GET /releases/{owner}/{name}
  - GET /readme/{owner}/{name}
  - GET /user/{username}
  - POST /events
- [ ] GitHub API 客户端 (Star/Unstar)
- [ ] OAuth Device Flow 实现
- [ ] Token 加密存储 (dart:io + platform channels)
- [ ] 三通道代理管理 (Discovery/Download/Translation)
- [ ] 内存 LRU 缓存 + TTL
- [ ] 数据库持久缓存 + TTL
- [ ] 两级缓存管理器

### 阶段 4: Core 层 — 平台服务 [进度: 待开始]
- [ ] 平台抽象接口
- [ ] Windows 安装器 (msiexec / exe)
- [ ] macOS 安装器 (open dmg / installer pkg)
- [ ] Linux 安装器 (apt/dpkg/gdebi-gtk, dnf/yum/zypper/rpm, pacman, AppImage)
- [ ] Linux 发行版检测 (/etc/os-release)
- [ ] Flatpak 沙箱检测与支持
- [ ] CPU 架构检测 (x86_64, arm64, aarch64)
- [ ] 安装包智能匹配算法
- [ ] 桌面通知 (osascript / notify-send / Windows Toast)
- [ ] 剪贴板监控

### 阶段 5: 共享 UI 组件 [进度: 待开始]
- [ ] RepositoryCard (仓库卡片)
- [ ] ExpressiveCard (Material You 表现力卡片)
- [ ] LoadingIndicator
- [ ] ErrorView
- [ ] EmptyState
- [ ] ScrollbarContainer
- [ ] PlatformChip
- [ ] SectionHeader
- [ ] DownloadProgressBar
- [ ] AnimatedBottomNav (毛玻璃底部导航 + 弹簧动画)
- [ ] UpdateBadge (红点)

### 阶段 6: Feature — 首页 [进度: 待开始]
- [ ] Trending 趋势区域 (无限滚动)
- [ ] Hot Release 热门发布区域
- [ ] Most Popular 最受欢迎区域
- [ ] Topic 分类区域 (Privacy/Media/Productivity/Networking/Dev Tools)
- [ ] 平台过滤 (All/Android/macOS/Windows/Linux)
- [ ] 隐藏已看开关
- [ ] HomeProvider + HomeRepository

### 阶段 7: Feature — 搜索 [进度: 待开始]
- [ ] 搜索输入框 + 防抖
- [ ] 全文搜索 (后端 API)
- [ ] 平台筛选
- [ ] 编程语言筛选 (底部弹窗)
- [ ] 排序 (最佳匹配/Star数/Fork数, 升序/降序)
- [ ] 无限滚动分页
- [ ] 搜索历史 (本地数据库)
- [ ] 剪贴板 GitHub URL 自动检测
- [ ] 直接 URL 解析跳转
- [ ] Explore 回退

### 阶段 8: Feature — 仓库详情 [进度: 待开始]
- [ ] 仓库头部 (图标/名称/版本/分享)
- [ ] 统计行 (Star/Fork/Issue/Watcher)
- [ ] 作者卡片 (点击跳转开发者主页)
- [ ] README Markdown 渲染 (中文 README 自动检测)
- [ ] Release 浏览器 (版本选择/Stable+Pre-release 过滤)
- [ ] Release Notes Markdown 渲染
- [ ] 资源列表 (平台标签 + 文件大小)
- [ ] 智能安装按钮 (自动选择最佳资源)
- [ ] 降级警告
- [ ] Attestation 验证徽章
- [ ] 收藏按钮
- [ ] 分享按钮
- [ ] 在浏览器打开

### 阶段 9: Feature — 下载与安装 [进度: 待开始]
- [ ] 下载管理器 (队列/并发控制)
- [ ] 下载进度追踪 (百分比 + 已下载/总大小)
- [ ] 下载取消
- [ ] 下载完成通知
- [ ] 平台安装器调用
- [ ] 安装日志
- [ ] DownloadProvider + DownloadRepository

### 阶段 10: Feature — 已安装应用管理 [进度: 待开始]
- [ ] 已安装应用列表
- [ ] 更新检查 (批量)
- [ ] 更新徽章
- [ ] 单个/批量更新
- [ ] 更新进度追踪
- [ ] 打开应用
- [ ] 卸载
- [ ] 排序 (更新优先/最近更新/名称)
- [ ] 搜索/过滤
- [ ] 链接已有应用 (3步引导)
- [ ] Variant 选择器 (多APK变体)
- [ ] 导出/导入 (JSON v4)
- [ ] AppsProvider + AppsRepository

### 阶段 11: Feature — 收藏 / Star / 最近浏览 [进度: 待开始]
- [ ] 本地收藏 (增删查列表)
- [ ] GitHub Star 列表 (需登录)
- [ ] Unstar 操作
- [ ] 最近浏览 (自动追踪 + 清除)
- [ ] FavoritesProvider + StarredProvider + RecentlyViewedProvider

### 阶段 12: Feature — GitHub 登录 [进度: 待开始]
- [ ] OAuth Device Flow (设备码输入)
- [ ] 轮询等待授权
- [ ] Token 加密存储
- [ ] 会话过期检测
- [ ] 登录/登出 UI
- [ ] AuthProvider + AuthRepository

### 阶段 13: Feature — 开发者主页 [进度: 待开始]
- [ ] 开发者信息卡片 (头像/名称/简介/统计)
- [ ] 开发者仓库列表
- [ ] 过滤 (有Release/已安装/收藏)
- [ ] 排序 (最近更新/Star数/名称)
- [ ] 搜索
- [ ] DevProfileProvider + DevProfileRepository

### 阶段 14: Feature — 设置 [进度: 待开始]
- [ ] 外观设置 (6色主题/亮暗模式/AMOLED/字体)
- [ ] 语言选择 (13种)
- [ ] 网络代理 (3通道 x HTTP/SOCKS + 测试)
- [ ] 翻译设置 (Google/有道 + API Key)
- [ ] 安装设置 (更新间隔/Pre-release)
- [ ] 存储管理 (缓存大小/清除)
- [ ] 剪贴板检测开关
- [ ] 隐藏已看开关
- [ ] 遥测开关
- [ ] 关于页面
- [ ] SettingsProvider + SettingsRepository

### 阶段 15: Feature — Deep Link + 翻译 + 通知 [进度: 待开始]
- [ ] Deep Link 处理 (githubstore:// / github.com URL / github-store.org URL)
- [ ] 单实例转发
- [ ] README 翻译 (Google/有道)
- [ ] Release Notes 翻译
- [ ] 分块翻译 (长文本拆分)
- [ ] 桌面通知 (下载完成/安装完成)

### 阶段 16: Feature — 高级功能 [进度: 待开始]
- [ ] 后台更新检查 (定时器)
- [ ] 自动更新
- [ ] 遥测 (匿名分析, 30秒批量)
- [ ] 崩溃报告 (日志写入磁盘)
- [ ] 速率限制处理 (对话框提示)
- [ ] 过期缓存回退 (离线模式)
- [ ] 键盘导航 (Ctrl+F)

### 阶段 17: 国际化 + 打包 [进度: 待开始]
- [ ] 13 种语言 ARB 文件
- [ ] 翻译所有 UI 文本
- [ ] Windows 打包 (MSI/EXE)
- [ ] macOS 打包 (DMG/PKG)
- [ ] Linux 打包 (DEB/RPM/AppImage)
- [ ] 应用图标和元数据
- [ ] 性能优化和最终测试

---

## 四、API 端点映射

### GitHub Store 后端 (api.github-store.org/v1)

| 端点 | 用途 | 对应功能 |
|------|------|---------|
| `GET /categories/trending/{platform}` | Trending | 首页 |
| `GET /categories/hot-release/{platform}` | Hot Release | 首页 |
| `GET /categories/most-popular/{platform}` | Most Popular | 首页 |
| `GET /topics/{bucket}/{platform}` | Topic 分类 | 首页 |
| `GET /search?q=&platform=&language=&sort=&order=&page=` | 搜索 | 搜索 |
| `GET /search/explore?q=&page=` | Explore 回退 | 搜索 |
| `GET /repo/{owner}/{name}` | 仓库详情 | 详情 |
| `GET /releases/{owner}/{name}` | Release 列表 | 详情 |
| `GET /readme/{owner}/{name}` | README 内容 | 详情 |
| `GET /user/{username}` | 用户信息 | 开发者主页 |
| `POST /events` | 遥测事件 | 遥测 |

### GitHub API (api.github.com)

| 端点 | 用途 | 认证 |
|------|------|------|
| `GET /user/starred/{owner}/{repo}` | 检查 Star 状态 | 需要 |
| `PUT /user/starred/{owner}/{repo}` | Star | 需要 |
| `DELETE /user/starred/{owner}/{repo}` | Unstar | 需要 |
| `GET /users/{username}/starred` | Star 列表 | 需要 |
| `GET /user` | 当前用户信息 | 需要 |

### GitHub Attestation API

| 端点 | 用途 |
|------|------|
| `GET /repos/{owner}/{repo}/attestations/{digest}` | APK 签名验证 |

### OAuth Device Flow

| 步骤 | 端点 |
|------|------|
| 请求设备码 | `POST https://github.com/login/device/code` |
| 轮询授权 | `POST https://github.com/login/oauth/access_token` |

---

## 五、数据库 Schema

### Drift 数据库表

```sql
-- 已安装应用
CREATE TABLE installed_apps (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_name TEXT NOT NULL,        -- "owner/repo"
  package_name TEXT,               -- Android 包名
  installed_version TEXT,
  installed_asset_url TEXT,
  installed_asset_hash TEXT,
  variant_fingerprint TEXT,        -- 多变体选择
  custom_regex TEXT,               -- 自定义资源过滤
  fallback_to_older INTEGER DEFAULT 0,
  install_time INTEGER NOT NULL,
  last_update_check INTEGER,
  is_update_available INTEGER DEFAULT 0,
  latest_version TEXT,
  glob_patterns TEXT,              -- 导出用
);

-- 本地收藏
CREATE TABLE favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  stars INTEGER DEFAULT 0,
  language TEXT,
  added_time INTEGER NOT NULL,
  UNIQUE(owner, name)
);

-- 最近浏览
CREATE TABLE recently_viewed (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  avatar_url TEXT,
  stars INTEGER DEFAULT 0,
  viewed_time INTEGER NOT NULL,
  UNIQUE(owner, name)
);

-- 搜索历史
CREATE TABLE search_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  query TEXT NOT NULL,
  searched_time INTEGER NOT NULL
);

-- 下载缓存
CREATE TABLE download_cache (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner TEXT NOT NULL,
  name TEXT NOT NULL,
  version TEXT NOT NULL,
  asset_name TEXT NOT NULL,
  asset_url TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size INTEGER,
  downloaded_at INTEGER NOT NULL,
  UNIQUE(owner, name, version, asset_name)
);

-- 遥测事件队列
CREATE TABLE telemetry_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_type TEXT NOT NULL,
  payload TEXT NOT NULL,            -- JSON
  created_at INTEGER NOT NULL
);

-- 设置
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- 代理配置
CREATE TABLE proxy_configs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scope TEXT NOT NULL,              -- DISCOVERY / DOWNLOAD / TRANSLATION
  proxy_type TEXT NOT NULL,         -- NONE / SYSTEM / HTTP / SOCKS
  host TEXT,
  port INTEGER,
  username TEXT,
  password TEXT
);
```

---

## 六、预期代码量估算

| 层级 | 预估行数 | 说明 |
|------|---------|------|
| Core (常量/工具/扩展) | ~1,500 | |
| Core (网络层) | ~2,000 | API 客户端 + 拦截器 + 代理 |
| Core (缓存/数据库) | ~1,500 | Drift 定义 + DAO |
| Core (平台服务) | ~2,000 | 安装器 + 发行版检测 + 通知 |
| Core (主题) | ~800 | 6色 x 3模式 |
| Shared UI | ~1,500 | 通用组件 |
| Feature - Home | ~800 | |
| Feature - Search | ~1,000 | |
| Feature - Details | ~1,500 | |
| Feature - Download/Install | ~1,200 | |
| Feature - Apps | ~1,800 | 含链接/导出/变体 |
| Feature - Favorites/Starred/Recent | ~800 | |
| Feature - Auth | ~600 | |
| Feature - DevProfile | ~600 | |
| Feature - Settings | ~1,500 | 6 个设置区域 |
| Feature - DeepLink/翻译/通知 | ~800 | |
| Feature - 高级功能 | ~600 | |
| L10n (13 ARB) | ~2,000 | |
| main + app + router | ~300 | |
| **总计** | **~23,300** | 原版 54,000 行的 ~43% |

---

## 七、时间线

这是一个大型项目，按优先级分批交付：

**第一批 (MVP 核心)**：阶段 1-5 + 6-8 + 9
→ 可以搜索、浏览、查看详情、下载安装

**第二批 (应用管理)**：阶段 10-11
→ 已安装应用管理、更新、收藏

**第三批 (社交与登录)**：阶段 12-13
→ GitHub 登录、Star、开发者主页

**第四批 (完善体验)**：阶段 14-15
→ 设置、Deep Link、翻译、通知

**第五批 (收尾)**：阶段 16-17
→ 高级功能、国际化、打包
