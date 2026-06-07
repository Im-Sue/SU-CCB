---
doc_type: dev_task
task_id: subtask-288cf7baa646
title: resize API + slots projection 扩展 + 绑定路径 lock 行为 + 后端 smoke
status: reviewing
current_node: implementation
node_substate: implementing
priority: high
requirement_id: cmmq2a2x3p25029cbd6d21ff1
section_id: pr5-resize-api-integration
order: 5
implementation_owner: ccb_codex
dependencies: [subtask-a00a63c9ef51, subtask-ec4511f2df83]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmmq2a2x3p25029cbd6d21ff1.json
source_draft_hash: d59d78137cdefb29c8589355c4c91fd32b4027006f16872f1b8e9e594060343a
created_at: 2026-06-06T15:09:08.542Z
updated_at: 2026-06-07T05:06:21.896Z
updated_by: slot3_claude
code_workspace: {"path":"../SU-CCB-req-cmmq2a2x3p25029cbd6d21ff1","branch":"ccb/req-cmmq2a2x3p25029cbd6d21ff1"}
---

# resize API + slots projection 扩展 + 绑定路径 lock 行为 + 后端 smoke

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 注册 POST /slots/resize（±1）、GET /slots projection 返回 slotCount+删除资格摘要（不新增单项目 GET 面）、bind/enqueue/worker 遇 resize lock 等待短超时超时 409、测试项目后端 smoke。 |
| 需求来源 | cmmq2a2x3p25029cbd6d21ff1 |
| 本期范围 | pr5-resize-api-integration · resize API + slots projection 扩展 + 绑定路径 lock 行为 + 后端 smoke |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
resize 能力接入 HTTP 与运行态：route 注册、projection 扩展、绑定路径与 resize lock 的冲突行为落地，并以测试项目完成首次端到端后端 smoke。

#### 任务分解
1. app.ts 注册 `POST /api/projects/:id/slots/resize` body `{direction: "grow"|"shrink"}`，调 SlotResizeService，返回新拓扑或结构化失败（资格不满足项/bridge 拒绝原因/离线 desired 已记录）。
2. `GET /api/projects/:id/slots` projection 扩展：slotCount + 尾部 slot 删除资格摘要（三重检查各项布尔，资格语义沿用 pr4——queue pending/submitted 含 su-cancel 行一律阻断）。不新增 `GET /api/projects/:id` 单项目路由（避免扩大 API 面）。
3. bind/enqueue/worker 路径接入 resize lock 可见性：遇 lock 持有等待短超时（默认 2s，常量可调）→ 超时返回/记录 409 语义（绑定重试由上游既有机制兜底）。
4. 后端 smoke（测试项目，不动主仓 .ccb/ccb.config）：grow → 绑定需求到新 slot → shrink 被拒（busy）→ 释放 → shrink 成功 → 再 grow；记录执行结果。

#### 验收标准
- route 集成测试：grow/shrink 成功、资格拒绝（结构化原因断言，含 queue 存在 su-cancel 行的阻断场景）、离线 desired。
- lock 冲突行为测试：lock 窗口内绑定等待成功；超时 409。
- smoke 通过并附记录（pane ready、其他 slot 无中断两个验证点必须显式确认）。

#### 边界与依赖
- 依赖：pr3（调度动态化）+ pr4（域逻辑）。
- UI 不在本批。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-a00a63c9ef51, subtask-ec4511f2df83
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
- Section: pr5-resize-api-integration
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-a00a63c9ef51, subtask-ec4511f2df83
