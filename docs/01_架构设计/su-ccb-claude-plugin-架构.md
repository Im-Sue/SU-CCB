---
doc_type: architecture
title: "su-ccb-claude-plugin 架构"
status: active
updated: 2026-06-02
---

# su-ccb-claude-plugin 架构

## 定位

`su-ccb-claude-plugin` 是 SU-CCB 的 Claude 侧主系统。它提供 `/ccb:su-flow` 等 skills、项目初始化、协议内核、schema generator、运行时文件写入工具和对 Codex 的路由辅助。

协议内核真相源在本仓 `references/kernel/`。Console 只做投影和触发；业务节点规则、schema、guard、transition 与 lint 以 plugin 内核为准。

## 目录结构

| 路径 | 责任 |
|---|---|
| `.claude-plugin/plugin.json`、`.claude-plugin/marketplace.json` | Claude plugin / marketplace 元数据 |
| `skills/` | Claude 侧用户入口和流程 skill |
| `references/kernel/` | 协议内核：节点、registry、schema、capability、lint、模拟工具 |
| `references/docs-structure-contract.yaml` | 默认文档结构契约 |
| `lib/` | 运行时库：文档契约、初始化、状态、draft、subtask、worktree、ask routing、safe write 等 |
| `templates/` | `CLAUDE.md` / `AGENTS.md` 模板、文档模板、hook 模板 |
| `scripts/generate-schema-validators.mjs` | 从 kernel schemas 生成 plugin validator；显式参数可生成 Oriel TS 产物 |
| `scripts/generate-capability-outcome-policy.mjs` | 从 capability outcome policy 生成 plugin policy；显式参数可生成 Oriel TS 产物 |
| `.github/workflows/kernel-lint.yml` | kernel lint CI |

## Kernel

`references/kernel/README.md` 是当前内核入口。活跃内容包括：

| 区域 | 当前文件 |
|---|---|
| 7 个节点 manifest | `nodes/requirement_analysis.node.md`、`technical_design.node.md`、`task_breakdown.node.md`、`dispatch.node.md`、`implementation.node.md`、`review.node.md`、`archive.node.md` |
| registry | `registries/transition-table.md`、`registries/guard-registry.md`、`registries/node-manifest-schema.yaml` |
| schemas | `schemas/*.schema.yaml`，覆盖 requirement、dev task、breakdown draft、anchor dispatch、plugin hook envelope、docs structure contract |
| capability | `capabilities/global.yaml`、`capability-outcome-policy.yaml`、`evidence-check-registry.yaml` |
| lifecycle | `lifecycles/requirement_lifecycle.yaml` |
| governance | `must-ask-checklist.md`、`agent-routing-contract.md`、`primitive-executor-contract.md`、`state-schema.yaml` |
| tools | `tools/lint_all.py`、`lint_manifest.py`、`lint_spec.py`、`lint_state.py`、`simulate_node.py` |

节点 manifest 当前是 Markdown 工作模式说明。每个节点采用“进入条件、核心做法、完成条件、硬约束、sc 推荐、三档样例”的 6 段结构；transition 和 guard 的注册表仍由 lint 工具消费。

## Skills

`skills/su-flow/SKILL.md` 是主入口，声明完整 7 节点集，并要求进入节点后读取对应 `.node.md`。

当前 skill 目录包括：

- 主流程：`su-flow`、`su-plan`、`su-dispatch`、`su-review`、`su-archive`、`su-resume`
- 需求与拆分：`requirement-reanalyze`、`su-materialize-requirement`、`su-revise-breakdown`
- 控制动作：`su-approve`、`su-cancel`、`su-defer`、`su-reactivate`、`su-quick-archive`、`su-reconcile`、`su-status`、`su-batch`

`su-flow` 约束 Console 是触发器，不调用 Console 业务写入接口。文档落点必须经 docs-structure resolver 定位；draft、event、state 写入走 plugin lib。

## Runtime Lib

| lib | 责任 |
|---|---|
| `lib/docs-structure/` | 解析和校验 docs structure contract；默认契约来自 plugin `references/docs-structure-contract.yaml` |
| `lib/su-init/` | 初始化项目骨架，复制 agent 文件、文档模板、契约、schema、hooks |
| `lib/runtime/` | `safeWriteFile`、hash、file lock、schema validate、event journal、hook notifier |
| `lib/requirement-analysis/` | requirement analysis 写入、promote planning、hash/CAS |
| `lib/breakdown-draft/` | breakdown draft 创建、更新、状态流转、业务规则 |
| `lib/subtask/` | dev task 物化与 event 记录 |
| `lib/worktree/` | requirement worktree lifecycle |
| `lib/ask-routing/` 与 `lib/agent-group/` | 从 `.ccb/ccb.config [windows]` 解析同组对端与 ask invocation |
| `lib/capability-outcome/` | capability outcome policy、evidence check、state effects、must-ask |
| `lib/state/`、`lib/review-status/`、`lib/reconcile/`、`lib/slot-health/` | 状态、review、reconcile 与 slot 健康辅助 |

写入路径以项目 `projectRoot` 为边界，避免由 Console DB 反向成为业务真相。

## Templates

模板真相源在 `templates/`：

- `templates/claude-md-template.md`
- `templates/codex-md-template.md`
- `templates/docs/`
- `templates/hooks/`

`lib/su-init/index.mjs` 会从 plugin 模板复制初始化产物到项目中。项目侧模板是初始化结果；后续模板源仍应回到 plugin 仓维护。

## Generator

两个 generator 都归 plugin：

| 脚本 | 默认输出 | Oriel 输出 |
|---|---|---|
| `scripts/generate-schema-validators.mjs` | plugin `lib/*/generated-validator.mjs` | 只有传 `--console-out-dir <dir>` 才写 Oriel TS validator |
| `scripts/generate-capability-outcome-policy.mjs` | plugin `lib/capability-outcome/generated-policy.mjs` | 只有传 `--console-out <path>` 才写 Oriel TS policy |

这保证 plugin 默认不认识也不写 Oriel 路径；Oriel 的 generated 刷新是显式集成动作。

## 验证入口

| 命令 | 说明 |
|---|---|
| `cd su-ccb-claude-plugin && python3 references/kernel/tools/lint_all.py` | kernel manifest / spec / state lint |
| `cd su-ccb-claude-plugin && node scripts/generate-schema-validators.mjs` | plugin validator regenerate |
| `cd su-ccb-claude-plugin && node scripts/generate-capability-outcome-policy.mjs` | plugin policy regenerate |

## 当前边界

- `registries/node-manifest-schema.yaml` 仍有历史注释文字，但当前活跃节点文件是 `nodes/*.node.md`。
- `su-plan` 仍作为 skill 目录存在；用户主入口和当前 README 指向 `/ccb:su-flow`。
- `lib/su-init/index.mjs` 当前仍会把文档模板复制到项目目录；架构上模板源归 plugin，项目副本是初始化 scaffold。
