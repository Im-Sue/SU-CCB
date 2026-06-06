---
doc_type: dev_task
task_id: subtask-a0e7528d9308
title: API 类型对齐 + lint 参数化 + specs 同步（工程收尾）
status: reviewing
current_node: dispatch
node_substate: awaiting_codex_pickup
priority: medium
requirement_id: cmmq2a2x3p25029cbd6d21ff1
section_id: pr6-engineering-finalize
order: 6
implementation_owner: ccb_codex
dependencies: [subtask-288cf7baa646]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmmq2a2x3p25029cbd6d21ff1.json
source_draft_hash: d59d78137cdefb29c8589355c4c91fd32b4027006f16872f1b8e9e594060343a
created_at: 2026-06-06T15:09:08.542Z
code_workspace: {"path":"../SU-CCB-req-cmmq2a2x3p25029cbd6d21ff1","branch":"ccb/req-cmmq2a2x3p25029cbd6d21ff1"}
---

# API 类型对齐 + lint 参数化 + specs 同步（工程收尾）

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | slotCount/resize 响应/资格摘要前后端 API 类型对齐（web 侧类型就位、不做 UI）；lint_main_anchor_config.py slot 数量参数化；关联 specs 同步（e6d3663 涉及面反向 + slot-topology/slot-resize/mutation-lock 新服务 spec）。 |
| 需求来源 | cmmq2a2x3p25029cbd6d21ff1 |
| 本期范围 | pr6-engineering-finalize · API 类型对齐 + lint 参数化 + specs 同步（工程收尾） |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
工程收尾批：API 类型、lint、specs 三件套，为 pr7 UI 实施提供类型与规格基础。不含任何 UI 改动。

#### 任务分解
1. API 类型：slotCount/resize 响应/尾部资格摘要的前后端类型对齐（web 侧类型定义就位，UI 组件不动）。
2. lint_main_anchor_config.py：slot 数量参数化校验（3/4-slot config 均通过，畸形 config 仍报错）。
3. 关联 specs 同步：e6d3663 涉及面反向 + slot-topology/slot-resize/mutation-lock 新服务 spec；grep MANAGED_WINDOW_NAMES/SLOT_IDS 旧常量 stale 引用清零。

#### 验收标准
- server/web typecheck 全绿；web 既有测试全绿（无 UI 行为变化）。
- lint 双形态通过；specs 无 stale 引用（grep 旧常量残留为零）。

#### 边界与依赖
- 依赖：pr5。
- 不做 UI（pr7 范围）；不做 slotAgentOverrides 编辑 UI（第一版 YAGNI，已拍板范围外）。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-288cf7baa646
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
- Section: pr6-engineering-finalize
- Owner: ccb_codex
- Priority: medium
- Dependencies: subtask-288cf7baa646
