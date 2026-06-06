---
doc_type: dev_task
task_id: subtask-a49275357378
title: ProjectSlotTopology 纯计算服务 + Prisma schema 两字段
status: reviewing
current_node: implementation
node_substate: implementing
priority: high
requirement_id: cmmq2a2x3p25029cbd6d21ff1
section_id: pr1-slot-topology-schema
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmmq2a2x3p25029cbd6d21ff1.json
source_draft_hash: d59d78137cdefb29c8589355c4c91fd32b4027006f16872f1b8e9e594060343a
created_at: 2026-06-06T15:09:08.542Z
updated_at: 2026-06-06T15:21:58.467Z
updated_by: slot3_claude
code_workspace: {"path":"../SU-CCB-req-cmmq2a2x3p25029cbd6d21ff1","branch":"ccb/req-cmmq2a2x3p25029cbd6d21ff1"}
---

# ProjectSlotTopology 纯计算服务 + Prisma schema 两字段

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 新建 slot-topology 模块（slotIds/agent-window 命名/managed 集合派生，1..16 边界）+ Project.slotCount Int @default(3) + slotAgentOverridesJson String? + migration + 单测。 |
| 需求来源 | cmmq2a2x3p25029cbd6d21ff1 |
| 本期范围 | pr1-slot-topology-schema · ProjectSlotTopology 纯计算服务 + Prisma schema 两字段 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
新建 `server/src/modules/slot-topology/` ProjectSlotTopology 纯计算服务：给定 slotCount 派生 slotIds、每 slot 的 agent 名（slotN_claude/slotN_codex）、window 名、managed window/agent 全集与 AGENT_CORE 映射（main 组恒定 + 业务 slot 动态）。无 IO、无状态。同批落 Prisma schema：`Project.slotCount Int @default(3)`、`Project.slotAgentOverridesJson String?`（遵循本仓 String ...Json 列惯例）+ migration（add-column-with-default，非破坏）。

#### 任务分解
1. topology 模块：`slotIds(slotCount)` / `agentNamesForSlot(slotId)` / `managedWindowNames(slotCount)` / `managedAgentNames(slotCount)` / `agentCore(slotCount)`；入参校验 1 ≤ slotCount ≤ 16（防御常量集中此处）。
2. Prisma schema 两字段 + migration 文件（不在本批执行到共享库，执行点 dispatch 审批）。
3. 单测：slotCount=3 派生的集合/命名与 managed-config.service.ts 现硬编码常量逐项一致；slotCount=1/4/16 形态正确；0/17 抛错。

#### 验收标准
- topology(3) 集合/命名与现 MANAGED_WINDOW_NAMES/MANAGED_AGENT_NAMES/AGENT_CORE 一致（单测断言，注意是集合一致不是 config 字节级——字节级在 pr2）。
- 边界行为单测全绿；migration 可应用可回滚；typecheck + 既有测试全绿。

#### 边界与依赖
- 依赖：无。
- 不改任何现有消费方（managed-config/slot-binding 等本批零接触）；纯新增。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
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

- Requirement: cmmq2a2x3p25029cbd6d21ff1
- Section: pr1-slot-topology-schema
- Owner: ccb_codex
- Priority: high
- Dependencies: none
