---
doc_type: architecture
title: "SU-Oriel 后端架构"
status: active
updated: 2026-06-02
---

# SU-Oriel 后端架构

## 定位

SU-Oriel 后端是本地控制台的 API、索引、投影和轻量触发层。它以项目文件为真相，从被观测项目的 `docs/` 与 `docs/.ccb/` 读取事实，写入本地 Prisma/SQLite 投影库，并向前端暴露项目、文档、任务、节点、协商、事件、终端和设置接口。

后端包名为 `su-oriel-server`，位于 `su-oriel/server/`。普通 build/test 不需要 sibling 仓；显式 generated 刷新和跨仓 drift 检查才会调用相邻 plugin 的 generator。

## 目录结构

| 路径 | 责任 |
|---|---|
| `su-oriel/server/src/app.ts` | Fastify app 组装、CORS/multipart/websocket、路由注册、file watcher 与启动扫描生命周期 |
| `su-oriel/server/src/index.ts` | 服务启动入口 |
| `su-oriel/server/src/db/prisma.ts` | Prisma client |
| `su-oriel/server/prisma/schema.prisma` | SQLite 投影库模型 |
| `su-oriel/server/src/indexer/` | 文档契约解析、扫描、frontmatter/body 解析、任务与需求投影 |
| `su-oriel/server/src/lib/project-root.ts` | 被观测项目根发现 |
| `su-oriel/server/src/modules/` | API 领域模块 |
| `su-oriel/server/src/generated/` | 已提交的 TS validators / policy 产物 |
| `su-oriel/server/scripts/` | 本地维护脚本、DB rehydrate、schema ownership lint、prompt template 校验 |

## 三 root

后端当前实际采用三类 root：

| root | 当前实现 | 用途 |
|---|---|---|
| sourceRoot | 模块自身路径与 `su-oriel/server/` | Prisma DB、dist、scripts、内置 fallback contract、server 自身资源 |
| projectRoot | `resolveCcbProjectRoot()`：`CCB_PROJECT_ROOT` 优先，否则从启动路径向上查找 `.ccb/` | 被观测 CCB 项目的 docs、`.ccb/ccb.config`、prompt、事件、draft、文档产物 |
| contractRoot | `CCB_DOCS_STRUCTURE_CONTRACT` 显式路径；否则项目本地契约；否则 Oriel bundled fallback | 文档类型、落点、模板、机器层路径解析 |

契约解析实现位于 `su-oriel/server/src/indexer/docs-structure-resolver.ts`：

1. 显式 `CCB_DOCS_STRUCTURE_CONTRACT`
2. `<projectRoot>/docs/.ccb/docs-structure-contract.yaml`
3. `su-oriel/server/src/indexer/default-docs-structure-contract.yaml`

默认 fallback 不猜相邻 plugin，因此单独 clone Oriel 也能启动和扫描。

## Fastify 模块边界

`app.ts` 注册的模块大致分为五组：

| 组 | 主要模块 |
|---|---|
| 项目与索引 | `project`、`project-onboarding`、`document`、`sync`、`settings` |
| 需求与任务投影 | `requirement`、`breakdown-draft`、`task`、`tasks`、`task-run`、`task-event-view`、`sprint` |
| 节点与协议投影 | `kernel`、`transitions`、`noderuns`、`capabilities`、`primitive`、`events`、`hooks`、`plugin-hooks` |
| 协作与 agent 控制 | `consult-requests`、`ccb-bridge`、`executor-profile`、`role-profile`、`user-intent`、`pending-interactions` |
| 本地运行面 | `ai-cli`、`ai-tools`、`anchor-*`、`slot-*`、`workspace`、`ccbd-client`、`checkpoints` |

接口职责是投影和受控触发。状态突变应通过 primitive wrapper、schema 校验、CAS/hash 或明确的服务边界完成。

## Prisma 投影模型

`schema.prisma` 当前实体可分为：

| 类别 | 模型 |
|---|---|
| 项目与设置 | `Project`、`ProjectSettings` |
| 文档/任务/需求 | `Document`、`Task`、`Requirement`、`RequirementEditAudit`、`SyncJob` |
| 节点运行与事件 | `EventJournal`、`NodeRun`、`CapabilityStatus`、`ReviewIntent`、`ConsultRequest`、`UserIntent` |
| 执行与 worktree | `TaskRun`、`TaskWorkspace`、`TaskCheckpoint` |
| anchor / slot | `AnchorAllocation`、`AnchorDispatchQueue`、`SlotBinding` |
| 审计与 primitive | `HookAuditLog`、`PrimitiveAudit` |
| profile / UI 组织 | `ExecutorProfile`、`RoleProfile`、`AiCliSetting`、`Sprint` |

`Task` 已以 `currentNode`、`nodeSubstate`、`runtimeState`、`lastTransitionId` 承接节点投影；`Document` 和多数派生字段归 `console-projection`；dev task / requirement 等核心字段标注为 plugin canonical。

## 索引链路

主要链路位于 `su-oriel/server/src/indexer/project-indexer.ts`：

1. 读取 project 的 `localPath`。
2. 通过 `getDocsStructureResolverForProject(project.localPath)` 解析文档契约。
3. 扫描 human docs，跳过机器层中不应进入文档中心的路径。
4. `document-parser.ts` 解析 frontmatter、正文摘要、需求 section 与任务字段。
5. 同步 `Document`、`Task`、`Requirement`、`SyncJob`、`EventJournal` 等投影。
6. 扫描 `docs/.ccb/drafts/breakdown/` 与 `events/journal.jsonl`，补充 breakdown、node、capability、activity 投影。

项目扫描进度通过 `SCAN_PHASE_PIPELINE_JOB_TYPES` 和 SyncJob 投影到前端进度条。

## Generated 与 schema ownership

`su-oriel/server/src/generated/` 中的 TS validator / policy 是提交产物，普通 `pnpm build` 只使用这些文件。

显式刷新脚本位于 `su-oriel/server/package.json`：

- `generate:validators` 调用相邻 plugin 的 `scripts/generate-schema-validators.mjs --console-out-dir src/generated`
- `generate:capability-policy` 调用相邻 plugin 的 `scripts/generate-capability-outcome-policy.mjs --console-out ...`
- `check:generated-drift` 重生后检查 `server/src/generated` diff

schema ownership lint 入口为 `su-oriel/server/scripts/lint-schema-ownership.ts` 与 `su-oriel/references/schema-ownership-matrix.yaml`。

## 验证入口

| 命令 | 说明 |
|---|---|
| `cd su-oriel && pnpm --filter su-oriel-server build` | Prisma generate + TypeScript build |
| `cd su-oriel && pnpm --filter su-oriel-server test` | main anchor lint、DB prepare、Prisma generate、Vitest |
| `cd su-oriel && pnpm --filter su-oriel-server lint:schema-ownership` | schema ownership lint |
| `cd su-oriel && pnpm --filter su-oriel-server check:generated-drift` | 需要相邻 plugin 的 generated drift 检查 |

## 已知边界

- `requirement-edit.service.ts` 的 `findRequirementMarkdown()` 当前仍调用默认 resolver，而不是 project resolver；多契约项目下存在读错目录的风险。
- `ai-cli.cwd.ts` 在未传 `projectId` 时回落 `process.cwd()`；这符合当前代码注释，但与“默认总是 projectRoot”不同。
- `document-parser.ts` 的默认参数仍是默认 resolver；项目扫描路径已传 project resolver，直接调用时需要注意上下文。
- generated 刷新脚本不是单仓运行时依赖，但在维护者四仓布局下才完整可用。
