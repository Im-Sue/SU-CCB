---
doc_type: dev_task
task_id: subtask-1ef3eb90e6d0
title: Console renderer 输出 C 形态 + parser 回归
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpr12lsa60ac902be46d5e9b
section_id: pr2-requirement-c-console
order: 2
implementation_owner: ccb_codex
dependencies: [subtask-c4dc86b6fa21]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpr12lsa60ac902be46d5e9b.json
source_draft_hash: 30c8d5e6f94d523f271eea5b66aac95406fdc8ec75b7719e677d66ddf8675ded
created_at: 2026-05-30T07:49:00.223Z
updated_at: 2026-05-30T08:20:02.655Z
updated_by: ai_session
---

# Console renderer 输出 C 形态 + parser 回归

## 目标

Console 创建需求的 renderer 输出 C 形态（与 PR1 需求模板一致），保证 Console 入口建的需求也是两层并存；并回归验证 parser 对 C 文档解析正确。

## 范围（Console server，含测试）

- `[MODIFY] apps/ccb-console/server/src/indexer/project-indexer.ts`（renderer ~729-757）：渲染需求 markdown 时输出 C 形态——开头 `## 需求描述` + `## 原话（verbatim）`，文末 `## Claude 解读` / `## 歧义点` / `## 保真差异`；中间预留模板主体（无内容时给模板章节占位或留空，结构与 PR1 模板对齐）。保持 description / verbatim / 三锚点字段映射不变。
- 测试：
  - `parseRequirementSections` 对 C 文档（锚点在文末）提取 description / verbatimSource / claudeInterpretation / ambiguities / fidelityDiff 全部正确。
  - renderer 往返（render → parse）一致。
  - 旧 5 段文档解析不变（回归）。

## 验收

- Console 新建需求产出 C 形态文档。
- parser 对 C 文档 5 字段提取正确；旧文档解析不变。
- `pnpm --filter ccb-console-server typecheck` + vitest 全绿。

## 边界

不改 `parseRequirementSections` 逻辑；不改 DB 投影字段；不动 plugin lib（PR1 负责）。

## 依赖

PR1（`pr1-requirement-c-plugin`）——C 结构以 PR1 定稿的需求模板为准。

## Materialization Context

- Requirement: cmpr12lsa60ac902be46d5e9b
- Section: pr2-requirement-c-console
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-c4dc86b6fa21

## 审查结论（2026-05-30 · Claude autonomous-batch review）

**通过**。Codex 实施(job_df2c36397e93)+ Claude 自验:

- 改动:project-indexer.ts renderRequirementMarkdown 改 C 形态 + requirement-md-roundtrip.spec.ts 测试。
- 硬约束:parseRequirementSections 解析逻辑、DB 投影字段、plugin lib 均未改(已核验 diff 为空)。
- 测试:roundtrip spec 24/24 自跑通过;requirement.routes 20/20;typecheck 通过。首次 deferred scan 用例 5s 超时为既有 flaky(复跑全过、无断言失败),非本片引入。
- C 形态:开头 `## 需求描述` + `## 原话（verbatim）` → 二~十三章模块占位 → 文末 `## Claude 解读` / `## 歧义点` / `## 保真差异`,与 PR1 模板对齐;空分析字段输出空 section、parser 投影 null(不写占位入库)。
