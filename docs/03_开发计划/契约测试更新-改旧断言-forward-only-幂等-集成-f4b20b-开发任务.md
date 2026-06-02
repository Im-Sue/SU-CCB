---
doc_type: dev_task
task_id: subtask-357110f4b20b
title: 契约测试更新:改旧断言 + forward-only/幂等/集成
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: medium
requirement_id: cmpvdh2mj3f9c0e75c576e83d
section_id: pr3-contract-test-update
order: 3
implementation_owner: ccb_codex
dependencies: [subtask-93b9c8c8b30d, subtask-a43ba8f1f313]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpvdh2mj3f9c0e75c576e83d.json
source_draft_hash: b6813bc818346c9ea3b4a9628f7f1a6aeef4cf6793b6f2d1eefd5fc5d357dd43
created_at: 2026-06-01T16:24:06.946Z
updated_at: 2026-06-02T03:33:19.397Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpvdh2mj3f9c0e75c576e83d","branch":"ccb/req-cmpvdh2mj3f9c0e75c576e83d"}
---

# 契约测试更新:改旧断言 + forward-only/幂等/集成

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 更新受旧契约(绑定后仍 drafting)守护的测试,补 forward-only 矩阵、幂等与 bind/analysis 集成用例,校验 planning anchor 门控不破坏。 |
| 需求来源 | cmpvdh2mj3f9c0e75c576e83d |
| 本期范围 | pr3-contract-test-update · 契约测试更新:改旧断言 + forward-only/幂等/集成 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述
更新受旧契约守护的测试并补 D1 行为测试:契约从「绑定后仍 drafting」变为「经 su-flow 晋升 planning」。

### 任务分解
- 更新 `apps/ccb-console/server/src/modules/anchor-broker/anchor-requirement-dispatch.routes.spec.ts:139` 等断言旧契约的用例。
- 补集成测试:主流程绑定→su-flow→晋升;分析→晋升;forward-only 不降级。
- 校验 planning anchor 启动门控(drafting/planning)不被破坏。

### 验收标准
- 全部受影响测试通过;新增 forward-only / 幂等 / 集成用例通过。
- 无回归:planning anchor 启动门控行为不变。

### 边界
- 不测 D2 路径(本期不实现)。

### 依赖
pr1-promotion-outcome-mechanism, pr2-wire-d1-triggers。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-93b9c8c8b30d, subtask-a43ba8f1f313
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
- Section: pr3-contract-test-update
- Owner: ccb_codex
- Priority: medium
- Dependencies: subtask-93b9c8c8b30d, subtask-a43ba8f1f313
