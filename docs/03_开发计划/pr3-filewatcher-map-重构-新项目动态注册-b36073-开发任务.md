---
doc_type: dev_task
task_id: subtask-910af5b36073
title: PR3:FileWatcher Map 重构 + 新项目动态注册
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpqlbcw1e06bb166ae00d341
section_id: pr3-filewatcher-dynamic
order: 3
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpqlbcw1e06bb166ae00d341.json
source_draft_hash: 32e6a56cb823328e84ea9f34bfe908d10c9a5bd77910b4943f2f9fb857c69576
created_at: 2026-05-29T09:38:09.240Z
updated_at: 2026-05-29T13:00:10.764Z
updated_by: ccb_claude
---

# PR3:FileWatcher Map 重构 + 新项目动态注册

## 目标
修「server 启动后新建项目不被 watcher 监听」+ WSL2 inotify 漏事件,把 FileWatcherService 从一次性整批枚举重构为按项目动态注册。

## 范围
- `[REFACTOR] file-watcher-service.ts:86,103`:`watchers: Map<projectId, FSWatcher>` + `ensureProjectWatcher(projectId)`(幂等,已存在则 no-op)+ `ensureAllProjectWatchers()`;`start()` 改调 ensureAll(替代一次性枚举 + started no-op)。
- `[MODIFY] project.routes.ts:22`:项目创建后在 **route 层**调 `ensureProjectWatcher`(不放 store,避免仓储依赖 watcher)。
- 新 watcher 注册成功后触发一次 `scanProject` backfill(补 `ignoreInitial:true` 漏掉的注册前文件,`:123`)。
- (评估)WSL2 `usePolling` 兜底:若一并加,需定轮询间隔;否则记为后续。本片至少先解决动态注册。

## 验收
- 新建项目后 `watchers` Map 含新 projectId;向新项目写文件 → 投影更新(无需手动 scan)。
- `start/stop` 幂等;不对同一 project 重复注册(否则同文件多次入 `DebouncedPathQueue`,`:157`)。
- 注册后 backfill 扫一次,注册前已写文件不丢。
- `file-watcher.spec.ts` 扩充并全绿;`pnpm --filter ccb-console-server typecheck` 绿。

## 边界
- 只动 watcher 生命周期;不碰 reindex 链路(PR2a)、不碰状态模型。

## 依赖
无(独立,可与 PR1/PR2a/PR3 并行)。

## Materialization Context

- Requirement: cmpqlbcw1e06bb166ae00d341
- Section: pr3-filewatcher-dynamic
- Owner: ccb_codex
- Priority: medium
- Dependencies: none
