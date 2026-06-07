---
doc_type: dev_task
task_id: subtask-5b026e7c0a53
title: 前端帧协议+渲染写入模型+scrollback 截断修复(P1)
status: done
current_node: archive
node_substate: archived
review_status: passed
priority: high
requirement_id: cmq3euisf1b2a90a0b3e057f6
section_id: pr1-protocol-renderer
order: 1
implementation_owner: ccb_codex
dependencies: []
source_breakdown_draft: docs/.ccb/drafts/breakdown/cmq3euisf1b2a90a0b3e057f6.json
source_draft_hash: 5b17e632c20263f23fee037170e920a8f175a0492e816e1f2a23ce07ae72134e
created_at: 2026-06-07T10:04:47.173Z
updated_at: 2026-06-07T10:31:26.264Z
updated_by: ccb_claude
code_workspace: {"path":"../SU-CCB-req-cmq3euisf1b2a90a0b3e057f6","branch":"ccb/req-cmq3euisf1b2a90a0b3e057f6"}
---

# 前端帧协议+渲染写入模型+scrollback 截断修复(P1)

> 本文档由 breakdown draft 物化生成；frontmatter 承载任务状态，正文按开发任务模板组织。

## 一、任务概述

| 项 | 说明 |
|----|------|
| 交付目标 | 三类帧 parse/分派/写入(stream 有序直写,initial/reset 统一 terminal.reset 重灌),client 帧分派,scrollback 2500,协议 fixture 供后续切片复用 |
| 需求来源 | cmq3euisf1b2a90a0b3e057f6 |
| 本期范围 | pr1-protocol-renderer · 前端帧协议+渲染写入模型+scrollback 截断修复(P1) |
| 不含范围 | 未在本子任务 spec_section_md 中声明的内容 |
| 预计工期 | 未估算 |
| 分工 | ccb_codex |

## 二、任务分解

### 任务概述

前端帧协议与渲染写入模型改造 + scrollback 截断修复(P1)。为 B-full-lite hybrid(td-e057f6)建立前端侧契约:三类帧(snapshot/stream/reset)的 parse、分派与写入;协议 fixture 作为 pr3/pr4 的共享契约。

### 任务分解

1. `web/src/types/slot-terminal.ts`:帧类型扩展——kind:"stream"(data、seq? 仅诊断)/"reset"(reason + snapshot 字段);无 kind = snapshot 向后兼容;mode 元数据("stream"|"snapshot-fallback")。
2. `web/src/lib/slot-terminal-ws.ts`:stream/reset 帧 parse 与回调分派,与现有 SlotTerminalSnapshotFrame 回调兼容。
3. `SlotTerminalFrameRenderer.ts` 写入模型:stream 帧有序直写 terminal.write(同一 RAF 周期多 chunk 不丢、不乱序——现行单 pendingFrame RAF 合批仅保留给 snapshot/reset);initial 与 reset 统一路径:terminal.reset() 全复位(清 mouse-tracking/bracketed paste/SGR 模式污染)后写深快照重灌(技设 D6);贴底沿用双底部判定,用户上滚中 stream 写入不拽视口。
4. `useXtermTerminal.ts`:scrollback 1000 → SLOT_TERMINAL_SCROLLBACK=2500 常量(P1,技设 D7)。
5. 协议 fixture/测试向量(snapshot/stream/reset/fallback 序列样本),供 pr3/pr4 双侧复用(4d8a20 同测试向量先例)。

### 验收标准

- 单测:三类帧状态机;同 RAF 周期 N 个 stream 帧逐字有序写入;initial/reset 后无模式残留(注入 mouse-tracking/SGR/宽字符后 reset 断言);上滚(viewportY<baseY)时 stream 写入不改 ydisp;贴底时跟随;无 kind 帧按 snapshot 处理。
- 现有 slot-terminal 测试全绿;tsc/lint 干净;fixture 落地并被本 PR 单测消费(契约自证)。

### 边界 / 不做项

不动 SlotTerminalSurface 滚动仲裁(06c62eb 回归红线);不动 server 任何文件;stream/reset 帧本 PR 无生产者(fixture 即契约);不实现 client resume(技设 v1 简化)。

> 派生自:技设 td-e057f6 八章(web 侧)+ breakdown 协商 job_6a4e5c3c62e4 findings 1-3。

## 三、执行顺序 / 里程碑

- 前置依赖: 无
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
- Section: pr1-protocol-renderer
- Owner: ccb_codex
- Priority: high
- Dependencies: none
