---
doc_type: dev_task
task_id: subtask-ed0152d39ca1
title: SlotsPage resize UI + 最终 smoke 验收文档
status: reviewing
current_node: dispatch
node_substate: awaiting_codex_pickup
priority: medium
requirement_id: cmmq2a2x3p25029cbd6d21ff1
section_id: pr7-slots-ui
order: 7
implementation_owner: claude
dependencies: [subtask-288cf7baa646, subtask-a0e7528d9308]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmmq2a2x3p25029cbd6d21ff1.json
source_draft_hash: d59d78137cdefb29c8589355c4c91fd32b4027006f16872f1b8e9e594060343a
created_at: 2026-06-06T15:09:08.542Z
code_workspace: {"path":"../SU-CCB-req-cmmq2a2x3p25029cbd6d21ff1","branch":"ccb/req-cmmq2a2x3p25029cbd6d21ff1"}
---

# SlotsPage resize UI + 最终 smoke 验收文档

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | SlotsPage 动态 N lanes + ± 控件 + 缩容确认对话框（列资格三项）+ 失败 toast + slotCount>5 资源提示；最终手动 smoke 验收文档（含扩回旧会话不恢复验证）+ 完整执行记录。web UI 分工惯例由 claude 亲自实施。 |
| 需求来源 | cmmq2a2x3p25029cbd6d21ff1 |
| 本期范围 | pr7-slots-ui · SlotsPage resize UI + 最终 smoke 验收文档 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | claude |

## 二、任务分解

#### 任务概述
用户可见层：SlotsPage 完整 resize 交互与最终端到端手动验收。按项目分工惯例（web UI/UX 由 Claude 实施）owner 为 claude。

#### 任务分解
1. SlotsPage：动态渲染 N lanes；+/- 控件（grow 直接执行、shrink 弹确认对话框列出将回收 slot 与资格三项状态）；失败原因 toast（透出结构化原因，含 su-cancel 行阻断）；slotCount>5 时资源开销提示文案（每 slot = claude+codex 双常驻进程）。
2. 最终 smoke 手动验收文档：步骤（UI grow → 派需求 → UI shrink 被拒 → 释放 → shrink → grow）+ 三验证点（pane ready / **扩回旧会话不恢复**（缩容后扩回检查 pane 无旧对话上下文）/ 其他 slot 无中断）+ 附一次完整执行记录。

#### 验收标准
- web 测试：4-lane 渲染、控件交互、确认对话框、toast。
- smoke 文档可独立执行，附执行记录，三验证点显式通过。

#### 边界与依赖
- 依赖：pr5（API）+ pr6（类型/lint/specs 先行）。
- 不做 slotAgentOverrides 编辑 UI（第一版 YAGNI，已拍板范围外）。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-288cf7baa646, subtask-a0e7528d9308
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
- Section: pr7-slots-ui
- Owner: claude
- Priority: medium
- Dependencies: subtask-288cf7baa646, subtask-a0e7528d9308
