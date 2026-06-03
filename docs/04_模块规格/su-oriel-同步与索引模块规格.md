---
doc_type: module_spec
title: "SU-Oriel 同步与索引模块规格"
status: active
updated: 2026-06-03
---

# SU-Oriel 同步与索引模块规格

## 1. 模块目标

同步与索引模块负责把被观测项目的 `docs` 与 `docs/.ccb` 机器层转换为 SU-Oriel 的 Prisma 投影，并把扫描、解析、同步、归并和异常记录为可观察的 `SyncJob`。它是文档中心、需求入口、任务看板和运行记录页的投影更新基础。

真实实现锚点：

- `su-oriel/server/src/indexer/project-indexer.ts`
- `su-oriel/server/src/indexer/document-parser.ts`
- `su-oriel/server/src/indexer/docs-structure-resolver.ts`
- `su-oriel/server/src/indexer/startup-project-scan.ts`
- `su-oriel/server/src/fs/file-watcher-service.ts`
- `su-oriel/server/src/modules/sync/sync.routes.ts`
- `su-oriel/server/src/modules/project/project.routes.ts`
- `su-oriel/server/prisma/schema.prisma`
- `su-oriel/web/src/pages/runs/RunsPage.tsx`
- `su-oriel/web/src/components/projects/ProjectScanProgressBar.tsx`
- `su-oriel/web/src/stores/project-store.ts`

## 2. 功能范围

| 能力 | 当前实现 |
|---|---|
| 启动扫描 | `startProjectScan` 对 `Project.syncStatus` 做抢占，创建或复用 scan job，并异步运行 `scanProject`。 |
| Markdown 扫描 | 枚举 docs structure resolver 指定的人读文档路径，跳过 machine layer 中不应扫描的缓存/资产/模板路径。 |
| 文档解析 | `parseDocument` 提取 frontmatter、标题、摘要、task key、kind、status、parse issues。 |
| 文档地图 | 写入 `doc_map` Markdown 与 `docs/.ccb/index/document-map.json`。 |
| 需求同步 | 从 requirement Markdown 同步 `Requirement` 投影，并在需求编辑后支持局部同步。 |
| 任务归并 | 从 dev_task 等文档派生 `Task` 投影，清理陈旧任务并记录 anomaly。 |
| 事件同步 | 同步 plugin event journal、需求设计文档、breakdown draft 和需求 rollup。 |
| 启动补扫 | `StartupProjectScanService` 在 server 启动时按 `lastScanAt` 与文件 mtime 判断是否补扫。 |
| 文件监听 | `FileWatcherService` 监听项目 `docs`，对 `.md` 与 breakdown draft JSON 变更做 debounce 后触发扫描。 |
| 运行记录 | `GET /api/projects/:projectId/sync-jobs` 返回项目全部 sync jobs。 |

## 3. 扫描流水线

当前 `SCAN_PHASE_PIPELINE_JOB_TYPES`：

| 阶段 | 作用 |
|---|---|
| `scan` | 枚举 Markdown、记录扫描进度、写文档地图。 |
| `parse` | upsert `Document` 投影，删除不再存在的文档。 |
| `template_conformance` | 检查文档模板符合度并记录 warning。 |
| `requirement_sync` | 同步 requirement Markdown 到 `Requirement`。 |
| `reconcile` | 从文档派生 `Task`，记录 anomaly。 |
| `plugin_journal_sync` | 同步事件流水到投影表。 |
| `requirement_design_doc_sync` | 同步需求设计文档路径/状态。 |
| `breakdown_draft_sync` | 同步拆分草案投影。 |
| `requirement_rollup` | 汇总需求状态与进度。 |

`ProjectScanProgressBar` 按当前阶段展示进度。只有 scan 阶段有确定文件计数，后续阶段显示为进行中，避免扫描中伪造 100%。

## 4. 页面组件

| 页面/组件 | 当前职责 |
|---|---|
| `RunsPage` | 展示 sync jobs 表格，支持全部/失败筛选和手动重新扫描。 |
| `ProjectScanProgressBar` | 扫描期间轮询 `/scan-status`，展示阶段、计数、完成或失败状态。 |
| `project-store` | `loadProjectData` 并行拉取 documents、tasks、requirements、syncJobs 和 indexHealth。 |
| `DocumentsPage` / `TasksBoardView` / `RequirementsPage` | 消费索引投影，不直接执行扫描逻辑。 |

## 5. 数据模型

| 模型 | 字段/关系 | 说明 |
|---|---|---|
| `SyncJob` | `jobType`、`status`、`processedCount`、`totalCount`、`logSummary`、`errorMessage` | 每个扫描阶段的可观测记录。 |
| `Project` | `syncStatus`、`lastScanAt`、`docsRoot`、`initStatus` | 项目级扫描状态和最近完成时间。 |
| `Document` | `contentHash`、`mtime`、`parseStatus`、`parseError` | 文档索引投影。 |
| `Requirement` / `Task` | 多个同步阶段写入 | 需求和任务的当前投影。 |

## 6. 接口边界

同步模块目前以项目级扫描为核心，不提供单个 sync job 的重试接口；用户侧“重新扫描项目”会重新进入整条流水线。文件监听不是增量 patch，而是 debounce 后触发项目扫描。

resolver 的契约解析顺序是显式 `CCB_DOCS_STRUCTURE_CONTRACT`、项目本地 `docs/.ccb/docs-structure-contract.yaml`、SU-Oriel 内置 fallback。扫描忽略 `docs/.ccb/index`、`docs/.ccb/locks`、文档地图和 machine layer 中的资产/上传/模板等路径。

## 7. 旧规格 vs 实际偏差

旧规格只列出“扫描、解析、归并、异常摘要、完整文件监听可后置”。真实 v1.0 已经有启动补扫、文件监听、阶段化 scan pipeline、文档地图写入、模板符合度检查、需求同步、事件流水同步、设计文档同步、拆分草案同步和需求 rollup。

旧规格未描述三 root 之后的 docs structure resolver 和内置 fallback；当前实现已经不依赖固定 monorepo 上行路径。

## 8. v1.0 校正点

- 同步结果是 SU-Oriel 的投影，不是文档真相源。
- 扫描阶段写 `SyncJob`，并通过 `Project.syncStatus` 暴露项目级状态。
- 任务状态归并读取 dev_task 文档中的 node 字段，旧阶段字段不参与写入。
- 文档地图和机器索引写在项目 `docs/.ccb` 约定位置。

## 9. 待定事项

- 是否需要 job 级 retry、cancel 或后台队列可视化，目前实现未提供。
- 文件监听触发全项目扫描，后续是否改成更细粒度增量索引需要单独设计。
