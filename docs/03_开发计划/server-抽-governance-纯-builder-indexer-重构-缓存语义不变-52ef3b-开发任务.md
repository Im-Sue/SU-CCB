---
doc_type: dev_task
task_id: subtask-1363bb52ef3b
title: server:抽 governance 纯 builder + indexer 重构(缓存语义不变)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpqiatcb7cf71d8fca2318ee
section_id: pr1-server-governance-builder
order: 1
implementation_owner: claude
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpqiatcb7cf71d8fca2318ee.json
source_draft_hash: ffbf787f0dcb2f5e29013ba2c7018e40faca5a97f7c5582be3add24ff642a62a
created_at: 2026-05-29T07:29:44.263Z
updated_at: 2026-05-29T08:52:30.608Z
updated_by: ccb_claude
---

# server:抽 governance 纯 builder + indexer 重构(缓存语义不变)

## 目标
把 document-map 派生规则抽成单一可复用纯函数,供 indexer(写 cache)与后续 documents route(pr2)共用,杜绝规则分叉;重构后 `document-map.json` 输出语义不变。

## 范围
- `[NEW] apps/ccb-console/server/src/indexer/document-governance.ts`:`deriveDocumentGovernance`(吃归一化最小 doc 形 → `{ tier, requirementId, entityStatus, taskId, healthFlags }`)+ 类型;命名归一(`requirement_id`→`requirementId`、`task_id`→`taskKey`)集中此处。
- `[REFACTOR] project-indexer.ts`:`buildDocumentMapEntries` / `deriveDocumentMapTier` / `deriveDocumentMapEntityStatus` 改调共用 builder。

## 验收
- **characterization test 先行**:固定 fixture 跑 scan,parse `document-map.json`,对 normalized JSON 做 `deepEqual`(排除顶层 `generated_at`),断言 `documents[]`、`dev_task_paths_by_task_id`、tier 排序、`null` 字段保留。
- 覆盖漂移点:`undefined` 丢字段、`task_id` fallback(dev_task)、tier 排序、缺失/非法 `updated`、parse_error 文档、未绑定 requirement 的 `entityStatus`。
- builder 单测:`requirement_id` 缺失 / 未绑定 / 各 tier / 各 entityStatus 分支。
- `pnpm --filter ccb-console-server typecheck` + vitest 全绿;onboarding-status / reconcile 既有测试不回归。

## 边界
- 不动 Prisma schema、不动 API route(pr2)、不引依赖。
- 仅重构 + 抽函数,对外行为不变。

## 依赖
无(基础片)。

## Materialization Context

- Requirement: cmpqiatcb7cf71d8fca2318ee
- Section: pr1-server-governance-builder
- Owner: claude
- Priority: medium
- Dependencies: none
