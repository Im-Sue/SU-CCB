---
doc_type: dev_task
task_id: subtask-dc853486109b
title: PR1：plugin 字段地基（code_workspace schema + 物化盖 path/branch）
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpimplworktree20260526
section_id: pr1-code-workspace-field
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpimplworktree20260526.json
source_draft_hash: 6245378503ccbf894e02ae637921f99189cd0d8a285ca19cb3a0d80b2ed5497b
created_at: 2026-06-01T15:13:32.005Z
updated_at: 2026-06-01T15:31:18.554Z
updated_by: slot1_claude
---

# PR1：plugin 字段地基（code_workspace schema + 物化盖 path/branch）

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | dev-task.schema 加 optional code_workspace + 重生 validator；su-materialize 物化盖 path/branch（仅声明，target_branch/base_sha 留 ensure 写）。 |
| 需求来源 | cmpimplworktree20260526 |
| 本期范围 | pr1-code-workspace-field · PR1：plugin 字段地基（code_workspace schema + 物化盖 path/branch） |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 目标
为 per-需求 worktree 打字段地基：`dev-task.schema.yaml` 新增 **optional** `code_workspace` 对象并重生 validator；`su-materialize` 物化子任务时盖 `code_workspace{path,branch}`（**仅声明，不物理建**）。

### 范围
- `[MODIFY] su-ccb-claude-plugin/references/kernel/schemas/dev-task.schema.yaml`：加 optional `code_workspace`（`path`/`branch` 必填字符串，`target_branch`/`base_sha` optional——后两者运行态优先，见技术设计决策 5）。
- `[MODIFY] scripts 重生 validator`（`pnpm run generate:validators`）：plugin + console 双产物，未知字段策略对齐（code_workspace 为已知 optional）。
- `[MODIFY] su-ccb-claude-plugin/lib/subtask/index.mjs`（frontmatter 区 ~L142-191）：物化盖 `path=../SU-CCB-req-<reqId>`、`branch=ccb/req-<reqId>`；**不盖 target_branch/base_sha**。

### 验收
- 新物化子任务 spec frontmatter 含 `code_workspace{path,branch}`；validator 接受含/不含该字段两种（optional 不破坏存量）。
- 存量 dev_task（无字段）validator 仍通过；不回填存量。
- codegen 产物无手改残留；schema-ownership lint 绿。

### 验证
```bash
pnpm run generate:validators
pnpm --filter su-ccb-claude-plugin test
pnpm run lint:schema-ownership
```

### 边界
- 只加 optional 字段 + 盖 path/branch；不盖 target_branch/base_sha；不改其它 frontmatter 字段；不回填存量。

### 依赖
无（基础片，先落）。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-01 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpimplworktree20260526
- Section: pr1-code-workspace-field
- Owner: ccb_codex
- Priority: high
- Dependencies: none
