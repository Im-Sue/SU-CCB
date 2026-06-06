---
doc_type: dev_task
task_id: subtask-943f772e1420
title: ADR-0036 修订 + plugin 分发副本/指针同步
status: reviewing
current_node: dispatch
node_substate: awaiting_codex_pickup
priority: medium
requirement_id: cmpworktreearchive260604
section_id: pr4-adr-distribution-sync
order: 4
implementation_owner: ccb_codex
dependencies: [subtask-cef1146edf96, subtask-e2777258a4e1, subtask-76e8328eaf5a]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpworktreearchive260604.json
source_draft_hash: 0d9d990c7e64a4f3fbee2476deb0e7adac5d696afba2fc3dd0557b74752a53ba
created_at: 2026-06-06T08:12:35.133Z
code_workspace: {"path":"../SU-CCB-req-cmpworktreearchive260604","branch":"ccb/req-cmpworktreearchive260604"}
---

# ADR-0036 修订 + plugin 分发副本/指针同步

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 修订 ADR-0036(merged/reopen/手动归档,merged 非终态) + 同步 kernel 真相源到分发副本/submodule 指针。不 carry 运行时 manifest。 |
| 需求来源 | cmpworktreearchive260604 |
| 本期范围 | pr4-adr-distribution-sync · ADR-0036 修订 + plugin 分发副本/指针同步 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
固化决策与分发：修订 ADR-0036（新增 `merged` 中间态、`merged→ready` reopen、合并后预览式手动归档；`merged` 非终态）+ 同步 plugin distribution kernel 副本 / submodule 指针。**不 carry 任何运行时 manifest 修正**（那些随 PR1/PR2 行为改）。依据技术设计 §八/变更记录，及 Codex 明确（PR4 只做 ADR/主仓文档/分发副本/指针）。

#### 任务分解
1. `docs/06_决策记录/ADR-0036-*.md`：修订记录新状态机（`missing→ready→merged→archived` + `ready→discarded` + `merged→ready` reopen）、合并后预览式手动归档、`finalize` 绑手动 cleanup 之后、canonical-sync-commit allowlist 决策；标注 amends 关系（merged 不再近终态）。
2. **plugin distribution kernel 副本同步**：主仓 `references/kernel/` 真相源（worktree/evidence/manifest 改动）→ 下游 distribution snapshot hard-copy 一致。
3. submodule 指针 bump（如涉及）。

#### 验收标准
- [ ] ADR-0036 反映最终设计，与技术设计/代码一致。
- [ ] kernel 真相源与分发副本一致（无漂移）。
- [ ] **仅文档/副本/指针，无运行时 manifest 行为改动混入**。

#### 边界 / 不做
- 不改任何 lib/manifest 运行时行为（PR1/PR2 已做）；不碰 Console。

#### 依赖 / 执行注意
- 依赖 **PR1+PR2+PR3 定稿**（最后做）。
- 跨主仓 + plugin submodule；回执分列两 repo 状态。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-cef1146edf96, subtask-e2777258a4e1, subtask-76e8328eaf5a
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-06 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpworktreearchive260604
- Section: pr4-adr-distribution-sync
- Owner: ccb_codex
- Priority: medium
- Dependencies: subtask-cef1146edf96, subtask-e2777258a4e1, subtask-76e8328eaf5a
