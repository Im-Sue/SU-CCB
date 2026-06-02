---
doc_type: dev_task
task_id: subtask-7422f1345148
title: server:documents list API additive 加 governance 投影
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpqiatcb7cf71d8fca2318ee
section_id: pr2-server-documents-governance-api
order: 2
implementation_owner: claude
dependencies: [subtask-1363bb52ef3b]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpqiatcb7cf71d8fca2318ee.json
source_draft_hash: ffbf787f0dcb2f5e29013ba2c7018e40faca5a97f7c5582be3add24ff642a62a
created_at: 2026-05-29T07:29:44.263Z
updated_at: 2026-05-29T08:59:08.447Z
updated_by: ccb_claude
---

# server:documents list API additive 加 governance 投影

## 目标
让 `GET /api/projects/:projectId/documents` 每个 list 项 additive 携带 `governance`,供前端派生覆盖度/健康度。

## 范围
- `[MODIFY] document.routes.ts` list 分支:取 `project.localPath` 构造 resolver;一次性 `findMany({ where:{projectId}, select:{id,status} })` 取全量 requirement 状态 ctx(**防 N+1**);对每个 document parse `frontmatterJson` → 调 pr1 `deriveDocumentGovernance` → 注入 `governance`。
- `governance` 形:`{ tier, requirementId, entityStatus, taskId, healthFlags:{parseError} }`;`healthFlags.parseError` 由 `parseStatus` 派生,**不暴露 `parseError` 原文**。
- 类型分层:`governance` **仅挂 list 响应**;detail 路由不变(配合 pr3 `DocumentBaseView`)。

## 验收
- 集成测:list 返回 `governance` 字段且形正确;既有字段形状不回归。
- **cache 缺失但 DB 有文档**仍返回 `governance`(不依赖磁盘 cache)。
- pr1(parsed requirement frontmatter)与 pr2(DB `Requirement.status`)同一 fixture 两路 `entityStatus` 结果一致。
- 不存在 `projectId` 的既有行为(返回空列表)**不被悄悄改成 404**,除非测试显式锁定该变更。
- `pnpm --filter ccb-console-server typecheck` + vitest 全绿。

## 边界
- 仅 additive,不改既有 `DocumentView` 字段、不碰 detail 阅读链路、不引依赖、不动 schema。

## 依赖
pr1(`deriveDocumentGovernance` builder)。

## Materialization Context

- Requirement: cmpqiatcb7cf71d8fca2318ee
- Section: pr2-server-documents-governance-api
- Owner: claude
- Priority: medium
- Dependencies: subtask-1363bb52ef3b
