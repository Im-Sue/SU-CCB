---
doc_type: dev_task
task_id: subtask-716fe56c874a
title: WS/pump 接线:stream 模式端到端(mock 集成)+降级链
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq3euisf1b2a90a0b3e057f6
section_id: pr3-ws-wiring
order: 3
implementation_owner: ccb_codex
dependencies: [subtask-5b026e7c0a53, subtask-c71bb70bfe44]
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3euisf1b2a90a0b3e057f6.json
source_draft_hash: 5b17e632c20263f23fee037170e920a8f175a0492e816e1f2a23ce07ae72134e
created_at: 2026-06-07T10:04:47.173Z
updated_at: 2026-06-07T12:23:52.587Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq3euisf1b2a90a0b3e057f6","branch":"ccb/req-cmq3euisf1b2a90a0b3e057f6"}
---

# WS/pump 接线:stream 模式端到端(mock 集成)+降级链

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | per-pane 共享接线、stream/reset 下发、seam 顺序、hidden/visible cursor 补发、snapshot-fallback+Surface 提示、更新只读命令断言 |
| 需求来源 | cmq3euisf1b2a90a0b3e057f6 |
| 本期范围 | pr3-ws-wiring · WS/pump 接线:stream 模式端到端(mock 集成)+降级链 |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

WS/pump 接线:把 recorder 流接入 slot-terminal WS 通道,完成 stream 模式端到端(mock 层面),含降级与 reset 触发链。

### 任务分解

1. `slot-terminal.frame-stream.ts`:快照通道降频为 initial/reset/降级模式;接 recorder 订阅;seam 顺序:先开 pipe 缓冲,initial capture 完成后 flush(技设四章);resize(cols/rows 变)→reset 帧;gap→reset。
2. `slot-terminal.ws.ts`:per-connection pump → per-pane recorder 共享接线;stream/reset 帧序列化下发;mode 元数据透传;hidden/visible→订阅 pause/resume(server 侧 cursor 补发,无 client resume 协议)。
3. Surface 降级提示:复用 header 现有 status/error 槽位显示「历史受限(快照模式)」,不碰仲裁逻辑。
4. 自动集成测试:mock recorder + 现有 ws fixture;更新 ws.spec 既有「tmux backend only uses read-only capture-pane and display-message」断言(pipe-pane 加入只读命令白名单)。
5. 消费 pr1 协议 fixture 作为下发帧契约校验。

### 验收标准

- 自动集成(mock):连接→initial→stream 续发顺序正确(seam 无缺口);hidden→大量 chunk→visible 走 cursor 补发,超 ring 走 reset;槽位占用→snapshot-fallback 模式 + mode 元数据 + Surface 提示;resize→reset 帧;READ_ONLY 输入契约不变。
- 全仓 server+web 测试绿;tsc/lint 干净。

### 边界 / 不做项

不动 anchor-terminal;不跑真 tmux(pr4);不改输入/粘贴;无 client resume 协议。

> 派生自:技设四章流程 + 八章(server 侧)+ 协商 finding 5 与 seam/mode 归属项。

## 三、执行顺序 / 里程碑

- 前置依赖: subtask-5b026e7c0a53, subtask-c71bb70bfe44
- 执行顺序: 按本任务分解完成实现、验证、回执。

## 四、进度记录

| 日期 | 完成内容 | 遇到问题 | 下一步 |
|------|----------|----------|--------|
| 2026-06-07 | 物化任务文档 | 无 | 等待 dispatch 派工 |

## 五、验收标准

- [ ] 完成 `spec_section_md` 定义的实现范围。
- [ ] 保持 dev_task frontmatter 状态机字段由流程命令维护。
- [ ] 完成必要验证，并在回执中说明测试命令与结果。

## 六、风险与注意

| 风险 / 注意 | 影响 | 处理 |
|------|------|------|
| 任务范围与需求或技术设计不一致 | 返工或越界实现 | 实施前回读需求、设计和本任务 spec_section_md |

## Materialization Context

- Requirement: cmq3euisf1b2a90a0b3e057f6
- Section: pr3-ws-wiring
- Owner: ccb_codex
- Priority: high
- Dependencies: subtask-5b026e7c0a53, subtask-c71bb70bfe44
