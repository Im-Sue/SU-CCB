---
doc_type: dev_task
task_id: subtask-a43ba8f1f313
title: 接线 D1 触发:su-flow planning 入口 promote + 分析成功 affirm
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpvdh2mj3f9c0e75c576e83d
section_id: pr2-wire-d1-triggers
order: 2
implementation_owner: ccb_codex
dependencies: [subtask-93b9c8c8b30d]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpvdh2mj3f9c0e75c576e83d.json
source_draft_hash: b6813bc818346c9ea3b4a9628f7f1a6aeef4cf6793b6f2d1eefd5fc5d357dd43
created_at: 2026-06-01T16:24:06.946Z
updated_at: 2026-06-02T03:26:44.457Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpvdh2mj3f9c0e75c576e83d","branch":"ccb/req-cmpvdh2mj3f9c0e75c576e83d"}
---

# 接线 D1 触发:su-flow planning 入口 promote + 分析成功 affirm

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 把 pr1 的 promotion outcome 接到两个触发点:su-flow planning 节点入口(D1a)与 applyRequirementAnalysis 成功后(D1b),幂等收敛。 |
| 需求来源 | cmpvdh2mj3f9c0e75c576e83d |
| 本期范围 | pr2-wire-d1-triggers · 接线 D1 触发:su-flow planning 入口 promote + 分析成功 affirm |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述
把 pr1 的 promotion outcome 接到 D1 两触发点:su-flow planning 节点入口 promote(D1a)+ `applyRequirementAnalysis` 成功后 affirm(D1b),幂等收敛。

### 任务分解
- D1b:`su-ccb-claude-plugin/lib/requirement-analysis/index.mjs` 在 applyRequirementAnalysis 成功落盘后,调用 `applyCapabilityOutcome(requirement.promote, planning, subjectRef={canonical_path, base_hash})`,已 planning 则 no-op。
- D1a:`su-ccb-claude-plugin/skills/su-flow/SKILL.md` 在 requirement_analysis / technical_design 节点入口执行同一 outcome,覆盖「主按钮绑定→派 planning anchor→su-flow 运行」的绑定路径。
- 设计触发幂等 key,避免重复 dispatch / 事件重复。

### 验收标准
- 绑定 slot 经主流程派 su-flow 后,需求 canonical 从 drafting 晋升 planning,看板进「推进中」。
- 仅执行分析后也晋升。
- 重复触发幂等,无重复事件 / 无降级。

### 边界
- 无派工的纯手动 `/bind-slot`、startup recovery 本期不晋升(D2 后续,已知缺口)。
- 不写 Console canonical。

### 依赖
pr1-promotion-outcome-mechanism。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-93b9c8c8b30d
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
- Section: pr2-wire-d1-triggers
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-93b9c8c8b30d
