---
task_id: subtask-b4ec616f3aba
title: P2 杀状态文档模型
doc_type: dev_task
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmppm45yt09j35fx6e2
section_id: pr3-kill-state-doc-model
order: 3
implementation_owner: claude
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmppm45yt09j35fx6e2.json
source_draft_hash: 2b4787f460f744188fe087b491beaae99f1d9665d4e47935076e05287b597e94
created_at: 2026-05-28T13:00:00.000Z
updated_at: 2026-05-29T12:00:00.000Z
updated_by: ccb_claude
---

# P2 杀状态文档模型

> 一句话:UI 不再假设有独立"状态文档",真相重指 docs/03 dev_task frontmatter。

## 范围(web 主导 + 耦合的小 server 端点移除)
- web 删 `stateProjection`/`statePath`、AlertStrip"数据已过期"、AdvancedDrawer"状态源" → 重指 docs/03 dev_task 文档本身。
- 删 `refresh-stale-projections`/`refresh-projection` 入口 + index-health `staleState` 字段(server 已 stub 0)+ `state-projection` stub。
- Overview "State drift" 卡换真实健康(解析失败 / 投影滞后 / dispatch 失败)。
- Documents 删 "实时状态文档(kind=state)" banner。

## 触及
web:`task-detail-v2` / `OverviewPage` / `DocumentsPage` ｜ server:`project.routes`(index-health)/`state-projection`

## 验收
- [x] task 级 stateProjection/statePath 残留清除,任务详情直读 docs/03 dev_task(AdvancedDrawer "真相源文档")
- [x] refresh-projection(task 级)端点/客户端/state-projection task 函数移除,前后端无 404/报错
- [x] web 构建 + 关键页面可用(web 222 / server 556 测试绿,typecheck 绿)
- [x] 项目级 drift 簇已清(Overview 接手时一并做):删 `staleStateCount*`/`staleTaskIds*` 字段 + `refresh-stale-projections` 端点 + `TasksBoardView` stale 板 + Overview "State drift" 卡 + `state-projection.ts` 项目级桩(整文件删)

## 注
(更新 2026-05-29)原以为 Overview 是用户未提交改版;经用户确认**非其在跟进**(`.ccb/ccb.config` 才是用户改的,已不碰)→ Claude 直接接手 Overview,drift 簇已在后续 commit 一并清完,本任务无遗留延后项。

## Materialization Context
- Requirement: cmppm45yt09j35fx6e2 ｜ Section: pr3-kill-state-doc-model ｜ Owner: claude(web UI/UX)｜ Priority: high ｜ Deps: 无

## 审查结论(2026-05-29 · Claude 自实施 + 自验)
- **已交付(task 级状态文档模型死透)**:
  - web:`types/task.ts` 删 `TaskStateProjectionView` / `TaskDetailView.{statePath,stateProjection,stateProjectionStatus}` / `RefreshTaskProjectionResponse`;`AlertStrip` 删"数据已过期"漂移告警;`AdvancedDrawer` "状态源"→"真相源文档"(改读 `linkedDocuments` kind=dev_task → docs/03 真相源);`TaskDetailFullPage` 删 projection badge;`TaskDetailPage` 拆 projection 刷新接线;`console-api` 删 `refreshTaskProjection`;`DocumentsPage` 删 "实时状态文档(kind=state)" banner。
  - server:`state-projection.ts` 删 `computeTaskStateProjection`/`refreshTaskStateProjection`/`StateProjectionStatus` 及全部 task 级私有 helper(仅留项目级 0 桩);`task.routes` 删 task detail 的 `statePath`/`stateProjection`/`stateProjectionStatus` + `/api/tasks/:id/refresh-projection` 端点。
  - 测试收口:删被删函数的专测(indexer-merge / primitive-wrapper)、改 fixture、e12 snapshot 重生成(仅去 projection badge,diff 干净)。
- **验证**:web `tsc --noEmit` 绿 + 222 测试绿(41 文件);server typecheck 绿 + 556 测试绿(94 文件)+ schema-ownership lint 0 failure。
- **项目级 drift 簇已清(2026-05-29 后续 commit · Claude 接手 Overview)**:用户确认 Overview 改动非其在跟进 → Claude 接手,一并删 `ProjectIndexHealthView.staleStateCount*`/`staleTaskIds*` + `/api/projects/:id/refresh-stale-projections` 端点 + `refreshStaleProjections` 客户端 + `TasksBoardView` projection=stale 板 + `OverviewPage` "State drift" 卡 + `state-projection.ts`(整文件删,无 importer)。web 220 / server 552 测试绿、双 typecheck 绿、schema-ownership 0 fail;`.ccb/ccb.config`(用户团队配置)未动。
