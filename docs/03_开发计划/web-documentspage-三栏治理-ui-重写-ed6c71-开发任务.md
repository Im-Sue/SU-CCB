---
doc_type: dev_task
task_id: subtask-637abbed6c71
title: web:DocumentsPage 三栏治理 UI 重写
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpqiatcb7cf71d8fca2318ee
section_id: pr4-web-documents-governance-ui
order: 4
implementation_owner: claude
dependencies: [subtask-7748088765b0]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpqiatcb7cf71d8fca2318ee.json
source_draft_hash: ffbf787f0dcb2f5e29013ba2c7018e40faca5a97f7c5582be3add24ff642a62a
created_at: 2026-05-29T07:29:44.263Z
updated_at: 2026-05-29T09:17:57.420Z
updated_by: ccb_claude
---

# web:DocumentsPage 三栏治理 UI 重写

## 目标
把 `DocumentsPage` 从扁平列表重写为三栏文档治理中心。

## 范围
- `[REWRITE] DocumentsPage.tsx` + `DocumentsPage.module.css`:
  - **左**:按 docs 目录 + 档位(生效中/历史/归档)分组导航 + 搜索(取代扁平 doc_type chips);可折叠用本地 state 轻实现,**不引库**。
  - **中**:覆盖度卡(每需求 有设计? 有任务? 缺口高亮)+ 健康度面板(`parseError`)+ **未绑定文档一等分组**。
  - **右**:保留 `MarkdownViewer` 阅读器,从任意文档/缺口跳转 `/documents/:documentId`。
  - 复用 `Card` / `Badge` / `EmptyState` / `Skeleton`。
- 更新 pr7 改过的 filter chip e2e/acceptance snapshot(**本片内,不独立成片**)。

## 验收
- 组件测:三栏渲染、缺口高亮、parse 异常面板、未绑定分组、选中跳阅读器。
- 文案统一"文档覆盖",**不出现"进度/完成度/交付状态"等混淆词**。
- e2e snapshot 更新且语义正确;`pnpm --filter ccb-console-web test` + `tsc` 全绿。

## 边界
- 不重造 Requirements/Tasks 看板状态流转(链路只读跳转)。
- 不引树/图重依赖;不做正文编辑。

## 依赖
pr3(projection)。

## Materialization Context

- Requirement: cmpqiatcb7cf71d8fca2318ee
- Section: pr4-web-documents-governance-ui
- Owner: claude
- Priority: medium
- Dependencies: subtask-7748088765b0
