---
doc_type: dev_task
task_id: subtask-edaac0e2eed9
title: 后端·WS 共享核 + agent-terminal WS + audit additive
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmpxp7yyc6ff3ff4e15ea509d
section_id: pr2-backend-ws-shared-core-audit
order: 2
implementation_owner: ccb_codex
dependencies: [subtask-02d1b93cf363]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmpxp7yyc6ff3ff4e15ea509d.json
source_draft_hash: b83ac26ce80783efeb6d8c6b8c0dfe5c30d9aee1bc46b64a0a23dc6bd9ab5ca0
created_at: 2026-06-03T09:17:07.818Z
updated_at: 2026-06-03T10:28:40.443Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmpxp7yyc6ff3ff4e15ea509d","branch":"ccb/req-cmpxp7yyc6ff3ff4e15ea509d"}
---

# 后端·WS 共享核 + agent-terminal WS + audit additive

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 抽共享 WS handler 核+subscription resolver 泛化 target union+新增 /agent-terminal/ws 薄路由(不复制大函数)+WS 加固(Origin/拒控制/每写 guard)；audit additive contextKind/contextId。 |
| 需求来源 | cmpxp7yyc6ff3ff4e15ea509d |
| 本期范围 | pr2-backend-ws-shared-core-audit · 后端·WS 共享核 + agent-terminal WS + audit additive |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

#### 任务概述
复用现有 slot-terminal WS plumbing，暴露 main 终端读写通道；audit 兼容非 requirement context。承接技术设计 §四/§七/§八。**红线：共享核不复制 WS 大函数**；保留现有 WS 加固（Origin / 拒控制命令 / 只读铁律）。

#### 任务分解(后端)
- `slot-terminal.ws.ts`:
  - 抽共享 handler 核：把现有 `/api/slot-terminal/ws` 的 socket 生命周期、frame pump 接线、input queue(per-conn 串行)、错误/关闭处理抽成与 target 无关的复用核。
  - subscription resolver 泛化为 target union `{kind:"requirement", projectId, requirementId}` | `{kind:"agentGroup", projectId, group}`：requirement 分支走 `resolveRequirementTerminal`+`assertTargetBelongsTo`；agentGroup 分支走 `resolveAgentGroupTerminal`+`assertTargetBelongsToAgentGroup`(pr1)。
  - 新增薄路由 `GET /api/agent-terminal/ws?projectId=&group=&pane=`，复用共享核（**不复制大函数**）。
  - 保留 WS 加固到新端点：Origin 白名单(精确匹配 / fail-closed，防 CSWSH)、拒绝 resize / request_write / release_write / 任何改 client 尺寸或 attach 的控制消息(只读铁律)、每条 input 写前走 agent-group guard。
- `slot-terminal.input.ts`:
  - `SlotTerminalInputAuditEvent` additive 加 `contextKind`("requirement"|"agent-group") + `contextId`；`recordInput` 文件名按 context(`<contextKind>-<contextId>.jsonl`，main → `agent-group-main.jsonl`)。
  - requirement 路径**保留** `requirementId` 字段与原文件名(`<requirementId>.jsonl`)兼容 —— 不破坏现有测试 / 日志格式。writer(sendInput/sendPaste)零改。

#### 验收标准
- 集成：`/api/agent-terminal/ws?group=main&pane=claude` 帧推 + 输入回显 + 每条 input 写前 agent-group guard 生效。
- 集成：agent WS 同 requirement WS 一样 ① 启用 Origin 白名单(非法 Origin 拒)；② 拒 resize / request_write / release_write 等控制消息(只读铁律)。
- 单测/集成：audit 对 main 写 `agent-group-main.jsonl` 且含 contextKind/contextId；requirement 写入仍落 `<requirementId>.jsonl` 且事件含 requirementId(向后兼容)。
- 回归：requirement WS **外部可观察契约不变**(URL/query/`ready·frame·error·input·paste` 消息形态)，现有 requirement WS 集成测试全过。（注：共享核重构必然改 ws.ts 内部，故验收是「契约不变」**非「字节不变」**。）

#### 边界·不做项
- 不复制 WS 大函数(共享核)。
- 不改 pr1 的 service resolver / guard。
- 不引入全局写锁(单人取舍；多连接写交错为已知残余风险，回执列明)。

#### 依赖·Owner
依赖：pr1-backend-agent-group-resolver(用 resolveAgentGroupTerminal + assertTargetBelongsToAgentGroup)。owner：ccb_codex。
> 协议契约见 plan.spec_outline_md「共享协议契约」。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-02d1b93cf363
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-03 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmpxp7yyc6ff3ff4e15ea509d
- Section: pr2-backend-ws-shared-core-audit
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-02d1b93cf363
