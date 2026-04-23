---
Task ID: 1
Agent: main
Task: WaveTerm i18n 汉化 - 完整翻译和构建

Work Log:
- 克隆 WaveTerm 仓库 (19.7k Stars, 开源 AI 集成终端)
- 全面扫描 ~170 个前端文件，发现 ~480+ 个硬编码英文字符串
- 建立 i18n 框架 (i18next + react-i18next)，支持自动语言检测和运行时切换
- 创建完整的 en.json (455 个翻译键) 和 zh-CN.json (455 个中文翻译)
- 修改 49 个 React 组件 + 12 个非 React 文件，替换硬编码文本为 t() 调用
- 安装 i18next 和 react-i18next 依赖
- 通过 electron-vite build 验证构建成功
- 共 59 个文件变更，826 行新增，1174 行删除

Stage Summary:
- 产出物: 完整的 WaveTerm 中文汉化版本
- 核心文件: frontend/app/i18n/index.ts, frontend/app/i18n/locales/en.json, frontend/app/i18n/locales/zh-CN.json
- 翻译覆盖: 455 个 UI 翻译键，涵盖 37 个命名空间
- 语言检测: 自动检测浏览器语言，默认中文环境显示中文
- 运行时切换: 提供 changeLanguage() API 和 SUPPORTED_LANGUAGES 常量
- 待办: 推送到用户 GitHub，打包 DMG
