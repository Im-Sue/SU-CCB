---
doc_type: architecture
title: "su-ccb-codex-skills 架构"
status: active
updated: 2026-06-02
---

# su-ccb-codex-skills 架构

## 定位

`su-ccb-codex-skills` 是 SU-CCB 的 Codex 侧 skill pack。它不持有协议内核，也不承担项目初始化主逻辑；它提供执行、勘探、协商、文档维护、worktree 校验与同组对端解析能力。

本仓当前没有 JS package workspace。主要内容是 `skills/`、`templates/` 与少量 Node/Bash 辅助脚本。

## 目录结构

| 路径 | 责任 |
|---|---|
| `skills/ccb-execute/SKILL.md` | Codex 执行、勘探、协商主 skill |
| `skills/ccb-execute/references/` | consult / receipt / validation / bounceback / superpowers 等契约 |
| `skills/ccb-execute/scripts/resolve-same-group-peer.mjs` | 解析同组 Claude/Codex 对端 |
| `skills/ccb-execute/scripts/ccb-execute-worktree.mjs` | per-需求 worktree 校验、验证命令运行、commit guard |
| `skills/ccb-doc/SKILL.md` | 文档维护 skill |
| `skills/ccb-doc/references/` | 文档路由、catalog/index 更新参考 |
| `templates/codex-md-template.md` | 项目 AGENTS 模板 |
| `scripts/ccb-init-codex.sh` | 初始化脚本示例 |

## ccb-execute

`ccb-execute` 支持三种模式：

| mode | 行为 |
|---|---|
| `execute` | 按 spec 实施、验证、输出精简回执 |
| `explore` | 只读和轻量验证，返回现状、风险、建议切分 |
| `consult` | 只读分析，按 consult contract 输出结构化意见 |

核心参考文件：

- `references/receipt-contract.md`
- `references/consult-contract.md`
- `references/bounceback-rules.md`
- `references/validation-rules.md`
- `references/superpowers-integration.md`

Codex 的职责是执行与复核，不做需求决策、节点推进或协议扩展；这些由 Claude plugin 和 kernel 决定。

## 同组对端解析

`skills/ccb-execute/scripts/resolve-same-group-peer.mjs` 是当前实际 resolver：

1. 必读 `<projectRoot>/.ccb/ccb.config`。
2. 解析 `[windows]` 下的 `window = "agent:provider, agent:provider"`。
3. 按 provider 互补关系解析当前 agent 的唯一同组对端。
4. 结果可能是 `peer`、`ambiguous`、`no_peer`。

contract 读取是辅助校验而非硬性运行前提：

| 输入 | 行为 |
|---|---|
| 显式 `--contract <path>` | 路径缺失或内容不匹配时按错误处理 |
| 未显式 contract，项目内存在 `references/kernel/agent-routing-contract.md` | 读取并校验 marker |
| 未显式 contract，项目内存在 `su-ccb-claude-plugin/references/kernel/agent-routing-contract.md` | 读取 sibling plugin snapshot 并校验 marker |
| 两个候选都不存在 | 不抛错，仍按 `.ccb/ccb.config [windows]` 解析 |

测试位于 `skills/ccb-execute/scripts/__tests__/resolve-same-group-peer.test.mjs`，共享向量在 `references/agent-routing-test-vectors.json`。

## Worktree 执行脚本

`skills/ccb-execute/scripts/ccb-execute-worktree.mjs` 负责把 Codex 执行限制在 plugin 已准备好的 worktree 内：

| 功能 | 实现要点 |
|---|---|
| frontmatter 解析 | 读取 dev task Markdown frontmatter |
| `code_workspace` 校验 | 要求 `path` 和 `branch`；path 必须相对 canonical root |
| codeRoot 校验 | codeRoot 必须已存在且是目录；脚本不会创建 worktree |
| 分支校验 | `git -C <codeRoot> rev-parse --abbrev-ref HEAD` 必须等于声明分支 |
| 验证命令 | 从 `## 验证` 或兼容 heading 的第一个 fenced block 提取逐行命令，在 codeRoot 执行 |
| commit guard | 用 `git status -- docs/.ccb` 阻止 canonical 协调层进入 worktree commit |

这使 Codex 能在 canonical root 读 spec/docs，同时把代码编辑和验证命令约束到 codeRoot。

## ccb-doc

`skills/ccb-doc/SKILL.md` 是文档维护 skill，负责：

- 读取任务要求和项目文档路由。
- 创建或更新正确分类下的文档。
- 必要时维护 catalog/index。
- 输出更新文件清单、索引状态和待决策事项。

当前本仓只提供 skill 指令与参考文档，不自动扫描项目结构。

## 安装与增强

`README.md` 提供两种安装方式：

- skill-installer 安装 `skills/ccb-execute` 和 `skills/ccb-doc`
- 手动复制 `skills/*` 到 Codex skills 目录

Superpowers 是可选增强；`ccb-execute` 在 `superpowers-integration.md` 中区分执行模式与协商模式的适用边界。

## 当前边界

- 本仓不持有 kernel；节点、guard、transition、schema 真相在 plugin。
- README 中仍有旧组织链接，架构以 `.gitmodules` 与 ADR-0042 的 Im-Sue 仓库模型为准。
- `ccb-execute/SKILL.md` 对 routing contract 的文字比脚本实现更保守；当前运行行为以 `resolve-same-group-peer.mjs` 为准。
- `scripts/ccb-init-codex.sh` 是示例脚本，当前文本仍是提示性质，不等价于 plugin 的项目初始化实现。
