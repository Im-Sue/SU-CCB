---
doc_type: architecture
title: "SU-CCB 系统总览架构"
status: active
updated: 2026-06-02
---

# SU-CCB 系统总览架构

## 定位

SU-CCB 是 AI 工程协作框架的根容器与文档中枢。它不再承担所有子项目的构建入口，而是钉住四仓组合、保存人读文档与 CCB 工作区，并提供跨仓一致性检查。

当前稳态由 `.gitmodules` 与 ADR-0042 定义：`SU-CCB` 是根容器，`su-oriel`、`su-ccb-claude-plugin`、`su-ccb-codex-skills` 作为 submodule 嵌套在根仓 `docs/` 同级。

## 仓库边界

| 仓库 | 当前路径 | 责任 |
|---|---|---|
| `Im-Sue/SU-CCB` | `./` | `docs/` 人读文档、`docs/.ccb/` 工作区、框架文件、跨仓脚本、submodule 版本绑定 |
| `Im-Sue/SU-Oriel` | `su-oriel/` | 可选可视化控制台；本地 Fastify API、Prisma 投影库、React UI |
| `Im-Sue/su-ccb-claude-plugin` | `su-ccb-claude-plugin/` | 协议内核真相源、Claude skills、初始化模板、schema generators |
| `Im-Sue/su-ccb-codex-skills` | `su-ccb-codex-skills/` | Codex 侧 execute / consult / doc skills 与本地辅助脚本 |

根仓不承载子项目包管理。当前根下只有 `scripts/check-cross-repo.sh`、`scripts/check-prerequisites.sh`、`scripts/check-su-flow-migration.sh` 等框架/集成脚本；Oriel 的 `package.json`、`pnpm-workspace.yaml`、lockfile 均在 `su-oriel/` 内部。

## 真相分层

| 层 | 真相位置 | 说明 |
|---|---|---|
| 业务文档真相 | `docs/00_项目总览.md`、`docs/00_文档地图.md`、`docs/01_架构设计/` 到 `docs/99_归档/` | 人读文档是需求、设计、任务、决策与经验的业务事实 |
| 协调与投影输入 | `docs/.ccb/` | 事件、draft、index、schema、config、lock 等协调数据；服务 UI 与恢复，不替代人读文档 |
| 协议内核 | `su-ccb-claude-plugin/references/kernel/` | 节点、transition、guard、schema、capability、lint 工具的运行真相源 |
| 控制台投影 | `su-oriel/server/prisma/schema.prisma` + Oriel DB | 可重建索引与运行视图；不是业务真相源 |
| Codex 执行契约 | `su-ccb-codex-skills/skills/ccb-execute/` | 执行、勘探、协商、worktree、回执与验证规则 |

## 协作流

1. 用户从 Claude 入口 `/ccb:su-flow` 或 Oriel 触发操作。
2. Claude plugin 根据当前意图进入 7 个 canonical 节点之一，节点规则来自 `su-ccb-claude-plugin/references/kernel/nodes/*.node.md`。
3. plugin 通过 resolver 读取或写入项目文档、`docs/.ccb/drafts/`、`docs/.ccb/events/journal.jsonl` 等项目内事实。
4. 需要执行或独立判断时，Claude 通过 CCB ask 派给 Codex；Codex skill 读取 spec、文档和代码后按模式返回。
5. SU-Oriel 扫描项目文档与 `.ccb` 协调层，写入本地 DB 并在 Web UI 中投影为任务、节点、协商、运行与事件视图。

Console 是触发器和投影层，不是业务正文的直接写入者。业务写入应由 plugin runtime / primitive / 项目文档路径完成。

## 版本绑定与跨仓检查

整套维护者通过 submodule commit 指针绑定三子仓版本。子仓更新后，需要在根仓提交新的 submodule 指针。

跨仓一致性只在四仓齐备时运行：

- `scripts/check-cross-repo.sh`：检查 Oriel generated drift、plugin generated drift、Codex resolver 测试。
- 单仓 CI 不依赖 sibling 仓，避免单独 clone 时失败。

## 当前实现锚点

- `.gitmodules`：三子仓 submodule URL 和路径。
- `docs/06_决策记录/ADR-0042-multirepo-submodule-role-model.md`：四仓角色、submodule 容器、三 root、generator 与模板归属决策。
- `README.md`：当前 multi-repo 角色模型、上手方式与关键决策。
- `scripts/check-cross-repo.sh`：四仓集成一致性 gate。
- `su-oriel/server/src/lib/project-root.ts` 与 `su-oriel/server/src/indexer/docs-structure-resolver.ts`：Oriel sourceRoot / projectRoot / contract fallback 的运行实现。
- `su-ccb-claude-plugin/scripts/generate-*.mjs`：plugin 持有 generator，console 输出必须显式传参。
- `su-ccb-codex-skills/skills/ccb-execute/scripts/resolve-same-group-peer.mjs`：Codex 同组对端解析。

## 当前边界

- 根仓没有子项目构建入口，不能用根仓命令替代各子仓自己的 build/test。
- 跨仓 drift 与 resolver 集成检查是维护者 gate，不进入任何单仓 CI。
- Oriel 运行时不要求 sibling plugin；但 Oriel 的显式 generated 刷新脚本仍需要相邻 plugin。
- Codex resolver 的脚本实现已允许缺少 routing contract 时只按 `.ccb/ccb.config` 解析；部分 skill 文本仍有更保守的旧表述。
