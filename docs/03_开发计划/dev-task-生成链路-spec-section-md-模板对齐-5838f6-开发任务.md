---
doc_type: dev_task
task_id: subtask-2fc3955838f6
title: dev_task 生成链路 spec_section_md 模板对齐
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpr12lsa60ac902be46d5e9b
section_id: pr3-devtask-template
order: 3
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpr12lsa60ac902be46d5e9b.json
source_draft_hash: 30c8d5e6f94d523f271eea5b66aac95406fdc8ec75b7719e677d66ddf8675ded
created_at: 2026-05-30T07:49:00.223Z
updated_at: 2026-05-30T08:28:01.923Z
updated_by: ai_session
---

# dev_task 生成链路 spec_section_md 模板对齐

## 目标

让物化产出的 dev_task 文档 body 按 `_模板_开发任务.md` 章节组织（任务概述 / 任务分解 / 验收等），落实「其他文档模板对齐」中 dev_task 这条线。dev_task 经 `materializeRequirement` 从 `spec_section_md` 生成（非纯手写）。

## 范围（plugin 生成链路，含测试）

- `[MODIFY] su-ccb-claude-plugin/lib/subtask/index.mjs`（`materializeRequirement` ~70-133,286-390）：dev_task body 由 `spec_section_md` 生成时，按开发任务模板核心章节组织（或在 body 外包裹模板骨架：任务概述 / 任务分解 / 验收标准）。
- 约定 breakdown draft 的 `spec_section_md` 写作贴合开发任务模板章节（写作规范，不改 draft schema）。

## 验收

- 物化出的 dev_task 含开发任务模板核心章节。
- dev_task frontmatter 状态机字段（current_node / status / node_substate / section_id / order…）不变。
- 现有 subtask / materialize 测试全绿。

## 边界

不改 dev_task frontmatter 状态机；不改 breakdown draft schema；不改 dispatch 逻辑。

## 依赖

无（独立线 B）。

## Materialization Context

- Requirement: cmpr12lsa60ac902be46d5e9b
- Section: pr3-devtask-template
- Owner: ccb_codex
- Priority: medium
- Dependencies: none

## 审查结论（2026-05-30 · Claude autonomous-batch review）

**通过**。Codex 实施(job_0c099a670bf7)+ Claude 自验:

- 改动:lib/subtask/index.mjs renderDevTaskBody(模板骨架包裹)+ subtask.test + su-flow / su-materialize SKILL,均在 spec 内。
- 测试:subtask 单测 12/12 自跑通过;su-flow-skill 1/1。
- 模板骨架:dev_task body = 一、任务概述 / 二、任务分解(spec 内容,标题 demote 一级)/ 三、执行顺序 / 四、进度记录 / 五、验收标准 / 六、风险,对齐 _模板_开发任务.md。
- 硬约束:dev_task frontmatter 状态机字段、breakdown draft schema、dispatch 逻辑 均未改;只影响今后物化、不回写已存在 dev_task。
