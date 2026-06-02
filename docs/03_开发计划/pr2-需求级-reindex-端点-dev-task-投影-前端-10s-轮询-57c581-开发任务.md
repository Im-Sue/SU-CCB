---
doc_type: dev_task
task_id: subtask-32356f57c581
title: PR2:需求级 reindex 端点 + dev_task 投影 + 前端 10s 轮询
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpqlbcw1e06bb166ae00d341
section_id: pr2-req-scoped-reindex
order: 2
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpqlbcw1e06bb166ae00d341.json
source_draft_hash: 32e6a56cb823328e84ea9f34bfe908d10c9a5bd77910b4943f2f9fb857c69576
created_at: 2026-05-29T09:38:09.240Z
updated_at: 2026-05-29T13:00:10.764Z
updated_by: ccb_claude
---

# PR2:需求级 reindex 端点 + dev_task 投影 + 前端 10s 轮询

## 目标
需求页定时轮询「单需求」reindex(默认 10s),修 plugin 写入后投影不刷新;补现有需求级 reindex 漏掉的 dev_task/子任务投影。

## 范围
- `[NEW] 端点 POST /api/projects/:projectId/requirements/:requirementId/reindex`(`requirement.routes.ts:346` 附近,浏览器可调);**不复用 plugin-hooks**(拒浏览器 origin)、**不整项目 scan**。
- `[MODIFY] requirement-reindex.service.ts`:新增需求级 orchestrator,复用现有三段(req md `:32`/设计 `:67`/draft `:136`),**补需求级 dev_task reindex**:扫 `docs/03` 中 `doc_type=dev_task && requirement_id==rid` → upsert Document → derive/upsert 子任务。
- `[REFACTOR] project-indexer.ts:475`:抽 `upsertTaskProjectionAsync` 为可复用 helper(**保留函数名或同步 `schema-ownership-lint.ts` 特判**,避免治理 lint 误报);**不碰 `deriveTasks`/`normalizeTaskStatus`**(留 PR4)。
- `[MODIFY] console-api.ts:617` 附近加客户端;`RequirementDetailPage.tsx:543` 改「mount 立即 reindex + 10s 轮询」,hidden/unmount 停、focus 触发一次、`inFlight` 跳过重入(**本片只加轮询/reindex 调用,不碰 status consumer——留 PR4**)。
- 后端按 `projectId:requirementId` mutex/TTL debounce 串行化;解析半成品返回 partial/issue,不扩散为页面硬错。

## 验收
- 需求级 reindex 覆盖 req md + 设计 + draft + **dev_task**;dev_task 新增/更新能 upsert Document 与 Task。
- stale Task 暂只报 orphan 不删。
- 多 tab 并发只串行一次、不重复写坏。
- 前端:mount 立即 reindex、10s interval、hidden/unmount 停、in-flight 跳过。
- `pnpm --filter ccb-console-server typecheck` + 双侧 vitest 全绿;`lint:schema-ownership` 绿。

## 边界
- 只读文件更新 DB 投影,不写 canonical docs;轮询不更新文档地图机器文件(避免 churn)。
- 不改 watcher(PR2b)、不改 normalizeTaskStatus/资格门(PR4)。

## 依赖
无(独立);与 PR4 在 `project-indexer.ts`/`RequirementDetailPage.tsx` 边界已划清,PR2a 先合更稳。

## Materialization Context

- Requirement: cmpqlbcw1e06bb166ae00d341
- Section: pr2-req-scoped-reindex
- Owner: ccb_codex
- Priority: high
- Dependencies: none
