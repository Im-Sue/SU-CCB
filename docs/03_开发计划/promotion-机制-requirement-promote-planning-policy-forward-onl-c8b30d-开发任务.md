---
doc_type: dev_task
task_id: subtask-93b9c8c8b30d
title: promotion 机制:requirement.promote:planning policy + forward-only guard + capability + codegen
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpvdh2mj3f9c0e75c576e83d
section_id: pr1-promotion-outcome-mechanism
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpvdh2mj3f9c0e75c576e83d.json
source_draft_hash: b6813bc818346c9ea3b4a9628f7f1a6aeef4cf6793b6f2d1eefd5fc5d357dd43
created_at: 2026-06-01T16:24:06.946Z
updated_at: 2026-06-02T03:17:11.237Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpvdh2mj3f9c0e75c576e83d","branch":"ccb/req-cmpvdh2mj3f9c0e75c576e83d"}
---

# promotion 机制:requirement.promote:planning policy + forward-only guard + capability + codegen

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 建 drafting→planning 晋升基础件:新增 enabled policy、注册 forward-only executable guard、注册 requirement.promote capability、重生成两端 generated policy。 |
| 需求来源 | cmpvdh2mj3f9c0e75c576e83d |
| 本期范围 | pr1-promotion-outcome-mechanism · promotion 机制:requirement.promote:planning policy + forward-only guard + capability + codegen |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述
新增 `requirement.promote:planning` capability-outcome 机制(D1 基础件,pr2 触发点依赖):policy + forward-only guard + capability 注册 + 两端 generated policy 重生成。

### 任务分解
- 在 `su-ccb-claude-plugin/references/kernel/capability-outcome-policy.yaml` 新增 enabled policy `requirement.promote:planning:requirement`:capability_id `requirement.promote`、outcome_type `planning`、write_target `requirement_md`、state_effects `status: set:planning`、evidence kind A `hash_matches`、guards `[no_self_referential_event, requirement_promote_forward_only]`。
- 在 `su-ccb-claude-plugin/lib/capability-outcome/index.mjs` 注册 executable guard `requirement_promote_forward_only`:要求 canonical_path + expectedHash/base_hash;当前 md status `drafting→planning` 允许、`planning` 幂等 no-op、`delivering|delivered|deferred|cancelled` 拒绝/no-op。
- 注册新 capability `requirement.promote` 到 **kernel/global capability registry**(不是 `docs/.ccb/config/capabilities.project.yaml`,后者仅 project override),与现有 requirement.* capability 对齐。
- 运行 `scripts/generate-capability-outcome-policy.mjs` 重生成 server 与 plugin 两端 generated policy。

### 验收标准
- guard 单测全状态矩阵:drafting→planning 通过;planning 幂等;delivering/delivered/deferred/cancelled 被拒不覆盖。
- **真实 `applyCapabilityOutcome` 写 md 集成测试**(非仅 guard 单测):drafting→planning 落盘、planning 幂等、终态不覆盖、缺/错 hash 拒绝、policy resolve 成功。
- evidence 用 CAS `hash_matches`,不依赖 schema_valid(分析前 md 无 analysis hash 仍可晋升)。
- 两端 generated policy 与 yaml 源一致(codegen 无 diff)。

### 边界
- 不接线触发点(pr2 做);不改 Console(D2 后续)。
- 不复用会放过 delivering 的 `requirement_not_cancelled_or_deferred`。

### 依赖
无(基础件)。

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

- Requirement: cmpvdh2mj3f9c0e75c576e83d
- Section: pr1-promotion-outcome-mechanism
- Owner: ccb_codex
- Priority: high
- Dependencies: none
