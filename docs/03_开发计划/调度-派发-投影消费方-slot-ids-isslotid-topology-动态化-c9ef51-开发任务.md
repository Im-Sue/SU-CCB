---
doc_type: dev_task
task_id: subtask-a00a63c9ef51
title: 调度/派发/投影消费方 SLOT_IDS/isSlotId → topology 动态化
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmmq2a2x3p25029cbd6d21ff1
section_id: pr3-scheduler-dynamic
order: 3
implementation_owner: ccb_codex
dependencies: [subtask-a49275357378]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmmq2a2x3p25029cbd6d21ff1.json
source_draft_hash: d59d78137cdefb29c8589355c4c91fd32b4027006f16872f1b8e9e594060343a
created_at: 2026-06-06T15:09:08.542Z
updated_at: 2026-06-07T04:39:25.224Z
updated_by: slot3_claude
code_workspace: {"path":"../SU-CCB-req-cmmq2a2x3p25029cbd6d21ff1","branch":"ccb/req-cmmq2a2x3p25029cbd6d21ff1"}
---

# 调度/派发/投影消费方 SLOT_IDS/isSlotId → topology 动态化

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 七处消费方动态化：slot-binding SLOT_IDS、job-slot-router 写死 agent 名、slot.routes 过滤、anchor-dispatch-worker isSlotId、slot-terminal、取消投影 reconcile、user-intent stop-and-append。slotCount=4 行为单测验收。 |
| 需求来源 | cmmq2a2x3p25029cbd6d21ff1 |
| 本期范围 | pr3-scheduler-dynamic · 调度/派发/投影消费方 SLOT_IDS/isSlotId → topology 动态化 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
调度/派发/投影层全部 slot 集合消费方从硬编码常量改为 topology 驱动，每个调用点明确 projectId → slotCount 取数路径（DB 读取或上游传递，禁止各自缓存常量）。参照 slot-context-reset.service.ts 既有的 project_view 动态枚举模式。

#### 任务分解
1. slot-binding.service.ts：删除 `SLOT_IDS` 常量导出，绑定/释放/恢复路径改 topology（注意 SlotId 类型从字面量联合改 string + 运行时校验）。
2. job-slot-router：slotN_claude 写死 → topology.agentNamesForSlot。
3. slot.routes.ts:436 一带 queue/degraded 过滤动态化。
4. anchor-dispatch-worker.ts:159 isSlotId → topology 判定（slot-4+ 不再落 legacy anchor 分支）。
5. slot-terminal.service isSlotId 同步。
6. reconcileCancelledRequirementProjection isSlotId 同步。
7. user-intent/user-intent.routes.ts：isSlotId/SlotId 导入（:9）、绑定 slot 判定（:91）、claudeAgentForSlot 提交（:252）随 topology 驱动同步，slot-4+ 的 stop-and-append 路径不再被拒。

#### 验收标准
- slotCount=4 行为单测：第 4 个 requirement 绑定落 slot-4；worker 识别 slot-4 正常派发；slots API 返回 4 lanes；terminal/取消 reconcile/user-intent stop-and-append 接受 slot-4。
- slotCount=3 全部既有测试零修改通过（行为兼容）；isSlotId 边界单测（slot-16 接受、slot-17/slot-0/非 slot 拒绝）。

#### 边界与依赖
- 依赖：pr1（与 pr2 文件面不交叉，可在 pr2 review 期间并行实施，按门顺序回执）。
- 不实现 resize：slotCount 变更本批仅可经 DB 手改（测试场景）。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-a49275357378
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
- Section: pr3-scheduler-dynamic
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-a49275357378
