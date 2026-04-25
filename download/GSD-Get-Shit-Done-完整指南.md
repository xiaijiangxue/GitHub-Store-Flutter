# GSD (Get Shit Done) 完整使用指南

> **仓库地址**: [https://github.com/gsd-build/get-shit-done](https://github.com/gsd-build/get-shit-done)  
> **版本**: v1.38.3 | **Stars**: 56,800+ | **协议**: MIT  
> **作者**: TÂCHES

---

## 目录

- [1. 项目简介](#1-项目简介)
- [2. 安装方式](#2-安装方式)
- [3. 系统要求与空间占用](#3-系统要求与空间占用)
- [4. 核心概念](#4-核心概念)
- [5. 工作流全景图](#5-工作流全景图)
- [6. 规划产物体系](#6-规划产物体系)
- [7. 完整命令参考（85个命令）](#7-完整命令参考85个命令)
  - [7.1 核心工作流命令](#71-核心工作流命令20个)
  - [7.2 阶段与里程碑管理](#72-阶段与里程碑管理18个)
  - [7.3 会话与导航](#73-会话与导航13个)
  - [7.4 代码库智能](#74-代码库智能5个)
  - [7.5 审查、调试与恢复](#75-审查调试与恢复7个)
  - [7.6 文档、配置与工具](#76-文档配置与工具12个)
- [8. Agent 体系（33个Agent）](#8-agent-体系33个agent)
- [9. Hook 机制（11个Hook）](#9-hook-机制11个hook)
- [10. 按任务复杂度的工作流](#10-按任务复杂度的工作流)
  - [10.1 简单任务：修 bug / 小改动](#101-简单任务修-bug--小改动)
  - [10.2 中等功能：新 API / 新组件](#102-中等功能新-api--新组件)
  - [10.3 大型功能：多阶段项目](#103-大型功能多阶段项目)
  - [10.4 R&D 技术验证](#104-rd-技术验证)
  - [10.5 全自动执行模式](#105-全自动执行模式)
- [11. Spike / Sketch 探索系统](#11-spike--sketch-探索系统)
- [12. UAT 验证系统](#12-uat-验证系统)
- [13. 会话管理](#13-会话管理)
- [14. 速度 vs 质量预设](#14-速度-vs-质量预设)
- [15. 多工作流并行（Workstreams）](#15-多工作流并行workstreams)
- [16. 自我进化机制](#16-自我进化机制)
- [17. 支持的 AI 运行时](#17-支持的-ai-运行时)
- [18. 卸载与更新](#18-卸载与更新)
- [19. 与其他工具对比](#19-与其他工具对比)
- [20. 日常高频命令速查表](#20-日常高频命令速查表)

---

## 1. 项目简介

GSD (Get Shit Done) 是一个**元提示 (meta-prompting)、上下文工程 (context engineering) 和规范驱动开发 (spec-driven development)** 系统，专为 AI 编程助手设计。它支持 15 种主流 AI 编程工具（Claude Code、Cursor、Copilot、Windsurf、Codex 等），通过**多 Agent 编排、原子计划、波次并行执行和上下文刷新**来解决 AI 编程中最大的痛点——**上下文腐烂 (context rot)**。

### 解决的核心问题

| 问题 | GSD 的解法 |
|------|-----------|
| 上下文窗口被填满后质量急剧下降 | 每个 Agent 使用全新的 200K 上下文 |
| AI 忘记项目整体架构 | PROJECT.md 始终被加载，ROADMAP.md 跟踪全局 |
| 执行结果缺乏追踪 | 原子 Git 提交 + SUMMARY.md + VERIFICATION.md |
| 多阶段项目管理混乱 | STATE.md 状态追踪 + 阶段门控 + 自动推进 |
| 质量不可控 | Plan Checker 8维验证 + UAT + 代码审查 |

### 核心特性

- **85 个斜杠命令**，覆盖从项目初始化到发布全流程
- **33 个专职 Agent**，各司其职，最小权限原则
- **11 个 Hook**，自动监控上下文、防护注入、规范提交
- **学习毕业流水线**，从失败中提取教训并晋升为永久规则
- **跨 AI 运行时**，一套命令适配 15 种工具

---

## 2. 安装方式

### 前提条件

- **Node.js ≥ 22.0.0**（硬性要求）
- npm（随 Node.js 一起安装）
- 至少一个 AI 编程工具（Claude Code、Cursor 等）

### 方式一：交互式安装（推荐）

```bash
npx get-shit-done-cc@latest
```

弹出交互式菜单，让你选择：
1. 目标运行时（可多选）
2. 安装范围（全局 / 当前项目）

### 方式二：非交互式一键安装

```bash
# 指定运行时 + 范围
npx get-shit-done-cc --claude --global
npx get-shit-done-cc --cursor --local

# 装所有支持的工具
npx get-shit-done-cc --all --global

# 跳过 SDK
npx get-shit-done-cc --claude --global --no-sdk
```

### 方式三：源码手动安装

```bash
git clone https://github.com/gsd-build/get-shit-done.git
cd get-shit-done
node scripts/build-hooks.js
node bin/install.js --claude --global
```

### 运行时参数

| 参数 | 对应工具 |
|------|---------|
| `--claude` | Claude Code |
| `--cursor` | Cursor |
| `--copilot` | GitHub Copilot |
| `--windsurf` | Windsurf |
| `--opencode` | OpenCode |
| `--gemini` | Gemini CLI |
| `--codex` | Codex |
| `--kilo` | Kilo |
| `--antigravity` | Antigravity |
| `--augment` | Augment |
| `--trae` | Trae |
| `--qwen` | Qwen Code |
| `--cline` | Cline |
| `--codebuddy` | CodeBuddy |
| `--all` | 全部 |

### 作用域参数

| 参数 | 安装路径 | 效果 |
|------|---------|------|
| `--global` / `-g` | `~/.claude/` 等 | 所有项目通用 |
| `--local` / `-l` | `./.claude/` 等 | 仅当前项目生效 |

---

## 3. 系统要求与空间占用

### 磁盘空间

| 组件 | 大小 |
|------|------|
| Git 仓库 | ~12 MB |
| 安装后配置文件 | 极小（Markdown 文件 + 脚本） |
| **总计** | **~15–20 MB** |

GSD 是纯 JavaScript 项目，不包含大模型权重、不需要 GPU，**非常轻量**。

### 内存占用

| 场景 | 内存占用 |
|------|---------|
| 空闲 | 几乎为零（只是配置文件） |
| 运行时（被 Claude Code 调用） | 取决于 Claude Code 本身 |

---

## 4. 核心概念

### 4.1 原子计划 (Atomic Plan)

每个计划是独立可执行的最小单元。执行时每个 Agent（Executor）获得**全新的 200K 上下文**，不继承上一个阶段的"噪音"，从根本上避免上下文腐烂。

### 4.2 波次执行 (Wave Execution)

独立计划在**同一波次并行执行**，有依赖关系的计划串行执行：

```
Wave 1:  Plan 01 (数据层) ──┐
                             ├──→ Wave 2: Plan 03 (集成层)
Wave 1:  Plan 02 (API层)  ──┘
```

### 4.3 最小权限原则 (Principle of Least Privilege)

| 角色 | 权限 |
|------|------|
| 检查者 (Checker) | 只读，无 Write/Edit |
| 研究者 (Researcher) | 可读写分析文档，有网络访问 |
| 执行者 (Executor) | 可 Edit 代码，但**无网络访问** |
| 映射者 (Mapper) | 可 Write 分析文档，但不可 Edit 代码 |

### 4.4 上下文刷新 (Context Refresh)

每个大步骤之间建议执行 `/clear`（清空上下文），让下一个 Agent 从规划产物中获取**最新、最干净**的上下文，而不是继承历史对话的噪音。

### 4.5 决策覆盖 (Decision Coverage)

- **规划阶段（阻塞门控）**：CONTEXT.md 中的每个决策 (D-NN) 必须出现在至少一个计划中
- **验证阶段（非阻塞）**：在计划、SUMMARY.md、Git 提交、代码中搜索决策实现情况

---

## 5. 工作流全景图

```
┌─────────────────────────────────────────────────────────────────┐
│                        新项目启动                                │
│                                                                 │
│  /gsd-map-codebase ──→ 4个Mapper并行分析现有代码库              │
│         │                                                       │
│         ▼                                                       │
│  /gsd-new-project ──→ 问答 → 研究 → 需求分析 → 路线图           │
│                       产出: PROJECT.md, REQUIREMENTS.md,         │
│                             ROADMAP.md, STATE.md                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    每个阶段循环 (Phase N)                        │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 1. DISCUSS                                              │    │
│  │    /gsd-discuss-phase N                                 │    │
│  │    → 锁定偏好、技术选型 → CONTEXT.md                    │    │
│  └─────────────────────┬───────────────────────────────────┘    │
│                        ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 2. UI DESIGN (前端可选)                                 │    │
│  │    /gsd-ui-phase N                                     │    │
│  │    → 设计合约 → UI-SPEC.md                             │    │
│  └─────────────────────┬───────────────────────────────────┘    │
│                        ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 3. PLAN                                                 │    │
│  │    /gsd-plan-phase N                                   │    │
│  │    → 4个Researcher并行调研                              │    │
│  │    → Planner生成2-3个原子计划                          │    │
│  │    → Plan Checker 8维验证 (最多3轮)                    │    │
│  │    → 产出: RESEARCH.md, PLAN.md, VALIDATION.md         │    │
│  └─────────────────────┬───────────────────────────────────┘    │
│                        ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 4. EXECUTE                                              │    │
│  │    /gsd-execute-phase N                                │    │
│  │    → 波次并行执行，每个Executor全新200K上下文           │    │
│  │    → 原子Git提交                                       │    │
│  │    → 产出: SUMMARY.md, VERIFICATION.md                 │    │
│  └─────────────────────┬───────────────────────────────────┘    │
│                        ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 5. VERIFY (UAT)                                         │    │
│  │    /gsd-verify-work N                                  │    │
│  │    → 逐条手动验收                                       │    │
│  │    → 失败时自动生成修复计划                             │    │
│  │    → 产出: UAT.md                                      │    │
│  └─────────────────────┬───────────────────────────────────┘    │
│                        ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 6. SHIP (可选)                                          │    │
│  │    /gsd-ship N                                         │    │
│  │    → 自动生成PR描述 → 创建PR                           │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│                  重复循环直到所有阶段完成                        │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                        里程碑收尾                                │
│                                                                 │
│  /gsd-audit-milestone      → 检查所有交付物                     │
│  /gsd-audit-uat            → 查漏补缺                           │
│  /gsd-extract-learnings    → 提取经验教训                       │
│  /gsd-complete-milestone   → 归档 + 打tag                       │
│  /gsd-milestone-summary    → 生成项目总结                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. 规划产物体系

GSD 所有规划产物存放在项目的 `.planning/` 目录下：

### 全局产物（始终存在）

| 文件 | 作用 | 谁来读 |
|------|------|--------|
| `PROJECT.md` | 项目愿景、约束、技术栈、关键决策 | **所有 Agent** |
| `REQUIREMENTS.md` | 已界定的 v1/v2 需求，带 REQ-ID 和阶段追溯 | Roadmapper |
| `ROADMAP.md` | 阶段列表、目标、依赖、需求映射、成功标准 | STATE.md + Planner |
| `STATE.md` | 活跃记忆 — 当前位置、速度、阻碍、会话连续性 | **所有命令** |
| `config.json` | 工作流开关、模型配置、Git 策略 | GSD 系统 |
| `CLAUDE.md` | 自动生成的 Claude Code 指令 | Claude Code |

### 阶段产物（每个阶段 N 生成）

| 文件 | 来源 | 消费者 |
|------|------|--------|
| `{N}-CONTEXT.md` | `/gsd-discuss-phase` | Researcher + Planner |
| `{N}-UI-SPEC.md` | `/gsd-ui-phase` | Planner + Executor |
| `{N}-RESEARCH.md` | `/gsd-plan-phase` (4个Researcher) | Planner |
| `{N}-{M}-PLAN.md` | `/gsd-plan-phase` (Planner) | Executor |
| `{N}-VALIDATION.md` | `/gsd-plan-phase` (Plan Checker) | Executor |
| `{N}-{M}-SUMMARY.md` | `/gsd-execute-phase` (Executor) | Verifier |
| `{N}-VERIFICATION.md` | `/gsd-execute-phase` (Verifier) | `/gsd-verify-work` |
| `{N}-UAT.md` | `/gsd-verify-work` | 用户验收 |

### 产物流转关系

```
PROJECT.md ←── 所有Agent读取（愿景、约束、决策）
    ↓
REQUIREMENTS.md ←── 映射到 ROADMAP 的各个阶段
    ↓
ROADMAP.md ←── 驱动"下一个阶段是哪个"（STATE.md 跟踪位置）
    ↓
{N}-CONTEXT.md ←── discuss 产出 → Researcher + Planner 消费
{N}-RESEARCH.md ←── 4个Researcher产出 → Planner 消费
{N}-{M}-PLAN.md ←── Planner 产出 → Executor 消费（全新200K上下文）
{N}-{M}-SUMMARY.md ←── Executor 产出 → Verifier 消费
{N}-VERIFICATION.md ←── Verifier 产出 → verify-work 消费
STATE.md ←── 每个重要操作后自动更新
```

### 研究产物（`research/` 子目录）

| 文件 | 内容 |
|------|------|
| `STACK.md` | 技术栈分析 |
| `FEATURES.md` | 功能特性调研 |
| `ARCHITECTURE.md` | 架构分析 |
| `PITFALLS.md` | 常见陷阱和避坑指南 |
| `SUMMARY.md` | 研究综合报告 |

### 代码库分析产物（`codebase/` 子目录）

| 文件 | 内容 |
|------|------|
| `STACK.md` | 代码库使用的技术栈 |
| `ARCHITECTURE.md` | 现有架构分析 |
| `CONVENTIONS.md` | 代码规范和约定 |
| `CONCERNS.md` | 代码异味和关注点 |
| `STRUCTURE.md` | 目录结构和模块关系 |
| `TESTING.md` | 测试策略和覆盖率 |
| `INTEGRATIONS.md` | 外部集成分析 |

---

## 7. 完整命令参考（85个命令）

### 7.1 核心工作流命令（20个）

| 命令 | 作用 | 详细说明 |
|------|------|---------|
| `/gsd-new-project [--auto @file]` | 初始化项目 | 问答 → 研究 → 需求 → 路线图。`--auto` 从文件加载需求 |
| `/gsd-new-workspace` | 创建隔离工作区 | 使用 Git worktree 隔离工作 |
| `/gsd-list-workspaces` | 查看所有工作区 | 显示工作区列表和状态 |
| `/gsd-remove-workspace` | 删除工作区 | 清理 worktree |
| `/gsd-discuss-phase [N]` | 阶段讨论 | 捕获实施偏好 → CONTEXT.md |
| `/gsd-spec-phase` | 需求精化 | 苏格拉底式提问 → SPEC.md |
| `/gsd-ui-phase [N]` | UI 设计合约 | 生成 UI-SPEC.md（前端项目必用） |
| `/gsd-ai-integration-phase` | AI 集成规划 | 框架选择 + 评估计划 → AI-SPEC.md |
| `/gsd-plan-phase [N]` | 阶段规划 | 4Researcher并行 → 2-3个原子计划 → Plan Checker验证 |
| `/gsd-plan-review-convergence N` | 跨 AI 收敛审查 | plan → review → replan → re-review 循环直到收敛 |
| `/gsd-ultraplan-phase N` | 云端超规划 | [BETA] 借用 Claude Code 的 ultraplan 云端能力 |
| `/gsd-spike [idea]` | 技术可行性实验 | Given/When/Then 假设验证 |
| `/gsd-sketch [idea]` | 交互式视觉原型 | 生成 2-3 个 HTML 变体，浏览器直接打开 |
| `/gsd-research-phase [N]` | 独立领域研究 | 为某阶段做专项调研 |
| `/gsd-execute-phase <N>` | 执行阶段 | 波次并行执行所有计划，原子 Git 提交 |
| `/gsd-verify-work [N]` | 手动验收 | 逐条 UAT 检查，失败自动修复 |
| `/gsd-ship [N] [--draft]` | 发 PR | 自动生成 PR 描述，`--draft` 创建草稿 |
| `/gsd-next` | 自动推进 | 检测当前状态，自动执行下一步 |
| `/gsd-fast <text>` | 快速内联任务 | 无子 Agent，无规划，直接执行 + 单次提交 |
| `/gsd-quick [--full]` | 即席任务 | 有规划+执行的轻量工作流 |

### 7.2 阶段与里程碑管理（18个）

| 命令 | 作用 |
|------|------|
| `/gsd-add-phase` | 追加新阶段到路线图 |
| `/gsd-insert-phase [N]` | 在阶段 N 后插入子阶段（如 3.1） |
| `/gsd-remove-phase [N]` | 删除未来阶段并重新编号 |
| `/gsd-add-tests [N]` | 为已完成阶段补充测试 |
| `/gsd-list-phase-assumptions [N]` | 查看规划前的假设（规划前检查） |
| `/gsd-analyze-dependencies` | 分析阶段间依赖关系 |
| `/gsd-validate-phase [N]` | 回溯式 Nyquist 测试覆盖率审计 |
| `/gsd-secure-phase [N]` | 回溯式安全威胁缓解验证 |
| `/gsd-audit-milestone` | 验证里程碑是否达成定义的完成标准 |
| `/gsd-audit-uat` | 跨阶段 UAT 遗漏审计 |
| `/gsd-audit-fix [--dry-run]` | 自动审计 → 分类 → 修复 → 提交 |
| `/gsd-plan-milestone-gaps` | 为审计发现的缺口创建修复阶段 |
| `/gsd-complete-milestone` | 归档里程碑，打 Git tag |
| `/gsd-new-milestone [name]` | 开始下一个版本周期 |
| `/gsd-milestone-summary [version]` | 生成项目综合总结 |
| `/gsd-cleanup` | 归档已完成里程碑的阶段目录 |
| `/gsd-manager` | 多阶段项目交互式控制台 |
| `/gsd-autonomous [--from N] [--to N]` | 全自动执行剩余阶段 |
| `/gsd-undo --last N / --phase NN` | 安全回滚 GSD 的 Git 提交 |

### 7.3 会话与导航（13个）

| 命令 | 作用 |
|------|------|
| `/gsd-progress [--forensic]` | 我在哪？下一步是什么？ |
| `/gsd-stats` | 项目指标仪表板 |
| `/gsd-session-report` | 会话总结（Token 使用量、工作产出） |
| `/gsd-pause-work` | 暂停工作，保存交接文件 |
| `/gsd-resume-work` | 从上次暂停处恢复 |
| `/gsd-explore [topic]` | 苏格拉底式头脑风暴 → 路由到合适的产物 |
| `/gsd-do <text>` | 自然语言路由到正确的 GSD 命令 |
| `/gsd-note <text> / list / promote N` | 零摩擦灵感捕获 |
| `/gsd-add-todo [desc]` | 添加待办事项 |
| `/gsd-check-todos` | 查看并选择待办 |
| `/gsd-add-backlog <desc>` | 添加到需求积压区（编号 999.x） |
| `/gsd-review-backlog` | 审查积压项（晋升/过期/删除） |
| `/gsd-plant-seed <idea>` | 种下带触发条件的创意种子 |
| `/gsd-thread [name]` | 跨会话持久化知识线程 |

### 7.4 代码库智能（5个）

| 命令 | 作用 |
|------|------|
| `/gsd-map-codebase [area]` | 全代码库分析（4个Mapper并行） |
| `/gsd-scan [--focus ...]` | 快速轻量评估 |
| `/gsd-intel refresh / query / status / diff` | 可查询的代码库知识库 |
| `/gsd-graphify` | 构建/查询项目知识图谱 |
| `/gsd-extract-learnings [N]` | 从已完成阶段提取模式/决策/教训 |

### 7.5 审查、调试与恢复（7个）

| 命令 | 作用 |
|------|------|
| `/gsd-review` | 跨 AI 同行评审（发给不同模型评审） |
| `/gsd-code-review [N]` | 代码审查（Bug/安全/质量） |
| `/gsd-code-review-fix [N] [--auto]` | 自动修复审查发现的问题 |
| `/gsd-debug [desc]` | 科学方法调试（有持久化状态） |
| `/gsd-forensics [desc]` | 失败工作流的事后调查诊断 |
| `/gsd-health [--repair]` | 验证 `.planning/` 目录完整性 |
| `/gsd-pr-branch` | 创建干净 PR 分支（过滤 .planning/ 提交） |

### 7.6 文档、配置与工具（12个）

| 命令 | 作用 |
|------|------|
| `/gsd-docs-update` | 生成并验证文档 |
| `/gsd-ingest-docs [dir]` | 从现有 ADR/PRD/SPEC 引导初始化 `.planning/` |
| `/gsd-spike-wrap-up` | 将 Spike 结论打包为项目 Skill |
| `/gsd-sketch-wrap-up` | 将 Sketch 结论打包为项目 Skill |
| `/gsd-profile-user` | 生成开发者行为画像（8维度） |
| `/gsd-settings` | 配置工作流开关和模型配置 |
| `/gsd-settings-advanced` | 高级配置（超时、分支策略、跨AI设置） |
| `/gsd-settings-integrations` | API Key、评审 CLI、Agent-Skill 注入 |
| `/gsd-set-profile <profile>` | 切换模型配置（quality/balanced/budget/inherit） |
| `/gsd-workstreams` | 管理并行工作流 |
| `/gsd-sync-skills` | 跨运行时同步 Skill |
| `/gsd-update` | 更新 GSD（带变更日志预览） |
| `/gsd-import --from <file>` | 导入外部计划（带冲突检测） |
| `/gsd-from-gsd2` | 从 GSD v2 格式迁移回 v1 |
| `/gsd-inbox` | 将 GitHub Issue 分拣到项目模板 |
| `/gsd-help` | 显示所有命令 |

---

## 8. Agent 体系（33个Agent）

### 主要 Agent（21个，有完整角色卡）

| Agent | 触发者 | 角色 |
|-------|--------|------|
| `gsd-project-researcher` | `/gsd-new-project` | 4个并行实例，分别调研技术栈/功能/架构/陷阱 |
| `gsd-phase-researcher` | `/gsd-plan-phase` | 4个并行实例，调研阶段实施细节 |
| `gsd-ui-researcher` | `/gsd-ui-phase` | 产出 UI-SPEC.md 设计合约 |
| `gsd-assumptions-analyzer` | discuss-phase (assumptions模式) | 基于代码库的结构化假设分析 |
| `gsd-advisor-researcher` | discuss-phase (advisor模式) | 灰度决策研究（对比表格） |
| `gsd-research-synthesizer` | `/gsd-new-project` | 合并 4 个 Researcher 输出为 SUMMARY.md |
| `gsd-planner` | `/gsd-plan-phase`, `/gsd-quick` | 创建 XML 结构化原子计划 |
| `gsd-roadmapper` | `/gsd-new-project` | 创建 ROADMAP.md 阶段分解 |
| `gsd-executor` | `/gsd-execute-phase`, `/gsd-quick` | 执行计划，原子提交（全新200K上下文） |
| `gsd-plan-checker` | `/gsd-plan-phase` | 8维度计划验证（最多3轮迭代） |
| `gsd-integration-checker` | `/gsd-audit-milestone` | 跨阶段集成验证 |
| `gsd-ui-checker` | `/gsd-ui-phase` | 6维度 UI-SPEC 验证 |
| `gsd-verifier` | `/gsd-execute-phase` | 目标倒推验证 + 测试质量审计 |
| `gsd-nyquist-auditor` | `/gsd-validate-phase` | 填补测试覆盖率缺口（不修改实现代码） |
| `gsd-ui-auditor` | `/gsd-ui-review` | 6支柱视觉审计（文案→体验设计） |
| `gsd-codebase-mapper` | `/gsd-map-codebase` | 4个并行 Mapper 写分析文档 |
| `gsd-debugger` | `/gsd-debug` | 科学方法调试，有持久化状态 |
| `gsd-user-profiler` | `/gsd-profile-user` | 8维度行为画像 |
| `gsd-doc-writer` | `/gsd-docs-update` | 多模式文档生成 |
| `gsd-doc-verifier` | `/gsd-docs-update` | 文档与代码库的事实校验 |
| `gsd-security-auditor` | `/gsd-secure-phase` | 威胁缓解验证（ASVS 1/2/3级） |

### 高级/专用 Agent（12个）

| Agent | 角色 |
|-------|------|
| `gsd-pattern-mapper` | 将新文件映射到现有类比 → PATTERNS.md |
| `gsd-debug-session-manager` | 隔离式调试检查点循环 |
| `gsd-code-reviewer` | Bug/安全/质量审查 → REVIEW.md |
| `gsd-code-fixer` | 自动修复 REVIEW.md 中的发现 |
| `gsd-ai-researcher` | AI 框架研究 → AI-SPEC.md |
| `gsd-domain-researcher` | 领域评估上下文 → AI-SPEC.md |
| `gsd-eval-planner` | AI 评估策略 → AI-SPEC.md |
| `gsd-eval-auditor` | 回溯式评估覆盖率审计 |
| `gsd-framework-selector` | ≤6问题的 AI 框架决策矩阵 |
| `gsd-intel-updater` | 可查询的代码库智能文件 |
| `gsd-doc-classifier` | 文档分类（ADR/PRD/SPEC/DOC） |
| `gsd-doc-synthesizer` | 合并已分类文档（带冲突检测） |

### 权限矩阵

| 角色 | Read | Write(文档) | Edit(代码) | 网络访问 |
|------|------|-----------|-----------|---------|
| Checker | ✅ | ❌ | ❌ | ❌ |
| Researcher | ✅ | ✅ | ❌ | ✅ |
| Planner | ✅ | ✅ | ❌ | ❌ |
| Executor | ✅ | ❌ | ✅ | ❌ |
| Mapper | ✅ | ✅ | ❌ | ❌ |

---

## 9. Hook 机制（11个Hook）

| Hook | 类型 | 触发时机 | 行为 |
|------|------|---------|------|
| `gsd-statusline.js` | SessionStart | 每次会话启动 | 显示模型 + GSD 状态 + 上下文使用率 |
| `gsd-check-update.js` | SessionStart | 每次会话启动 | 后台检查 GSD 更新 |
| `gsd-context-monitor.js` | PostToolUse | 每次工具调用后 | 上下文 ≤35% 警告，≤25% 严重警告 |
| `gsd-prompt-guard.js` | PreToolUse | 写入 `.planning/` 时 | 扫描提示注入模式 |
| `gsd-read-guard.js` | PreToolUse | 编辑已有文件时 | 提醒先 Read 文件（防无限重试） |
| `gsd-read-injection-scanner.js` | PostToolUse | Read 工具后 | 扫描文件内容中的注入模式 |
| `gsd-workflow-guard.js` | PreToolUse | GSD 上下文外编辑 | 提醒用 `/gsd-quick` 代替直接编辑（需开启） |
| `gsd-validate-commit.sh` | PreToolUse | `git commit` 时 | 强制 Conventional Commits 格式（需开启） |
| `gsd-phase-boundary.sh` | PostToolUse | 写入 `.planning/` 后 | 提醒更新 STATE.md（需开启） |
| `gsd-session-state.sh` | SessionStart | 每次会话启动 | 显示 STATE.md 头部（需开启） |

**需手动开启的 Hook**（默认关闭，避免打扰）：
- `hooks.workflow_guard: true`
- `hooks.community: true`（一次开启上面三个社区 Hook）

---

## 10. 按任务复杂度的工作流

### 10.1 简单任务：修 bug / 小改动

**场景**："修复移动端 Safari 登录按钮无响应"

#### 方案 A：极速模式

```bash
/gsd-fast Fix the login button not responding on mobile Safari
```

- 无子 Agent、无规划
- 内联执行 + 单次原子提交
- 适合：1-2 个文件的小修改

#### 方案 B：快速模式

```bash
/gsd-quick
```

然后描述任务。自动走 Planner + Executor，有原子提交和状态追踪，存储在 `.planning/quick/001-xxx/`。

```bash
/gsd-quick --full    # 加上讨论 + 研究 + 验证（较正式）
```

---

### 10.2 中等功能：新 API / 新组件

**场景**："添加 `/api/notifications` 端点，支持 WebSocket 实时推送"

#### 完整 5 步流程

```bash
# ① 讨论 — 锁定偏好
/gsd-discuss-phase 2
# 回答问题：响应格式、认证方式、错误处理、技术选型...
# 产出: 02-CONTEXT.md

/clear    # ← 重要：清空上下文

# ② 规划 — 研究 + 计划 + 验证
/gsd-plan-phase 2
# 4个Researcher并行：技术栈/功能/架构/陷阱
# Planner生成2-3个原子计划
# Plan Checker 8维验证（最多3轮）
# 产出: 02-RESEARCH.md, 02-01-PLAN.md, 02-02-PLAN.md, 02-VALIDATION.md

/clear    # ← 重要

# ③ 执行 — 波次并行
/gsd-execute-phase 2
# Wave 1: Plan 01 和 Plan 02 并行（如独立）
# Wave 2: Plan 03（如有依赖）
# 每个Executor拿全新200K上下文
# 原子Git提交
# 产出: 02-01-SUMMARY.md, 02-02-SUMMARY.md, 02-VERIFICATION.md

# ④ 验证 — 手动UAT
/gsd-verify-work 2
# 逐条检查："能 GET /api/notifications 吗？返回 200 吗？"
# 失败时：自动生成修复计划 → 重新执行
# 产出: 02-UAT.md

# ⑤ 发PR（可选）
/gsd-ship 2
# 自动生成PR描述 → 创建PR
```

#### 偷懒模式

```bash
/gsd-discuss-phase 2
/clear
/gsd-next    # ← 自动检测需要规划 → 执行 /gsd-plan-phase
/clear
/gsd-next    # ← 自动检测需要执行 → 执行 /gsd-execute-phase
/gsd-next    # ← 自动检测需要验证 → 执行 /gsd-verify-work
```

#### 链式模式

```bash
/gsd-discuss-phase 2 --chain    # 自动链式执行: discuss → plan → execute
```

---

### 10.3 大型功能：多阶段项目

**场景**："构建完整的实时协作系统（CRDT + 在线状态 + 冲突解决）"

```bash
# ==========================================
# 第 0 步：技术验证（强烈推荐）
# ==========================================

/gsd-spike "CRDT库对比：Yjs vs Automerge 对我们的场景"
/gsd-spike-wrap-up                          # 结论打包为项目 Skill

/gsd-sketch "协作UI：光标显示、选区高亮、冲突提示"
/gsd-sketch-wrap-up                         # 设计决策打包为项目 Skill

# ==========================================
# 第 1 步：项目初始化
# ==========================================

/gsd-map-codebase                           # 4个Mapper并行分析现有代码库
/gsd-new-project                            # 问答 → 研究 → 需求 → 路线图

/clear

# ==========================================
# 第 2 步：逐阶段推进
# ==========================================

# --- 阶段 1: CRDT 数据层 ---
/gsd-discuss-phase 1         # 锁定：CRDT库、数据模型、持久化策略
/gsd-plan-phase 1            # 研究 + 规划 + 验证
/clear
/gsd-execute-phase 1         # 并行执行
/gsd-verify-work 1           # 手动验收
/gsd-code-review 1           # 代码审查
/gsd-ship 1                  # 发PR

/clear

# --- 阶段 2: WebSocket 传输层 ---
/gsd-discuss-phase 2
/gsd-plan-phase 2
/clear
/gsd-execute-phase 2
/gsd-verify-work 2
/gsd-ship 2

/clear

# --- 阶段 3: 在线状态系统 ---
/gsd-discuss-phase 3
/gsd-ui-phase 3              # UI 设计合约（前端必加这步）
/gsd-plan-phase 3
/clear
/gsd-execute-phase 3
/gsd-verify-work 3
/gsd-ship 3

/clear

# --- 继续后续阶段 ---

# ==========================================
# 第 3 步：项目管理
# ==========================================

/gsd-manager                 # 交互式控制台，查看所有阶段状态
/gsd-progress                # 查看当前位置和下一步
/gsd-autonomous --from 4     # 阶段 4 以后全自动执行

# ==========================================
# 第 4 步：里程碑收尾
# ==========================================

/gsd-audit-milestone         # 检查所有交付物是否完整
/gsd-audit-uat               # 跨阶段 UAT 漏洞审计
/gsd-extract-learnings       # 提取经验教训
/gsd-plan-milestone-gaps     # 如有缺口，创建修复阶段
/gsd-complete-milestone      # 归档 + 打 Git tag
/gsd-milestone-summary       # 生成项目综合总结
```

---

### 10.4 R&D 技术验证

**场景**：在做大型项目前，先验证技术方案是否可行

```bash
# ① 技术可行性实验
/gsd-spike "SSE vs WebSocket 延迟对比"
/gsd-spike --quick "Redis Streams 是否支持我们需要的吞吐量"

# 每个Spike运行2-5个实验：
# - Given/When/Then 假设
# - 输出: VALIDATED / INVALIDATED / PARTIAL
# 存储: .planning/spikes/NNN-name/

# ② 打包结论（重要！）
/gsd-spike-wrap-up
# → 打包为 .claude/skills/spike-findings-[project]/
# → 未来的构建会话中自动加载

# ③ 视觉设计探索（前端项目）
/gsd-sketch "仪表板布局"
/gsd-sketch --quick "侧边栏导航"
/gsd-sketch --text "引导流程"    # 非 Claude 运行时的纯文本模式

/gsd-sketch-wrap-up
# → 打包为 .claude/skills/sketch-findings-[project]/

# ④ 然后正常进入规划流程
/gsd-discuss-phase N    # 此时会自动加载 spike + sketch 的结论
/gsd-plan-phase N
```

---

### 10.5 全自动执行模式

```bash
# 从阶段 3 到阶段 8，全自动
/gsd-autonomous --from 3 --to 8

# 从当前阶段到结束
/gsd-autonomous

# 干完后去喝杯咖啡 ☕
```

---

## 11. Spike / Sketch 探索系统

### Spike（技术可行性实验）

```bash
/gsd-spike "能否通过 SSE 流式传输 LLM tokens？"
/gsd-spike --quick "WebSocket vs SSE 延迟"
```

- 运行 2–5 个 Given/When/Then 假设验证实验
- 输出：VALIDATED / INVALIDATED / PARTIAL 判定
- 存储在 `.planning/spikes/NNN-name/`

### Sketch（视觉设计原型）

```bash
/gsd-sketch "仪表板布局"
/gsd-sketch --quick "侧边栏导航"
/gsd-sketch --text "引导流程"    # 纯文本模式
```

- 生成 2–3 个可交互的 HTML 变体
- **浏览器直接打开**，无需构建步骤
- 6 维度评估：文案、视觉、色彩、排版、间距、体验设计

### 集成到工作流

```
/gsd-spike "SSE vs WebSocket"  →  /gsd-spike-wrap-up
/gsd-sketch "实时UI"           →  /gsd-sketch-wrap-up
         ↓
/gsd-discuss-phase N           (现在已获得 spike + sketch 的结论支撑)
/gsd-plan-phase N
```

---

## 12. UAT 验证系统

### 自动验证（执行后自动运行）

- `gsd-verifier` 对比代码库与阶段目标（目标倒推分析）
- 测试质量审计：检查被禁用的测试、循环模式、弱断言
- 里程碑范围过滤：后续阶段的缺口标记为"延迟"

### 手动 UAT（`/gsd-verify-work`）

1. 从规划产物中提取可测试的交付物
2. 逐条引导你验收："能用邮箱登录吗？" 是/否
3. 失败时 → 自动生成 `gsd-debugger` + 修复计划 → 重新执行

### 安全验证

```bash
/gsd-secure-phase N    # 验证 PLAN.md 威胁模型中的缓解措施是否实现
                        # 支持 ASVS 1/2/3 级
```

### UI 验证

```bash
/gsd-ui-review    # 6支柱审计：
                  # 文案 → 视觉 → 色彩 → 排版 → 间距 → 体验设计
                  # 每项 1-4 分，给出 Top 3 优先修复项
```

---

## 13. 会话管理

### 暂停 / 恢复

```bash
/gsd-pause-work     # 创建 HANDOFF.json + continue-here.md
# ... 关闭 Claude，明天继续 ...

/gsd-resume-work    # 从 STATE.md + HANDOFF 完整恢复上下文
```

### 快速定位

```bash
/gsd-progress               # 我在哪？下一步干啥？
/gsd-progress --forensic    # 深度诊断（卡住了用这个）
```

### 会话报告

```bash
/gsd-session-report    # Token 使用量、工作总结、成果、建议
```

### 跨会话线程

```bash
/gsd-thread                    # 列出所有线程
/gsd-thread "调查TCP连接问题"   # 创建/恢复线程
```

---

## 14. 速度 vs 质量预设

| 场景 | 模式 | 颗粒度 | 模型配置 | 研究 | 计划检查 | 验证 |
|------|------|--------|---------|------|---------|------|
| 原型开发 | `yolo` | `coarse` | `budget` | 关闭 | 关闭 | 关闭 |
| 正常开发 | `interactive` | `standard` | `balanced` | 开启 | 开启 | 开启 |
| 生产项目 | `interactive` | `fine` | `quality` | 开启 | 开启 | 开启 |

**配置方式：**

```bash
/gsd-settings                    # 基础配置
/gsd-settings-advanced           # 高级配置（超时、分支策略等）
/gsd-set-profile quality         # 切换模型配置
```

---

## 15. 多工作流并行（Workstreams）

```bash
# 创建多个并行工作流
/gsd-workstreams create backend-crdt
/gsd-workstreams create frontend-presence
/gsd-workstreams create infra-websocket

# 切换工作流
/gsd-workstreams switch backend-crdt
/gsd-discuss-phase 1
/gsd-plan-phase 1
/gsd-execute-phase 1

/gsd-workstreams switch frontend-presence
/gsd-discuss-phase 1
/gsd-plan-phase 1
/gsd-execute-phase 1

# 完成工作流
/gsd-workstreams complete backend-crdt
/gsd-workstreams complete frontend-presence
```

---

## 16. 自我进化机制

### 学习提取 → 毕业晋升流水线

这是 GSD 的核心自我进化机制，三阶段闭环：

```
┌──────────────────────────────────────────────────────────────┐
│  阶段完成                                                     │
│      ↓                                                        │
│  /gsd-extract-learnings                                       │
│  → 分析: PLAN.md, SUMMARY.md, VERIFICATION.md, UAT.md        │
│  → 提取4类: 决策 / 教训 / 模式 / 意外                        │
│  → 产出: {N}-LEARNINGS.md                                     │
│      ↓                                                        │
│  下次 /gsd-plan-phase 时                                      │
│  → 自动加载最近3期的 LEARNINGS.md（占上下文15%）               │
│  → Planner 基于历史教训制定更好的计划                         │
│      ↓                                                        │
│  阶段转换时自动扫描（transition.md）                          │
│  → 用 Jaccard 相似度 (≥0.25) 聚类重复出现的教训              │
│  → 在3+个阶段反复出现的教训 → 提示"毕业"                     │
│      ↓                                                        │
│  人工确认 (HITL):                                             │
│  → P (晋升) → 写入 PROJECT.md 或 PATTERNS.md（永久规则）     │
│  → D (延迟) → 下次转换时再次提示                             │
│  → X ( dismiss ) → 永不再提示                                │
└──────────────────────────────────────────────────────────────┘
```

### 全局知识库（跨项目）

```bash
~/.gsd/knowledge/{id}.json
```

- 跨项目持久化，SHA-256 去重
- 默认关闭，需手动开启：`features.global_learnings: true`
- Planner 在规划时注入相关知识

### 用户画像

```bash
/gsd-profile-user
```

- 分析你的 Claude Code 会话历史，生成 8 维行为画像
- 产出: `USER-PROFILE.md`，持久保存在 `~/.claude/get-shit-done/`
- 维度：沟通风格、决策速度、解释深度、调试方式、UX哲学等

---

## 17. 支持的 AI 运行时

| 运行时 | 全局路径 | 本地路径 |
|--------|---------|---------|
| Claude Code | `~/.claude/` | `./.claude/` |
| OpenCode | `~/.config/opencode/` | `./.opencode/` |
| Gemini CLI | `~/.gemini/` | `./.gemini/` |
| Kilo | `~/.config/kilo/` | `./.kilo/` |
| Codex | `~/.codex/` | `./.codex/` |
| GitHub Copilot | `~/.github/` | `./.github/` |
| Cursor | `~/.cursor/` | `./.cursor/` |
| Windsurf | `~/.codeium/windsurf/` | `./.windsurf/` |
| Antigravity | `~/.gemini/antigravity/` | `./.agent/` |
| Augment | `~/.augment/` | `./.augment/` |
| Trae | `~/.trae/` | `./.trae/` |
| Qwen Code | `~/.qwen/` | `./.qwen/` |
| Cline | `~/.cline/` | `./.clinerules` |
| CodeBuddy | `~/.codebuddy/` | `./.codebuddy/` |

---

## 18. 卸载与更新

### 更新

```bash
npx get-shit-done-cc@latest    # 重新运行安装命令即可更新
```

或在 Claude Code 中：

```bash
/gsd-update    # 带变更日志预览
```

### 卸载

```bash
npx get-shit-done-cc --claude --global --uninstall
npx get-shit-done-cc --all --global --uninstall
```

---

## 19. 与其他工具对比

| 特性 | GSD | Claude Code (原生) | Cursor | Copilot |
|------|-----|-------------------|--------|---------|
| 多阶段项目管理 | ✅ 完整 | ❌ | ❌ | ❌ |
| 上下文腐烂防护 | ✅ 全新上下文/Agent | ❌ | ⚠️ 有限 | ❌ |
| 规划产物体系 | ✅ 10+ 种产物 | ⚠️ CLAUDE.md | ⚠️ .cursorrules | ❌ |
| 多 Agent 编排 | ✅ 33个专职Agent | ⚠️ 子Agent | ❌ | ❌ |
| 波次并行执行 | ✅ | ❌ | ❌ | ❌ |
| 计划质量保证 | ✅ 8维验证 | ❌ | ❌ | ❌ |
| UAT 验证 | ✅ 结构化 | ❌ | ❌ | ❌ |
| 经验学习 | ✅ 毕业流水线 | ❌ | ❌ | ❌ |
| Spike/Sketch | ✅ | ❌ | ⚠️ | ❌ |
| 跨项目记忆 | ✅ 全局知识库 | ❌ | ❌ | ❌ |
| 代码库映射 | ✅ 4并行Mapper | ❌ | ⚠️ | ❌ |
| 安全审计 | ✅ ASVS 1/2/3 | ❌ | ❌ | ❌ |
| 支持的AI工具 | 15种 | 1种 | 1种 | 1种 |

---

## 20. 日常高频命令速查表

| 我想要... | 命令 |
|-----------|------|
| 我在哪？下一步干啥？ | `/gsd-progress` |
| 随手记个想法 | `/gsd-note 刚想到的优化点` |
| 快速修个小东西 | `/gsd-fast xxx` |
| 正式做个功能（轻量） | `/gsd-quick` |
| 正式做个功能（完整） | `/gsd-discuss-phase N` → `/gsd-plan-phase N` → `/gsd-execute-phase N` → `/gsd-verify-work N` |
| 不想手动推了 | `/gsd-next` |
| 全自动干活 | `/gsd-autonomous --from 3` |
| 验证技术方案 | `/gsd-spike "xxx"` |
| 探索 UI 设计 | `/gsd-sketch "xxx"` |
| 中断后继续 | `/gsd-resume-work` |
| 暂停收工 | `/gsd-pause-work` |
| 代码出问题了 | `/gsd-debug xxx` |
| 查看项目状态 | `/gsd-stats` |
| 会话总结 | `/gsd-session-report` |
| 回滚 GSD 提交 | `/gsd-undo --last 3` |
| 代码审查 | `/gsd-code-review N` |
| 安全审计 | `/gsd-secure-phase N` |
| 提取经验教训 | `/gsd-extract-learnings N` |
| 自然语言不知道用啥命令 | `/gsd-do xxx` |
| 配置工作流 | `/gsd-settings` |
| 多项目管理控制台 | `/gsd-manager` |
