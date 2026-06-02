---
doc_type: dev_task
task_id: subtask-f736ef472be5
title: technical_design 写作规范 + Console 非阻断 template_conformance
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpr12lsa60ac902be46d5e9b
section_id: pr4-conformance-lint
order: 4
implementation_owner: ccb_codex
dependencies: [subtask-c4dc86b6fa21, subtask-2fc3955838f6]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpr12lsa60ac902be46d5e9b.json
source_draft_hash: 30c8d5e6f94d523f271eea5b66aac95406fdc8ec75b7719e677d66ddf8675ded
created_at: 2026-05-30T07:49:00.223Z
updated_at: 2026-05-30T13:38:35.558Z
updated_by: ai_session
---

# technical_design 写作规范 + Console 非阻断 template_conformance

## 目标

technical_design 写作规范化 + Console 加**非阻断**模板符合度校验，覆盖各 doc_type 是否按模板核心章节产出，但绝不阻断投影。

## 范围（manifest/SKILL + Console server，含测试）

- `[MODIFY] technical_design / task_breakdown 节点 manifest 或 SKILL`：写作按 `_模板_技术设计.md` 章节规范（设计概述 / 方案与架构 / 测试策略等）。
- `[NEW] Console template_conformance 校验`：检查文档是否含对应 doc_type 模板核心必填章节；warning 级，写入**独立字段 / 独立 sync warning**(注:`Document` 表当前仅 `parseStatus / parseError`,无 template_conformance 字段 → 实施时定:新增 migration 字段 或 sync-level warning)，**不**进 `parseIssues` / `parseStatus`；容忍复杂度自适应（「用不上的段删掉」不算缺失）。
- 章节白名单按 doc_type 配置（requirement / technical_design / dev_task）。

## 验收

- 缺核心章节的文档标 conformance warning，但投影**不被跳过**（dev_task / design `parseStatus === success` 仍正常投影）。
- 章节白名单可配；复杂度自适应删段不误报。
- `pnpm --filter ccb-console-server typecheck` + vitest 全绿。

## 边界

不接入 `parseStatus` / `parseIssues`；不阻断、不强制；不改投影字段。

## 依赖

PR1（`pr1-requirement-c-plugin`）——需求模板定稿后才能定 requirement 章节白名单;PR3（`pr3-devtask-template`）——dev_task conformance 须待其模板对齐后再校验,避免误报旧物化产物。

## Materialization Context

- Requirement: cmpr12lsa60ac902be46d5e9b
- Section: pr4-conformance-lint
- Owner: ccb_codex
- Priority: medium
- Dependencies: subtask-c4dc86b6fa21, subtask-2fc3955838f6
