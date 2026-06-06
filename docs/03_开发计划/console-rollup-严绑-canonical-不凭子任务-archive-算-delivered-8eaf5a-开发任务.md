---
doc_type: dev_task
task_id: subtask-76e8328eaf5a
title: Console rollup 严绑 canonical（不凭子任务 archive 算 delivered）
status: reviewing
current_node: dispatch
node_substate: awaiting_codex_pickup
priority: medium
requirement_id: cmpworktreearchive260604
section_id: pr3-console-rollup-canonical
order: 3
implementation_owner: ccb_codex
dependencies: [subtask-cef1146edf96]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpworktreearchive260604.json
source_draft_hash: 0d9d990c7e64a4f3fbee2476deb0e7adac5d696afba2fc3dd0557b74752a53ba
created_at: 2026-06-06T08:12:35.133Z
code_workspace: {"path":"../SU-CCB-req-cmpworktreearchive260604","branch":"ccb/req-cmpworktreearchive260604"}
---

# Console rollup 严绑 canonical（不凭子任务 archive 算 delivered）

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | progress-aggregation.ts 全子任务 archive 但 canonical 非 delivered 时算 delivering、delivered 只镜像 canonical + spec。 |
| 需求来源 | cmpworktreearchive260604 |
| 本期范围 | pr3-console-rollup-canonical · Console rollup 严绑 canonical（不凭子任务 archive 算 delivered） |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
修 Console rollup 语义漂移：`progress-aggregation.ts` 不再仅凭「全子任务 archive」算 `delivered`，`delivered` 严绑 canonical `Requirement.status`。依据技术设计 §三决策（claim4 收窄：web 已用 canonical、无 UI 误报，但投影层 `rollupStatus` 会提前 delivered）/§五。

#### 任务分解
1. `su-oriel/server/src/modules/task/progress-aggregation.ts`：`computeRequirementAggregation` 的 `computedStatus` 逻辑——全子任务 `currentNode==archive` 但 canonical 非 `delivered` 时算 `delivering`（**不算 `delivered`**）；`delivered` 只镜像 canonical。
2. 补/改 `progress-aggregation.spec.ts`：全 archive + canonical `delivering` → `delivering`；canonical `delivered` → `delivered`。
3.（可选，非必须）派生标签「已合并待归档」仅子任务级展示，不改 canonical（按 §三决策5）。

#### 验收标准
- [ ] 全子任务 archive 但 requirement canonical=`delivering`（merged 待归档）→ rollup **不报 `delivered`**。
- [ ] canonical=`delivered` → rollup `delivered`。
- [ ] spec 绿；su-oriel typecheck / web 不回归。

#### 边界 / 不做
- 不碰 plugin lib/manifest；不改 canonical 写入路径（rollup 只读派生）；不做 UI 按钮。

#### 依赖 / 执行注意
- 依赖 **PR1**（语义前提）。**独立于 PR2 可实施**（canonical-bound 在 A 阶段 finalize→delivered 与 B 阶段 merged+delivering 都正确）；建议 PR2 后校验最终语义。
- su-oriel 是 submodule；勿在主仓跑 server test（`db:prepare` 清 dev.db）。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-cef1146edf96
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
- Section: pr3-console-rollup-canonical
- Owner: ccb_codex
- Priority: medium
- Dependencies: subtask-cef1146edf96
