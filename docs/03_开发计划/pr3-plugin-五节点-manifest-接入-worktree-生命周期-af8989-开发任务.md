---
doc_type: dev_task
task_id: subtask-192a50af8989
title: PR3：plugin 五节点 manifest 接入 worktree 生命周期
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpimplworktree20260526
section_id: pr3-node-lifecycle-wiring
order: 3
implementation_owner: ccb_codex
dependencies: [subtask-dc853486109b, subtask-c3e3278da080]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpimplworktree20260526.json
source_draft_hash: 6245378503ccbf894e02ae637921f99189cd0d8a285ca19cb3a0d80b2ed5497b
created_at: 2026-06-01T15:13:32.005Z
updated_at: 2026-06-01T16:08:46.634Z
updated_by: slot1_claude
---

# PR3：plugin 五节点 manifest 接入 worktree 生命周期

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | dispatch（派工前 ensure）/archive（archive）/cancel（discard）等五 manifest 接入生命周期 + canonicalRoot/codeRoot 分工；正本改 + 同步副本。 |
| 需求来源 | cmpimplworktree20260526 |
| 本期范围 | pr3-node-lifecycle-wiring · PR3：plugin 五节点 manifest 接入 worktree 生命周期 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 目标
把 PR2 的生命周期 helper 接入 dispatch / implementation / batch / archive / cancel 五个 node manifest，明确 canonicalRoot vs codeRoot 分工。

### 范围
- `[MODIFY] su-ccb-claude-plugin/references/kernel/nodes/{dispatch,implementation,batch,archive,cancel}.node.md`（或主仓 `references/kernel` 正本→同步插件副本）：
  - dispatch：`ccb ask` 派工**前** `await ensureRequirementWorktree`（幂等）。
  - archive：归档前置 + `archiveRequirementWorktree`。
  - cancel：`discardRequirementWorktree`。
  - implementation/batch：声明 codeRoot 消费 + canonicalRoot 真相分工（执行细节在 PR4 codex 侧）。
- 主仓 `references/kernel` 为正本时：改正本 + 机械同步插件副本（保持单向）。

### 验收
- 五 manifest 接入点明确：首次派工触发 ensure、归档触发 archive、取消触发 discard。
- canonicalRoot/codeRoot 分工在 manifest 中可读、与 ADR-0036 不变量一致。
- 主仓正本 ↔ 插件副本一致（diff 仅分发快照）。

### 验证
```bash
python3 references/kernel/tools/lint_state.py
pnpm --filter su-ccb-claude-plugin test
```

### 边界
- 只接生命周期调用点 + 分工说明；不改 lib 本体（PR2）；**manifest 是 kernel 真相源，改动需 Claude 在 review 门把关**。

### 依赖
pr1-code-workspace-field（字段存在）+ pr2-worktree-lifecycle-lib（helper 存在）。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-dc853486109b, subtask-c3e3278da080
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
- Section: pr3-node-lifecycle-wiring
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-dc853486109b, subtask-c3e3278da080
